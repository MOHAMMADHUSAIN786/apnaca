export type LlmRole = "system" | "user" | "assistant" | "tool";

export interface LlmMessage {
  role: LlmRole;
  content: string;
  /** assistant turns that requested tools */
  toolCalls?: ToolCall[];
  /** for role:"tool" — which call this answers */
  toolCallId?: string;
}

export interface ToolCall {
  id: string;
  name: string;
  /** parsed arguments */
  args: Record<string, unknown>;
}

/** JSON-schema description handed to the model. */
export interface ToolSchema {
  name: string;
  description: string;
  parameters: Record<string, unknown>; // JSON Schema object
}

export interface GenerateInput {
  system: string;
  messages: LlmMessage[];
  tools: ToolSchema[];
  /** upper bound on the model's reply */
  maxTokens?: number;
  temperature?: number;
  signal?: AbortSignal;
  /** called with each text delta as it streams in */
  onDelta?: (text: string) => void;
}

export interface Usage {
  tokensIn: number;
  tokensOut: number;
}

export interface GenerateOutput {
  text: string;
  toolCalls: ToolCall[];
  finishReason: "stop" | "tool_calls" | "length" | "other";
  usage: Usage;
  model: string;
}

export interface LlmProvider {
  readonly name: string;
  generate(input: GenerateInput, model: string): Promise<GenerateOutput>;
}
