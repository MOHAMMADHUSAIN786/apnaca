# Firestore / Storage security-rules tests

Runs `firestore.rules` + `storage.rules` against the Firebase emulators and
asserts the cross-tenant boundary holds. **Run this green before every
`firebase deploy --only firestore:rules,storage`.**

## Run

```bash
cd firebase-tests
npm ci
npm test          # starts the emulators, runs vitest, tears down
```

Needs the `firebase` CLI (bundled here as a devDependency) and a JDK (the
Firestore/Storage emulators are Java).

## What it checks

- `users/{uid}` + `users/{uid}/AI_CHAT/**` — private to the account.
- `subscriptions/{uid}` — owner may create the free doc and bump usage
  counters, but **cannot** self-upgrade `plan` / `expiry_date` (webhook-only).
- `companies/{id}` — owner reads own, strangers denied.
- `ai_error_logs` — create-own only, no client reads (admin can read).
- Storage `database_backups/user_{uid}*.db` + `users/{uid}/branding/**` — owner
  only; a stranger with no `team_access` doc is denied.
- Undeclared collections are denied (default-deny catch-all).

## Not covered here (test manually in the emulator UI or the app)

- Team-member access: a user **with** a `team_access/{uid}` doc pointing at an
  owner should be able to read that owner's company + DB backup. The storage
  side needs both emulators up so `firestore.get()` inside the storage rule
  resolves.
- `collectionGroup('members')` invite lookup by email.
