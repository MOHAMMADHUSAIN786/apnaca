#!/usr/bin/env bash
# Build → migrate → deploy the Agent Gateway to Cloud Run.
# One-time provisioning (Cloud SQL, secrets, service account) is in DEPLOY.md.
#
# Usage:  ./deploy.sh
# Requires: gcloud (authenticated), the vars below, and Cloud SQL Auth Proxy
#           OR a reachable DATABASE_URL for the migration step.
set -euo pipefail

# ── config ───────────────────────────────────────────────────────────────────
PROJECT="${GCP_PROJECT:-apnaca-5098e}"
REGION="${GCP_REGION:-asia-south1}"
SERVICE="${GATEWAY_SERVICE:-apnaca-agent-gateway}"
SQL_INSTANCE="${SQL_INSTANCE:-apnaca-agent-db}"            # Cloud SQL instance name
SQL_CONNECTION="${PROJECT}:${REGION}:${SQL_INSTANCE}"

echo "▶ project=$PROJECT region=$REGION service=$SERVICE"

# ── 1. migrations ────────────────────────────────────────────────────────────
# Needs DATABASE_URL pointing at the DB (via Cloud SQL Auth Proxy locally).
if [[ -n "${DATABASE_URL:-}" ]]; then
  echo "▶ applying migrations"
  npm ci
  npm run build
  node dist/db/migrate.js
else
  echo "⚠ DATABASE_URL not set — skipping migrations. Run them before this deploy serves traffic:"
  echo "    cloud-sql-proxy $SQL_CONNECTION &"
  echo "    DATABASE_URL='postgres://apnaca:PASS@localhost:5432/apnaca_agent' npm run db:migrate:run"
fi

# ── 2. deploy ────────────────────────────────────────────────────────────────
echo "▶ deploying to Cloud Run (source build)"
gcloud run deploy "$SERVICE" \
  --project "$PROJECT" \
  --region "$REGION" \
  --source . \
  --platform managed \
  --allow-unauthenticated \
  --add-cloudsql-instances "$SQL_CONNECTION" \
  --set-env-vars "NODE_ENV=production,FIREBASE_PROJECT_ID=${PROJECT},LLM_MODEL_FAST=google/gemini-2.5-flash,LLM_MODEL_STANDARD=google/gemini-2.5-flash,MAX_AGENT_STEPS=5" \
  --set-secrets "OPENROUTER_KEY=openrouter-key:latest,DATABASE_URL=agent-database-url:latest,RAZORPAY_KEY_ID=razorpay-key-id:latest,RAZORPAY_KEY_SECRET=razorpay-key-secret:latest,RAZORPAY_WEBHOOK_SECRET=razorpay-webhook-secret:latest" \
  --min-instances 0 \
  --max-instances 10 \
  --cpu 1 --memory 512Mi \
  --timeout 120

URL="$(gcloud run services describe "$SERVICE" --project "$PROJECT" --region "$REGION" --format='value(status.url)')"
echo "✅ deployed: $URL"
echo "   health:   $URL/healthz"
echo "   webhook:  $URL/webhooks/razorpay   (add this in the Razorpay dashboard)"
