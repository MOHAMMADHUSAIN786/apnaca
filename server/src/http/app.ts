import { Hono } from "hono";
import { cors } from "hono/cors";
import { HTTPException } from "hono/http-exception";
import { config } from "../config.js";
import { logger } from "../observability/logger.js";
import { health } from "../routes/health.js";
import { agent } from "../routes/agent.js";
import { billing } from "../routes/billing.js";
import { webhooks } from "../routes/webhooks.js";

export function buildApp(): Hono {
  const app = new Hono();

  // Basic request logging.
  app.use("*", async (c, next) => {
    const start = Date.now();
    await next();
    logger.info(
      { method: c.req.method, path: c.req.path, status: c.res.status, ms: Date.now() - start },
      "request",
    );
  });

  if (config.CORS_ORIGINS.length) {
    app.use("*", cors({ origin: config.CORS_ORIGINS, allowHeaders: ["Authorization", "Content-Type"] }));
  }

  app.route("/", health);
  app.route("/v1/agent", agent);
  app.route("/v1/billing", billing);
  app.route("/webhooks", webhooks);

  app.onError((err, c) => {
    if (err instanceof HTTPException) {
      return c.json({ error: err.message }, err.status);
    }
    logger.error({ err }, "unhandled error");
    return c.json({ error: "internal_error" }, 500);
  });

  app.notFound((c) => c.json({ error: "not_found" }, 404));

  return app;
}
