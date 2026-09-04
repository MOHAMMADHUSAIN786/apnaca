import type { z } from "zod";
import type { Permissions, TenantContext } from "../auth/tenant.js";
import type { ToolSchema } from "../llm/types.js";

/**
 * Compact business snapshot the CLIENT sends with each request. The gateway
 * has no business DB yet (Phase 7), so read tools answer from this and write
 * tools return a proposedAction the client applies locally.
 */
export interface BusinessContext {
  items?: Array<{ id?: number; name: string; qty?: number; price?: number }>;
  customers?: Array<{ id?: number; name: string; phone?: string }>;
  suppliers?: Array<{ id?: number; name: string; phone?: string }>;
  recentBills?: Array<{
    billNumber: string;
    customerName?: string;
    total?: number;
    status?: string;
  }>;
  /** Precomputed by the client (today's sale, unpaid total, …). */
  analytics?: Record<string, unknown>;
}

export interface ToolContext {
  tenant: TenantContext;
  business: BusinessContext;
  conversationId: string;
}

/** Optional UI hint so the client can render the same cards the local path does. */
export type RenderCard =
  | { type: "table"; title?: string; rows: Array<Record<string, string>> }
  | { type: "detail"; title?: string; fields: Record<string, string> };

export type ToolResult =
  | { status: "ok"; data: unknown; card?: RenderCard }
  | { status: "error"; error: string }
  /** client must apply this to local SQLite (with confirmation if destructive) */
  | { status: "proposed"; action: { tool: string; args: Record<string, unknown> } };

export interface Tool<A = unknown> {
  name: string;
  description: string;
  category: "read" | "write" | "destructive";
  /** permission the caller needs; undefined = any authenticated user */
  requiresPermission?: keyof Permissions;
  /** JSON Schema handed to the model */
  parameters: Record<string, unknown>;
  /** zod schema — throws on invalid args */
  schema: z.ZodType<A>;
  run(args: A, ctx: ToolContext): Promise<ToolResult>;
}

const registry = new Map<string, Tool<any>>();

export function register(tool: Tool<any>): void {
  if (registry.has(tool.name)) throw new Error(`duplicate tool: ${tool.name}`);
  registry.set(tool.name, tool);
}

export function getTool(name: string): Tool<any> | undefined {
  return registry.get(name);
}

/** Schemas for tools this tenant is allowed to call — keeps the model in-bounds. */
export function toolSchemasFor(tenant: TenantContext): ToolSchema[] {
  const out: ToolSchema[] = [];
  for (const tool of registry.values()) {
    if (tool.requiresPermission && !tenant.can(tool.requiresPermission)) continue;
    out.push({
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters,
    });
  }
  return out;
}

export function allTools(): Tool<any>[] {
  return [...registry.values()];
}
