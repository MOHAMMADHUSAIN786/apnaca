import { z } from "zod";
import { register, type Tool } from "./registry.js";

const str = (v: unknown): string => (v === null || v === undefined ? "-" : String(v));

// ── list_items ───────────────────────────────────────────────────────────────
const listItems: Tool<{ nameContains?: string; limit?: number }> = {
  name: "list_items",
  description:
    "List the user's inventory items with stock and price. Optionally filter by a substring of the name.",
  category: "read",
  requiresPermission: "viewItems",
  parameters: {
    type: "object",
    properties: {
      nameContains: { type: "string", description: "case-insensitive substring filter" },
      limit: { type: "integer", minimum: 1, maximum: 100 },
    },
    additionalProperties: false,
  },
  schema: z.object({
    nameContains: z.string().trim().min(1).optional(),
    limit: z.number().int().min(1).max(100).optional(),
  }),
  async run(args, ctx) {
    let items = ctx.business.items ?? [];
    if (args.nameContains) {
      const q = args.nameContains.toLowerCase();
      items = items.filter((i) => i.name.toLowerCase().includes(q));
    }
    const rows = items.slice(0, args.limit ?? 50);
    return {
      status: "ok",
      data: rows,
      card: {
        type: "table",
        title: "Items",
        rows: rows.map((i) => ({
          Name: str(i.name),
          Stock: str(i.qty),
          Price: i.price != null ? `₹${i.price}` : "-",
        })),
      },
    };
  },
};

// ── find_customer ────────────────────────────────────────────────────────────
const findCustomer: Tool<{ name: string }> = {
  name: "find_customer",
  description: "Look up a customer by (fuzzy) name. Returns matches with phone.",
  category: "read",
  requiresPermission: "viewCustomers",
  parameters: {
    type: "object",
    properties: { name: { type: "string" } },
    required: ["name"],
    additionalProperties: false,
  },
  schema: z.object({ name: z.string().trim().min(1) }),
  async run(args, ctx) {
    const q = args.name.toLowerCase();
    const matches = (ctx.business.customers ?? []).filter(
      (c) => c.name.toLowerCase().includes(q) || q.includes(c.name.toLowerCase()),
    );
    const rows = matches.slice(0, 10);
    return {
      status: "ok",
      data: rows,
      card:
        rows.length > 1
          ? {
              type: "table",
              title: "Customers",
              rows: rows.map((c) => ({ Name: str(c.name), Phone: str(c.phone) })),
            }
          : rows.length === 1
            ? {
                type: "detail",
                title: "Customer",
                fields: { Name: str(rows[0]!.name), Phone: str(rows[0]!.phone) },
              }
            : undefined,
    };
  },
};

// ── get_analytics ────────────────────────────────────────────────────────────
const getAnalytics: Tool<{ metric: string }> = {
  name: "get_analytics",
  description:
    "Read a precomputed business metric. Known keys are in the DATA block under `analytics` (todaySale, monthSale, unpaidTotal, unpaidCount, lowStockCount, receivable, payable, itemCount, customerCount, …).",
  category: "read",
  requiresPermission: "viewReports",
  parameters: {
    type: "object",
    properties: { metric: { type: "string" } },
    required: ["metric"],
    additionalProperties: false,
  },
  schema: z.object({ metric: z.string().trim().min(1) }),
  async run(args, ctx) {
    const a = ctx.business.analytics ?? {};
    if (!(args.metric in a)) {
      return {
        status: "error",
        error: `Unknown metric "${args.metric}". Available: ${Object.keys(a).join(", ") || "none"}`,
      };
    }
    return {
      status: "ok",
      data: { [args.metric]: a[args.metric] },
      card: {
        type: "detail",
        title: "Analytics",
        fields: { [args.metric]: str(a[args.metric]) },
      },
    };
  },
};

export function registerReadTools(): void {
  register(listItems);
  register(findCustomer);
  register(getAnalytics);
}
