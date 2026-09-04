import { Hono } from "hono";
import { logger } from "../observability/logger.js";
import { activateFromOrder } from "../billing/activate.js";
import { billingEnabled, verifyWebhookSignature } from "../billing/razorpay.js";

export const webhooks = new Hono();

// ── POST /webhooks/razorpay ─────────────────────────────────────────────────
// NO auth middleware — authenticity is the HMAC signature over the raw body.
webhooks.post("/razorpay", async (c) => {
  if (!billingEnabled()) return c.json({ ok: false }, 503);

  const raw = await c.req.text();
  const sig = c.req.header("x-razorpay-signature") ?? "";

  if (!verifyWebhookSignature(raw, sig)) {
    logger.warn("razorpay webhook: bad signature");
    return c.json({ error: "bad signature" }, 400);
  }

  let body: Record<string, unknown>;
  try {
    body = JSON.parse(raw);
  } catch {
    return c.json({ error: "bad json" }, 400);
  }

  const event = body["event"] as string | undefined;
  const payload = (body["payload"] ?? {}) as Record<string, unknown>;
  const payment = ((payload["payment"] as Record<string, unknown>)?.["entity"] ??
    {}) as Record<string, unknown>;
  const orderEntity = ((payload["order"] as Record<string, unknown>)?.["entity"] ??
    {}) as Record<string, unknown>;

  const orderId =
    (payment["order_id"] as string | undefined) ??
    (orderEntity["id"] as string | undefined);
  const paymentId = payment["id"] as string | undefined;

  logger.info({ event, orderId, paymentId }, "razorpay webhook");

  // Only act on a successful payment. Ack everything else with 200 so Razorpay
  // stops retrying.
  if (
    (event === "payment.captured" || event === "order.paid") &&
    orderId &&
    paymentId
  ) {
    try {
      const res = await activateFromOrder(orderId, paymentId);
      return c.json({ ok: true, ...res });
    } catch (err) {
      logger.error({ err, orderId }, "activation failed");
      // 500 → Razorpay retries, which is what we want for a transient failure.
      return c.json({ ok: false }, 500);
    }
  }

  return c.json({ ok: true, ignored: event ?? "unknown" });
});
