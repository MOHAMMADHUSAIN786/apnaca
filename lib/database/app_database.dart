import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../core/services/sync_service.dart';
import '../features/customer/model/customer_model.dart';
import '../features/item/model/item_model.dart';
import '../features/supplier/model/supplier_model.dart';
import '../features/subscription/service/subscription_service.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _db;
  static String? _currentUid; // ← track which user's DB is open
  AppDatabase._internal();

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  // ════════════════════════════════════════════════════════
  //  USER SWITCH — call on login with new UID
  //  Closes old DB, opens fresh DB for new user
  // ════════════════════════════════════════════════════════
  static Future<void> switchUser(String uid) async {
    if (_currentUid == uid && _db != null) return; // same user, already open

    // Close existing connection
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _currentUid = uid;
    // Re-open will happen lazily on next `database` call
  }

  // ════════════════════════════════════════════════════════
  //  CLEAR ALL LOCAL DATA — call on logout
  //  Wipes every table so next user starts fresh
  // ════════════════════════════════════════════════════════
  Future<void> clearAllData() async {
    try {
      final db = await database;
      final tables = [
        'users',
        'items',
        'customers',
        'suppliers',
        'sale_bills',
        'sale_bill_items',
        'purchase_bills',
        'purchase_bill_items',
        'transactions',
        'warehouses',
        'warehouse_items',
      ];
      await db.transaction((txn) async {
        for (final table in tables) {
          try {
            await txn.execute('DELETE FROM $table');
          } catch (_) {
            // Table may not exist in older schema — skip silently
          }
        }
      });
    } catch (e) {
      // If even this fails, close & nullify — fresh open next time
    } finally {
      if (_db != null) {
        await _db!.close();
        _db = null;
      }
      _currentUid = null;
    }
  }

  Future<Database> _initDb() async {
    // Per-user DB file: billnex_<uid>.db  (fallback: billnex.db for safety)
    final uid      = _currentUid ?? 'default';
    final dbName   = 'billnex_$uid.db';
    final path     = join(await getDatabasesPath(), dbName);
      return await openDatabase(
        path,
        version: 15, // bumped to 15 — Repairs, Ecommerce, Assets, GST, Tally, MultiCurrency, Franchise, CRM
        onCreate: _onCreate,
        onUpgrade: _onUpgrade
      );
  }

  // ════════════════════════════════════════════════════════
  //  CREATE (fresh install)
  // ════════════════════════════════════════════════════════

  Future<void> _onCreate(Database db, int version) async {
    await _createUsers(db);
    await _createItems(db);
    await _createCustomers(db);
    await _createSaleBills(db);
    await _createSaleBillItems(db);
    await _createSuppliers(db);        // ✅ added
    await _createPurchaseBills(db);    // ✅ added
    await _createPurchaseBillItems(db); // ✅ added
    await _createOutbox(db);
    await _createSyncLogs(db);
    // v13 — new feature tables
    await _createExpenses(db);
    await _createLedgerEntries(db);
    await _createQuotations(db);
    await _createQuotationItems(db);
    await _createCompanies(db);
    await _createWarehouses(db);
    await _createWarehouseItems(db);
    await _createStockTransfers(db);
    // v14 — Milestone 1
    await _createBom(db);
    await _createBomItems(db);
    await _createProductionOrders(db);
    await _createStaff(db);
    await _createStaffAttendance(db);
    await _createBankAccounts(db);
    await _createBankTransactions(db);
    await _createDeliveryChallans(db);
    await _createChallanItems(db);
    // v15 — Enterprise modules
    await _createRepairJobs(db);
    await _createRepairParts(db);
    await _createEcommerceSettings(db);
    await _createEcommerceSyncLogs(db);
    await _createAssets(db);
    await _createAssetDepreciation(db);
    await _createAssetMaintenance(db);
    await _createGstReturns(db);
    await _createEInvoice(db);
    await _createEWayBill(db);
    await _createTdsEntries(db);
    await _createTallyExportLogs(db);
    await _createCurrencyRates(db);
    await _createFranchiseOutlets(db);
    await _createFranchiseRoyalty(db);
    await _createCrmTasks(db);
    await _createCrmPipeline(db);
  }

  // ════════════════════════════════════════════════════════
  //  UPGRADE (existing installs)
  // ════════════════════════════════════════════════════════

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createCustomers(db);
    if (oldVersion < 3) {
      await _createSaleBills(db);
      await _createSaleBillItems(db);
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE sale_bills ADD COLUMN tax_type TEXT DEFAULT "exclusive"');
      await db.execute('ALTER TABLE sale_bills ADD COLUMN discount_type TEXT DEFAULT "none"');
      await db.execute('ALTER TABLE sale_bills ADD COLUMN discount_value REAL DEFAULT 0');
      await db.execute('ALTER TABLE sale_bills ADD COLUMN discount_amount REAL DEFAULT 0');
      await db.execute('ALTER TABLE sale_bill_items ADD COLUMN discount_amount REAL DEFAULT 0');
    }
    if (oldVersion < 11) {
      await _createOutbox(db);
      await _createSyncLogs(db);
    }
    if (oldVersion < 12) {
      // add barcode column to items for barcode/sku mapping
      try {
        await db.execute('ALTER TABLE items ADD COLUMN barcode TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      await db.execute('''
      CREATE TABLE sale_bills_temp (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_number      TEXT    UNIQUE NOT NULL,
        customer_id      INTEGER REFERENCES customers(id),
        bill_date        TEXT    NOT NULL,
        due_date         TEXT,
        tax_type         TEXT    DEFAULT "exclusive",
        discount_type    TEXT    DEFAULT "none",
        discount_value   REAL    DEFAULT 0,
        discount_amount  REAL    DEFAULT 0,
        subtotal         REAL    NOT NULL DEFAULT 0,
        gst_amount       REAL    NOT NULL DEFAULT 0,
        total_amount     REAL    NOT NULL DEFAULT 0,
        payment_mode     TEXT    DEFAULT "cash",
        payment_status   TEXT    DEFAULT "unpaid",
        notes            TEXT,
        created_at       TEXT    DEFAULT CURRENT_TIMESTAMP
      )''');
      await db.execute('''
      INSERT INTO sale_bills_temp
      SELECT id, bill_number, customer_id, bill_date, due_date,
             COALESCE(tax_type, 'exclusive'),
             COALESCE(discount_type, 'none'),
             COALESCE(discount_value, 0),
             COALESCE(discount_amount, 0),
             subtotal, gst_amount, total_amount,
             COALESCE(payment_mode, 'cash'),
             COALESCE(payment_status, 'unpaid'),
             notes, created_at
      FROM sale_bills''');
      await db.execute('DROP TABLE sale_bills');
      await db.execute('ALTER TABLE sale_bills_temp RENAME TO sale_bills');
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN photo_url TEXT');
      } catch (e) {}
    }
    if (oldVersion < 7) {
      try { await db.execute('ALTER TABLE users ADD COLUMN companyName TEXT'); } catch (e) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN mobile TEXT'); } catch (e) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN username TEXT'); } catch (e) {}
    }
    if (oldVersion < 8) {
      // ✅ Add suppliers + purchase bills for existing users upgrading
      await _createSuppliers(db);
      await _createPurchaseBills(db);
      await _createPurchaseBillItems(db);
      // new tables
      await _createCompanies(db);
      await _createWarehouses(db);
      await _createWarehouseItems(db);
      await _createStockTransfers(db);
      await _createOutbox(db);
    }
    if (oldVersion < 9) {
      // Add multi-warehouse & outbox support
      await _createCompanies(db);
      await _createWarehouses(db);
      await _createWarehouseItems(db);
      await _createStockTransfers(db);
      await _createOutbox(db);
    }
      if (oldVersion < 10) {
        // Add warehouse_id to existing sale_bills and purchase_bills
        try {
          await db.execute('ALTER TABLE sale_bills ADD COLUMN warehouse_id INTEGER');
        } catch (e) {}
        try {
          await db.execute('ALTER TABLE purchase_bills ADD COLUMN warehouse_id INTEGER');
        } catch (e) {}
      }
    if (oldVersion < 13) {
      // v13 — Expenses, Party Ledger, Quotations
      await _createExpenses(db);
      await _createLedgerEntries(db);
      await _createQuotations(db);
      await _createQuotationItems(db);
    }
    if (oldVersion < 14) {
      // v14 — Manufacturing, Staff, Bank, Challan
      await _createBom(db);
      await _createBomItems(db);
      await _createProductionOrders(db);
      await _createStaff(db);
      await _createStaffAttendance(db);
      await _createBankAccounts(db);
      await _createBankTransactions(db);
      await _createDeliveryChallans(db);
      await _createChallanItems(db);
    }
    if (oldVersion < 15) {
      // v15 — Enterprise modules
      await _createRepairJobs(db);
      await _createRepairParts(db);
      await _createEcommerceSettings(db);
      await _createEcommerceSyncLogs(db);
      await _createAssets(db);
      await _createAssetDepreciation(db);
      await _createAssetMaintenance(db);
      await _createGstReturns(db);
      await _createEInvoice(db);
      await _createEWayBill(db);
      await _createTdsEntries(db);
      await _createTallyExportLogs(db);
      await _createCurrencyRates(db);
      await _createFranchiseOutlets(db);
      await _createFranchiseRoyalty(db);
      await _createCrmTasks(db);
      await _createCrmPipeline(db);
    }
  }

  // ════════════════════════════════════════════════════════
  //  TABLE DEFINITIONS
  // ════════════════════════════════════════════════════════

  Future<void> _createUsers(Database db) => db.execute('''
CREATE TABLE users (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  firebaseUid TEXT UNIQUE,
  email       TEXT,
  displayName TEXT,
  companyName TEXT,
  mobile      TEXT,
  username    TEXT,
  photo_url   TEXT,
  createdAt   TEXT
)''');

  Future<void> _createItems(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS items (
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  name     TEXT NOT NULL,
  qty      INTEGER,
  price    REAL,
  hsn_code TEXT,
  barcode  TEXT
 )''');

  Future<void> _createCustomers(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS customers (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL,
  email      TEXT,
  phone      TEXT,
  address    TEXT,
  gst_number TEXT,
  state      TEXT
)''');

  Future<void> _createSaleBills(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS sale_bills (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  bill_number      TEXT    UNIQUE NOT NULL,
  customer_id      INTEGER REFERENCES customers(id),
  warehouse_id     INTEGER REFERENCES warehouses(id),
  bill_date        TEXT    NOT NULL,
  due_date         TEXT,
  tax_type         TEXT    DEFAULT "exclusive",
  discount_type    TEXT    DEFAULT "none",
  discount_value   REAL    DEFAULT 0,
  discount_amount  REAL    DEFAULT 0,
  subtotal         REAL    NOT NULL DEFAULT 0,
  gst_amount       REAL    NOT NULL DEFAULT 0,
  total_amount     REAL    NOT NULL DEFAULT 0,
  payment_mode     TEXT    DEFAULT "cash",
  payment_status   TEXT    DEFAULT "unpaid",
  notes            TEXT,
  created_at       TEXT    DEFAULT CURRENT_TIMESTAMP
)''');

  Future<void> _createSaleBillItems(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS sale_bill_items (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  bill_id         INTEGER NOT NULL REFERENCES sale_bills(id) ON DELETE CASCADE,
  item_id         INTEGER REFERENCES items(id),
  item_name       TEXT    NOT NULL,
  qty             INTEGER NOT NULL,
  unit_price      REAL    NOT NULL,
  discount_amount REAL    DEFAULT 0,
  tax_rate        REAL    DEFAULT 0,
  tax_amount      REAL    DEFAULT 0,
  line_total      REAL    NOT NULL
)''');

  Future<void> _createSuppliers(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS suppliers (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT    NOT NULL,
  email      TEXT,
  phone      TEXT,
  address    TEXT,
  gst_number TEXT,
  state      TEXT
)''');

  Future<void> _createPurchaseBills(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS purchase_bills (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  bill_number    TEXT    UNIQUE NOT NULL,
  supplier_id    INTEGER REFERENCES suppliers(id),
  warehouse_id   INTEGER REFERENCES warehouses(id),
  bill_date      TEXT    NOT NULL,
  subtotal       REAL    NOT NULL DEFAULT 0,
  tax_amount     REAL    NOT NULL DEFAULT 0,
  total_amount   REAL    NOT NULL DEFAULT 0,
  payment_mode   TEXT    DEFAULT 'cash',
  payment_status TEXT    DEFAULT 'unpaid',
  notes          TEXT,
  created_at     TEXT    DEFAULT (datetime('now'))
)''');

  Future<void> _createPurchaseBillItems(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS purchase_bill_items (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  bill_id    INTEGER NOT NULL REFERENCES purchase_bills(id) ON DELETE CASCADE,
  item_id    INTEGER REFERENCES items(id),
  item_name  TEXT    NOT NULL,
  qty        INTEGER NOT NULL,
  unit_price REAL    NOT NULL,
  tax_rate   REAL    DEFAULT 0,
  tax_amount REAL    DEFAULT 0,
  line_total REAL    NOT NULL
)''');

  Future<void> _createCompanies(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS companies (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  db_name     TEXT,
  branding    TEXT,
  created_at  TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createWarehouses(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS warehouses (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  code        TEXT,
  location    TEXT,
  created_at  TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createWarehouseItems(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS warehouse_items (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  warehouse_id  INTEGER NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  item_id       INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  quantity      REAL    DEFAULT 0,
  reserved_qty  REAL    DEFAULT 0,
  last_updated  TEXT    DEFAULT (datetime('now')),
  UNIQUE(warehouse_id, item_id)
)
''');

  Future<void> _createStockTransfers(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS stock_transfers (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  from_warehouse_id INTEGER REFERENCES warehouses(id),
  to_warehouse_id   INTEGER REFERENCES warehouses(id),
  item_id           INTEGER REFERENCES items(id),
  qty               REAL NOT NULL,
  status            TEXT DEFAULT 'pending',
  created_at        TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createExpenses(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS expenses (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  category    TEXT    NOT NULL,
  amount      REAL    NOT NULL DEFAULT 0,
  date        TEXT    NOT NULL,
  notes       TEXT,
  created_at  TEXT    DEFAULT (datetime('now'))
)
''');

  Future<void> _createLedgerEntries(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS ledger_entries (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  party_type      TEXT    NOT NULL,
  party_id        INTEGER NOT NULL,
  party_name      TEXT    NOT NULL,
  date            TEXT    NOT NULL,
  amount          REAL    NOT NULL DEFAULT 0,
  type            TEXT    NOT NULL,
  notes           TEXT,
  ref_bill_number TEXT,
  created_at      TEXT    DEFAULT (datetime('now'))
)
''');

  Future<void> _createQuotations(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS quotations (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  quotation_number TEXT    UNIQUE NOT NULL,
  customer_id      INTEGER REFERENCES customers(id),
  customer_name    TEXT,
  quotation_date   TEXT    NOT NULL,
  expiry_date      TEXT,
  tax_type         TEXT    DEFAULT "exclusive",
  discount_type    TEXT    DEFAULT "none",
  discount_value   REAL    DEFAULT 0,
  discount_amount  REAL    DEFAULT 0,
  subtotal         REAL    NOT NULL DEFAULT 0,
  gst_amount       REAL    NOT NULL DEFAULT 0,
  total_amount     REAL    NOT NULL DEFAULT 0,
  status           TEXT    DEFAULT "draft",
  notes            TEXT,
  created_at       TEXT    DEFAULT (datetime('now'))
)
''');

  Future<void> _createQuotationItems(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS quotation_items (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  quotation_id    INTEGER NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
  item_id         INTEGER REFERENCES items(id),
  item_name       TEXT    NOT NULL,
  qty             REAL    NOT NULL,
  unit_price      REAL    NOT NULL,
  discount_amount REAL    DEFAULT 0,
  tax_rate        REAL    DEFAULT 0,
  tax_amount      REAL    DEFAULT 0,
  line_total      REAL    NOT NULL
)
''');

  Future<void> _createOutbox(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS outbox (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type  TEXT NOT NULL,
  entity_id    TEXT,
  action       TEXT NOT NULL,
  payload      TEXT,
  status       TEXT DEFAULT 'pending',
  last_try     TEXT,
  created_at   TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createSyncLogs(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS sync_logs (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  status     TEXT NOT NULL,
  message    TEXT,
  created_at TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createBom(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS bom (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  finished_item_id INTEGER NOT NULL REFERENCES items(id),
  name         TEXT NOT NULL,
  notes        TEXT,
  created_at   TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createBomItems(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS bom_items (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  bom_id       INTEGER NOT NULL REFERENCES bom(id) ON DELETE CASCADE,
  raw_item_id  INTEGER NOT NULL REFERENCES items(id),
  qty          REAL NOT NULL
)
''');

  Future<void> _createProductionOrders(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS production_orders (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  order_number TEXT UNIQUE NOT NULL,
  bom_id       INTEGER NOT NULL REFERENCES bom(id),
  qty_to_produce REAL NOT NULL,
  status       TEXT DEFAULT 'pending',
  order_date   TEXT NOT NULL,
  notes        TEXT,
  created_at   TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createStaff(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS staff (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  name         TEXT NOT NULL,
  role         TEXT DEFAULT 'staff',
  phone        TEXT,
  pin          TEXT,
  salary       REAL,
  created_at   TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createStaffAttendance(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS staff_attendance (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  staff_id     INTEGER NOT NULL REFERENCES staff(id),
  date         TEXT NOT NULL,
  status       TEXT NOT NULL,
  notes        TEXT,
  created_at   TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createBankAccounts(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS bank_accounts (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  bank_name      TEXT NOT NULL,
  account_name   TEXT NOT NULL,
  account_number TEXT,
  ifsc_code      TEXT,
  opening_balance REAL DEFAULT 0,
  created_at     TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createBankTransactions(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS bank_transactions (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  bank_account_id INTEGER NOT NULL REFERENCES bank_accounts(id),
  date            TEXT NOT NULL,
  type            TEXT NOT NULL,
  amount          REAL NOT NULL,
  reference       TEXT,
  notes           TEXT,
  created_at      TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createDeliveryChallans(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS delivery_challans (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  challan_number   TEXT UNIQUE NOT NULL,
  customer_id      INTEGER REFERENCES customers(id),
  challan_date     TEXT NOT NULL,
  driver_name      TEXT,
  vehicle_number   TEXT,
  status           TEXT DEFAULT 'pending',
  notes            TEXT,
  created_at       TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createChallanItems(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS challan_items (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  challan_id      INTEGER NOT NULL REFERENCES delivery_challans(id) ON DELETE CASCADE,
  item_id         INTEGER REFERENCES items(id),
  item_name       TEXT NOT NULL,
  qty             REAL NOT NULL
)
''');

  // ════════════════════════════════════════════════════════
  //  v15 — REPAIRS & SERVICE
  // ════════════════════════════════════════════════════════

  Future<void> _createRepairJobs(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS repair_jobs (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  job_number      TEXT UNIQUE NOT NULL,
  customer_name   TEXT NOT NULL,
  customer_phone  TEXT,
  device_type     TEXT NOT NULL,
  device_model    TEXT,
  serial_number   TEXT,
  issue_reported  TEXT NOT NULL,
  service_charges REAL DEFAULT 0,
  status          TEXT DEFAULT 'pending',
  technician      TEXT,
  delivered_date  TEXT,
  notes           TEXT,
  created_at      TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createRepairParts(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS repair_parts (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id      INTEGER NOT NULL REFERENCES repair_jobs(id) ON DELETE CASCADE,
  part_name   TEXT NOT NULL,
  qty         REAL DEFAULT 1,
  unit_price  REAL DEFAULT 0,
  line_total  REAL DEFAULT 0
)
''');

  // ════════════════════════════════════════════════════════
  //  v15 — E-COMMERCE INTEGRATION
  // ════════════════════════════════════════════════════════

  Future<void> _createEcommerceSettings(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS ecommerce_settings (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  platform    TEXT NOT NULL,
  api_key     TEXT,
  api_secret  TEXT,
  store_url   TEXT,
  sync_stock  INTEGER DEFAULT 1,
  auto_order  INTEGER DEFAULT 0,
  last_sync   TEXT,
  created_at  TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createEcommerceSyncLogs(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS ecommerce_sync_logs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  platform    TEXT NOT NULL,
  direction   TEXT NOT NULL,
  entity_type TEXT,
  status      TEXT DEFAULT 'pending',
  message     TEXT,
  created_at  TEXT DEFAULT (datetime('now'))
)
''');

  // ════════════════════════════════════════════════════════
  //  v15 — ASSETS MANAGEMENT
  // ════════════════════════════════════════════════════════

  Future<void> _createAssets(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS assets (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name            TEXT NOT NULL,
  category        TEXT NOT NULL,
  purchase_date   TEXT,
  purchase_price  REAL DEFAULT 0,
  current_value   REAL DEFAULT 0,
  useful_life_yrs INTEGER DEFAULT 5,
  depreciation_pct REAL DEFAULT 10,
  warranty_until  TEXT,
  location        TEXT,
  notes           TEXT,
  created_at      TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createAssetDepreciation(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS asset_depreciation (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id    INTEGER NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  year        INTEGER NOT NULL,
  amount      REAL NOT NULL,
  book_value  REAL NOT NULL,
  created_at  TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createAssetMaintenance(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS asset_maintenance (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id    INTEGER NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  date        TEXT NOT NULL,
  description TEXT NOT NULL,
  cost        REAL DEFAULT 0,
  next_due    TEXT,
  created_at  TEXT DEFAULT (datetime('now'))
)
''');

  // ════════════════════════════════════════════════════════
  //  v15 — GST COMPLIANCE SUITE
  // ════════════════════════════════════════════════════════

  Future<void> _createGstReturns(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS gst_returns (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  return_type TEXT NOT NULL,
  period      TEXT NOT NULL,
  json_data   TEXT,
  status      TEXT DEFAULT 'draft',
  filed_date  TEXT,
  created_at  TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createEInvoice(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS e_invoices (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  bill_id         INTEGER REFERENCES sale_bills(id),
  irn             TEXT,
  ack_no          TEXT,
  ack_date        TEXT,
  status          TEXT DEFAULT 'pending',
  json_response   TEXT,
  created_at      TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createEWayBill(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS e_way_bills (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  bill_id         INTEGER REFERENCES sale_bills(id),
  ewb_no          TEXT,
  distance        REAL,
  valid_until     TEXT,
  status          TEXT DEFAULT 'pending',
  json_response   TEXT,
  created_at      TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createTdsEntries(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS tds_entries (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  party_name      TEXT NOT NULL,
  bill_number     TEXT,
  amount          REAL NOT NULL,
  tds_pct         REAL DEFAULT 10,
  tds_amount      REAL DEFAULT 0,
  section         TEXT DEFAULT '194A',
  date            TEXT NOT NULL,
  status          TEXT DEFAULT 'pending',
  created_at      TEXT DEFAULT (datetime('now'))
)
''');

  // ════════════════════════════════════════════════════════
  //  v15 — TALLY INTEGRATION
  // ════════════════════════════════════════════════════════

  Future<void> _createTallyExportLogs(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS tally_export_logs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  export_type TEXT NOT NULL,
  xml_data    TEXT,
  status      TEXT DEFAULT 'pending',
  message     TEXT,
  created_at  TEXT DEFAULT (datetime('now'))
)
''');

  // ════════════════════════════════════════════════════════
  //  v15 — MULTI-CURRENCY
  // ════════════════════════════════════════════════════════

  Future<void> _createCurrencyRates(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS currency_rates (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  code        TEXT NOT NULL UNIQUE,
  name        TEXT,
  symbol      TEXT,
  rate_inr    REAL NOT NULL,
  updated_at  TEXT DEFAULT (datetime('now'))
)
''');

  // ════════════════════════════════════════════════════════
  //  v15 — FRANCHISE MANAGEMENT
  // ════════════════════════════════════════════════════════

  Future<void> _createFranchiseOutlets(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS franchise_outlets (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  location    TEXT,
  owner_name  TEXT,
  phone       TEXT,
  royalty_pct REAL DEFAULT 5,
  status      TEXT DEFAULT 'active',
  created_at  TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createFranchiseRoyalty(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS franchise_royalty (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  outlet_id   INTEGER NOT NULL REFERENCES franchise_outlets(id),
  period      TEXT NOT NULL,
  sale_amount REAL DEFAULT 0,
  royalty_pct REAL DEFAULT 5,
  royalty_amount REAL DEFAULT 0,
  status      TEXT DEFAULT 'pending',
  paid_date   TEXT,
  created_at  TEXT DEFAULT (datetime('now'))
)
''');

  // ════════════════════════════════════════════════════════
  //  v15 — CRM
  // ════════════════════════════════════════════════════════

  Future<void> _createCrmTasks(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS crm_tasks (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id     INTEGER REFERENCES customers(id),
  customer_name   TEXT NOT NULL,
  task_type       TEXT NOT NULL,
  description     TEXT,
  due_date        TEXT,
  status          TEXT DEFAULT 'pending',
  created_at      TEXT DEFAULT (datetime('now'))
)
''');

  Future<void> _createCrmPipeline(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS crm_pipeline (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id     INTEGER REFERENCES customers(id),
  customer_name   TEXT NOT NULL,
  deal_value      REAL DEFAULT 0,
  stage           TEXT DEFAULT 'lead',
  probability     INTEGER DEFAULT 20,
  expected_close  TEXT,
  notes           TEXT,
  created_at      TEXT DEFAULT (datetime('now'))
)
''');

  Future<int> addSyncLog(String status, String? message) async {
    final db = await database;
    return await db.insert('sync_logs', {
      'status': status,
      'message': message,
    });
  }

  Future<List<Map<String, dynamic>>> getRecentSyncLogs({int limit = 50}) async {
    final db = await database;
    return await db.rawQuery('SELECT * FROM sync_logs ORDER BY id DESC LIMIT ?', [limit]);
  }

  // ════════════════════════════════════════════════════════
  //  USER
  // ════════════════════════════════════════════════════════

  Future<void> insertOrUpdateUser(Map<String, dynamic> data) async =>
      (await database).insert('users', data,
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Map<String, dynamic>?> getUserByFirebaseUid(String uid) async {
    final rows = await (await database).query(
        'users', where: 'firebaseUid = ?', whereArgs: [uid]);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> updateUserDisplayName(String uid, String displayName) async {
    final result = await (await database).update(
        'users', {'displayName': displayName},
        where: 'firebaseUid = ?', whereArgs: [uid]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<int> updateUserPhotoUrl(String uid, String photoUrl) async {
    final result = await (await database).update(
        'users', {'photo_url': photoUrl},
        where: 'firebaseUid = ?', whereArgs: [uid]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  // ════════════════════════════════════════════════════════
  //  ITEMS
  // ════════════════════════════════════════════════════════

  Future<int> insertItem(ItemModel item) async {
    final result = await (await database).insert('items', item.toMap());
    FirebaseSyncService.debouncedUpload();
    // Track subscription usage (fire-and-forget — never block DB op)
    SubscriptionService.instance.incrementItemCount().catchError((_) {});
    return result;
  }

  Future<List<ItemModel>> getAllItems() async {
    final rows = await (await database).query('items', orderBy: 'id DESC');
    return rows.map(ItemModel.fromMap).toList();
  }

  Future<ItemModel?> getItemById(int id) async {
    final rows = await (await database)
        .query('items', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : ItemModel.fromMap(rows.first);
  }

  Future<ItemModel?> getItemByName(String name) async {
    final rows = await (await database).query('items',
        where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    return rows.isEmpty ? null : ItemModel.fromMap(rows.first);
  }

  Future<ItemModel?> getItemByBarcode(String barcode) async {
    final rows = await (await database).query('items', where: 'barcode = ?', whereArgs: [barcode]);
    return rows.isEmpty ? null : ItemModel.fromMap(rows.first);
  }

  Future<ItemModel?> getItemFuzzy(String name) async {
    final all = await getAllItems();
    return _fuzzyFind(name, all.map((i) => MapEntry(i.name, i)).toList())?.value;
  }

  Future<int> updateItem(ItemModel item) async {
    final result = await (await database).update('items', item.toMap(),
        where: 'id = ?', whereArgs: [item.id]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<int> deleteItem(int id) async {
    final result = await (await database)
        .delete('items', where: 'id = ?', whereArgs: [id]);
    FirebaseSyncService.debouncedUpload();
    // Decrement subscription count
    SubscriptionService.instance.decrementItemCount().catchError((_) {});
    return result;
  }

  Future<void> deductItemStock(int itemId, int qty) async =>
      (await database).execute(
          'UPDATE items SET qty = MAX(0, COALESCE(qty,0) - ?) WHERE id = ?',
          [qty, itemId]);

  Future<void> restoreItemStock(int itemId, int qty) async =>
      (await database).execute(
          'UPDATE items SET qty = COALESCE(qty, 0) + ? WHERE id = ?',
          [qty, itemId]);

  Future<void> addItemStock(int itemId, int qty) async =>
      (await database).execute(
          'UPDATE items SET qty = COALESCE(qty, 0) + ? WHERE id = ?',
          [qty, itemId]);

  Future<bool> itemNameExists(String name) async {
    final rows = await (await database).query('items',
        where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    return rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getItemTransactions(String itemName) async {
    final item = await getItemByName(itemName) ?? await getItemFuzzy(itemName);
    if (item == null) return [];
    return (await database).rawQuery('''
      SELECT sb.bill_number, c.name AS customer_name,
             sb.bill_date, sbi.qty, sbi.unit_price,
             sbi.tax_rate, sbi.line_total, sb.payment_status
      FROM sale_bill_items sbi
      JOIN sale_bills sb ON sbi.bill_id = sb.id
      LEFT JOIN customers c ON sb.customer_id = c.id
      WHERE sbi.item_id = ?
      ORDER BY sb.bill_date DESC
    ''', [item.id]);
  }

  Future<String> getItemSummaryForAi() async {
    final items = await getAllItems();
    if (items.isEmpty) return 'ITEMS: none';
    return 'ITEMS (${items.length}):\n' +
        items.take(30).map((i) =>
        '  id:${i.id} name:"${i.name}" qty:${i.qty ?? "?"} price:${i.price ?? "?"}').join('\n');
  }

  // ════════════════════════════════════════════════════════
  //  CUSTOMERS
  // ════════════════════════════════════════════════════════

  Future<int> insertCustomer(CustomerModel c) async {
    final result = await (await database).insert('customers', c.toMap());
    FirebaseSyncService.debouncedUpload();
    // Track subscription usage
    SubscriptionService.instance.incrementCustomerCount().catchError((_) {});
    return result;
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    final rows = await (await database).query('customers', orderBy: 'id DESC');
    return rows.map(CustomerModel.fromMap).toList();
  }

  Future<CustomerModel?> getCustomerById(int id) async {
    final rows = await (await database)
        .query('customers', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : CustomerModel.fromMap(rows.first);
  }

  Future<CustomerModel?> getCustomerByName(String name) async {
    final rows = await (await database).query('customers',
        where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    return rows.isEmpty ? null : CustomerModel.fromMap(rows.first);
  }

  Future<CustomerModel?> getCustomerFuzzy(String name) async {
    final all = await getAllCustomers();
    return _fuzzyFind(name, all.map((c) => MapEntry(c.name, c)).toList())?.value;
  }

  Future<int> updateCustomer(CustomerModel c) async {
    final result = await (await database).update('customers', c.toMap(),
        where: 'id = ?', whereArgs: [c.id]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<int> deleteCustomer(int id) async {
    final result = await (await database)
        .delete('customers', where: 'id = ?', whereArgs: [id]);
    FirebaseSyncService.debouncedUpload();
    // Decrement subscription count
    SubscriptionService.instance.decrementCustomerCount().catchError((_) {});
    return result;
  }

  Future<bool> customerNameExists(String name) async {
    final rows = await (await database).query('customers',
        where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    return rows.isNotEmpty;
  }

  Future<String> getCustomerSummaryForAi() async {
    final customers = await getAllCustomers();
    if (customers.isEmpty) return 'CUSTOMERS: none';
    return 'CUSTOMERS (${customers.length}):\n' +
        customers.take(30).map((c) =>
        '  id:${c.id} name:"${c.name}" phone:${c.phone ?? "?"}').join('\n');
  }

  // ════════════════════════════════════════════════════════
  //  SUPPLIERS
  // ════════════════════════════════════════════════════════

  Future<int> insertSupplier(SupplierModel s) async {
    final result = await (await database).insert('suppliers', s.toMap());
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<List<SupplierModel>> getAllSuppliers() async {
    final rows = await (await database).query('suppliers', orderBy: 'id DESC');
    return rows.map(SupplierModel.fromMap).toList();
  }

  Future<SupplierModel?> getSupplierById(int id) async {
    final rows = await (await database)
        .query('suppliers', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : SupplierModel.fromMap(rows.first);
  }

  Future<SupplierModel?> getSupplierByName(String name) async {
    final rows = await (await database).query('suppliers',
        where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    return rows.isEmpty ? null : SupplierModel.fromMap(rows.first);
  }

  Future<SupplierModel?> getSupplierFuzzy(String name) async {
    final all = await getAllSuppliers();
    return _fuzzyFind(name, all.map((s) => MapEntry(s.name, s)).toList())?.value;
  }

  Future<int> updateSupplier(SupplierModel s) async {
    final result = await (await database).update('suppliers', s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<int> deleteSupplier(int id) async {
    final result = await (await database)
        .delete('suppliers', where: 'id = ?', whereArgs: [id]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<bool> supplierNameExists(String name) async {
    final rows = await (await database).query('suppliers',
        where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    return rows.isNotEmpty;
  }

  Future<String> getSupplierSummaryForAi() async {
    final suppliers = await getAllSuppliers();
    if (suppliers.isEmpty) return 'SUPPLIERS: none';
    return 'SUPPLIERS (${suppliers.length}):\n' +
        suppliers.take(30).map((s) =>
        '  id:${s.id} name:"${s.name}" phone:${s.phone ?? "?"}').join('\n');
  }

  // ════════════════════════════════════════════════════════
  //  SALE BILLS
  // ════════════════════════════════════════════════════════

  Future<String> generateBillNumber() async {
    final db = await database;
    final year = DateTime.now().year;
    final result = await db.rawQuery('SELECT MAX(id) as max_id FROM sale_bills');
    final nextId = ((result.first['max_id'] as int?) ?? 0) + 1;
    return 'SB-$year-${nextId.toString().padLeft(4, '0')}';
  }

  Future<int> insertSaleBill(Map<String, dynamic> data) async {
    final db = await database;
    final result = await db.insert('sale_bills', data,
        conflictAlgorithm: ConflictAlgorithm.abort);
    FirebaseSyncService.debouncedUpload();
    // Track subscription usage
    SubscriptionService.instance.incrementSaleBillCount().catchError((_) {});
    return result;
  }

  Future<int> insertSaleBillItem(Map<String, dynamic> data) async {
    final db = await database;
    final result = await db.insert('sale_bill_items', data);
    // Update warehouse/global stock based on parent bill's warehouse_id
    try {
      final billId = data['bill_id'];
      if (billId != null) {
        final bill = await getSaleBillById(billId as int);
        final whId = bill != null ? bill['warehouse_id'] as int? : null;
        final itemId = data['item_id'] as int?;
        final qty = (data['qty'] as num?)?.toDouble() ?? 0.0;
        if (itemId != null) {
          if (whId != null) {
            await upsertWarehouseItem(whId, itemId, -qty);
          } else {
            await deductItemStock(itemId, qty.toInt());
          }
        }
      }
    } catch (e) {}
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllSaleBills() async =>
      (await database).rawQuery('''
        SELECT sb.*, c.name as customer_name
        FROM sale_bills sb
        LEFT JOIN customers c ON sb.customer_id = c.id
        ORDER BY sb.id DESC
      ''');

  Future<Map<String, dynamic>?> getSaleBillById(int id) async {
    final rows = await (await database).rawQuery('''
      SELECT sb.*, c.name as customer_name
      FROM sale_bills sb LEFT JOIN customers c ON sb.customer_id = c.id
      WHERE sb.id = ?''', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getSaleBillByNumber(String billNumber) async {
    final rows = await (await database).rawQuery('''
      SELECT sb.*, c.name as customer_name
      FROM sale_bills sb LEFT JOIN customers c ON sb.customer_id = c.id
      WHERE sb.bill_number = ?''', [billNumber]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getSaleBillItems(int billId) async =>
      (await database).query('sale_bill_items',
          where: 'bill_id = ?', whereArgs: [billId]);

  Future<void> updateSaleBillStatus(int billId, String status) async {
    await (await database).update('sale_bills', {'payment_status': status},
        where: 'id = ?', whereArgs: [billId]);
    FirebaseSyncService.debouncedUpload();
  }

  /// Sale bill delete — items ka stock restore + CASCADE delete
  Future<void> deleteSaleBillWithStockRestore(int billId) async {
    final db = await database;
    // 1. Restore stock
    final items = await getSaleBillItems(billId);
    for (final item in items) {
      final itemId = item['item_id'];
      final qty    = item['qty'];
      if (itemId != null && qty != null) {
        // if bill had warehouse_id, restore to that warehouse
        try {
          final bill = await getSaleBillById(billId);
          final whId = bill != null ? bill['warehouse_id'] as int? : null;
          if (whId != null) {
            await upsertWarehouseItem(whId, itemId as int, (qty as num).toDouble());
          } else {
            await restoreItemStock(itemId as int, qty as int);
          }
        } catch (e) {}
      }
    }
    // 2. Delete bill (CASCADE deletes sale_bill_items)
    await db.delete('sale_bills', where: 'id = ?', whereArgs: [billId]);
    FirebaseSyncService.debouncedUpload();
  }

  Future<void> updatePurchaseBillStatus(int billId, String status) async {
    await (await database).update('purchase_bills', {'payment_status': status},
        where: 'id = ?', whereArgs: [billId]);
    FirebaseSyncService.debouncedUpload();
  }

  /// Purchase bill delete — items ka stock deduct back + CASCADE delete
  Future<void> deletePurchaseBillWithStockDeduct(int billId) async {
    final db = await database;
    // 1. Deduct stock that was added during purchase
    final items = await getPurchaseBillItems(billId);
    for (final item in items) {
      final itemId = item['item_id'];
      final qty    = item['qty'];
      if (itemId != null && qty != null) {
        // if bill had warehouse_id, deduct from that warehouse
        try {
          final rows = await db.rawQuery('SELECT warehouse_id FROM purchase_bills WHERE id = ?', [billId]);
          final whId = rows.isNotEmpty ? rows.first['warehouse_id'] as int? : null;
          if (whId != null) {
            await upsertWarehouseItem(whId, itemId as int, -(qty as num).toDouble());
          } else {
            await deductItemStock(itemId as int, qty as int);
          }
        } catch (e) {}
      }
    }
    // 2. Delete bill (CASCADE deletes purchase_bill_items)
    await db.delete('purchase_bills', where: 'id = ?', whereArgs: [billId]);
    FirebaseSyncService.debouncedUpload();
  }

  Future<String> getSaleBillSummaryForAi() async {
    final bills = await getAllSaleBills();
    if (bills.isEmpty) return 'SALE_BILLS: none';
    return 'SALE_BILLS (${bills.length}):\n' +
        bills.take(15).map((b) =>
        '  ${b['bill_number']} customer:"${b['customer_name'] ?? "?"}" total:${b['total_amount']} status:${b['payment_status']}').join('\n');
  }

  // ════════════════════════════════════════════════════════
  //  PURCHASE BILLS
  // ════════════════════════════════════════════════════════

  Future<String> generatePurchaseBillNumber() async {
    final db = await database;
    final year = DateTime.now().year;
    final prefix = 'PB-$year-';
    final result = await db.rawQuery(
      "SELECT MAX(CAST(SUBSTR(bill_number, ?) AS INTEGER)) as max_num "
          "FROM purchase_bills WHERE bill_number LIKE ?",
      [prefix.length + 1, '$prefix%'],
    );
    final maxNum = (result.first['max_num'] as int?) ?? 0;
    int nextNum = maxNum + 1;
    String candidate;
    do {
      candidate = '$prefix${nextNum.toString().padLeft(4, '0')}';
      final existing = await db.rawQuery(
          'SELECT 1 FROM purchase_bills WHERE bill_number = ? LIMIT 1',
          [candidate]);
      if (existing.isEmpty) break;
      nextNum++;
    } while (true);
    return candidate;
  }

  Future<int> insertPurchaseBill(Map<String, dynamic> data) async {
    final result = await (await database).insert('purchase_bills', data);
    FirebaseSyncService.debouncedUpload();
    // Track subscription usage
    SubscriptionService.instance.incrementPurchaseBillCount().catchError((_) {});
    return result;
  }

  Future<int> insertPurchaseBillItem(Map<String, dynamic> data) async {
    final db = await database;
    final result = await db.insert('purchase_bill_items', data);
    // Update stock: if purchase bill has warehouse_id, add to that warehouse; else add to global
    try {
      final billId = data['bill_id'];
      if (billId != null) {
        final billRows = await db.rawQuery('SELECT warehouse_id FROM purchase_bills WHERE id = ?', [billId]);
        final whId = billRows.isNotEmpty ? billRows.first['warehouse_id'] as int? : null;
        final itemId = data['item_id'] as int?;
        final qty = (data['qty'] as num?)?.toDouble() ?? 0.0;
        if (itemId != null) {
          if (whId != null) {
            await upsertWarehouseItem(whId, itemId, qty);
          } else {
            await addItemStock(itemId, qty.toInt());
          }
        }
      }
    } catch (e) {}
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  // ✅ FIXED: was returning empty list []
  Future<List<Map<String, dynamic>>> getAllPurchaseBills() async =>
      (await database).rawQuery('''
        SELECT pb.*, s.name as supplier_name
        FROM purchase_bills pb
        LEFT JOIN suppliers s ON pb.supplier_id = s.id
        ORDER BY pb.id DESC
      ''');

  Future<Map<String, dynamic>?> getPurchaseBillByNumber(String billNumber) async {
    final rows = await (await database).rawQuery('''
      SELECT pb.*, s.name as supplier_name
      FROM purchase_bills pb LEFT JOIN suppliers s ON pb.supplier_id = s.id
      WHERE pb.bill_number = ?''', [billNumber]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getPurchaseBillItems(int billId) async =>
      (await database).query('purchase_bill_items',
          where: 'bill_id = ?', whereArgs: [billId]);

  Future<String> getPurchaseSummaryForAi() async {
    final bills = await getAllPurchaseBills();
    if (bills.isEmpty) return 'PURCHASE_BILLS: none';
    return 'PURCHASE_BILLS (${bills.length}):\n' +
        bills.take(10).map((b) =>
        '  ${b['bill_number']} supplier:"${b['supplier_name'] ?? "?"}" total:${b['total_amount']}').join('\n');
  }

  // ════════════════════════════════════════════════════════
  //  FULL AI CONTEXT
  // ════════════════════════════════════════════════════════

  Future<String> getFullContextForAi() async {
    return '${await getItemSummaryForAi()}\n\n'
        '${await getCustomerSummaryForAi()}\n\n'
        '${await getSupplierSummaryForAi()}\n\n'   // ✅ added
        '${await getSaleBillSummaryForAi()}\n\n'
        '${await getPurchaseSummaryForAi()}';       // ✅ added
  }

  // ════════════════════════════════════════════════════════
  //  ANALYTICS — Sales reports
  // ════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getTodaySaleSummary() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as bill_count,
        COALESCE(SUM(total_amount), 0) as total_sale,
        COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total_amount ELSE 0 END), 0) as paid_amount,
        COALESCE(SUM(CASE WHEN payment_status = 'unpaid' THEN total_amount ELSE 0 END), 0) as unpaid_amount
      FROM sale_bills WHERE bill_date = ?
    ''', [today]);
    return result.first;
  }

  Future<Map<String, dynamic>> getDateRangeSaleSummary(int days) async {
    final db = await database;
    final fromStr = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .split('T')[0];
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as bill_count,
        COALESCE(SUM(total_amount), 0) as total_sale,
        COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total_amount ELSE 0 END), 0) as paid_amount,
        COALESCE(SUM(CASE WHEN payment_status = 'unpaid' THEN total_amount ELSE 0 END), 0) as unpaid_amount,
        COUNT(DISTINCT customer_id) as unique_customers
      FROM sale_bills WHERE bill_date >= ?
    ''', [fromStr]);
    return result.first;
  }

  Future<List<Map<String, dynamic>>> getMonthlySaleBreakdown() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        strftime('%Y-%m', bill_date) as month,
        COUNT(*) as bill_count,
        COALESCE(SUM(total_amount), 0) as total_sale,
        COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total_amount ELSE 0 END), 0) as paid_amount
      FROM sale_bills
      WHERE bill_date >= date('now', '-6 months')
      GROUP BY strftime('%Y-%m', bill_date)
      ORDER BY month DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getUnpaidBills() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT sb.bill_number, sb.bill_date, sb.total_amount,
             sb.payment_mode, c.name as customer_name, c.phone as customer_phone
      FROM sale_bills sb
      LEFT JOIN customers c ON sb.customer_id = c.id
      WHERE sb.payment_status = 'unpaid' OR sb.payment_status = 'partial'
      ORDER BY sb.bill_date DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getTopSellingItems({int limit = 5}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT sbi.item_name,
             SUM(sbi.qty) as total_qty_sold,
             SUM(sbi.line_total) as total_revenue
      FROM sale_bill_items sbi
      JOIN sale_bills sb ON sbi.bill_id = sb.id
      GROUP BY sbi.item_name
      ORDER BY total_revenue DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<List<Map<String, dynamic>>> getLowStockItems({int threshold = 5}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT name, qty, price FROM items
      WHERE qty IS NOT NULL AND qty <= ?
      ORDER BY qty ASC
    ''', [threshold]);
  }

  Future<String> getAnalyticsContextForAi() async {
    final today = await getTodaySaleSummary();
    final month = await getDateRangeSaleSummary(30);
    final unpaid = await getUnpaidBills();
    return '''
ANALYTICS:
  Today: bills:${today['bill_count']} total:₹${today['total_sale']} paid:₹${today['paid_amount']} unpaid:₹${today['unpaid_amount']}
  Last 30 days: bills:${month['bill_count']} total:₹${month['total_sale']} customers:${month['unique_customers']}
  Unpaid bills: ${unpaid.length} pending''';
  }

  // ════════════════════════════════════════════════════════
  //  EXPENSES
  // ════════════════════════════════════════════════════════

  Future<int> insertExpense(Map<String, dynamic> data) async {
    final result = await (await database).insert('expenses', data);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    return await (await database).query('expenses', orderBy: 'date DESC, id DESC');
  }

  Future<List<Map<String, dynamic>>> getExpensesByMonth(String yearMonth) async {
    final db = await database;
    return await db.rawQuery(
        "SELECT * FROM expenses WHERE strftime('%Y-%m', date) = ? ORDER BY date DESC",
        [yearMonth]);
  }

  Future<double> getTotalExpenseThisMonth() async {
    final db = await database;
    final month = DateTime.now().toIso8601String().substring(0, 7);
    final result = await db.rawQuery(
        "SELECT COALESCE(SUM(amount),0) as total FROM expenses WHERE strftime('%Y-%m', date) = ?",
        [month]);
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getTotalExpenseLastMonth() async {
    final db = await database;
    final lastMonth = DateTime(DateTime.now().year, DateTime.now().month - 1)
        .toIso8601String()
        .substring(0, 7);
    final result = await db.rawQuery(
        "SELECT COALESCE(SUM(amount),0) as total FROM expenses WHERE strftime('%Y-%m', date) = ?",
        [lastMonth]);
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getTotalExpenseAllTime() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT COALESCE(SUM(amount),0) as total FROM expenses');
    return (result.first['total'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getExpenseByCategory() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT category,
             COALESCE(SUM(amount),0) as total,
             COUNT(*) as count
      FROM expenses
      GROUP BY category
      ORDER BY total DESC
    ''');
  }

  Future<int> updateExpense(Map<String, dynamic> data, int id) async {
    final result = await (await database)
        .update('expenses', data, where: 'id = ?', whereArgs: [id]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<int> deleteExpense(int id) async {
    final result = await (await database)
        .delete('expenses', where: 'id = ?', whereArgs: [id]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  // ════════════════════════════════════════════════════════
  //  LEDGER ENTRIES
  // ════════════════════════════════════════════════════════

  Future<int> insertLedgerEntry(Map<String, dynamic> data) async {
    final result = await (await database).insert('ledger_entries', data);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<List<Map<String, dynamic>>> getLedgerByParty(
      String partyType, int partyId) async {
    return await (await database).query(
      'ledger_entries',
      where: 'party_type = ? AND party_id = ?',
      whereArgs: [partyType, partyId],
      orderBy: 'date DESC, id DESC',
    );
  }

  Future<double> getPartyBalance(String partyType, int partyId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'debit'  THEN amount ELSE 0 END), 0) as total_debit,
        COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0) as total_credit
      FROM ledger_entries
      WHERE party_type = ? AND party_id = ?
    ''', [partyType, partyId]);
    final debit  = (result.first['total_debit']  as num).toDouble();
    final credit = (result.first['total_credit'] as num).toDouble();
    return debit - credit; // positive = you will receive, negative = you will pay
  }

  Future<List<Map<String, dynamic>>> getAllPartiesWithBalance() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT party_type, party_id, party_name,
        COALESCE(SUM(CASE WHEN type='debit'  THEN amount ELSE 0 END),0)
        - COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE 0 END),0) as balance
      FROM ledger_entries
      GROUP BY party_type, party_id, party_name
      ORDER BY ABS(balance) DESC
    ''');
  }

  Future<int> deleteLedgerEntry(int id) async {
    final result = await (await database)
        .delete('ledger_entries', where: 'id = ?', whereArgs: [id]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  // ════════════════════════════════════════════════════════
  //  QUOTATIONS
  // ════════════════════════════════════════════════════════

  Future<String> generateQuotationNumber() async {
    final db   = await database;
    final year = DateTime.now().year;
    final prefix = 'QT-$year-';
    final result = await db.rawQuery(
      "SELECT MAX(CAST(SUBSTR(quotation_number,?) AS INTEGER)) as max_num "
      "FROM quotations WHERE quotation_number LIKE ?",
      [prefix.length + 1, '$prefix%'],
    );
    final maxNum = (result.first['max_num'] as int?) ?? 0;
    return '$prefix${(maxNum + 1).toString().padLeft(4, '0')}';
  }

  Future<int> insertQuotation(Map<String, dynamic> data) async {
    final result = await (await database).insert('quotations', data,
        conflictAlgorithm: ConflictAlgorithm.abort);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<int> insertQuotationItem(Map<String, dynamic> data) async {
    final result = await (await database).insert('quotation_items', data);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllQuotations() async =>
      (await database).rawQuery('''
        SELECT q.*, c.name as cust_name
        FROM quotations q
        LEFT JOIN customers c ON q.customer_id = c.id
        ORDER BY q.id DESC
      ''');

  Future<Map<String, dynamic>?> getQuotationById(int id) async {
    final rows = await (await database).rawQuery('''
      SELECT q.*, c.name as cust_name
      FROM quotations q LEFT JOIN customers c ON q.customer_id = c.id
      WHERE q.id = ?''', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getQuotationItems(int quotationId) async =>
      (await database).query('quotation_items',
          where: 'quotation_id = ?', whereArgs: [quotationId]);

  Future<void> updateQuotationStatus(int id, String status) async {
    await (await database).update('quotations', {'status': status},
        where: 'id = ?', whereArgs: [id]);
    FirebaseSyncService.debouncedUpload();
  }

  Future<void> deleteQuotation(int id) async {
    await (await database).delete('quotations', where: 'id = ?', whereArgs: [id]);
    FirebaseSyncService.debouncedUpload();
  }

  /// Convert quotation → sale bill (1-click)
  Future<int> convertQuotationToSaleBill(int quotationId) async {
    final db = await database;
    final quot = await getQuotationById(quotationId);
    if (quot == null) throw Exception('Quotation not found');
    if (quot['status'] == 'converted') throw Exception('Already converted');

    return await db.transaction((txn) async {
      final billNum = await generateBillNumber();
      final billId  = await txn.insert('sale_bills', {
        'bill_number':     billNum,
        'customer_id':     quot['customer_id'],
        'bill_date':       DateTime.now().toIso8601String().split('T')[0],
        'tax_type':        quot['tax_type'],
        'discount_type':   quot['discount_type'],
        'discount_value':  quot['discount_value'],
        'discount_amount': quot['discount_amount'],
        'subtotal':        quot['subtotal'],
        'gst_amount':      quot['gst_amount'],
        'total_amount':    quot['total_amount'],
        'payment_mode':    'cash',
        'payment_status':  'unpaid',
        'notes':           quot['notes'],
      });
      final qItems = await txn.query('quotation_items',
          where: 'quotation_id = ?', whereArgs: [quotationId]);
      for (final qi in qItems) {
        await txn.insert('sale_bill_items', {
          'bill_id':         billId,
          'item_id':         qi['item_id'],
          'item_name':       qi['item_name'],
          'qty':             qi['qty'],
          'unit_price':      qi['unit_price'],
          'discount_amount': qi['discount_amount'],
          'tax_rate':        qi['tax_rate'],
          'tax_amount':      qi['tax_amount'],
          'line_total':      qi['line_total'],
        });
        // deduct stock
        final itemId = qi['item_id'] as int?;
        final qty    = (qi['qty'] as num).toInt();
        if (itemId != null) {
          await txn.execute(
              'UPDATE items SET qty = MAX(0, COALESCE(qty,0) - ?) WHERE id = ?',
              [qty, itemId]);
        }
      }
      await txn.update('quotations', {'status': 'converted'},
          where: 'id = ?', whereArgs: [quotationId]);
      return billId;
    });
  }

  // ════════════════════════════════════════════════════════
  //  UTILITY
  // ════════════════════════════════════════════════════════

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  // ════════════════════════════════════════════════════════
  //  FUZZY MATCH (Levenshtein)
  // ════════════════════════════════════════════════════════

  MapEntry<String, T>? _fuzzyFind<T>(
      String query, List<MapEntry<String, T>> entries) {
    if (entries.isEmpty) return null;
    final q = query.toLowerCase();
    MapEntry<String, T>? best;
    int bestDist = 999;
    for (final e in entries) {
      final d = _levenshtein(q, e.key.toLowerCase());
      if (d < bestDist) {
        bestDist = d;
        best = e;
      }
    }
    return bestDist <= 2 ? best : null;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = List.generate(
        a.length + 1, (i) => List.filled(b.length + 1, 0));
    for (int i = 0; i <= a.length; i++) m[i][0] = i;
    for (int j = 0; j <= b.length; j++) m[0][j] = j;
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        m[i][j] = [m[i-1][j]+1, m[i][j-1]+1, m[i-1][j-1]+cost]
            .reduce((x, y) => x < y ? x : y);
      }
    }
    return m[a.length][b.length];
  }

  Future<double> getYouWillReceiveAmount() async {

    final db = await database;

    final result = await db.rawQuery('''
    SELECT
    COALESCE(SUM(total_amount), 0) as total
    FROM sale_bills
    WHERE payment_status IN ('unpaid', 'partial')
  ''');

    return (result.first['total'] as num)
        .toDouble();
  }

  Future<double> getYouWillPayAmount() async {

    final db = await database;

    final result = await db.rawQuery('''
    SELECT
    COALESCE(SUM(total_amount), 0) as total
    FROM purchase_bills
    WHERE payment_status IN ('unpaid', 'partial')
  ''');

    return (result.first['total'] as num)
        .toDouble();
  }

  // ═══════════════════════════════════════════════════════════════════════════
// ADD THESE METHODS TO AppDatabase class in app_database.dart
// ═══════════════════════════════════════════════════════════════════════════

  // ── Top customers by total purchase ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTopCustomers({int limit = 10}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        c.name as customer_name,
        c.phone,
        COUNT(sb.id) as bill_count,
        COALESCE(SUM(sb.total_amount), 0) as total_spent,
        COALESCE(SUM(CASE WHEN sb.payment_status = 'unpaid' OR sb.payment_status = 'partial'
          THEN sb.total_amount ELSE 0 END), 0) as pending_amount
      FROM customers c
      LEFT JOIN sale_bills sb ON sb.customer_id = c.id
      GROUP BY c.id, c.name, c.phone
      ORDER BY total_spent DESC
      LIMIT ?
    ''', [limit]);
  }

  // ── Customers with pending payment ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCustomersWithPending() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        c.name as customer_name,
        c.phone,
        COUNT(sb.id) as unpaid_count,
        COALESCE(SUM(sb.total_amount), 0) as pending_amount
      FROM customers c
      JOIN sale_bills sb ON sb.customer_id = c.id
      WHERE sb.payment_status = 'unpaid' OR sb.payment_status = 'partial'
      GROUP BY c.id, c.name, c.phone
      ORDER BY pending_amount DESC
    ''');
  }

  // ── Customer full transaction history ────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCustomerTransactions(String customerName) async {
    final customer = await getCustomerByName(customerName) ?? await getCustomerFuzzy(customerName);
    if (customer == null) return [];
    final db = await database;
    return await db.rawQuery('''
      SELECT sb.bill_number, sb.bill_date, sb.total_amount,
             sb.payment_mode, sb.payment_status,
             GROUP_CONCAT(sbi.item_name || ' x' || sbi.qty, ', ') as items
      FROM sale_bills sb
      LEFT JOIN sale_bill_items sbi ON sbi.bill_id = sb.id
      WHERE sb.customer_id = ?
      GROUP BY sb.id
      ORDER BY sb.bill_date DESC
    ''', [customer.id]);
  }

  // ── Top suppliers by total purchase ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTopSuppliers({int limit = 10}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        s.name as supplier_name,
        s.phone,
        COUNT(pb.id) as bill_count,
        COALESCE(SUM(pb.total_amount), 0) as total_purchased,
        COALESCE(SUM(CASE WHEN pb.payment_status = 'unpaid' OR pb.payment_status = 'partial'
          THEN pb.total_amount ELSE 0 END), 0) as pending_amount
      FROM suppliers s
      LEFT JOIN purchase_bills pb ON pb.supplier_id = s.id
      GROUP BY s.id, s.name, s.phone
      ORDER BY total_purchased DESC
      LIMIT ?
    ''', [limit]);
  }

  // ── Suppliers with pending payment ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSuppliersWithPending() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        s.name as supplier_name,
        s.phone,
        COUNT(pb.id) as unpaid_count,
        COALESCE(SUM(pb.total_amount), 0) as pending_amount
      FROM suppliers s
      JOIN purchase_bills pb ON pb.supplier_id = s.id
      WHERE pb.payment_status = 'unpaid' OR pb.payment_status = 'partial'
      GROUP BY s.id, s.name, s.phone
      ORDER BY pending_amount DESC
    ''');
  }

  // ── Supplier purchase history ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSupplierTransactions(String supplierName) async {
    final supplier = await getSupplierByName(supplierName) ?? await getSupplierFuzzy(supplierName);
    if (supplier == null) return [];
    final db = await database;
    return await db.rawQuery('''
      SELECT pb.bill_number, pb.bill_date, pb.total_amount,
             pb.payment_mode, pb.payment_status,
             GROUP_CONCAT(pbi.item_name || ' x' || pbi.qty, ', ') as items
      FROM purchase_bills pb
      LEFT JOIN purchase_bill_items pbi ON pbi.bill_id = pb.id
      WHERE pb.supplier_id = ?
      GROUP BY pb.id
      ORDER BY pb.bill_date DESC
    ''', [supplier.id]);
  }

  // ── Unpaid purchase bills ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getUnpaidPurchaseBills() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT pb.bill_number, pb.bill_date, pb.total_amount,
             pb.payment_mode, s.name as supplier_name, s.phone as supplier_phone
      FROM purchase_bills pb
      LEFT JOIN suppliers s ON pb.supplier_id = s.id
      WHERE pb.payment_status = 'unpaid' OR pb.payment_status = 'partial'
      ORDER BY pb.bill_date DESC
    ''');
  }

  // ── Purchase summary by days ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getPurchaseSummaryByDays(int days) async {
    final db = await database;
    final fromStr = DateTime.now().subtract(Duration(days: days))
        .toIso8601String().split('T')[0];
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as bill_count,
        COALESCE(SUM(total_amount), 0) as total_purchase,
        COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total_amount ELSE 0 END), 0) as paid_amount,
        COALESCE(SUM(CASE WHEN payment_status = 'unpaid' THEN total_amount ELSE 0 END), 0) as unpaid_amount
      FROM purchase_bills
      WHERE bill_date >= ?
    ''', [fromStr]);
    return result.first;
  }

  // ── Most profitable items (by revenue) ───────────────────────────────────
  Future<List<Map<String, dynamic>>> getMostProfitableItems({int limit = 10}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT sbi.item_name,
             SUM(sbi.qty) as total_qty_sold,
             SUM(sbi.line_total) as total_revenue,
             AVG(sbi.unit_price) as avg_price
      FROM sale_bill_items sbi
      JOIN sale_bills sb ON sbi.bill_id = sb.id
      GROUP BY sbi.item_name
      ORDER BY total_revenue DESC
      LIMIT ?
    ''', [limit]);
  }

  // ── Cash vs Credit/UPI sales ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getCashVsCreditSales() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN LOWER(payment_mode) = 'cash' THEN total_amount ELSE 0 END), 0) as cash_total,
        COALESCE(SUM(CASE WHEN LOWER(payment_mode) IN ('upi', 'gpay', 'phonepay', 'online') THEN total_amount ELSE 0 END), 0) as upi_total,
        COALESCE(SUM(CASE WHEN LOWER(payment_mode) IN ('credit', 'udhaar', 'cheque') THEN total_amount ELSE 0 END), 0) as credit_total
      FROM sale_bills
    ''');
    return result.first;
  }

  // ── Stock for single item ─────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getItemStock(String name) async {
    final item = await getItemByName(name) ?? await getItemFuzzy(name);
    if (item == null) return null;
    return {'name': item.name, 'qty': item.qty ?? 0, 'price': item.price ?? 0};
  }

  // ── WAREHOUSE / MULTI-WAREHOUSE HELPERS ─────────────────────────────────

  Future<int> insertWarehouse(Map<String, dynamic> data) async {
    final id = await (await database).insert('warehouses', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
    FirebaseSyncService.debouncedUpload();
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllWarehouses() async {
    return await (await database).query('warehouses', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getWarehouseById(int id) async {
    final rows = await (await database).query('warehouses', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<double> getWarehouseItemQty(int warehouseId, int itemId) async {
    final rows = await (await database).query('warehouse_items',
        columns: ['quantity'], where: 'warehouse_id = ? AND item_id = ?', whereArgs: [warehouseId, itemId]);
    if (rows.isEmpty) return 0.0;
    return (rows.first['quantity'] as num).toDouble();
  }

  Future<void> _recalculateGlobalItemQty(int itemId) async {
    final db = await database;
    final res = await db.rawQuery('SELECT COALESCE(SUM(quantity),0) as total FROM warehouse_items WHERE item_id = ?', [itemId]);
    final total = (res.first['total'] as num).toInt();
    await db.execute('UPDATE items SET qty = ? WHERE id = ?', [total, itemId]);
  }

  Future<void> upsertWarehouseItem(int warehouseId, int itemId, double deltaQty) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('warehouse_items', where: 'warehouse_id = ? AND item_id = ?', whereArgs: [warehouseId, itemId]);
      if (rows.isEmpty) {
        await txn.insert('warehouse_items', {
          'warehouse_id': warehouseId,
          'item_id': itemId,
          'quantity': deltaQty,
          'last_updated': DateTime.now().toIso8601String()
        });
      } else {
        final current = (rows.first['quantity'] as num).toDouble();
        final updated = current + deltaQty;
        await txn.update('warehouse_items', {
          'quantity': updated,
          'last_updated': DateTime.now().toIso8601String()
        }, where: 'id = ?', whereArgs: [rows.first['id']]);
      }
      // keep global item qty in sync for compatibility
      final res = await txn.rawQuery('SELECT COALESCE(SUM(quantity),0) as total FROM warehouse_items WHERE item_id = ?', [itemId]);
      final total = (res.first['total'] as num).toInt();
      await txn.execute('UPDATE items SET qty = ? WHERE id = ?', [total, itemId]);
    });
    FirebaseSyncService.debouncedUpload();
  }

  Future<bool> transferStock(int fromWarehouseId, int toWarehouseId, int itemId, double qty) async {
    final db = await database;
    return await db.transaction((txn) async {
      // check availability
      final fromRows = await txn.query('warehouse_items', where: 'warehouse_id = ? AND item_id = ?', whereArgs: [fromWarehouseId, itemId]);
      final fromQty = fromRows.isEmpty ? 0.0 : (fromRows.first['quantity'] as num).toDouble();
      if (fromQty < qty) return false;
      // deduct from source
      final newFrom = fromQty - qty;
      if (fromRows.isEmpty) {
        // shouldn't happen due to check
        await txn.insert('warehouse_items', {'warehouse_id': fromWarehouseId, 'item_id': itemId, 'quantity': 0, 'last_updated': DateTime.now().toIso8601String()});
      } else {
        await txn.update('warehouse_items', {'quantity': newFrom, 'last_updated': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [fromRows.first['id']]);
      }
      // add to destination
      final toRows = await txn.query('warehouse_items', where: 'warehouse_id = ? AND item_id = ?', whereArgs: [toWarehouseId, itemId]);
      if (toRows.isEmpty) {
        await txn.insert('warehouse_items', {'warehouse_id': toWarehouseId, 'item_id': itemId, 'quantity': qty, 'last_updated': DateTime.now().toIso8601String()});
      } else {
        final toQty = (toRows.first['quantity'] as num).toDouble();
        await txn.update('warehouse_items', {'quantity': toQty + qty, 'last_updated': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [toRows.first['id']]);
      }
      // insert transfer record
      await txn.insert('stock_transfers', {
        'from_warehouse_id': fromWarehouseId,
        'to_warehouse_id': toWarehouseId,
        'item_id': itemId,
        'qty': qty,
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String()
      });
      // update global item qty
      final res = await txn.rawQuery('SELECT COALESCE(SUM(quantity),0) as total FROM warehouse_items WHERE item_id = ?', [itemId]);
      final total = (res.first['total'] as num).toInt();
      await txn.execute('UPDATE items SET qty = ? WHERE id = ?', [total, itemId]);
      return true;
    });
  }

  Future<int> addOutbox(String entityType, String action, String payload, {String? entityId}) async {
    final db = await database;
    return await db.insert('outbox', {
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload': payload,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String()
    });
  }

  // ════════════════════════════════════════════════════════
  //  MANUFACTURING / BOM
  // ════════════════════════════════════════════════════════

  Future<int> insertBom(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('bom', data);
  }

  Future<int> insertBomItem(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('bom_items', data);
  }

  Future<List<Map<String, dynamic>>> getAllBoms() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT b.*, i.name as finished_item_name
      FROM bom b
      LEFT JOIN items i ON b.finished_item_id = i.id
      ORDER BY b.id DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getBomItems(int bomId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT bi.*, i.name as raw_item_name
      FROM bom_items bi
      LEFT JOIN items i ON bi.raw_item_id = i.id
      WHERE bi.bom_id = ?
    ''', [bomId]);
  }

  Future<int> insertProductionOrder(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('production_orders', data);
  }

  Future<List<Map<String, dynamic>>> getAllProductionOrders() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT po.*, b.name as bom_name, b.finished_item_id as finished_item_id
      FROM production_orders po
      LEFT JOIN bom b ON po.bom_id = b.id
      ORDER BY po.id DESC
    ''');
  }

  Future<void> completeProductionOrder(int orderId) async {
    final db = await database;
    await db.transaction((txn) async {
      final orders = await txn.query('production_orders', where: 'id = ?', whereArgs: [orderId]);
      if (orders.isEmpty) return;
      final order = orders.first;
      if (order['status'] == 'completed') return;

      final bomId = order['bom_id'] as int;
      final qtyToProduce = (order['qty_to_produce'] as num).toDouble();

      // Deduct raw materials
      final boms = await txn.query('bom', where: 'id = ?', whereArgs: [bomId]);
      if (boms.isEmpty) return;
      final finishedItemId = boms.first['finished_item_id'] as int;
      
      final bomItems = await txn.query('bom_items', where: 'bom_id = ?', whereArgs: [bomId]);
      for (final item in bomItems) {
        final rawItemId = item['raw_item_id'] as int;
        final rawQtyRequired = (item['qty'] as num).toDouble() * qtyToProduce;
        await txn.execute('UPDATE items SET qty = MAX(0, COALESCE(qty,0) - ?) WHERE id = ?', [rawQtyRequired, rawItemId]);
      }

      // Add finished good
      await txn.execute('UPDATE items SET qty = COALESCE(qty,0) + ? WHERE id = ?', [qtyToProduce, finishedItemId]);

      // Update status
      await txn.update('production_orders', {'status': 'completed'}, where: 'id = ?', whereArgs: [orderId]);
    });
  }

  // ════════════════════════════════════════════════════════
  //  STAFF & ATTENDANCE
  // ════════════════════════════════════════════════════════

  Future<int> insertStaff(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('staff', data);
  }

  Future<List<Map<String, dynamic>>> getAllStaff() async {
    final db = await database;
    return await db.query('staff', orderBy: 'id DESC');
  }

  Future<int> insertStaffAttendance(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('staff_attendance', data);
  }

  Future<List<Map<String, dynamic>>> getStaffAttendance(int staffId) async {
    final db = await database;
    return await db.query('staff_attendance', where: 'staff_id = ?', whereArgs: [staffId], orderBy: 'date DESC');
  }

  // ════════════════════════════════════════════════════════
  //  BANK & CASH MANAGEMENT
  // ════════════════════════════════════════════════════════

  Future<int> insertBankAccount(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('bank_accounts', data);
  }

  Future<List<Map<String, dynamic>>> getAllBankAccounts() async {
    final db = await database;
    return await db.query('bank_accounts', orderBy: 'id DESC');
  }

  Future<int> insertBankTransaction(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('bank_transactions', data);
  }

  Future<List<Map<String, dynamic>>> getBankTransactions(int bankAccountId) async {
    final db = await database;
    return await db.query('bank_transactions', where: 'bank_account_id = ?', whereArgs: [bankAccountId], orderBy: 'id DESC');
  }

  Future<double> getBankAccountBalance(int bankAccountId) async {
    final db = await database;
    final accountRes = await db.query('bank_accounts', where: 'id = ?', whereArgs: [bankAccountId]);
    if (accountRes.isEmpty) return 0;
    
    final openingBalance = (accountRes.first['opening_balance'] as num).toDouble();
    
    final txRes = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = 'deposit' THEN amount ELSE 0 END) as total_deposit,
        SUM(CASE WHEN type = 'withdrawal' THEN amount ELSE 0 END) as total_withdrawal
      FROM bank_transactions WHERE bank_account_id = ?
    ''', [bankAccountId]);

    final deposits = (txRes.first['total_deposit'] as num?)?.toDouble() ?? 0.0;
    final withdrawals = (txRes.first['total_withdrawal'] as num?)?.toDouble() ?? 0.0;
    
    return openingBalance + deposits - withdrawals;
  }

  // ════════════════════════════════════════════════════════
  //  DELIVERY CHALLAN
  // ════════════════════════════════════════════════════════

  Future<int> insertChallan(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('delivery_challans', data);
  }

  Future<int> insertChallanItem(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('challan_items', data);
  }

  Future<List<Map<String, dynamic>>> getAllChallans() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT c.*, cust.name as customer_name
      FROM delivery_challans c
      LEFT JOIN customers cust ON c.customer_id = cust.id
      ORDER BY c.id DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getChallanItems(int challanId) async {
    final db = await database;
    return await db.query('challan_items', where: 'challan_id = ?', whereArgs: [challanId]);
  }

  Future<void> updateChallanStatus(int challanId, String status) async {
    final db = await database;
    await db.update('delivery_challans', {'status': status}, where: 'id = ?', whereArgs: [challanId]);
  }

  Future<void> convertChallanToSaleBill(int challanId) async {
    final db = await database;
    await db.transaction((txn) async {
      final challanRes = await txn.query('delivery_challans', where: 'id = ?', whereArgs: [challanId]);
      if (challanRes.isEmpty) return;
      final challan = challanRes.first;
      if (challan['status'] == 'converted') return;

      final billNumber = 'INV-CH-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      
      final billId = await txn.insert('sale_bills', {
        'bill_number': billNumber,
        'customer_id': challan['customer_id'],
        'bill_date': DateTime.now().toIso8601String().split('T')[0],
        'total_amount': 0.0, // Should be calculated
        'payment_mode': 'cash',
        'status': 'unpaid',
      });

      final items = await txn.query('challan_items', where: 'challan_id = ?', whereArgs: [challanId]);
      
      for (final item in items) {
        await txn.insert('sale_bill_items', {
          'sale_bill_id': billId,
          'item_id': item['item_id'],
          'item_name': item['item_name'],
          'qty': item['qty'],
          'price': 0.0, // Assuming 0 price for now, to be updated in Bill UI
          'total': 0.0,
        });

        // Deduct stock if item_id exists
        if (item['item_id'] != null) {
          await txn.execute('UPDATE items SET qty = MAX(0, COALESCE(qty,0) - ?) WHERE id = ?', [item['qty'], item['item_id']]);
        }
      }

      await txn.update('delivery_challans', {'status': 'converted'}, where: 'id = ?', whereArgs: [challanId]);
    });
  }

  // ════════════════════════════════════════════════════════
  //  REPAIRS & SERVICE
  // ════════════════════════════════════════════════════════

  Future<String> generateJobNumber() async {
    final db = await database;
    final year = DateTime.now().year;
    final result = await db.rawQuery('SELECT MAX(id) as max_id FROM repair_jobs');
    final nextId = ((result.first['max_id'] as int?) ?? 0) + 1;
    return 'JOB-$year-${nextId.toString().padLeft(4, '0')}';
  }

  Future<int> insertRepairJob(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('repair_jobs', data);
  }

  Future<List<Map<String, dynamic>>> getAllRepairJobs({String? status}) async {
    final db = await database;
    if (status != null && status.isNotEmpty) {
      return await db.query('repair_jobs', where: 'status = ?', whereArgs: [status], orderBy: 'id DESC');
    }
    return await db.query('repair_jobs', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getRepairJobById(int id) async {
    final rows = await (await database).query('repair_jobs', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> updateRepairJob(Map<String, dynamic> data, int id) async {
    final db = await database;
    return await db.update('repair_jobs', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteRepairJob(int id) async {
    return await (await database).delete('repair_jobs', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertRepairPart(Map<String, dynamic> data) async {
    return await (await database).insert('repair_parts', data);
  }

  Future<List<Map<String, dynamic>>> getRepairParts(int jobId) async {
    return await (await database).query('repair_parts', where: 'job_id = ?', whereArgs: [jobId]);
  }

  Future<int> deleteRepairPart(int id) async {
    return await (await database).delete('repair_parts', where: 'id = ?', whereArgs: [id]);
  }

  // ════════════════════════════════════════════════════════
  //  E-COMMERCE INTEGRATION
  // ════════════════════════════════════════════════════════

  Future<int> insertEcommerceSetting(Map<String, dynamic> data) async {
    return await (await database).insert('ecommerce_settings', data);
  }

  Future<List<Map<String, dynamic>>> getAllEcommerceSettings() async {
    return await (await database).query('ecommerce_settings', orderBy: 'id DESC');
  }

  Future<int> updateEcommerceSetting(Map<String, dynamic> data, int id) async {
    return await (await database).update('ecommerce_settings', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteEcommerceSetting(int id) async {
    return await (await database).delete('ecommerce_settings', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertEcommerceSyncLog(Map<String, dynamic> data) async {
    return await (await database).insert('ecommerce_sync_logs', data);
  }

  Future<List<Map<String, dynamic>>> getEcommerceSyncLogs({String? platform}) async {
    final db = await database;
    if (platform != null) {
      return await db.query('ecommerce_sync_logs', where: 'platform = ?', whereArgs: [platform], orderBy: 'id DESC');
    }
    return await db.query('ecommerce_sync_logs', orderBy: 'id DESC');
  }

  // ════════════════════════════════════════════════════════
  //  ASSETS MANAGEMENT
  // ════════════════════════════════════════════════════════

  Future<int> insertAsset(Map<String, dynamic> data) async {
    return await (await database).insert('assets', data);
  }

  Future<List<Map<String, dynamic>>> getAllAssets() async {
    return await (await database).query('assets', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getAssetById(int id) async {
    final rows = await (await database).query('assets', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> updateAsset(Map<String, dynamic> data, int id) async {
    return await (await database).update('assets', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAsset(int id) async {
    return await (await database).delete('assets', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertAssetDepreciation(Map<String, dynamic> data) async {
    return await (await database).insert('asset_depreciation', data);
  }

  Future<List<Map<String, dynamic>>> getAssetDepreciation(int assetId) async {
    return await (await database).query('asset_depreciation', where: 'asset_id = ?', whereArgs: [assetId], orderBy: 'year ASC');
  }

  Future<int> insertAssetMaintenance(Map<String, dynamic> data) async {
    return await (await database).insert('asset_maintenance', data);
  }

  Future<List<Map<String, dynamic>>> getAssetMaintenance(int assetId) async {
    return await (await database).query('asset_maintenance', where: 'asset_id = ?', whereArgs: [assetId], orderBy: 'date DESC');
  }

  /// Calculate and log depreciation for an asset
  Future<void> calculateDepreciation(int assetId) async {
    final asset = await getAssetById(assetId);
    if (asset == null) return;
    final price = (asset['purchase_price'] as num).toDouble();
    final pct = (asset['depreciation_pct'] as num).toDouble();
    final years = (asset['useful_life_yrs'] as num).toInt();
    final db = await database;
    double bookValue = price;
    for (int y = 1; y <= years; y++) {
      final depAmount = bookValue * pct / 100;
      bookValue -= depAmount;
      if (bookValue < 0) bookValue = 0;
      final existing = await db.query('asset_depreciation',
          where: 'asset_id = ? AND year = ?', whereArgs: [assetId, y]);
      if (existing.isEmpty) {
        await db.insert('asset_depreciation', {
          'asset_id': assetId,
          'year': y,
          'amount': depAmount,
          'book_value': bookValue,
        });
      }
    }
    await db.update('assets', {'current_value': bookValue}, where: 'id = ?', whereArgs: [assetId]);
  }

  // ════════════════════════════════════════════════════════
  //  GST COMPLIANCE SUITE
  // ════════════════════════════════════════════════════════

  Future<int> insertGstReturn(Map<String, dynamic> data) async {
    return await (await database).insert('gst_returns', data);
  }

  Future<List<Map<String, dynamic>>> getAllGstReturns() async {
    return await (await database).query('gst_returns', orderBy: 'id DESC');
  }

  Future<int> updateGstReturn(Map<String, dynamic> data, int id) async {
    return await (await database).update('gst_returns', data, where: 'id = ?', whereArgs: [id]);
  }

  /// Auto-generate GSTR-1 data from sale_bills
  Future<Map<String, dynamic>> generateGstr1Data(String period) async {
    final db = await database;
    final bills = await db.rawQuery('''
      SELECT sb.*, c.gst_number as customer_gst, c.name as customer_name, c.state as customer_state
      FROM sale_bills sb
      LEFT JOIN customers c ON sb.customer_id = c.id
      WHERE strftime('%Y-%m', sb.bill_date) = ?
      ORDER BY sb.bill_date
    ''', [period]);
    final b2b = <Map<String, dynamic>>[];
    final b2cs = <Map<String, dynamic>>[];
    for (final bill in bills) {
      if (bill['customer_gst'] != null && (bill['customer_gst'] as String).isNotEmpty) {
        b2b.add(bill);
      } else {
        b2cs.add(bill);
      }
    }
    return {
      'period': period,
      'b2b_count': b2b.length,
      'b2b_amount': b2b.fold<double>(0, (s, b) => s + ((b['total_amount'] as num?)?.toDouble() ?? 0)),
      'b2cs_count': b2cs.length,
      'b2cs_amount': b2cs.fold<double>(0, (s, b) => s + ((b['total_amount'] as num?)?.toDouble() ?? 0)),
    };
  }

  Future<int> insertEInvoice(Map<String, dynamic> data) async {
    return await (await database).insert('e_invoices', data);
  }

  Future<List<Map<String, dynamic>>> getEInvoicesForBill(int billId) async {
    return await (await database).query('e_invoices', where: 'bill_id = ?', whereArgs: [billId], orderBy: 'id DESC');
  }

  Future<int> insertEWayBill(Map<String, dynamic> data) async {
    return await (await database).insert('e_way_bills', data);
  }

  Future<List<Map<String, dynamic>>> getEWayBillsForBill(int billId) async {
    return await (await database).query('e_way_bills', where: 'bill_id = ?', whereArgs: [billId], orderBy: 'id DESC');
  }

  Future<int> insertTdsEntry(Map<String, dynamic> data) async {
    return await (await database).insert('tds_entries', data);
  }

  Future<List<Map<String, dynamic>>> getAllTdsEntries() async {
    return await (await database).query('tds_entries', orderBy: 'id DESC');
  }

  // ════════════════════════════════════════════════════════
  //  TALLY INTEGRATION
  // ════════════════════════════════════════════════════════

  Future<int> insertTallyExportLog(Map<String, dynamic> data) async {
    return await (await database).insert('tally_export_logs', data);
  }

  Future<List<Map<String, dynamic>>> getTallyExportLogs() async {
    return await (await database).query('tally_export_logs', orderBy: 'id DESC');
  }

  /// Generate Tally XML for sale bills
  Future<String> generateTallyXml({String? fromDate, String? toDate}) async {
    final db = await database;
    String where = '';
    if (fromDate != null && toDate != null) {
      where = "WHERE sb.bill_date BETWEEN '$fromDate' AND '$toDate'";
    }
    final bills = await db.rawQuery('''
      SELECT sb.*, c.name as customer_name, c.gst_number
      FROM sale_bills sb LEFT JOIN customers c ON sb.customer_id = c.id
      $where ORDER BY sb.bill_date
    ''');
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<ENVELOPE>');
    buffer.writeln('  <HEADER><TALLYREQUEST>Import Data</TALLYREQUEST></HEADER>');
    buffer.writeln('  <BODY><IMPORTDATA><REQUESTDATA>');
    for (final bill in bills) {
      buffer.writeln('    <TALLYMESSAGE>');
      buffer.writeln('      <VOUCHER>');
      buffer.writeln('        <VOUCHERTYPE>Sales</VOUCHERTYPE>');
      buffer.writeln('        <VOUCHERNUMBER>${bill['bill_number']}</VOUCHERNUMBER>');
      buffer.writeln('        <DATE>${bill['bill_date']}</DATE>');
      buffer.writeln('        <PARTYLEDGERNAME>${bill['customer_name'] ?? 'Cash'}</PARTYLEDGERNAME>');
      buffer.writeln('        <AMOUNT>${(bill['total_amount'] as num?)?.toDouble() ?? 0}</AMOUNT>');
      buffer.writeln('      </VOUCHER>');
      buffer.writeln('    </TALLYMESSAGE>');
    }
    buffer.writeln('  </REQUESTDATA></IMPORTDATA></BODY>');
    buffer.writeln('</ENVELOPE>');
    return buffer.toString();
  }

  // ════════════════════════════════════════════════════════
  //  MULTI-CURRENCY
  // ════════════════════════════════════════════════════════

  Future<int> insertCurrencyRate(Map<String, dynamic> data) async {
    return await (await database).insert('currency_rates', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllCurrencyRates() async {
    return await (await database).query('currency_rates', orderBy: 'code ASC');
  }

  Future<Map<String, dynamic>?> getCurrencyRate(String code) async {
    final rows = await (await database).query('currency_rates', where: 'code = ?', whereArgs: [code.toUpperCase()]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Convert INR amount to target currency
  Future<double> convertCurrency(double inrAmount, String targetCurrency) async {
    final rate = await getCurrencyRate(targetCurrency);
    if (rate == null) return inrAmount;
    final rateInr = (rate['rate_inr'] as num).toDouble();
    if (rateInr == 0) return inrAmount;
    return inrAmount / rateInr;
  }

  // ════════════════════════════════════════════════════════
  //  FRANCHISE MANAGEMENT
  // ════════════════════════════════════════════════════════

  Future<int> insertFranchiseOutlet(Map<String, dynamic> data) async {
    return await (await database).insert('franchise_outlets', data);
  }

  Future<List<Map<String, dynamic>>> getAllFranchiseOutlets() async {
    return await (await database).query('franchise_outlets', orderBy: 'id DESC');
  }

  Future<int> updateFranchiseOutlet(Map<String, dynamic> data, int id) async {
    return await (await database).update('franchise_outlets', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertFranchiseRoyalty(Map<String, dynamic> data) async {
    return await (await database).insert('franchise_royalty', data);
  }

  Future<List<Map<String, dynamic>>> getFranchiseRoyalties(int outletId) async {
    return await (await database).query('franchise_royalty', where: 'outlet_id = ?', whereArgs: [outletId], orderBy: 'period DESC');
  }

  /// Calculate royalty for an outlet for a given period
  Future<double> calculateRoyalty(int outletId, String period) async {
    final db = await database;
    final outlet = await db.query('franchise_outlets', where: 'id = ?', whereArgs: [outletId]);
    if (outlet.isEmpty) return 0;
    final pct = (outlet.first['royalty_pct'] as num).toDouble();
    // Calculate total sale for this period (example logic)
    final bills = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as total FROM sale_bills
      WHERE strftime('%Y-%m', bill_date) = ?
    ''', [period]);
    final saleAmount = (bills.first['total'] as num).toDouble();
    return saleAmount * pct / 100;
  }

  // ════════════════════════════════════════════════════════
  //  CRM (Customer Relationship)
  // ════════════════════════════════════════════════════════

  Future<int> insertCrmTask(Map<String, dynamic> data) async {
    return await (await database).insert('crm_tasks', data);
  }

  Future<List<Map<String, dynamic>>> getAllCrmTasks({String? status}) async {
    final db = await database;
    if (status != null) {
      return await db.query('crm_tasks', where: 'status = ?', whereArgs: [status], orderBy: 'due_date ASC');
    }
    return await db.query('crm_tasks', orderBy: 'id DESC');
  }

  Future<int> updateCrmTask(Map<String, dynamic> data, int id) async {
    return await (await database).update('crm_tasks', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCrmTask(int id) async {
    return await (await database).delete('crm_tasks', where: 'id = ?', whereArgs: [id]);
  }

  /// Get today's follow-ups/reminders
  Future<List<Map<String, dynamic>>> getTodayCrmTasks() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await (await database).query('crm_tasks',
        where: "due_date = ? AND status = 'pending'",
        whereArgs: [today],
        orderBy: 'id DESC');
  }

  Future<int> insertCrmPipeline(Map<String, dynamic> data) async {
    return await (await database).insert('crm_pipeline', data);
  }

  Future<List<Map<String, dynamic>>> getAllCrmPipeline({String? stage}) async {
    final db = await database;
    if (stage != null) {
      return await db.query('crm_pipeline', where: 'stage = ?', whereArgs: [stage], orderBy: 'deal_value DESC');
    }
    return await db.query('crm_pipeline', orderBy: 'id DESC');
  }

  Future<int> updateCrmPipeline(Map<String, dynamic> data, int id) async {
    return await (await database).update('crm_pipeline', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCrmPipeline(int id) async {
    return await (await database).delete('crm_pipeline', where: 'id = ?', whereArgs: [id]);
  }

  /// CRM Dashboard stats
  Future<Map<String, dynamic>> getCrmDashboard() async {
    final db = await database;
    final pipeline = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_deals,
        COALESCE(SUM(deal_value), 0) as total_pipeline_value,
        COALESCE(SUM(CASE WHEN stage = 'lead' THEN 1 ELSE 0 END), 0) as leads,
        COALESCE(SUM(CASE WHEN stage = 'negotiation' THEN deal_value ELSE 0 END), 0) as negotiation_value
      FROM crm_pipeline
    ''');
    final tasks = await db.rawQuery('''
      SELECT COUNT(*) as pending_tasks FROM crm_tasks WHERE status = 'pending'
    ''');
    return {
      'total_deals': pipeline.first['total_deals'] ?? 0,
      'total_pipeline_value': pipeline.first['total_pipeline_value'] ?? 0,
      'leads': pipeline.first['leads'] ?? 0,
      'negotiation_value': pipeline.first['negotiation_value'] ?? 0,
      'pending_tasks': tasks.first['pending_tasks'] ?? 0,
    };
  }

}