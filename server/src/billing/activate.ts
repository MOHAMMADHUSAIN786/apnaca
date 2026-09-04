import { FieldValue } from "firebase-admin/firestore";
import { eq } from "drizzle-orm";
import { adminFirestore } from "../auth/firebase.js";
import { db, schema } from "../db/client.js";
import { logger } from "../observability/logger.js";
import { recordAudit } from "../observability/usage.js";
import { expiryFor, type Cycle, type Plan } from "./prices.js";

/**
 * Activates a paid subscription. Called ONLY from the verified webhook.
 * Idempotent: a second call for the same order (Razorpay retries) is a no-op.
 * The Admin SDK write bypasses security rules, so the client cannot forge this.
 */
export async function activateFromOrder(
  orderId: string,
  razorpayPaymentId: string,
): Promise<{ activated: boolean; reason?: string }> {
  const [order] = await db
    .select()
    .from(schema.subscriptionOrders)
    .where(eq(schema.subscriptionOrders.id, orderId))
    .limit(1);

  if (!order) {
    logger.warn({ orderId }, "webhook for unknown order");
    return { activated: false, reason: "unknown_order" };
  }
  if (order.status === "paid") {
    return { activated: false, reason: "already_paid" };
  }

  const plan = order.plan as Plan;
  const cycle = order.cycle as Cycle;
  const expiry = expiryFor(cycle);

  await adminFirestore()
    .collection("subscriptions")
    .doc(order.tenantId)
    .set(
      {
        plan,
        billing_cycle: cycle,
        expiry_date: expiry.toISOString(),
        razorpay_payment_id: razorpayPaymentId,
        razorpay_order_id: orderId,
        activated_at: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  await db
    .update(schema.subscriptionOrders)
    .set({ status: "paid", razorpayPaymentId, paidAt: new Date() })
    .where(eq(schema.subscriptionOrders.id, orderId));

  await db.insert(schema.usageEvents).values({
    tenantId: order.tenantId,
    userUid: order.userUid,
    kind: "subscription_activated",
    model: null,
    costMicros: -order.amountPaise * 10_000, // negative = revenue, in micros
  });

  await recordAudit({
    tenant: { tenantId: order.tenantId, userUid: "razorpay-webhook" },
    action: `subscription.activate.${plan}.${cycle}`,
    target: order.tenantId,
    result: "activated",
  });

  logger.info({ orderId, tenantId: order.tenantId, plan, cycle }, "subscription activated");
  return { activated: true };
}
