import OpenAI from "openai";
import { config } from "../config.js";
import type {
  GenerateInput,
  GenerateOutput,
  LlmProvider,
  LlmMessage,
  ToolCall,
} from "./types.js";

// OpenRouter is OpenAI-compatible, so we reuse the OpenAI SDK and its
// tool-calling types. Swapping to native Anthropic later is a new provider
// module implementing the same LlmProvider interface.
const client = new OpenAI({
  apiKey: config.OPENROUTER_KEY,
  baseURL: config.OPENROUTER_BASE_URL,
  defaultHeaders: {
    "HTTP-Referer": "https://apnaca.app",
    "X-Title": "ApnaCA Agent Gateway",
  },
});

function toOpenAiMessages(
  system: string,
  messages: LlmMessage[],
): OpenAI.Chat.ChatCompletionMessageParam[] {
  const out: OpenAI.Chat.ChatCompletionMessageParam[] = [
    { role: "system", content: system },
  ];
  for (const m of messages) {
    if (m.role === "tool") {
      out.push({
        role: "tool",
        tool_call_id: m.toolCallId ?? "",
        content: m.content,
      });
    } else if (m.role === "assistant" && m.toolCalls?.length) {
      out.push({
        role: "assistant",
        content: m.content || null,
        tool_calls: m.toolCalls.map((tc) => ({
          id: tc.id,
          type: "function",
          function: { name: tc.name, arguments: JSON.stringify(tc.args) },
        })),
      });
    } else if (m.role === "assistant" || m.role === "user") {
      out.push({ role: m.role, content: m.content });
    }
  }
  return out;
}

function parseToolCalls(
  raw: OpenAI.Chat.ChatCompletionMessageToolCall[] | undefined,
): ToolCall[] {
  if (!raw?.length) return [];
  const calls: ToolCall[] = [];
  for (const tc of raw) {
    if (tc.type !== "function") continue;
    let args: Record<string, unknown> = {};
    try {
      args = tc.function.arguments ? JSON.parse(tc.function.arguments) : {};
    } catch {
      args = { __unparsed: tc.function.arguments };
    }
    calls.push({ id: tc.id, name: tc.function.name, args });
  }
  return calls;
}

interface ToolCallAccum {
  id: string;
  name: string;
  args: string;
}

export const openRouterProvider: LlmProvider = {
  name: "openrouter",

  async generate(input: GenerateInput, model: string): Promise<GenerateOutput> {
    const stream = await client.chat.completions.create(
      {
        model,
        messages: toOpenAiMessages(input.system, input.messages),
        tools: input.tools.map((t) => ({
          type: "function",
          function: {
            name: t.name,
            description: t.description,
            parameters: t.parameters,
          },
        })),
        tool_choice: input.tools.length ? "auto" : undefined,
        temperature: input.temperature ?? 0.2,
        max_tokens: input.maxTokens ?? 1024,
        stream: true,
        stream_options: { include_usage: true },
      },
      { signal: input.signal },
    );

    let text = "";
    let finishReason: GenerateOutput["finishReason"] = "other";
    const toolAccum = new Map<number, ToolCallAccum>();
    const usage = { tokensIn: 0, tokensOut: 0 };

    for await (const chunk of stream) {
      if (chunk.usage) {
        usage.tokensIn = chunk.usage.prompt_tokens ?? usage.tokensIn;
        usage.tokensOut = chunk.usage.completion_tokens ?? usage.tokensOut;
      }
      const choice = chunk.choices[0];
      if (!choice) continue;

      const delta = choice.delta;
      if (delta?.content) {
        text += delta.content;
        input.onDelta?.(delta.content);
      }
      for (const tc of delta?.tool_calls ?? []) {
        const idx = tc.index ?? 0;
        const cur = toolAccum.get(idx) ?? { id: "", name: "", args: "" };
        if (tc.id) cur.id = tc.id;
        if (tc.function?.name) cur.name = tc.function.name;
        if (tc.function?.arguments) cur.args += tc.function.arguments;
        toolAccum.set(idx, cur);
      }
      if (choice.finish_reason) {
        finishReason =
          choice.finish_reason === "tool_calls"
            ? "tool_calls"
            : choice.finish_reason === "stop"
              ? "stop"
              : choice.finish_reason === "length"
                ? "length"
                : "other";
      }
    }

    const toolCalls = parseToolCalls(
      [...toolAccum.values()].map((t) => ({
        id: t.id || `call_${t.name}`,
        type: "function" as const,
        function: { name: t.name, arguments: t.args },
      })),
    );

    return {
      text,
      toolCalls,
      finishReason: toolCalls.length ? "tool_calls" : finishReason,
      usage,
      model,
    };
  },
};
