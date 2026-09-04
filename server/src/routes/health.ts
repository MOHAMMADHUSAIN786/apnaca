import { Hono } from "hono";
import { pool } from "../db/client.js";

export const health = new Hono();

health.get("/healthz", (c) => c.json({ ok: true }));

health.get("/readyz", async (c) => {
  try {
    await pool.query("select 1");
    return c.json({ ok: true, db: "up" });
  } catch {
    return c.json({ ok: false, db: "down" }, 503);
  }
});
