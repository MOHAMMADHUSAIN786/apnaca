# ApnaCA Agent Gateway

The server that the Flutter app talks to for all AI features. It holds every
secret, verifies every payment, meters every call, and runs the agent loop
with real tool-calling and permission checks.

Introduced in **Phase 2** of the modernization roadmap. This is a skeleton:
the shape is production-grade, several handlers are stubs marked `TODO`.

---

## Why this exists

Today the Flutter app calls OpenRouter directly with a bundled API key, parses
the model's JSON with regex, and executes it against local SQLite with no
authorization. That cannot scale or be secured. The gateway fixes it without a
rewrite of the client:

| Concern | Before | With the gateway |
| --- | --- | --- |
| LLM API key | in the app bundle | server-only env var |
| Payment verification | client success callback | server order + signed webhook |
| Quota enforcement | client counter (bypassable) | checked server-side per call |
| Tool calling | "output one JSON object" + regex | provider tool schemas + a real loop |
| Permissions on AI writes | none | per-tool check against the caller's role |
| Prompt injection via data | DB text in the system prompt | isolated, delimited untrusted-data block |
| Observability | `developer.log` | structured traces + `usage_events` per call |

---

## The transitional data model (important)

The business data (items, customers, bills) still lives in **on-device SQLite**.
Moving it to the server is the row-level sync rebuild — **Phase 7**, later.

Until then the gateway is **stateless with respect to business data**:

```
Flutter client                              Agent Gateway
─────────────                               ─────────────
POST /v1/agent/chat
  ├─ message: "raj ko 5 apple ka bill"
  └─ context: {                    ──────►  read tools read from this payload
        items:      [...compact...]         (never from a server DB yet)
        customers:  [...compact...]
        analytics:  {...precomputed...}
        permissions:{...}
      }
                                  ◄──────   SSE stream of events:
                                            step_start / tool_call / tool_result
                                            / message / done
apply proposedActions locally     ◄──────   done: {
via the existing ActionExecutor              text: "...",
(confirmation UI for destructive)            proposedActions: [
                                               { id, tool:"create_sale_bill", args:{...} }
POST /v1/agent/actions/ack        ──────►     ]
  └─ which actions were applied            }  ← recorded for audit + metering
```

- **Read tools** (`list_items`, `get_analytics`, …) answer from `context`.
- **Write tools** (`create_sale_bill`, `create_customer`, …) do **not** touch a
  database. They return a validated `proposedAction`. The client applies it to
  local SQLite (reusing `ActionExecutor`, now permission-gated) and calls
  `/actions/ack` so the gateway can write the audit + usage rows.
- When Phase 7 lands, write tools gain real handlers and `proposedAction`
  becomes an internal implementation detail.

Postgres is used **now** only for gateway-owned data: conversations, messages,
tool executions, usage events, audit log, tenant memory.

---

## Request lifecycle

```
POST /v1/agent/chat
  │
  ├─ auth middleware        verify Firebase ID token → uid
  ├─ tenant middleware      uid → { tenantId, role, permissions }
  │                         (owner: tenantId = uid; team member: from team_access)
  ├─ rate limit             per tenant  (TODO: Redis; in-memory for now)
  ├─ quota check            plan limits, server-authoritative  (TODO)
  │
  ├─ load conversation      last N messages from Postgres
  ├─ build context          system prompt (instructions only)
  │                         + untrusted-data block (client context, delimited)
  │
  └─ orchestrator loop  (max MAX_AGENT_STEPS)
       │
       ├─ llm.generate({ system, messages, tools })   ← model router picks tier
       ├─ no tool calls  → emit `message`, break
       ├─ for each tool call:
       │     permission denied      → tool result: error, continue
       │     requiresConfirmation   → push proposedAction, tool result: pending
       │     else                   → run handler, emit `tool_result`
       └─ feed results back, next step
  │
  ├─ persist messages + tool_executions + usage_events + audit_log
  └─ emit `done` { text, proposedActions }
```

---

## Layout

```
server/
  src/
    index.ts               bootstrap (starts the HTTP server)
    config.ts              env parsing + validation (zod)
    http/app.ts            Hono app, middleware wiring, error handler
    auth/
      firebase.ts          Admin SDK init, verifyIdToken
      tenant.ts            auth + tenant-resolution middleware
    db/
      client.ts            pg pool + drizzle
      schema.ts            gateway tables (conversations, usage_events, …)
    llm/
      types.ts             provider-agnostic interface (tool calling)
      openrouter.ts        OpenRouter implementation (OpenAI-compatible)
      router.ts            model tier selection + fallback
    agent/
      prompt.ts            system prompt + untrusted-data block builder
      orchestrator.ts      the loop + SSE event types
    tools/
      registry.ts          Tool type, ToolContext, the registry
      read.ts              read tools (operate on client-provided context)
      write.ts             write tools (return proposedAction)
    billing/
      prices.ts            server-authoritative price table + expiry calc
      razorpay.ts          create order (REST), verify webhook signature
      activate.ts          webhook-only: activate plan in Firestore (Admin SDK)
    routes/
      health.ts            GET /healthz
      agent.ts             POST /v1/agent/chat (SSE), /actions/ack, /conversations
      billing.ts           POST /v1/billing/order, GET /v1/billing/subscription
      webhooks.ts          POST /webhooks/razorpay  (signature-verified, no auth)
    observability/
      logger.ts            pino
      usage.ts             record usage_events / tool_executions / audit_log
  drizzle.config.ts
  docker-compose.yml       local Postgres
  Dockerfile               Cloud Run image
```

---

## Local development

```bash
cd server
cp .env.example .env          # fill OPENROUTER_KEY, FIREBASE_* , DATABASE_URL
docker compose up -d          # Postgres on :5432
npm install
npm run db:push               # create tables from src/db/schema.ts
npm run dev                   # http://localhost:8080
```

Smoke test (needs a real Firebase ID token from the app / emulator):

```bash
curl -N http://localhost:8080/v1/agent/chat \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "conversationId": null,
        "message": "aaj ka sale kitna hua",
        "context": { "analytics": { "todaySale": 1180, "billCount": 2 },
                     "items": [], "customers": [], "permissions": {} }
      }'
```

---

## Deployment (Cloud Run)

```bash
gcloud run deploy apnaca-agent-gateway \
  --source . \
  --region asia-south1 \
  --no-allow-unauthenticated=false \
  --set-env-vars NODE_ENV=production \
  --set-secrets OPENROUTER_KEY=openrouter-key:latest,DATABASE_URL=agent-db-url:latest
```

- Region `asia-south1` — keep customer PII in India.
- Secrets from Secret Manager, never env files.
- Cloud SQL Postgres via the Cloud SQL connector (add `--add-cloudsql-instances`).

---

## Client change (Flutter, minimal, feature-flagged)

`AiChatRepository` gains an `AgentGatewayClient`. When the flag is on,
`sendMessage` posts to `/v1/agent/chat` and streams events instead of calling
`OpenRouterService` + `ActionParser` + `ActionExecutor`. `ActionExecutor` stays
as the local "apply a proposed action" layer, now called only after a
permission + confirmation check. Offline, the old local path remains as a
read-only fallback.

---

## What is still TODO in this skeleton

- Redis rate limiting + response cache (in-memory placeholder).
- Server-authoritative quota check against the plan (billing state is now server-owned — wire it into `/v1/agent/chat`).
- Anthropic / Vertex provider implementations + real model-tier routing.
- Team invite / accept routes.
- Real write-tool handlers (arrives with Phase 7 sync).
- OpenTelemetry exporter wiring.

**Done:** token streaming, structured cards, Razorpay order + verified webhook.
