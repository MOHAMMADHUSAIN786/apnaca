import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { afterAll, beforeAll, describe, it } from "vitest";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { ref, uploadBytes, getBytes } from "firebase/storage";

const root = dirname(fileURLToPath(import.meta.url));
const A = "userA";
const B = "userB";
const bytes = new Uint8Array([1, 2, 3]);

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "apnaca-test",
    storage: { rules: readFileSync(join(root, "..", "storage.rules"), "utf8") },
  });
});
afterAll(() => env.cleanup());

const asA = () => env.authenticatedContext(A, {}).storage();
const asB = () => env.authenticatedContext(B, {}).storage();

describe("database_backups", () => {
  it("owner can write + read their own backup", async () => {
    await assertSucceeds(uploadBytes(ref(asA(), `database_backups/user_${A}.db`), bytes));
    await assertSucceeds(getBytes(ref(asA(), `database_backups/user_${A}.db`)));
  });

  it("owner can write + read a company-scoped backup", async () => {
    await assertSucceeds(
      uploadBytes(ref(asA(), `database_backups/user_${A}_comp_abc123.db`), bytes),
    );
  });

  it("another user CANNOT read someone's backup (no team_access)", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), `database_backups/user_${A}.db`), bytes);
    });
    await assertFails(getBytes(ref(asB(), `database_backups/user_${A}.db`)));
  });
});

describe("branding", () => {
  it("owner writes their branding; stranger cannot read it", async () => {
    await assertSucceeds(
      uploadBytes(ref(asA(), `users/${A}/branding/company_logo.jpg`), bytes, {
        contentType: "image/jpeg",
      }),
    );
    await assertFails(getBytes(ref(asB(), `users/${A}/branding/company_logo.jpg`)));
  });
});
