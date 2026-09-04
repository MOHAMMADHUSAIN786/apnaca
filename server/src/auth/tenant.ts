import { getFirestore } from "firebase-admin/firestore";
import { createMiddleware } from "hono/factory";
import { HTTPException } from "hono/http-exception";
import { verifyIdToken } from "./firebase.js";
import { logger } from "../observability/logger.js";

/** Permission flags the tools care about. Mirrors the client `TeamPermissions`. */
export interface Permissions {
  viewSaleBills: boolean;
  viewPurchaseBills: boolean;
  viewItems: boolean;
  viewCustomers: boolean;
  viewSuppliers: boolean;
  viewReports: boolean;
  createSaleBills: boolean;
  createPurchaseBills: boolean;
  manageItems: boolean;
  manageCustomers: boolean;
  manageSuppliers: boolean;
}

export type Role = "owner" | "editor" | "viewer";

export interface TenantContext {
  /** Owner uid — the tenant boundary. */
  tenantId: string;
  /** The authenticated user (owner or team member). */
  userUid: string;
  email: string | null;
  role: Role;
  companyId: string | null;
  permissions: Permissions;
  isAdmin: boolean;
  can(p: keyof Permissions): boolean;
}

const OWNER_PERMISSIONS: Permissions = {
  viewSaleBills: true,
  viewPurchaseBills: true,
  viewItems: true,
  viewCustomers: true,
  viewSuppliers: true,
  viewReports: true,
  createSaleBills: true,
  createPurchaseBills: true,
  manageItems: true,
  manageCustomers: true,
  manageSuppliers: true,
};

const DENY_ALL: Permissions = {
  viewSaleBills: false,
  viewPurchaseBills: false,
  viewItems: false,
  viewCustomers: false,
  viewSuppliers: false,
  viewReports: false,
  createSaleBills: false,
  createPurchaseBills: false,
  manageItems: false,
  manageCustomers: false,
  manageSuppliers: false,
};

function coercePermissions(raw: unknown): Permissions {
  const r = (raw ?? {}) as Record<string, unknown>;
  const b = (k: string) => r[k] === true;
  return {
    viewSaleBills: b("canViewSaleBills"),
    viewPurchaseBills: b("canViewPurchaseBills"),
    viewItems: b("canViewItems"),
    viewCustomers: b("canViewCustomers"),
    viewSuppliers: b("canViewSuppliers"),
    viewReports: b("canViewReports"),
    createSaleBills: b("canCreateSaleBills"),
    createPurchaseBills: b("canCreatePurchaseBills"),
    manageItems: b("canManageItems"),
    manageCustomers: b("canManageCustomers"),
    manageSuppliers: b("canManageSuppliers"),
  };
}

function makeContext(base: Omit<TenantContext, "can">): TenantContext {
  return { ...base, can: (p) => base.isAdmin || base.permissions[p] };
}

/**
 * Verifies the bearer token and resolves the caller into a TenantContext.
 * Owner  → tenantId = own uid, full permissions.
 * Member → tenantId = owner uid (from team_access/{uid}), scoped permissions.
 */
export const tenantMiddleware = createMiddleware<{
  Variables: { tenant: TenantContext };
}>(async (c, next) => {
  const header = c.req.header("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) throw new HTTPException(401, { message: "Missing bearer token" });

  let decoded;
  try {
    decoded = await verifyIdToken(token);
  } catch (err) {
    logger.warn({ err }, "token verification failed");
    throw new HTTPException(401, { message: "Invalid or expired token" });
  }

  const uid = decoded.uid;
  const email = (decoded.email ?? null)?.toLowerCase() ?? null;
  const isAdmin = email === "admin@gmail.com"; // TODO: custom claim

  const fs = getFirestore();
  const teamAccessSnap = await fs.collection("team_access").doc(uid).get();

  let ctx: TenantContext;
  if (teamAccessSnap.exists) {
    const d = teamAccessSnap.data() ?? {};
    const role = (d["role"] as Role) ?? "viewer";
    ctx = makeContext({
      tenantId: (d["ownerUid"] as string) ?? uid,
      userUid: uid,
      email,
      role,
      companyId: (d["companyId"] as string) ?? null,
      permissions:
        role === "editor" && !d["permissions"]
          ? OWNER_PERMISSIONS
          : { ...DENY_ALL, ...coercePermissions(d["permissions"]) },
      isAdmin,
    });
  } else {
    ctx = makeContext({
      tenantId: uid,
      userUid: uid,
      email,
      role: "owner",
      companyId: null,
      permissions: OWNER_PERMISSIONS,
      isAdmin,
    });
  }

  c.set("tenant", ctx);
  await next();
});
