import { config } from "../config.js";
import type { TenantContext } from "../auth/tenant.js";
import { generate, pickTier } from "../llm/router.js";
import type { LlmMessage, ToolCall } from "../llm/types.js";
import {
  getTool,
  toolSchemasFor,
  type BusinessContext,
  type RenderCard,
  type ToolContext,
} from "../tools/registry.js";
import { recordLlmUsage, recordToolExecution } from "../observability/usage.js";
import { logger } from "../observability/logger.js";
import { buildDataMessage, buildSystemPrompt } from "./prompt.js";

export type AgentEvent =
  | { type: "step_start"; step: number }
  | { type: "text_delta"; text: string }
  | { type: "tool_call"; step: number; name: string; args: Record<string, unknown> }
  | { type: "tool_result"; step: number; name: string; status: string }
  | { type: "card"; card: RenderCard }
  | { type: "message"; text: string }
  | { type: "error"; message: string }
  | {
      type: "done";
      text: string;
      proposedActions: ProposedAction[];
      cards: RenderCard[];
      usage: { tokensIn: number; tokensOut: number };
    };

export interface ProposedAction {
  id: string;
  tool: string;
  args: Record<string, unknown>;
  /** client must show a confirm dialog before applying */
  requiresConfirmation: boolean;
}

export interface RunAgentTurnInput {
  tenant: TenantContext;
  conversationId: string;
  history: LlmMessage[];
  userMessage: string;
  business: BusinessContext;
  signal: AbortSignal;
  emit: (e: AgentEvent) => void;
}

export interface RunAgentTurnResult {
  finalText: string;
  proposedActions: ProposedAction[];
  cards: RenderCard[];
  newMessages: LlmMessage[];
  usage: { tokensIn: number; tokensOut: number };
}

let actionSeq = 0;

export async function runAgentTurn(
  input: RunAgentTurnInput,
): Promise<RunAgentTurnResult> {
  const { tenant, conversationId, userMessage, business, signal, emit } = input;

  const system = buildSystemPrompt(tenant);
  const tools = toolSchemasFor(tenant);

  const messages: LlmMessage[] = [
    buildDataMessage(business),
    ...input.history,
    { role: "user", content: userMessage },
  ];
  const newMessages: LlmMessage[] = [{ role: "user", content: userMessage }];
  const proposedActions: ProposedAction[] = [];
  const cards: RenderCard[] = [];
  const usage = { tokensIn: 0, tokensOut: 0 };

  let hadToolResults = false;

  for (let step = 0; step < config.MAX_AGENT_STEPS; step++) {
    if (signal.aborted) break;
    emit({ type: "step_start", step });

    const tier = pickTier({ step, userMessage, hadToolResults });
    const out = await generate(
      {
        system,
        messages,
        tools,
        signal,
        onDelta: (text) => emit({ type: "text_delta", text }),
      },
      tier,
    );

    usage.tokensIn += out.usage.tokensIn;
    usage.tokensOut += out.usage.tokensOut;
    void recordLlmUsage({
      tenant,
      model: out.model,
      tokensIn: out.usage.tokensIn,
      tokensOut: out.usage.tokensOut,
    });

    // No tool calls → the model answered. Done.
    if (out.toolCalls.length === 0) {
      emit({ type: "message", text: out.text });
      newMessages.push({ role: "assistant", content: out.text });
      emit({ type: "done", text: out.text, proposedActions, cards, usage });
      return { finalText: out.text, proposedActions, cards, newMessages, usage };
    }

    // Record the assistant's tool-call turn.
    const assistantTurn: LlmMessage = {
      role: "assistant",
      content: out.text,
      toolCalls: out.toolCalls,
    };
    messages.push(assistantTurn);
    newMessages.push(assistantTurn);

    for (const call of out.toolCalls) {
      const result = await executeToolCall({
        call,
        step,
        tenant,
        conversationId,
        business,
        emit,
      });
      if (result.kind === "proposed") {
        proposedActions.push(result.action);
      }
      if (result.kind === "value" && result.card) {
        cards.push(result.card);
        emit({ type: "card", card: result.card });
      }
      hadToolResults = true;
      const toolMsg: LlmMessage = {
        role: "tool",
        toolCallId: call.id,
        content: JSON.stringify(result.payload),
      };
      messages.push(toolMsg);
      newMessages.push(toolMsg);
    }
  }

  // Ran out of steps.
  const text =
    "Main is request ko poora nahi kar paaya (kaafi steps ho gaye). Thoda simple tarike se batayein.";
  emit({ type: "message", text });
  emit({ type: "done", text, proposedActions, cards, usage });
  return { finalText: text, proposedActions, cards, newMessages, usage };
}

async function executeToolCall(args: {
  call: ToolCall;
  step: number;
  tenant: TenantContext;
  conversationId: string;
  business: BusinessContext;
  emit: (e: AgentEvent) => void;
}): Promise<
  | { kind: "value"; payload: unknown; card?: RenderCard }
  | { kind: "proposed"; action: ProposedAction; payload: unknown }
> {
  const { call, step, tenant, conversationId, business, emit } = args;
  const started = Date.now();
  emit({ type: "tool_call", step, name: call.name, args: call.args });

  const tool = getTool(call.name);
  if (!tool) {
    emit({ type: "tool_result", step, name: call.name, status: "unknown" });
    return { kind: "value", payload: { error: `Unknown tool "${call.name}"` } };
  }

  // Permission — authoritative, server-side.
  if (tool.requiresPermission && !tenant.can(tool.requiresPermission)) {
    void recordToolExecution({
      tenant,
      conversationId,
      tool: call.name,
      args: call.args,
      status: "denied",
      latencyMs: Date.now() - started,
    });
    emit({ type: "tool_result", step, name: call.name, status: "denied" });
    return {
      kind: "value",
      payload: { error: "permission_denied", detail: `role ${tenant.role} cannot ${call.name}` },
    };
  }

  // Validate args.
  const parsed = tool.schema.safeParse(call.args);
  if (!parsed.success) {
    emit({ type: "tool_result", step, name: call.name, status: "invalid_args" });
    return {
      kind: "value",
      payload: {
        error: "invalid_args",
        issues: parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`),
      },
    };
  }

  const ctx: ToolContext = { tenant, business, conversationId };
  let result;
  try {
    result = await tool.run(parsed.data, ctx);
  } catch (err) {
    logger.error({ err, tool: call.name }, "tool handler threw");
    emit({ type: "tool_result", step, name: call.name, status: "error" });
    return { kind: "value", payload: { error: "tool_failed" } };
  }

  void recordToolExecution({
    tenant,
    conversationId,
    tool: call.name,
    args: parsed.data,
    status: result.status === "proposed" ? "pending" : result.status,
    latencyMs: Date.now() - started,
  });
  emit({ type: "tool_result", step, name: call.name, status: result.status });

  if (result.status === "proposed") {
    const action: ProposedAction = {
      id: `act_${Date.now()}_${actionSeq++}`,
      tool: result.action.tool,
      args: result.action.args,
      requiresConfirmation: tool.category === "destructive",
    };
    return {
      kind: "proposed",
      action,
      payload: {
        status: "proposed",
        note: "Queued for the user to confirm/apply in the app.",
        action: { id: action.id, tool: action.tool },
      },
    };
  }

  return {
    kind: "value",
    payload: result,
    card: result.status === "ok" ? result.card : undefined,
  };
}
