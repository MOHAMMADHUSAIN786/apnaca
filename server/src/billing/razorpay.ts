import { createHmac, timingSafeEqual } from "node:crypto";
import { config } from "../config.js";

export function billingEnabled(): boolean {
  return Boolean(
    config.RAZORPAY_KEY_ID &&
      config.RAZORPAY_KEY_SECRET &&
      config.RAZORPAY_WEBHOOK_SECRET,
  );
}

export interface RazorpayOrder {
  id: string;
  amount: number;
  currency: string;
  status: string;
}

/** Creates a Razorpay order via the REST API (server-side, uses the secret). */
export async function createRazorpayOrder(opts: {
  amountPaise: number;
  currency?: string;
  receipt: string;
  notes?: Record<string, string>;
}): Promise<RazorpayOrder> {
  const auth = Buffer.from(
    `${config.RAZORPAY_KEY_ID}:${config.RAZORPAY_KEY_SECRET}`,
  ).toString("base64");

  const res = await fetch("https://api.razorpay.com/v1/orders", {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      amount: opts.amountPaise,
      currency: opts.currency ?? "INR",
      receipt: opts.receipt,
      notes: opts.notes ?? {},
      payment_capture: 1,
    }),
  });

  if (!res.ok) {
    throw new Error(`Razorpay order create failed: ${res.status} ${await res.text()}`);
  }
  return (await res.json()) as RazorpayOrder;
}

/** Verifies the `X-Razorpay-Signature` header against the raw request body. */
export function verifyWebhookSignature(rawBody: string, signature: string): boolean {
  const secret = config.RAZORPAY_WEBHOOK_SECRET;
  if (!secret || !signature) return false;
  const expected = createHmac("sha256", secret).update(rawBody).digest("hex");
  const a = Buffer.from(expected, "utf8");
  const b = Buffer.from(signature, "utf8");
  return a.length === b.length && timingSafeEqual(a, b);
}
