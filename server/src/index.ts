import { serve } from "@hono/node-server";
import { config } from "./config.js";
import { logger } from "./observability/logger.js";
import { buildApp } from "./http/app.js";
import { registerReadTools } from "./tools/read.js";
import { registerWriteTools } from "./tools/write.js";
import { closeDb } from "./db/client.js";

registerReadTools();
registerWriteTools();

const app = buildApp();

const server = serve({ fetch: app.fetch, port: config.PORT }, (info) => {
  logger.info({ port: info.port, env: config.NODE_ENV }, "agent gateway listening");
});

async function shutdown(sig: string): Promise<void> {
  logger.info({ sig }, "shutting down");
  server.close();
  await closeDb();
  process.exit(0);
}

process.on("SIGTERM", () => void shutdown("SIGTERM"));
process.on("SIGINT", () => void shutdown("SIGINT"));
