import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  collection,
  addDoc,
  getDocs,
  query,
  where,
  limit,
} from "firebase/firestore";

const root = dirname(fileURLToPath(import.meta.url));
const A = "userA";
const B = "userB";

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "apnaca-test",
    firestore: {
      rules: readFileSync(join(root, "..", "firestore.rules"), "utf8"),
    },
  });
});
afterAll(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const asA = () => env.authenticatedContext(A, { email: "a@x.com" }).firestore();
const asB = () => env.authenticatedContext(B, { email: "b@x.com" }).firestore();
const asAdmin = () =>
  env.authenticatedContext("admin", { email: "admin@gmail.com" }).firestore();

async function seed(fn: (db: any) => Promise<unknown>) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

describe("users", () => {
  it("owner reads/writes own profile", async () => {
    await assertSucceeds(setDoc(doc(asA(), "users", A), { email: "a@x.com" }));
    await assertSucceeds(getDoc(doc(asA(), "users", A)));
  });

  it("another user cannot read someone's profile", async () => {
    await seed((db) => setDoc(doc(db, "users", A), { email: "a@x.com" }));
    await assertFails(getDoc(doc(asB(), "users", A)));
  });

  it("cannot bulk-enumerate users; a limit(1) email lookup is allowed", async () => {
    await seed(async (db) => {
      await setDoc(doc(db, "users", A), { email: "a@x.com" });
      await setDoc(doc(db, "users", B), { email: "b@x.com" });
    });
    // full dump — denied
    await assertFails(getDocs(collection(asB(), "users")));
    // single-doc lookup by email — allowed (TeamService pattern)
    await assertSucceeds(
      getDocs(query(collection(asB(), "users"), where("email", "==", "a@x.com"), limit(1))),
    );
  });

  it("AI chat memory is private to the account", async () => {
    await seed((db) =>
      setDoc(doc(db, "users", A, "AI_CHAT", "context"), { lastAction: "x" }),
    );
    await assertSucceeds(getDoc(doc(asA(), "users", A, "AI_CHAT", "context")));
    await assertFails(getDoc(doc(asB(), "users", A, "AI_CHAT", "context")));
  });
});

describe("subscriptions", () => {
  it("owner can write own subscription (INTERIM — locks to webhook in Phase B)", async () => {
    await assertSucceeds(
      setDoc(doc(asA(), "subscriptions", A), { plan: "free", items_count: 0 }),
    );
    await assertSucceeds(
      updateDoc(doc(asA(), "subscriptions", A), { items_count: 5 }),
    );
  });

  it("another user cannot read someone's subscription", async () => {
    await seed((db) => setDoc(doc(db, "subscriptions", A), { plan: "gold" }));
    await assertFails(getDoc(doc(asB(), "subscriptions", A)));
  });
});

describe("companies", () => {
  it("owner reads own company; stranger cannot", async () => {
    await seed((db) => setDoc(doc(db, "companies", "c1"), { ownerUid: A, name: "Co" }));
    await assertSucceeds(getDoc(doc(asA(), "companies", "c1")));
    await assertFails(getDoc(doc(asB(), "companies", "c1")));
  });
});

describe("telemetry collections", () => {
  it("write-only: create own ai_error_logs, cannot read", async () => {
    await assertSucceeds(
      addDoc(collection(asA(), "ai_error_logs"), { uid: A, type: "parse_error" }),
    );
    await assertFails(getDocs(collection(asB(), "ai_error_logs")));
  });

  it("admin can read ai_error_logs", async () => {
    await seed((db) => addDoc(collection(db, "ai_error_logs"), { uid: A }));
    await assertSucceeds(getDocs(collection(asAdmin(), "ai_error_logs")));
  });
});

describe("default deny", () => {
  it("an undeclared collection is closed", async () => {
    await assertFails(getDoc(doc(asA(), "random_stuff", "x")));
    await assertFails(setDoc(doc(asA(), "random_stuff", "x"), { a: 1 }));
  });
});
