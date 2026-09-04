import {
  pgTable,
  uuid,
  text,
  integer,
  bigint,
  jsonb,
  timestamp,
  index,
} from "drizzle-orm/pg-core";

// ─────────────────────────────────────────────────────────────────────────────
//  Gateway-owned data only. Business data (items/customers/bills) stays in the
//  on-device SQLite until the Phase 7 sync rebuild. Every row carries tenant_id
//  (= the owner's Firebase uid) and should be behind Postgres RLS in production.
// ─────────────────────────────────────────────────────────────────────────────

export const conversations = pgTable(
  "conversations",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: text("tenant_id").notNull(),
    userUid: text("user_uid").notNull(),
    title: text("title"),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
    lastAt: timestamp("last_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (t) => ({
    byTenant: index("conv_tenant_idx").on(t.tenantId, t.lastAt),
  }),
);

export const messages = pgTable(
  "messages",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    conversationId: uuid("conversation_id")
      .notNull()
      .references(() => conversations.id, { onDelete: "cascade" }),
    tenantId: text("tenant_id").notNull(),
    role: text("role").notNull(), // user | assistant | tool
    content: text("content").notNull().default(""),
    toolCalls: jsonb("tool_calls"),
    tokensIn: integer("tokens_in").default(0).notNull(),
    tokensOut: integer("tokens_out").default(0).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (t) => ({
    byConversation: index("msg_conv_idx").on(t.conversationId, t.createdAt),
  }),
);

export const agentTasks = pgTable("agent_tasks", {
  id: uuid("id").defaultRandom().primaryKey(),
  tenantId: text("tenant_id").notNull(),
  conversationId: uuid("conversation_id").references(() => conversations.id, {
    onDelete: "set null",
  }),
  type: text("type").notNull(),
  state: jsonb("state").notNull().default({}),
  status: text("status").notNull().default("open"), // open | done | failed
  steps: integer("steps").default(0).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  closedAt: timestamp("closed_at", { withTimezone: true }),
});

export const toolExecutions = pgTable(
  "tool_executions",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: text("tenant_id").notNull(),
    conversationId: uuid("conversation_id"),
    tool: text("tool").notNull(),
    argsHash: text("args_hash").notNull(),
    resultStatus: text("result_status").notNull(), // ok | error | denied | pending
    latencyMs: integer("latency_ms").default(0).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (t) => ({
    byTenant: index("tool_exec_tenant_idx").on(t.tenantId, t.createdAt),
  }),
);

export const usageEvents = pgTable(
  "usage_events",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: text("tenant_id").notNull(),
    userUid: text("user_uid").notNull(),
    kind: text("kind").notNull(), // llm_call | tool_call
    model: text("model"),
    tokensIn: integer("tokens_in").default(0).notNull(),
    tokensOut: integer("tokens_out").default(0).notNull(),
    costMicros: bigint("cost_micros", { mode: "number" }).default(0).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (t) => ({
    byTenant: index("usage_tenant_idx").on(t.tenantId, t.createdAt),
  }),
);

export const auditLog = pgTable(
  "audit_log",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: text("tenant_id").notNull(),
    actorUid: text("actor_uid").notNull(),
    action: text("action").notNull(),
    target: text("target"),
    argsHash: text("args_hash"),
    result: text("result").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (t) => ({
    byTenant: index("audit_tenant_idx").on(t.tenantId, t.createdAt),
  }),
);

export const subscriptionOrders = pgTable(
  "subscription_orders",
  {
    // = the Razorpay order id (order_xxx)
    id: text("id").primaryKey(),
    tenantId: text("tenant_id").notNull(),
    userUid: text("user_uid").notNull(),
    plan: text("plan").notNull(), // silver | gold
    cycle: text("cycle").notNull(), // monthly | yearly
    amountPaise: integer("amount_paise").notNull(),
    currency: text("currency").notNull().default("INR"),
    status: text("status").notNull().default("created"), // created | paid | failed
    razorpayPaymentId: text("razorpay_payment_id"),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
    paidAt: timestamp("paid_at", { withTimezone: true }),
  },
  (t) => ({
    byTenant: index("suborder_tenant_idx").on(t.tenantId, t.createdAt),
  }),
);

export const tenantMemory = pgTable(
  "tenant_memory",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: text("tenant_id").notNull(),
    kind: text("kind").notNull(), // fact | preference | task_summary
    key: text("key").notNull(),
    value: text("value").notNull(),
    source: text("source"),
    expiresAt: timestamp("expires_at", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (t) => ({
    byTenant: index("mem_tenant_idx").on(t.tenantId, t.kind),
  }),
);
