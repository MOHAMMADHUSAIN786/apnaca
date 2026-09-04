import pg from "pg";
import { drizzle } from "drizzle-orm/node-postgres";
import { config } from "../config.js";
import * as schema from "./schema.js";

// Cloud Run → Cloud SQL: preferred connection is the unix socket added via
//   gcloud run deploy --add-cloudsql-instances=PROJECT:REGION:INSTANCE
// with DATABASE_URL = postgresql://USER:PASS@/DB?host=/cloudsql/PROJECT:REGION:INSTANCE
// (no SSL needed). Set DATABASE_SSL=true only for a direct public-IP connection.
export const pool = new pg.Pool({
  connectionString: config.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 10_000,
  ...(process.env.DATABASE_SSL === "true"
    ? { ssl: { rejectUnauthorized: false } }
    : {}),
});

export const db = drizzle(pool, { schema });
export { schema };

export async function closeDb(): Promise<void> {
  await pool.end();
}
