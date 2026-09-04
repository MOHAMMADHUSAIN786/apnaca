// Applies pending SQL migrations from ./drizzle. Run this once per deploy,
// before the new revision serves traffic:
//   - locally (Cloud SQL Auth Proxy running):  npm run db:migrate:run
//   - as a container job:  node dist/db/migrate.js
import { drizzle } from "drizzle-orm/node-postgres";
import { migrate } from "drizzle-orm/node-postgres/migrator";
import pg from "pg";
import { config } from "../config.js";
import { logger } from "../observability/logger.js";

async function main(): Promise<void> {
  const pool = new pg.Pool({
    connectionString: config.DATABASE_URL,
    max: 1,
    ...(process.env.DATABASE_SSL === "true"
      ? { ssl: { rejectUnauthorized: false } }
      : {}),
  });
  const db = drizzle(pool);
  logger.info("running migrations…");
  await migrate(db, { migrationsFolder: "./drizzle" });
  logger.info("migrations complete");
  await pool.end();
}

main().catch((err) => {
  logger.error({ err }, "migration failed");
  process.exit(1);
});
