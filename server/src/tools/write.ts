import { z } from "zod";
import { register, type Tool } from "./registry.js";

// Write tools do NOT touch a database in Phase 2. They validate + normalize the
// arguments and return a `proposed` action. The client applies it to local
// SQLite via the existing ActionExecutor (with a confirmation dialog for
// destructive categories) and then calls POST /v1/agent/actions/ack.
//
// When Phase 7 sync lands, `run` gains a real handler and executes here.

// ── create_customer ─────────────────────────────────────────────────────────
const createCustomer: Tool<{
  name: string;
  phone?: string;
  email?: string;
  gstNumber?: string;
  state?: string;
}> = {
  name: "create_customer",
  description: "Create a new customer. Phone must be exactly 10 digits if given.",
  category: "write",
  requiresPermission: "manageCustomers",
  parameters: {
    type: "object",
    properties: {
      name: { type: "string" },
      phone: { type: "string", description: "10 digits" },
      email: { type: "string" },
      gstNumber: { type: "string" },
      state: { type: "string" },
    },
    required: ["name"],
    additionalProperties: false,
  },
  schema: z.object({
    name: z.string().trim().min(1),
    phone: z
      .string()
      .trim()
      .regex(/^\d{10}$/, "phone must be exactly 10 digits")
      .optional(),
    email: z.string().trim().email().optional(),
    gstNumber: z.string().trim().optional(),
    state: z.string().trim().optional(),
  }),
  async run(args, ctx) {
    const exists = (ctx.business.customers ?? []).some(
      (c) => c.name.toLowerCase() === args.name.toLowerCase(),
    );
    if (exists) {
      return { status: "error", error: `Customer "${args.name}" already exists.` };
    }
    return { status: "proposed", action: { tool: "create_customer", args } };
  },
};

// ── create_sale_bill ────────────────────────────────────────────────────────
const saleItem = z.object({
  name: z.string().trim().min(1),
  qty: z.number().int().positive(),
  price: z.number().positive().optional(),
});

const createSaleBill: Tool<{
  customerName: string;
  items: z.infer<typeof saleItem>[];
  discountType?: "none" | "percent" | "amount";
  discountValue?: number;
  taxType?: "inclusive" | "exclusive";
  taxRate?: number;
  paymentMode?: "cash" | "upi" | "udhar" | "cheque";
  paymentStatus?: "paid" | "unpaid" | "partial";
}> = {
  name: "create_sale_bill",
  description:
    "Create a sale bill (invoice) for a customer. Only propose this once you have a customer that exists and at least one item.",
  category: "write",
  requiresPermission: "createSaleBills",
  parameters: {
    type: "object",
    properties: {
      customerName: { type: "string" },
      items: {
        type: "array",
        items: {
          type: "object",
          properties: {
            name: { type: "string" },
            qty: { type: "integer", minimum: 1 },
            price: { type: "number" },
          },
          required: ["name", "qty"],
        },
      },
      discountType: { type: "string", enum: ["none", "percent", "amount"] },
      discountValue: { type: "number" },
      taxType: { type: "string", enum: ["inclusive", "exclusive"] },
      taxRate: { type: "number" },
      paymentMode: { type: "string", enum: ["cash", "upi", "udhar", "cheque"] },
      paymentStatus: { type: "string", enum: ["paid", "unpaid", "partial"] },
    },
    required: ["customerName", "items"],
    additionalProperties: false,
  },
  schema: z.object({
    customerName: z.string().trim().min(1),
    items: z.array(saleItem).min(1),
    discountType: z.enum(["none", "percent", "amount"]).optional(),
    discountValue: z.number().min(0).optional(),
    taxType: z.enum(["inclusive", "exclusive"]).optional(),
    taxRate: z.number().min(0).max(100).optional(),
    paymentMode: z.enum(["cash", "upi", "udhar", "cheque"]).optional(),
    paymentStatus: z.enum(["paid", "unpaid", "partial"]).optional(),
  }),
  async run(args, ctx) {
    const known = ctx.business.customers ?? [];
    if (!known.some((c) => c.name.toLowerCase() === args.customerName.toLowerCase())) {
      return {
        status: "error",
        error: `No customer named "${args.customerName}". Use find_customer or create_customer first.`,
      };
    }
    return { status: "proposed", action: { tool: "create_sale_bill", args } };
  },
};

// ── delete_item (destructive → always confirmed on the client) ───────────────
const deleteItem: Tool<{ name: string }> = {
  name: "delete_item",
  description: "Delete an inventory item by name. Destructive — the user will be asked to confirm.",
  category: "destructive",
  requiresPermission: "manageItems",
  parameters: {
    type: "object",
    properties: { name: { type: "string" } },
    required: ["name"],
    additionalProperties: false,
  },
  schema: z.object({ name: z.string().trim().min(1) }),
  async run(args) {
    return { status: "proposed", action: { tool: "delete_item", args } };
  },
};

export function registerWriteTools(): void {
  register(createCustomer);
  register(createSaleBill);
  register(deleteItem);
}
