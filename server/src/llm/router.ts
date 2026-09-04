import { config } from "../config.js";
import { logger } from "../observability/logger.js";
import { openRouterProvider } from "./openrouter.js";
import type { GenerateInput, GenerateOutput, LlmProvider } from "./types.js";

export type Tier = "fast" | "standard" | "advanced";

const MODEL_BY_TIER: Record<Tier, string> = {
  fast: config.LLM_MODEL_FAST,
  standard: config.LLM_MODEL_STANDARD,
  advanced: config.LLM_MODEL_ADVANCED,
};

// Ordered fallback chain. Today only OpenRouter; add Anthropic/Vertex here.
const PROVIDERS: LlmProvider[] = [openRouterProvider];

/**
 * Cheap heuristic tier picker. Step 0 uses this; later steps that already
 * have tool results usually only need to compose a reply → keep them cheap.
 * TODO: replace with a tiny trained classifier fed by eval data.
 */
export function pickTier(opts: {
  step: number;
  userMessage: string;
  hadToolResults: boolean;
}): Tier {
  if (opts.step > 0 && opts.hadToolResults) return "standard";
  const msg = opts.userMessage.toLowerCase();
  const complex =
    msg.length > 240 ||
    /\b(and then|uske baad|phir|compare|analyse|analyze|reconcile|draft|plan)\b/.test(
      msg,
    );
  return complex ? "advanced" : "standard";
}

/** Runs the tier's model, falling back down the provider chain on failure. */
export async function generate(
  input: GenerateInput,
  tier: Tier,
): Promise<GenerateOutput> {
  const model = MODEL_BY_TIER[tier];
  let lastErr: unknown;
  for (const provider of PROVIDERS) {
    try {
      return await provider.generate(input, model);
    } catch (err) {
      lastErr = err;
      logger.warn({ err, provider: provider.name, model }, "provider failed, trying next");
    }
  }
  throw lastErr instanceof Error ? lastErr : new Error("all LLM providers failed");
}
