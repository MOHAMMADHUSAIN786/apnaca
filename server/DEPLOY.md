# Deploying the ApnaCA Agent Gateway

Target: **Cloud Run** + **Cloud SQL (Postgres)**, region **`asia-south1`** (keep
Indian customer PII in India). Project: `apnaca-5098e`.

Everything below is done **by a human with `gcloud` + Firebase + Razorpay
access** — Claude cannot provision or deploy.

---

## A. One-time provisioning

### 1. Enable APIs

```bash
gcloud config set project apnaca-5098e
gcloud services enable \
  run.googleapis.com sqladmin.googleapis.com \
  secretmanager.googleapis.com cloudbuild.googleapis.com \
  artifactregistry.googleapis.com
```

### 2. Cloud SQL (Postgres 16)

```bash
gcloud sql instances create apnaca-agent-db \
  --database-version=POSTGRES_16 \
  --edition=ENTERPRISE \
  --tier=db-f1-micro \
  --region=asia-south1 \
  --storage-size=10GB --storage-auto-increase
# NOTE: --edition=ENTERPRISE is required — the new default (ENTERPRISE_PLUS)
# rejects shared-core tiers like db-f1-micro.

gcloud sql databases create apnaca_agent --instance=apnaca-agent-db
gcloud sql users create apnaca --instance=apnaca-agent-db --password='<STRONG_PW>'
```

Connection name: `apnaca-5098e:asia-south1:apnaca-agent-db`.

### 3. Service account for the gateway

```bash
gcloud iam service-accounts create apnaca-agent-gw \
  --display-name="ApnaCA Agent Gateway"

SA="apnaca-agent-gw@apnaca-5098e.iam.gserviceaccount.com"

# Cloud SQL client + Firebase admin (Firestore) + read secrets
gcloud projects add-iam-policy-binding apnaca-5098e \
  --member="serviceAccount:$SA" --role="roles/cloudsql.client"
gcloud projects add-iam-policy-binding apnaca-5098e \
  --member="serviceAccount:$SA" --role="roles/datastore.user"
gcloud projects add-iam-policy-binding apnaca-5098e \
  --member="serviceAccount:$SA" --role="roles/secretmanager.secretAccessor"
```

The gateway uses **Application Default Credentials** on Cloud Run (no
`GOOGLE_APPLICATION_CREDENTIALS` file needed there) — `firebase-admin` picks up
the service account automatically.

### 4. Secrets (Secret Manager)

```bash
# rotate these FIRST if they were ever in the app bundle / git
printf '%s' '<NEW_OPENROUTER_KEY>'        | gcloud secrets create openrouter-key         --data-file=-
printf '%s' '<RAZORPAY_LIVE_KEY_ID>'      | gcloud secrets create razorpay-key-id        --data-file=-
printf '%s' '<RAZORPAY_LIVE_KEY_SECRET>'  | gcloud secrets create razorpay-key-secret    --data-file=-
printf '%s' '<RAZORPAY_WEBHOOK_SECRET>'   | gcloud secrets create razorpay-webhook-secret --data-file=-

# DATABASE_URL via the Cloud SQL unix socket (no SSL needed):
printf '%s' 'postgresql://apnaca:<STRONG_PW>@/apnaca_agent?host=/cloudsql/apnaca-5098e:asia-south1:apnaca-agent-db' \
  | gcloud secrets create agent-database-url --data-file=-
```

To rotate later: `gcloud secrets versions add <name> --data-file=-`.

---

## B. Apply the DB schema

Migrations live in `server/drizzle/`. Run them **before** the new revision
serves traffic.

```bash
# terminal 1 — proxy
cloud-sql-proxy apnaca-5098e:asia-south1:apnaca-agent-db

# terminal 2 — migrate
cd server
npm ci
DATABASE_URL='postgres://apnaca:<STRONG_PW>@localhost:5432/apnaca_agent' npm run db:migrate:run
```

(`deploy.sh` also runs this step if `DATABASE_URL` is exported.)

---

## C. Deploy the gateway

```bash
cd server
GCP_PROJECT=apnaca-5098e ./deploy.sh
```

`deploy.sh` runs `gcloud run deploy --source .` with the Cloud SQL socket, env
vars, and all five secrets wired. It prints the service URL.

Set the runtime service account:

```bash
gcloud run services update apnaca-agent-gateway \
  --region asia-south1 \
  --service-account apnaca-agent-gw@apnaca-5098e.iam.gserviceaccount.com
```

Smoke test:

```bash
curl -s https://<SERVICE_URL>/healthz          # {"ok":true}
curl -s https://<SERVICE_URL>/readyz           # {"ok":true,"db":"up"}
```

---

## D. Razorpay webhook

1. Dashboard → **Settings → Webhooks → Add New Webhook**
   - URL: `https://<SERVICE_URL>/webhooks/razorpay`
   - Secret: the value you put in `razorpay-webhook-secret`
   - Events: **`payment.captured`** and **`order.paid`**
2. Send a test event → gateway logs should show `razorpay webhook` and
   `ignored`/`activated`.
3. Do a real ₹1 test payment end to end (test-mode keys), confirm the
   `subscriptions/{uid}` doc flips to the paid plan and the app's screen updates
   after polling.

---

## E. Firestore / Storage security rules

The repo has `firestore.rules` + `storage.rules`; `firebase.json` references
them. **Test in the emulator before deploying** (see `../firebase-tests/`).

```bash
cd firebase-tests
npm ci
npm test                       # rules-unit-testing suite — must pass

cd ..
firebase deploy --only firestore:rules,storage
```

After deploy, re-run every app flow: signup, login, **team-member login**,
create/switch company, add team member, **buy a plan**, AI chat, contact-us,
feedback, admin. Confirm a second user cannot read the first user's
`subscriptions/*` or `database_backups/*`.

---

## F. Point the app at the gateway

In the app's `.env` (out of band — never commit):

```
AGENT_GATEWAY_URL=https://<SERVICE_URL>
AGENT_GATEWAY_ENABLED=true
```

Rebuild. The AI chat + billing now go through the gateway. Set
`AGENT_GATEWAY_ENABLED=false` to roll back instantly to the local path.

---

## Rollback

- **App:** flip `AGENT_GATEWAY_ENABLED=false`, ship a build (or use a remote
  config flag once one exists).
- **Gateway:** `gcloud run services update-traffic apnaca-agent-gateway
  --region asia-south1 --to-revisions <PREV>=100`.
- **Rules:** `firebase deploy` a reverted `firestore.rules` (keep the previous
  version in git).

## Cost (rough, low traffic)

Cloud Run scale-to-zero ≈ ₹0 idle · Cloud SQL `db-f1-micro` ≈ ₹600–900/mo ·
Secret Manager ≈ ₹0 · egress negligible. Bump the SQL tier only when
`usage_events` / `messages` growth or connection count demands it.
