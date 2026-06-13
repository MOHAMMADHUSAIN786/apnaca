# New Features (Company / Warehouse / POS / Outbox Sync)

This document describes the features added to `apnaca` in the recent updates: multi-company DB switching, multi-warehouse stock, a basic POS quick-billing screen, and an Outbox-based offline sync worker.

## 1) Multi-Company (per-user DBs)
- Location: `lib/core/services/company_service.dart` and `lib/features/company/presentation/pages/company_switcher.dart`
- Approach: Each company/user uses a separate SQLite file named `billnex_<uid>.db`. Use `CompanyService.switchCompany(dbName)` to switch the active DB. The `AppDatabase` class exposes `switchUser(String uid)` for switching.
- Notes:
  - Switching closes the existing DB connection and opens the selected company DB on next access.
  - Backups: simply copy the DB file from the device's database path.

## 2) Warehouses & Per-Warehouse Stock
- Location: `lib/database/app_database.dart` (tables: `warehouses`, `warehouse_items`, helpers `upsertWarehouseItem`, `getWarehouseItemQty`, `transferStock`)
- Behavior:
  - Sale and Purchase bill item insert/delete methods update per-warehouse stock when the parent bill includes `warehouse_id`.
  - If `warehouse_id` is absent, the app falls back to existing global `items` stock helpers.
- Migration: DB version bumped to 10; upgrade logic adds `warehouse_id` column to bills for existing installs.

## 3) POS (Quick Billing)
- Location: `lib/features/pos/presentation/pages/pos_screen.dart`
- Behavior:
  - Simple item grid + cart, checkout creates a `sale_bills` entry and `sale_bill_items`.
  - Uses `current_warehouse_id` from `SharedPreferences` if set.
  - Accessible via FAB on the Sales list screen.
- Next improvements: barcode scanning, payment dialogs, thermal printing, and immediate receipts.

## 4) Outbox-based Offline Sync Worker
- Location: `lib/core/services/outbox_sync_service.dart`
- Behavior:
  - Periodically scans `outbox` table for rows with `status = 'pending'` and attempts upload.
  - Uses `SYNC_ENDPOINT` and `SYNC_AUTH_TOKEN` (from `.env`) to POST JSON payloads.
  - Deletes outbox rows on success; writes `last_try` timestamp on failure (simple backoff).
- Startup: `OutboxSyncService.startPeriodicSync()` is invoked from `main.dart` during startup.

## How to configure
1. Add the following to your `.env` file at repo root (create if needed):

```
SYNC_ENDPOINT=https://your-server.example.com/api/sync
SYNC_AUTH_TOKEN=your_api_token_here
```

2. Run:

```bash
flutter pub get
flutter analyze
flutter test
```

## Tests
- Basic test stubs are included under `test/` to help you validate wiring locally. The tests are intentionally marked to skip unless the test runner environment is configured for `sqflite`.

## How to verify manually
- Company switcher: open the Company screen, create/switch a company, then check device DB file `billnex_<db>.db` created under the device database path.
- Warehouses: create a warehouse in the DB (or via UI if built), then create sale/purchase bills with `warehouse_id` set and verify `warehouse_items` quantities are updated.
- POS: open Sales list screen and tap the FAB to open POS; add items and `Pay & Save` — confirm a sale bill appears.
- Outbox: create a local change that calls `AppDatabase.addOutbox(...)`, then watch `outbox` table and confirm the periodic uploader attempts to send them to `SYNC_ENDPOINT`.

## Next actions (suggested)
- Wire all bill-create UIs to include explicit warehouse selection.
- Add unit/integration tests that run with `sqflite_common_ffi` in CI.
- Implement robust conflict resolution rules on the server and a retry/queue policy client-side.
- Add UI status indicator for sync activity and error logs.

If you want, I can now:
- Add CI-friendly tests using `sqflite_common_ffi` and `http/testing` and update `pubspec.yaml`.
- Wire a small sync status indicator in the app's main UI.
Which should I do next?

---

## Demo data and quick start

I added a tiny demo-data loader to help validate multi-company and warehouse flows locally.

- File: `lib/tools/demo_data.dart`
- Purpose: seeds a `demo_company` DB with a `companies` row, two `warehouses`, and a few `items`.

Run it from your project root with Dart/Flutter:

```bash
# fetch packages first
flutter pub get

# run demo loader
dart run lib/tools/demo_data.dart
```

After running, open the app and switch to company `demo_company` (use the Company Switcher UI) or call `CompanyService.switchCompany('demo_company')` programmatically. The demo loader also saves a `current_warehouse_id` into `SharedPreferences` so POS will pick a default warehouse.

If you want, I can extend the demo loader to create sample sales/purchase bills and export a ready-to-import DB file.

---

## Implementation Verification (feature-by-feature)

Below is a quick verification of the roadmap items you listed and whether they are implemented in the codebase (as of this commit).

- **Immediate (Month 1-2)**
  - **Warehouse / Godown Management:** Implemented
    - Evidence: `lib/database/app_database.dart` defines `warehouses`, `warehouse_items`, `upsertWarehouseItem`, and `transferStock`. Sale/purchase insertion updates per-warehouse stock when `warehouse_id` is present. See [lib/database/app_database.dart](lib/database/app_database.dart#L326).
  - **POS (Point of Sale):** Partially implemented
    - Evidence: Quick POS UI at [lib/features/pos/presentation/pages/pos_screen.dart](lib/features/pos/presentation/pages/pos_screen.dart#L1) creates sale bills and uses `current_warehouse_id`.
    - Missing: barcode scanner integration, cash-drawer, thermal printing, richer payment dialogs — not present yet.
    - Recent enhancements: search box, payment dialog scaffold, hardware service stubs (`HardwareService`) and outbox enqueue on POS save.
      - Files: [lib/features/pos/presentation/pages/pos_screen.dart](lib/features/pos/presentation/pages/pos_screen.dart#L1), [lib/core/services/hardware_service.dart](lib/core/services/hardware_service.dart#L1)
      - **Barcode / SKU support:** Added `barcode` column to `items` table and basic camera-scan stub that maps scanned code to items by `barcode` or name. DB version bumped to 12 for migration. See [lib/database/app_database.dart](lib/database/app_database.dart#L1) and [lib/features/item/model/item_model.dart](lib/features/item/model/item_model.dart#L1).
  - **Multiple Company / Business:** Implemented
    - Evidence: `CompanyService` and `AppDatabase.switchUser` with per-user DB files (`billnex_<uid>.db`). See [lib/core/services/company_service.dart](lib/core/services/company_service.dart) and [lib/database/app_database.dart](lib/database/app_database.dart#L1).

- **Growth (Month 2-3)**
  - **Party Ledger / Khata Book:** Not implemented
    - Evidence: No `ledger`/`khata` feature files; `transactions` table referenced in cleanup but no full ledger UI or running balance code.
  - **Expense Management & P&L:** Not implemented (placeholder)
    - Evidence: `getAllExpenses()` is a placeholder in `AppDatabase` and there are no `features/expense` files.
  - **Manufacturing / BOM:** Not implemented
  - **Staff Management & Access Control:** Not implemented
  - **Quotation / Estimate:** Not implemented

- **Scale (Month 3-4)**
  - **Delivery / Challan:** Not implemented
  - **Repairs & Service Module:** Not implemented
  - **E-Commerce Integrations (Shopify/Woo):** Not implemented
  - **Bank & Cash Management:** Partially implemented
    - Evidence: `sale_bills` and `purchase_bills` have `payment_mode` and `payment_status` fields; no bank reconciliation module.
  - **Assets Management:** Not implemented

- **Enterprise (Month 4-6)**
  - **GST & Compliance Suite:** Partially implemented
    - Evidence: GST fields and supplier/customer `gst_number` are present (see supplier UI widgets), but no GSTR generation, IRN/e-invoice or e-way bill integration.
  - **Tally Integration:** Not implemented
  - **Multi-Currency Support:** Not implemented
  - **Franchise Management:** Not implemented
  - **CRM Features:** Partially implemented
    - Evidence: Customer model and basic customer screens exist (customer CRUD), but no reminders, pipeline, or activity history.

### Quick notes & next verification steps
- To mark unimplemented items as "available", I can scaffold DB tables and simple UI stubs (e.g., `features/expense`, `features/ledger`) and add tests.
- For partially implemented items (POS, GST, Bank/CRM), I can list a concrete small plan to finish core gaps (barcode, printing, reconciliation, GST export).

If you want, I will now:
- Scaffold minimal modules for the highest-priority missing items (choose up to 2: `expense`, `ledger`, `barcode/pos enhancements`, `gst exports`).
- Or run the tests and fix analyzer failures reported by your local `flutter pub get` run.