import { Hono } from "hono";
import { streamSSE } from "hono/streaming";
import { HTTPException } from "hono/http-exception";
import { z } from "zod";
import { and, asc, desc, eq } from "drizzle-orm";
import { db, schema } from "../db/client.js";
import { tenantMiddleware, type TenantContext } from "../auth/tenant.js";
import { runAgentTurn, type AgentEvent } from "../agent/orchestrator.js";
import type { BusinessContext } from "../tools/registry.js";
import type { LlmMessage } from "../llm/types.js";
import { recordAudit } from "../observability/usage.js";
import { logger } from "../observability/logger.js";

export const agent = new Hono<{ Variables: { tenant: TenantContext } }>();
agent.use("*", tenantMiddleware);

const HISTORY_LIMIT = 16;

const chatBody = z.object({
  conversationId: z.string().uuid().nullable().default(null),
  message: z.string().trim().min(1).max(2000),
  context: z
    .object({
      items: z.array(z.record(z.unknown())).optional(),
      customers: z.array(z.record(z.unknown())).optional(),
      suppliers: z.array(z.record(z.unknown())).optional(),
      recentBills: z.array(z.record(z.unknown())).optional(),
      analytics: z.record(z.unknown()).optional(),
    })
    .default({}),
});

async function loadHistory(conversationId: string): Promise<LlmMessage[]> {
  const rows = await db
    .select()
    .from(schema.messages)
    .where(eq(schema.messages.conversationId, conversationId))
    .orderBy(desc(schema.messages.createdAt))
    .limit(HISTORY_LIMIT);

  return rows
    .reverse()
    .filter((r) => r.role === "user" || r.role === "assistant")
    .map((r) => ({ role: r.role as "user" | "assistant", content: r.content }));
}

async function ensureConversation(
  tenant: TenantContext,
  conversationId: string | null,
  firstMessage: string,
): Promise<string> {
  if (conversationId) {
    const [row] = await db
      .select({ id: schema.conversations.id, tenantId: schema.conversations.tenantId })
      .from(schema.conversations)
      .where(eq(schema.conversations.id, conversationId))
      .limit(1);
    if (!row) throw new HTTPException(404, { message: "conversation not found" });
    if (row.tenantId !== tenant.tenantId)
      throw new HTTPException(403, { message: "not your conversation" });
    return conversationId;
  }
  const [created] = await db
    .insert(schema.conversations)
    .values({
      tenantId: tenant.tenantId,
      userUid: tenant.userUid,
      title: firstMessage.slice(0, 80),
    })
    .returning({ id: schema.conversations.id });
  return created!.id;
}

async function persistTurn(
  conversationId: string,
  tenantId: string,
  msgs: LlmMessage[],
  tokens: { tokensIn: number; tokensOut: number },
): Promise<void> {
  if (msgs.length === 0) return;
  await db.insert(schema.messages).values(
    msgs.map((m, i) => ({
      conversationId,
      tenantId,
      role: m.role,
      content: m.content,
      toolCalls: m.toolCalls ?? null,
      // attribute all output tokens to the last row for a rough per-turn view
      tokensIn: i === 0 ? tokens.tokensIn : 0,
      tokensOut: i === msgs.length - 1 ? tokens.tokensOut : 0,
    })),
  );
  await db
    .update(schema.conversations)
    .set({ lastAt: new Date() })
    .where(eq(schema.conversations.id, conversationId));
}

// ── POST /v1/agent/chat  (SSE) ──────────────────────────────────────────────
agent.post("/chat", async (c) => {
  const tenant = c.get("tenant");
  const parsed = chatBody.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) {
    throw new HTTPException(400, { message: parsed.error.issues[0]?.message ?? "bad body" });
  }
  const { message, context } = parsed.data;

  // TODO: server-authoritative quota check against the plan here.

  const conversationId = await ensureConversation(
    tenant,
    parsed.data.conversationId,
    message,
  );
  const history = await loadHistory(conversationId);

  return streamSSE(c, async (stream) => {
    const ac = new AbortController();
    stream.onAbort(() => ac.abort());

    const send = (e: AgentEvent) =>
      stream.writeSSE({ event: e.type, data: JSON.stringify(e) });

    await send({ type: "step_start", step: -1 } as AgentEvent); // "connected" ping
    await stream.writeSSE({ event: "conversation", data: JSON.stringify({ conversationId }) });

    try {
      const result = await runAgentTurn({
        tenant,
        conversationId,
        history,
        userMessage: message,
        business: context as BusinessContext,
        signal: ac.signal,
        emit: (e) => void send(e),
      });

      await persistTurn(conversationId, tenant.tenantId, result.newMessages, result.usage);
      void recordAudit({
        tenant,
        action: "agent.chat",
        target: conversationId,
        result: `proposed=${result.proposedActions.length}`,
      });
    } catch (err) {
      logger.error({ err }, "agent turn failed");
      await send({ type: "error", message: "Agent request failed. Try again." });
    }
  });
});

// ── POST /v1/agent/actions/ack ──────────────────────────────────────────────
// The client reports which proposed actions it actually applied to local
// SQLite (after any confirmation dialog). We record them for audit + metering.
const ackBody = z.object({
  conversationId: z.string().uuid(),
  applied: z
    .array(
      z.object({
        tool: z.string(),
        args: z.record(z.unknown()),
        result: z.enum(["applied", "rejected", "failed"]),
      }),
    )
    .max(20),
});

agent.post("/actions/ack", async (c) => {
  const tenant = c.get("tenant");
  const parsed = ackBody.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) throw new HTTPException(400, { message: "bad body" });

  for (const a of parsed.data.applied) {
    await recordAudit({
      tenant,
      action: `apply.${a.tool}`,
      target: parsed.data.conversationId,
      args: a.args,
      result: a.result,
    });
  }
  return c.json({ ok: true, recorded: parsed.data.applied.length });
});

// ── GET /v1/agent/conversations ─────────────────────────────────────────────
agent.get("/conversations", async (c) => {
  const tenant = c.get("tenant");
  const rows = await db
    .select()
    .from(schema.conversations)
    .where(eq(schema.conversations.tenantId, tenant.tenantId))
    .orderBy(desc(schema.conversations.lastAt))
    .limit(50);
  return c.json({ conversations: rows });
});

// ── GET /v1/agent/conversations/:id/messages ────────────────────────────────
agent.get("/conversations/:id/messages", async (c) => {
  const tenant = c.get("tenant");
  const id = c.req.param("id");
  const rows = await db
    .select()
    .from(schema.messages)
    .where(
      and(eq(schema.messages.conversationId, id), eq(schema.messages.tenantId, tenant.tenantId)),
    )
    .orderBy(asc(schema.messages.createdAt))
    .limit(500);
  return c.json({ messages: rows });
});
