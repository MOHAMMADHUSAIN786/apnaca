// Server-authoritative pricing. The client never sends an amount.
// Mirrors lib/features/subscription/model/subscription_model.dart.

export type Plan = "silver" | "gold";
export type Cycle = "monthly" | "yearly";

const PRICE_RUPEES: Record<Plan, Record<Cycle, number>> = {
  silver: { monthly: 99, yearly: 999 },
  gold: { monthly: 299, yearly: 2999 },
};

export function isPlan(v: unknown): v is Plan {
  return v === "silver" || v === "gold";
}
export function isCycle(v: unknown): v is Cycle {
  return v === "monthly" || v === "yearly";
}

export function amountPaise(plan: Plan, cycle: Cycle): number {
  return PRICE_RUPEES[plan][cycle] * 100;
}

/** Expiry = now + 1 month (monthly) or + 1 year (yearly). */
export function expiryFor(cycle: Cycle, from = new Date()): Date {
  const d = new Date(from);
  if (cycle === "yearly") d.setFullYear(d.getFullYear() + 1);
  else d.setMonth(d.getMonth() + 1);
  return d;
}
