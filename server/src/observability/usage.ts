import { createHash } from "node:crypto";
import { db, schema } from "../db/client.js";
import { logger } from "./logger.js";
import type { TenantContext } from "../auth/tenant.js";

export function argsHash(args: unknown): string {
  return createHash("sha256").update(JSON.stringify(args ?? {})).digest("hex").slice(0, 32);
}

export async function recordLlmUsage(opts: {
  tenant: TenantContext;
  model: string;
  tokensIn: number;
  tokensOut: number;
  costMicros?: number;
}): Promise<void> {
  try {
    await db.insert(schema.usageEvents).values({
      tenantId: opts.tenant.tenantId,
      userUid: opts.tenant.userUid,
      kind: "llm_call",
      model: opts.model,
      tokensIn: opts.tokensIn,
      tokensOut: opts.tokensOut,
      costMicros: opts.costMicros ?? 0,
    });
  } catch (err) {
    logger.error({ err }, "failed to record llm usage");
  }
}

export async function recordToolExecution(opts: {
  tenant: TenantContext;
  conversationId: string | null;
  tool: string;
  args: unknown;
  status: "ok" | "error" | "denied" | "pending";
  latencyMs: number;
}): Promise<void> {
  try {
    await db.insert(schema.toolExecutions).values({
      tenantId: opts.tenant.tenantId,
      conversationId: opts.conversationId ?? null,
      tool: opts.tool,
      argsHash: argsHash(opts.args),
      resultStatus: opts.status,
      latencyMs: opts.latencyMs,
    });
  } catch (err) {
    logger.error({ err }, "failed to record tool execution");
  }
}

export async function recordAudit(opts: {
  tenant: Pick<TenantContext, "tenantId" | "userUid">;
  action: string;
  target?: string;
  args?: unknown;
  result: string;
}): Promise<void> {
  try {
    await db.insert(schema.auditLog).values({
      tenantId: opts.tenant.tenantId,
      actorUid: opts.tenant.userUid,
      action: opts.action,
      target: opts.target ?? null,
      argsHash: opts.args ? argsHash(opts.args) : null,
      result: opts.result,
    });
  } catch (err) {
    logger.error({ err }, "failed to record audit");
  }
}
