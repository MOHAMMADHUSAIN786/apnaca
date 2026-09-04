import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { z } from "zod";
import { desc, eq } from "drizzle-orm";
import { adminFirestore } from "../auth/firebase.js";
import { db, schema } from "../db/client.js";
import { tenantMiddleware, type TenantContext } from "../auth/tenant.js";
import { config } from "../config.js";
import { logger } from "../observability/logger.js";
import { amountPaise, isCycle, isPlan } from "../billing/prices.js";
import { billingEnabled, createRazorpayOrder } from "../billing/razorpay.js";

export const billing = new Hono<{ Variables: { tenant: TenantContext } }>();
billing.use("*", tenantMiddleware);

const orderBody = z.object({
  plan: z.string(),
  cycle: z.string(),
});

// ── POST /v1/billing/order ──────────────────────────────────────────────────
// Server computes the amount and creates the Razorpay order. The client never
// sends a price and never writes the plan.
billing.post("/order", async (c) => {
  if (!billingEnabled()) {
    throw new HTTPException(503, { message: "billing not configured" });
  }
  const tenant = c.get("tenant");
  const parsed = orderBody.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success || !isPlan(parsed.data.plan) || !isCycle(parsed.data.cycle)) {
    throw new HTTPException(400, { message: "invalid plan/cycle" });
  }
  // Only the owner may purchase for the tenant.
  if (tenant.role !== "owner") {
    throw new HTTPException(403, { message: "only the owner can buy a plan" });
  }

  const { plan, cycle } = parsed.data;
  const amount = amountPaise(plan, cycle);
  const receipt = `sub_${tenant.tenantId.slice(0, 12)}_${Date.now()}`;

  const order = await createRazorpayOrder({
    amountPaise: amount,
    receipt,
    notes: { tenantId: tenant.tenantId, plan, cycle },
  });

  await db.insert(schema.subscriptionOrders).values({
    id: order.id,
    tenantId: tenant.tenantId,
    userUid: tenant.userUid,
    plan,
    cycle,
    amountPaise: amount,
    currency: order.currency,
    status: "created",
  });

  logger.info({ orderId: order.id, tenantId: tenant.tenantId, plan, cycle }, "order created");

  return c.json({
    orderId: order.id,
    amount: order.amount,
    currency: order.currency,
    keyId: config.RAZORPAY_KEY_ID,
  });
});

// ── GET /v1/subscription ────────────────────────────────────────────────────
// Authoritative plan state (client polls this after paying).
billing.get("/subscription", async (c) => {
  const tenant = c.get("tenant");
  const snap = await adminFirestore()
    .collection("subscriptions")
    .doc(tenant.tenantId)
    .get();
  const d = snap.exists ? (snap.data() ?? {}) : {};
  const plan = (d["plan"] as string) ?? "free";
  const expiryIso = (d["expiry_date"] as string) ?? null;
  const active =
    plan === "free" || (expiryIso ? new Date(expiryIso).getTime() > Date.now() : false);

  return c.json({
    plan,
    billingCycle: (d["billing_cycle"] as string) ?? null,
    expiryDate: expiryIso,
    isActive: active,
  });
});

// ── GET /v1/billing/orders ──────────────────────────────────────────────────
billing.get("/orders", async (c) => {
  const tenant = c.get("tenant");
  const rows = await db
    .select()
    .from(schema.subscriptionOrders)
    .where(eq(schema.subscriptionOrders.tenantId, tenant.tenantId))
    .orderBy(desc(schema.subscriptionOrders.createdAt))
    .limit(20);
  return c.json({ orders: rows });
});
