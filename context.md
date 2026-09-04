# ApnaCA — Project Context & Modernization Log

> Single source of truth for the "grow ApnaCA into a production-grade agentic
> SaaS" effort. Read this first before touching AI, sync, payments, or the
> `server/` gateway. Keep it updated as work lands.

Last updated: **2026-09-02**

---

## 1. What ApnaCA is

An **offline-first Flutter billing app** for Indian small businesses ("ApnaCA").
Core domain: items, customers, suppliers, sale bills, purchase bills, stock
ledger, GST, PDF invoices, analytics. Ambition: reach Vyapar-scale (millions of
SMB users).

There is an **AI chat assistant** (`lib/features/ai_chat/`) — the main focus of
this modernization.

### Verified current stack (do not assume — this is from the code)

| Layer | Tech |
| --- | --- |
| Client | Flutter (Android/iOS), `flutter_bloc`, `flutter_screenutil` |
| Local DB | **sqflite** raw SQL, per-user + per-company file `billnex_{uid}[_{companyId}].db`, schema **v10** |
| Sync | Whole SQLite file → Firebase Storage `database_backups/user_{uid}[_comp_{id}].db`, debounced 2s after any write. **Last-write-wins, no merge.** |
| Auth | Firebase Auth (email/password) |
| Multi-tenant | `companies/`, `team_access/{memberUid}`; team members operate on the owner's uid DB |
| Payments | Razorpay, **client-side only, test keys, no server verification** |
| AI | OpenRouter → `google/gemini-2.5-flash`, single `http.post`, no streaming, no tool-calling. `MasterPromptService` (one big prompt) → `ActionParser` (regex) → `ActionExecutor` (1.5k-line switch) → local SQLite |
| "RAG" | `RagMemoryService` = Firestore chat log + substring entity match. **No embeddings / vectors.** |
| Backend | None, except one admin-only Cloud Function (`functions/index.js`) |
| Unused deps | `drift`, `get_it`, `get`, `dio` all in `pubspec.yaml` |

---

## 2. The plan

Full audit (21 sections + Top 10): **Artifact** →
`https://claude.ai/code/artifact/139f0f35-2beb-439c-b718-c2bdaa582d8d`
(also drafted at `C:\Users\91962\AppData\Local\Temp\...\scratchpad\apnca-audit.html`)

**Direction:** incremental, not a rewrite. Introduce **one thin backend** — a
stateless **Agent Gateway** (Cloud Run, `server/`) that holds keys, verifies
payments, meters usage, and runs the agent loop with permission checks. Keep the
Flutter client and the offline SQLite cache.

**Do NOT adopt** (not justified at current scale): microservices, Kafka,
Kubernetes, a vector database, MCP, multi-region. Revisit only on real signals.

### Roadmap phases

| Phase | Goal | Status |
| --- | --- | --- |
| 1 | Stop the bleeding — secrets, payments, rules, transactions, indexes | **mostly done**: payments ✅, transactions ✅, indexes ✅, rules written (not deployed), secrets still in bundle (needs full gateway cutover) |
| 2 | Agent core on the gateway — tool registry, real loop, permissions, streaming, cards | **done: skeleton + client wired + streaming + structured cards** (see §3) |
| 3 | Memory layers (facts, task state, durable history) | not started |
| 4 | RAG + pgvector — **only if** document Q&A becomes a real feature | not started |
| 5 | Tool hardening + outbound actions (WhatsApp reminders etc.) | not started |
| 6 | Observability + AI evaluation harness in CI | partial (usage/audit tables exist) |
| 7 | SaaS: server quotas, row-level sync replacing whole-file backup, invite links | not started |
| 8 | Perf + cost — Redis cache, model routing tuning, money-as-paise | not started |

---

## 3. Work completed so far

### Phase 1 — safe local fixes (done, NOT yet deployed/committed)

| Item | Files | Notes |
| --- | --- | --- |
| `.env` removed from git tracking | `.gitignore`, `.env.example`, `git rm --cached .env` | `.env` was never committed (only staged). Still on disk, still in `pubspec.yaml assets:` — **fully removing from the bundle needs the gateway**. **Keys must still be rotated.** |
| Atomic bill creation | `app_database.dart` (`createSaleBillAtomic`, `createPurchaseBillAtomic`), `action_executor.dart` | Bill + line items + stock deduction + stock-history in one `db.transaction()`. |
| DB indexes | `app_database.dart` (`_createIndexes`, schema **v9 → v10**) | 15 indexes on all FK / lookup / sort columns. Auto-migrates on app update. |
| Security rules — interim, **DEPLOYED 2026-09-03** ✅ | `firestore.rules`, `storage.rules`, `firebase-tests/` | The old deployed rules were unsafe (Storage `allow read,write: if auth != null` → any user could download any tenant's SQLite backup; Firestore let any user list all `users`). Interim rules now live: Storage locked per-tenant, `users` list constrained to `limit(1)`, `ai_error_logs` added. `subscriptions` write still client-open (marked `PHASE B` — flip after the Razorpay webhook is live). 14/14 rules tests pass. |
| FK enforcement | deliberately **left off** | `PRAGMA foreign_keys = ON` would make deleting a referenced row throw. Needs delete-handler updates first. TODO comment in `app_database.dart`. |

**Payment verification (Phase 1 #2) — DONE server-side** (see Phase 2 billing below).
`subscriptions/{uid}` rule now blocks the client from writing plan/expiry/payment
fields; the Razorpay webhook (Admin SDK) is the only activator.
`SubscriptionService.activateSubscription` is now a deprecated no-op.

**Prod context:** ~50 users, app is live on Play Store. Production API keys
were **NOT** rotated (only the local `.env` was changed) — so the live app
keeps working. The old OpenRouter/Razorpay keys are still extractable from the
shipped APK (low risk at this scale); rotate them **together with** shipping a
gateway build (no keys in the bundle), not before — rotating now breaks the 50
live users.

**Still on the user:**
1. ✅ DONE — interim rules deployed 2026-09-03.
2. Smoke-test the live app after the rules deploy (normal user: login + make a bill = Storage sync; a Gold/team user if any).
3. gcloud install → then STEP 1–4 of `server/DEPLOY.md` (Cloud SQL + Cloud Run).
4. Razorpay dashboard → Webhooks → add `<gateway>/webhooks/razorpay` (`payment.captured` + `order.paid`), signing secret → `RAZORPAY_WEBHOOK_SECRET`.
5. After the webhook works: flip `firestore.rules` `subscriptions` to the PHASE B block, redeploy rules, update the test.

### Phase 2 — Agent Gateway skeleton (`server/`, done, compiles, boots)

TypeScript + **Hono** + **Postgres/Drizzle**. Full design in `server/README.md`.

Key idea — **stateless w.r.t. business data**: business data still lives in
on-device SQLite (server move = Phase 7). So the client sends a compact
`context` snapshot with each turn; gateway **read tools** answer from it,
**write tools** return a `proposedAction` the client applies locally.

| Piece | File |
| --- | --- |
| Auth + tenant resolve (owner/member, per-tool permission check) | `server/src/auth/tenant.ts` |
| LLM provider interface (real tool-calling) + OpenRouter impl | `server/src/llm/{types,openrouter}.ts` |
| Model router (fast/standard/advanced + fallback) | `server/src/llm/router.ts` |
| Agent loop (plan→act→observe, max 5 steps, SSE events) | `server/src/agent/orchestrator.ts` |
| Prompt (system = instructions only; data in a delimited untrusted block) | `server/src/agent/prompt.ts` |
| Typed tool registry + 6 sample tools | `server/src/tools/{registry,read,write}.ts` |
| DB schema (conversations, messages, tool_executions, usage_events, audit_log, tenant_memory) | `server/src/db/schema.ts` |
| Endpoint `POST /v1/agent/chat` (SSE), `/actions/ack`, `/conversations*` | `server/src/routes/agent.ts` |
| Deploy | `server/Dockerfile`, `server/docker-compose.yml` |

**TODO in the skeleton:** token streaming, Redis rate-limit/cache,
server-authoritative quota check, Anthropic provider, Razorpay routes, team
invite routes, real write handlers (Phase 7), OTel exporter.

### Phase 2 — Flutter client wired to the gateway (done, feature-flagged OFF)

| File | Change |
| --- | --- |
| `lib/features/ai_chat/service/agent_gateway_client.dart` | SSE client + `AgentGatewayConfig` (flag) |
| `lib/database/app_database.dart` | `getBusinessContextForGateway()` — snapshot builder |
| `lib/features/ai_chat/repository/ai_chat_repository.dart` | `sendMessage()` → `_sendViaGateway()` when flag on; **falls back to local path on any failure** |
| `lib/main.dart` | reads `AGENT_GATEWAY_URL` + `AGENT_GATEWAY_ENABLED` from `.env` |

Bill proposals re-enter the existing `BillFlowManager` state machine.

**Turn on:** set both env vars in the app's `.env`, rebuild. Off = instant rollback.

### Phase 2 — streaming + structured cards (done)

- **Token streaming:** gateway streams the model (`openrouter.ts` uses `stream:true`, accumulates tool-call deltas), emits `text_delta` SSE events. Client → `AiChatRepository.sendMessage(onToken:)` → `ChatBloc` emits new **`ChatStreaming`** state → `chat_screen` renders the growing bubble. Buffer resets on each `step_start` (multi-step turns don't concatenate).
- **Structured cards:** read tools return an optional `RenderCard` (`{type:table,rows}` / `{type:detail,fields}`). Orchestrator emits `card` events + `cards[]` in `done`. Client maps first table → `tableData`, first detail → `detailCard` (same bubble rendering as the local path).
- Files touched: `server/src/llm/{types,openrouter}.ts`, `server/src/agent/orchestrator.ts`, `server/src/tools/{registry,read}.ts`, `agent_gateway_client.dart`, `ai_chat_repository.dart`, `chat_bloc.dart`, `chat_state.dart`, `chat_screen.dart`.

**Remaining first-cut limits (deliberate):** one card per turn (bubble model is
single-card); `create_item` / `create_purchase_bill` gateway tools not built yet
(client mapping ready).

### Phase 2 — in-chat confirm for destructive actions (done)

- Gateway marks `delete_*` / `stock_adjustment` tools `requiresConfirmation`.
- `_sendViaGateway` returns `ActionResult.confirmRequired(pendingActions, conversationId)` instead of skipping. Non-destructive writes still auto-apply.
- New: `ChatMessage.pendingActions`, `ActionResultType.confirmRequired`, `ConfirmAiActionsEvent`, `ChatBloc._onConfirmAiActions`, `_ConfirmActionsCard` widget (Haan/Nahi buttons in the bubble).
- On **Haan** → `AiChatRepository.applyConfirmedActions` resolves name→id (`_enrichActionData`), runs `ActionExecutor`, acks the gateway `applied`; on **Nahi** → acks `rejected`. Buttons clear from the message either way.
- Files: `chat_models.dart`, `chat_event.dart`, `chat_bloc.dart`, `ai_chat_repository.dart`, `chat_screen.dart`.

### Phase 2 — Razorpay: server order + verified webhook (done)

Closes Phase 1 #2 (payment could be forged / plan self-granted).

- **`POST /v1/billing/order`** (`server/src/routes/billing.ts`) — owner only; server computes the amount from `billing/prices.ts` (mirrors `SubscriptionModel`), creates the Razorpay order (`billing/razorpay.ts`, REST + secret), inserts a `subscription_orders` row, returns `{orderId, amount, currency, keyId}` (publishable key only).
- **`POST /webhooks/razorpay`** (`server/src/routes/webhooks.ts`) — **no auth**, HMAC-SHA256 signature over the raw body (`timingSafeEqual`). On `payment.captured` / `order.paid` → `billing/activate.ts` writes `subscriptions/{tenantId}` via **Admin SDK** (bypasses rules), idempotent, + audit + revenue `usage_events` row.
- **`GET /v1/billing/subscription`** — authoritative plan; the client polls it after paying.
- **Client:** `lib/features/subscription/service/billing_client.dart`; `subscription_screen._startPayment` now fetches the order first and opens Razorpay with `order_id`; `_handlePaymentSuccess` polls instead of writing; `SubscriptionService.activateSubscription` → deprecated no-op.
- **Rules:** `subscriptions/{uid}` — client may create the free doc + update usage counters, but `plan/billing_cycle/expiry_date/razorpay_*/activated_at` are server-only.
- New table: `subscription_orders`. New env: `RAZORPAY_KEY_ID` / `_KEY_SECRET` / `_WEBHOOK_SECRET` (billing routes 503 until all set).

### Deploy tooling (done — not yet run)

- `server/DEPLOY.md` — full runbook: enable APIs, Cloud SQL (`asia-south1`), service account + IAM, Secret Manager (all 5 secrets + `DATABASE_URL` via Cloud SQL unix socket), migrate, `deploy.sh`, Razorpay webhook, rules deploy, point the app at the gateway, rollback.
- `server/deploy.sh` — build → migrate → `gcloud run deploy --source .` with `--add-cloudsql-instances` + `--set-secrets`.
- `server/drizzle/0000_*.sql` — generated migration (committed; `drizzle/` no longer gitignored). `server/src/db/migrate.ts` + `npm run db:migrate:run` for a programmatic apply. Dockerfile now copies `drizzle/`.
- `firebase-tests/` — `@firebase/rules-unit-testing` + vitest suite, run via `firebase emulators:exec`. **15 assertions, all green.**
- `db/client.ts` — `DATABASE_SSL=true` opt-in for direct public-IP Postgres.

---

## 4. Immediate next steps (pick one)

- **(d)** RUN the deploy: follow `server/DEPLOY.md` (needs gcloud + Firebase + Razorpay console — a human). Tooling is ready.
- **(e)** Build out remaining gateway tools (`create_item`, `update_*`, `stock_in/out`, `create_purchase_bill`, `update_*_bill_status`, more `get_analytics` metrics) so the gateway path covers everything the local path does.
- **(f)** Multi-card support in the chat bubble (currently one table + one detail per turn).
- **(g)** Wire the server-authoritative quota check into `POST /v1/agent/chat` (billing state is now server-owned).

The highest-risk open items are still: **payment verification**, **deployed
rules unknown**, **whole-file sync data loss** (Phase 7).

---

## 5. Key decisions (do not re-litigate)

- **Keep offline-first SQLite.** Vyapar is offline-first too. It's a feature, not debt.
- **One backend, not microservices.** Cloud Run, scale-to-zero.
- **No vector DB yet.** Structured billing data needs SQL, not embeddings. Add `pgvector` (same Postgres) only when document Q&A ships.
- **No MCP yet.** All tools are first-party + tenant-coupled; internal typed registry is simpler and safer.
- **Gateway is stateless w.r.t. business data until Phase 7.** Client sends context, client applies writes.
- **Firestore stays** for auth-adjacent + realtime; **Postgres** is the new system of record for gateway-owned data (and later, synced business data).
- **Async = Cloud Tasks** when needed, not Kafka/RabbitMQ.
- **Region `asia-south1`** — keep customer PII in India.

---

## 6. How to work on it

### Gateway (local)

```bash
cd server
cp .env.example .env         # OPENROUTER_KEY, FIREBASE_PROJECT_ID, DATABASE_URL
#                            # + service-account.json (Firebase console → Service accounts)
docker compose up -d         # Postgres :5432
npm install
npm run db:push              # tables from src/db/schema.ts
npm run dev                  # :8080
npm run typecheck            # must pass before commit
```

### Security rules (before any deploy)

```bash
firebase emulators:start --only firestore,storage
# walk EVERY flow: signup, login, team-member login, company create/switch,
# add team member, buy subscription, AI chat, contact-us, feedback, admin.
# + negative: user B must NOT read user A's subscription / DB backup.
firebase deploy --only firestore:rules,storage
```

### Client feature flag

`.env`: `AGENT_GATEWAY_URL=https://...` + `AGENT_GATEWAY_ENABLED=true`.
Anything wrong with the gateway → app auto-falls-back to the local LLM path.

### Conventions

- Flutter DB migrations: bump `version:` in `app_database.dart` `_initDb`, add an `if (oldVersion < N)` block, make it idempotent (`IF NOT EXISTS`, `try/catch`).
- Gateway: every new table/query carries `tenant_id`. Every write tool declares `requiresPermission` + `category`.
- Nothing that touches money or plan state is trusted from the client.

---

## 7. Open risks / debt not yet addressed

- Payment verification (P0) — still client-side.
- Deployed security rules state — **unknown**, must be checked.
- Whole-file sync data loss (P0/P1) — Phase 7.
- Team-member onboarding: owner sets member's password — Phase 7.
- No tests (`test/` effectively empty).
- `getFullContextForAi()` dumps `.take(30)` of each table into the local-path prompt — silently wrong for larger shops (gateway path fixes this).
- Hinglish keyword parsers (`BillFlowManager`, `ActionParser._fuzzyFallback`) are locale-locked.
- Dead `sync_service` import in `main.dart`; unused deps in `pubspec.yaml`.
