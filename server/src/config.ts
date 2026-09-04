import { z } from "zod";

const schema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().positive().default(8080),
  LOG_LEVEL: z
    .enum(["fatal", "error", "warn", "info", "debug", "trace"])
    .default("info"),

  OPENROUTER_KEY: z.string().min(1, "OPENROUTER_KEY is required"),
  OPENROUTER_BASE_URL: z.string().url().default("https://openrouter.ai/api/v1"),
  LLM_MODEL_FAST: z.string().default("google/gemini-2.5-flash"),
  LLM_MODEL_STANDARD: z.string().default("google/gemini-2.5-flash"),
  LLM_MODEL_ADVANCED: z.string().default("anthropic/claude-sonnet-4"),
  MAX_AGENT_STEPS: z.coerce.number().int().min(1).max(20).default(5),

  FIREBASE_PROJECT_ID: z.string().min(1),
  GOOGLE_APPLICATION_CREDENTIALS: z.string().optional(),

  DATABASE_URL: z.string().url(),

  // Razorpay — server-only. Billing routes return 503 until all three are set.
  RAZORPAY_KEY_ID: z.string().optional(),
  RAZORPAY_KEY_SECRET: z.string().optional(),
  RAZORPAY_WEBHOOK_SECRET: z.string().optional(),

  CORS_ORIGINS: z
    .string()
    .default("")
    .transform((s) =>
      s
        .split(",")
        .map((v) => v.trim())
        .filter(Boolean),
    ),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  // eslint-disable-next-line no-console
  console.error(
    "Invalid environment:\n" +
      parsed.error.issues.map((i) => `  ${i.path.join(".")}: ${i.message}`).join("\n"),
  );
  process.exit(1);
}

export const config = parsed.data;
export type Config = typeof config;
