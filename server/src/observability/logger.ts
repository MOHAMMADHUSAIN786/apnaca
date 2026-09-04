import pino from "pino";
import { config } from "../config.js";

export const logger = pino({
  level: config.LOG_LEVEL,
  // Cloud Logging picks up `severity`; keep JSON in production.
  ...(config.NODE_ENV === "development"
    ? { transport: { target: "pino-pretty", options: { colorize: true } } }
    : {}),
  redact: {
    paths: [
      "req.headers.authorization",
      "*.OPENROUTER_KEY",
      "*.apiKey",
      "*.token",
      "context.customers",
      "context.items",
    ],
    censor: "[redacted]",
  },
});

export type Logger = typeof logger;
