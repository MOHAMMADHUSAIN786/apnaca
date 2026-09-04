// lib/database/app_database.dart
// UPDATED: Per-company SQLite isolation
// DB naming: billnex_{uid}.db          → default (no company selected)
//            billnex_{uid}_{compId}.db → company-specific DB

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
  static String? _currentUid;
  static String? _currentCompanyId; // ← NEW: active company

  AppDatabase._internal();

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  // ════════════════════════════════════════════════════════
  //  USER SWITCH — login pe call karo
  // ════════════════════════════════════════════════════════
  static Future<void> switchUser(String uid) async {
    // NOTE: No early return here — team member needs to switch to
    // owner's uid even if uid matches a previous session
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _currentUid = uid;
    _currentCompanyId = null; // reset company — switchCompany() must be called after
  }

  // ════════════════════════════════════════════════════════
  //  COMPANY SWITCH — jab user company select kare
  //  companyId = null → default (no company) DB
  // ════════════════════════════════════════════════════════
  static Future<void> switchCompany(String? companyId) async {
    if (_currentCompanyId == companyId && _db != null) return;

    // Close current DB before switching
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _currentCompanyId = companyId;
    // DB will open lazily on next `database` access
  }

  // Current company ID getter (readable from anywhere)
  static String? get activeCompanyId => _currentCompanyId;
  static String? get activeUid => _currentUid;

  // ════════════════════════════════════════════════════════
  //  DB FILE NAME LOGIC
  //  No company   → billnex_{uid}.db
  //  With company → billnex_{uid}_{companyId}.db
  // ════════════════════════════════════════════════════════
  static String _buildDbName(String uid, String? companyId) {
    if (companyId == null || companyId.isEmpty) {
      return 'billnex_$uid.db';
    }
    // Sanitize companyId (remove special chars for safe filename)
    final safeId = companyId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'billnex_${uid}_$safeId.db';
  }

  // Get DB file path for any uid + companyId (used by sync service)
  static Future<String> getDbPath(String uid, String? companyId) async {
    final dbDir = await getDatabasesPath();
    return join(dbDir, _buildDbName(uid, companyId));
  }

  // ════════════════════════════════════════════════════════
  //  CLEAR ALL LOCAL DATA — logout pe call karo
  // ════════════════════════════════════════════════════════
  Future<void> clearAllData() async {
    try {
      final db = await database;
      final tables = [
        'users', 'items', 'customers', 'suppliers',
        'sale_bills', 'sale_bill_items',
        'purchase_bills', 'purchase_bill_items',
        'transactions', 'warehouses', 'warehouse_items',
        'stock_history',
      ];
      await db.transaction((txn) async {
        for (final table in tables) {
          try { await txn.execute('DELETE FROM $table'); } catch (_) {}
        }
      });
    } catch (_) {} finally {
      if (_db != null) {
        await _db!.close();
        _db = null;
      }
      _currentUid = null;
      _currentCompanyId = null;
    }
  }

  Future<Database> _initDb() async {
    final uid     = _currentUid ?? 'default';
    final dbName  = _buildDbName(uid, _currentCompanyId);
    final path    = join(await getDatabasesPath(), dbName);
    return await openDatabase(
      path,
      version: 10,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // TODO(gateway-phase): enable `PRAGMA foreign_keys = ON` once the
      // delete handlers (deleteItem / deleteCustomer / deleteSupplier) are
      // updated to null-out or block references — turning it on now would
      // make deleting a referenced row throw instead of silently orphaning.
    );
  }

  // ════════════════════════════════════════════════════════
  //  CREATE + UPGRADE
  // ════════════════════════════════════════════════════════
  Future<void> _onCreate(Database db, int version) async {
    await _createUsers(db);
    await _createItems(db);
    await _createCustomers(db);
    await _createSaleBills(db);
    await _createSaleBillItems(db);
    await _createSuppliers(db);
    await _createPurchaseBills(db);
    await _createPurchaseBillItems(db);
    await _createStockHistory(db);
    await _createIndexes(db);
  }

  // ── INDEXES ──────────────────────────────────────────────────
  // Every FK / lookup / sort column used by the analytics + list
  // queries. Without these, each report is a full table scan; with
  // a few thousand bills that is a visible freeze on the AI path
  // (getAnalyticsContextForAi runs on every message).
  // (bill_number already has an implicit index via its UNIQUE constraint.)
  Future<void> _createIndexes(Database db) async {
    const stmts = [
      'CREATE INDEX IF NOT EXISTS idx_sbi_bill_id     ON sale_bill_items(bill_id)',
      'CREATE INDEX IF NOT EXISTS idx_sbi_item_id     ON sale_bill_items(item_id)',
      'CREATE INDEX IF NOT EXISTS idx_sb_customer_id  ON sale_bills(customer_id)',
      'CREATE INDEX IF NOT EXISTS idx_sb_bill_date    ON sale_bills(bill_date)',
      'CREATE INDEX IF NOT EXISTS idx_sb_pay_status   ON sale_bills(payment_status)',
      'CREATE INDEX IF NOT EXISTS idx_pbi_bill_id     ON purchase_bill_items(bill_id)',
      'CREATE INDEX IF NOT EXISTS idx_pbi_item_id     ON purchase_bill_items(item_id)',
      'CREATE INDEX IF NOT EXISTS idx_pb_supplier_id  ON purchase_bills(supplier_id)',
      'CREATE INDEX IF NOT EXISTS idx_pb_bill_date    ON purchase_bills(bill_date)',
      'CREATE INDEX IF NOT EXISTS idx_pb_pay_status   ON purchase_bills(payment_status)',
      'CREATE INDEX IF NOT EXISTS idx_sh_item_id      ON stock_history(item_id)',
      'CREATE INDEX IF NOT EXISTS idx_sh_created_at   ON stock_history(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_items_name      ON items(name COLLATE NOCASE)',
      'CREATE INDEX IF NOT EXISTS idx_customers_name  ON customers(name COLLATE NOCASE)',
      'CREATE INDEX IF NOT EXISTS idx_suppliers_name  ON suppliers(name COLLATE NOCASE)',
    ];
    for (final s in stmts) {
      try { await db.execute(s); } catch (_) {}
    }
  }

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
             COALESCE(tax_type, 'exclusive'), COALESCE(discount_type, 'none'),
             COALESCE(discount_value, 0), COALESCE(discount_amount, 0),
             subtotal, gst_amount, total_amount,
             COALESCE(payment_mode, 'cash'), COALESCE(payment_status, 'unpaid'),
             notes, created_at
      FROM sale_bills''');
      await db.execute('DROP TABLE sale_bills');
      await db.execute('ALTER TABLE sale_bills_temp RENAME TO sale_bills');
    }
    if (oldVersion < 6) {
      try { await db.execute('ALTER TABLE users ADD COLUMN photo_url TEXT'); } catch (_) {}
    }
    if (oldVersion < 7) {
      try { await db.execute('ALTER TABLE users ADD COLUMN companyName TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN mobile TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN username TEXT'); } catch (_) {}
    }
    if (oldVersion < 8) {
      await _createSuppliers(db);
      await _createPurchaseBills(db);
      await _createPurchaseBillItems(db);
    }
    if (oldVersion < 9) {
      // ── INVENTORY MANAGEMENT — new columns on items ──────────
      try { await db.execute('ALTER TABLE items ADD COLUMN sku TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE items ADD COLUMN min_stock_alert INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE items ADD COLUMN purchase_price REAL'); } catch (_) {}
      await _createStockHistory(db);
    }
    if (oldVersion < 10) {
      // ── PERFORMANCE — indexes on all FK / lookup / sort columns ──
      await _createIndexes(db);
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
CREATE TABLE items (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name            TEXT NOT NULL,
  qty             INTEGER,
  price           REAL,
  hsn_code        TEXT,
  sku             TEXT,
  min_stock_alert INTEGER DEFAULT 0,
  purchase_price  REAL
)''');

  // ── STOCK HISTORY / LEDGER ───────────────────────────────────
  // change_type: stock_in | stock_out | adjustment | sale | purchase |
  //              sale_cancel | purchase_cancel
  Future<void> _createStockHistory(Database db) => db.execute('''
CREATE TABLE IF NOT EXISTS stock_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id     INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  item_name   TEXT    NOT NULL,
  change_type TEXT    NOT NULL,
  qty_change  INTEGER NOT NULL,
  qty_before  INTEGER NOT NULL,
  qty_after   INTEGER NOT NULL,
  reason      TEXT,
  reference_no TEXT,
  created_at  TEXT    DEFAULT (datetime('now'))
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

  // ════════════════════════════════════════════════════════
  //  USER
  // ════════════════════════════════════════════════════════
  Future<void> insertOrUpdateUser(Map<String, dynamic> data) async =>
      (await database).insert('users', data, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Map<String, dynamic>?> getUserByFirebaseUid(String uid) async {
    final rows = await (await database).query('users', where: 'firebaseUid = ?', whereArgs: [uid]);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> updateUserDisplayName(String uid, String displayName) async {
    final result = await (await database).update('users', {'displayName': displayName}, where: 'firebaseUid = ?', whereArgs: [uid]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<int> updateUserPhotoUrl(String uid, String photoUrl) async {
    final result = await (await database).update('users', {'photo_url': photoUrl}, where: 'firebaseUid = ?', whereArgs: [uid]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  // ════════════════════════════════════════════════════════
  //  ITEMS
  // ════════════════════════════════════════════════════════
  Future<int> insertItem(ItemModel item) async {
    final result = await (await database).insert('items', item.toMap());
    FirebaseSyncService.debouncedUpload();
    SubscriptionService.instance.incrementItemCount().catchError((_) {});
    return result;
  }

  Future<List<ItemModel>> getAllItems() async {
    final rows = await (await database).query('items', orderBy: 'id DESC');
    return rows.map(ItemModel.fromMap).toList();
  }

  Future<ItemModel?> getItemById(int id) async {
    final rows = await (await database).query('items', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : ItemModel.fromMap(rows.first);
  }

  Future<ItemModel?> getItemByName(String name) async {
    final rows = await (await database).query('items', where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    return rows.isEmpty ? null : ItemModel.fromMap(rows.first);
  }

  Future<ItemModel?> getItemFuzzy(String name) async {
    final all = await getAllItems();
    return _fuzzyFind(name, all.map((i) => MapEntry(i.name, i)).toList())?.value;
  }

  Future<int> updateItem(ItemModel item) async {
    final result = await (await database).update('items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<int> deleteItem(int id) async {
    final result = await (await database).delete('items', where: 'id = ?', whereArgs: [id]);
    FirebaseSyncService.debouncedUpload();
    SubscriptionService.instance.decrementItemCount().catchError((_) {});
    return result;
  }

  Future<void> deductItemStock(int itemId, int qty, {String changeType = 'sale', String? referenceNo}) async {
    final item = await getItemById(itemId);
    final before = item?.qty ?? 0;
    final after = (before - qty) < 0 ? 0 : before - qty;
    await (await database).execute('UPDATE items SET qty = MAX(0, COALESCE(qty,0) - ?) WHERE id = ?', [qty, itemId]);
    if (item != null) {
      await insertStockHistory(
        itemId: itemId, itemName: item.name, changeType: changeType,
        qtyChange: -qty, qtyBefore: before, qtyAfter: after, referenceNo: referenceNo,
      );
    }
  }

  Future<void> restoreItemStock(int itemId, int qty, {String changeType = 'sale_cancel', String? referenceNo}) async {
    final item = await getItemById(itemId);
    final before = item?.qty ?? 0;
    final after = before + qty;
    await (await database).execute('UPDATE items SET qty = COALESCE(qty, 0) + ? WHERE id = ?', [qty, itemId]);
    if (item != null) {
      await insertStockHistory(
        itemId: itemId, itemName: item.name, changeType: changeType,
        qtyChange: qty, qtyBefore: before, qtyAfter: after, referenceNo: referenceNo,
      );
    }
  }

  Future<void> addItemStock(int itemId, int qty, {String changeType = 'purchase', String? referenceNo}) async {
    final item = await getItemById(itemId);
    final before = item?.qty ?? 0;
    final after = before + qty;
    await (await database).execute('UPDATE items SET qty = COALESCE(qty, 0) + ? WHERE id = ?', [qty, itemId]);
    if (item != null) {
      await insertStockHistory(
        itemId: itemId, itemName: item.name, changeType: changeType,
        qtyChange: qty, qtyBefore: before, qtyAfter: after, referenceNo: referenceNo,
      );
    }
  }

  Future<bool> itemNameExists(String name) async {
    final rows = await (await database).query('items', where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
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
        items.take(30).map((i) {
          final extra = <String>[];
          if (i.sku != null) extra.add('sku:${i.sku}');
          if (i.purchasePrice != null) extra.add('purchase_price:${i.purchasePrice}');
          if (i.minStockAlert != null && i.minStockAlert != 0) extra.add('min_stock_alert:${i.minStockAlert}');
          final extraStr = extra.isEmpty ? '' : ' ${extra.join(' ')}';
          return '  id:${i.id} name:"${i.name}" qty:${i.qty ?? "?"} price:${i.price ?? "?"}$extraStr';
        }).join('\n');
  }

  // ════════════════════════════════════════════════════════
  //  INVENTORY MANAGEMENT (Stock In / Out / Adjustment / History)
  // ════════════════════════════════════════════════════════

  Future<int> insertStockHistory({
    required int itemId,
    required String itemName,
    required String changeType,
    required int qtyChange,
    required int qtyBefore,
    required int qtyAfter,
    String? reason,
    String? referenceNo,
  }) async {
    final result = await (await database).insert('stock_history', {
      'item_id': itemId,
      'item_name': itemName,
      'change_type': changeType,
      'qty_change': qtyChange,
      'qty_before': qtyBefore,
      'qty_after': qtyAfter,
      'reason': reason,
      'reference_no': referenceNo,
      'created_at': DateTime.now().toIso8601String(),
    });
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<List<Map<String, dynamic>>> getStockHistory(int itemId, {int limit = 50}) async {
    return (await database).query(
      'stock_history',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'id DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getAllStockHistory({int limit = 50}) async {
    return (await database).query('stock_history', orderBy: 'id DESC', limit: limit);
  }

  /// Stock IN — purchase, restock, return, etc. Increases qty.
  Future<ItemModel?> stockIn(int itemId, int qty, {String? reason, String? referenceNo}) async {
    if (qty <= 0) throw Exception('Quantity must be greater than 0');
    final item = await getItemById(itemId);
    if (item == null) return null;
    final before = item.qty ?? 0;
    final after = before + qty;
    await (await database).update('items', {'qty': after}, where: 'id = ?', whereArgs: [itemId]);
    await insertStockHistory(
      itemId: itemId, itemName: item.name, changeType: 'stock_in',
      qtyChange: qty, qtyBefore: before, qtyAfter: after,
      reason: reason, referenceNo: referenceNo,
    );
    FirebaseSyncService.debouncedUpload();
    return item.copyWith(qty: after);
  }

  /// Stock OUT — damage, loss, manual usage, etc. Decreases qty.
  Future<ItemModel?> stockOut(int itemId, int qty, {String? reason, String? referenceNo}) async {
    if (qty <= 0) throw Exception('Quantity must be greater than 0');
    final item = await getItemById(itemId);
    if (item == null) return null;
    final before = item.qty ?? 0;
    if (qty > before) throw Exception('Stock out quantity ($qty) cannot exceed current stock ($before)');
    final after = before - qty;
    await (await database).update('items', {'qty': after}, where: 'id = ?', whereArgs: [itemId]);
    await insertStockHistory(
      itemId: itemId, itemName: item.name, changeType: 'stock_out',
      qtyChange: -qty, qtyBefore: before, qtyAfter: after,
      reason: reason, referenceNo: referenceNo,
    );
    FirebaseSyncService.debouncedUpload();
    return item.copyWith(qty: after);
  }

  /// Stock ADJUSTMENT — set absolute stock value (e.g. after physical count).
  Future<ItemModel?> adjustStock(int itemId, int newQty, {String? reason}) async {
    if (newQty < 0) throw Exception('Stock cannot be negative');
    final item = await getItemById(itemId);
    if (item == null) return null;
    final before = item.qty ?? 0;
    final after = newQty;
    await (await database).update('items', {'qty': after}, where: 'id = ?', whereArgs: [itemId]);
    await insertStockHistory(
      itemId: itemId, itemName: item.name, changeType: 'adjustment',
      qtyChange: after - before, qtyBefore: before, qtyAfter: after,
      reason: reason,
    );
    FirebaseSyncService.debouncedUpload();
    return item.copyWith(qty: after);
  }

  /// Low stock items based on PER-ITEM min_stock_alert (falls back to 5 if not set/0).
  Future<List<Map<String, dynamic>>> getLowStockItemsByAlert() async {
    return (await database).rawQuery('''
      SELECT id, name, qty, price, sku, min_stock_alert FROM items
      WHERE qty IS NOT NULL
        AND qty <= CASE WHEN min_stock_alert IS NULL OR min_stock_alert = 0 THEN 5 ELSE min_stock_alert END
      ORDER BY qty ASC
    ''');
  }

  /// Total inventory valuation — sum(qty * purchase_price), fallback to selling price.
  Future<Map<String, dynamic>> getInventoryValuation() async {
    final items = await getAllItems();
    double totalValue = 0;
    double totalSellingValue = 0;
    int totalUnits = 0;
    for (final i in items) {
      final qty = i.qty ?? 0;
      final cost = i.purchasePrice ?? i.price ?? 0;
      final sell = i.price ?? 0;
      totalValue += qty * cost;
      totalSellingValue += qty * sell;
      totalUnits += qty;
    }
    return {
      'item_count': items.length,
      'total_units': totalUnits,
      'total_cost_value': double.parse(totalValue.toStringAsFixed(2)),
      'total_selling_value': double.parse(totalSellingValue.toStringAsFixed(2)),
      'potential_profit': double.parse((totalSellingValue - totalValue).toStringAsFixed(2)),
    };
  }

  // ════════════════════════════════════════════════════════
  //  CUSTOMERS
  // ════════════════════════════════════════════════════════
  Future<int> insertCustomer(CustomerModel c) async {
    final result = await (await database).insert('customers', c.toMap());
    FirebaseSyncService.debouncedUpload();
    SubscriptionService.instance.incrementCustomerCount().catchError((_) {});
    return result;
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    final rows = await (await database).query('customers', orderBy: 'id DESC');
    return rows.map(CustomerModel.fromMap).toList();
  }

  Future<CustomerModel?> getCustomerById(int id) async {
    final rows = await (await database).query('customers', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : CustomerModel.fromMap(rows.first);
  }

  Future<CustomerModel?> getCustomerByName(String name) async {
    final rows = await (await database).query('customers', where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    return rows.isEmpty ? null : CustomerModel.fromMap(rows.first);
  }

  Future<CustomerModel?> getCustomerFuzzy(String name) async {
    final all = await getAllCustomers();
    return _fuzzyFind(name, all.map((c) => MapEntry(c.name, c)).toList())?.value;
  }

  Future<int> updateCustomer(CustomerModel c) async {
    final result = await (await database).update('customers', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<int> deleteCustomer(int id) async {
    final result = await (await database).delete('customers', where: 'id = ?', whereArgs: [id]);
    FirebaseSyncService.debouncedUpload();
    SubscriptionService.instance.decrementCustomerCount().catchError((_) {});
    return result;
  }

  Future<bool> customerNameExists(String name) async {
    final rows = await (await database).query('customers', where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    return rows.isNotEmpty;
  }

  Future<String> getCustomerSummaryForAi() async {
    final customers = await getAllCustomers();
    if (customers.isEmpty) return 'CUSTOMERS: none';
    return 'CUSTOMERS (${customers.length}):\n' +
        customers.take(30).map((c) => '  id:${c.id} name:"${c.name}" phone:${c.phone ?? "?"}').join('\n');
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
    final rows = await (await database).query('suppliers', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : SupplierModel.fromMap(rows.first);
  }

  Future<SupplierModel?> getSupplierByName(String name) async {
    final rows = await (await database).query('suppliers', where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    return rows.isEmpty ? null : SupplierModel.fromMap(rows.first);
  }

  Future<SupplierModel?> getSupplierFuzzy(String name) async {
    final all = await getAllSuppliers();
    return _fuzzyFind(name, all.map((s) => MapEntry(s.name, s)).toList())?.value;
  }

  Future<int> updateSupplier(SupplierModel s) async {
    final result = await (await database).update('suppliers', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<int> deleteSupplier(int id) async {
    final result = await (await database).delete('suppliers', where: 'id = ?', whereArgs: [id]);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  Future<bool> supplierNameExists(String name) async {
    final rows = await (await database).query('suppliers', where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    return rows.isNotEmpty;
  }

  Future<String> getSupplierSummaryForAi() async {
    final suppliers = await getAllSuppliers();
    if (suppliers.isEmpty) return 'SUPPLIERS: none';
    return 'SUPPLIERS (${suppliers.length}):\n' +
        suppliers.take(30).map((s) => '  id:${s.id} name:"${s.name}" phone:${s.phone ?? "?"}').join('\n');
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
    final result = await db.insert('sale_bills', data, conflictAlgorithm: ConflictAlgorithm.abort);
    FirebaseSyncService.debouncedUpload();
    SubscriptionService.instance.incrementSaleBillCount().catchError((_) {});
    return result;
  }

  Future<int> insertSaleBillItem(Map<String, dynamic> data) async {
    final result = await (await database).insert('sale_bill_items', data);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  /// Atomically create a sale bill + its line items + stock deductions +
  /// stock-history rows in ONE transaction. If anything fails (e.g. a
  /// bill_number collision) the whole thing rolls back — no orphan bill,
  /// no half-deducted stock.
  ///
  /// [bill] must include 'bill_number'. Each entry in [lineItems] must be a
  /// full `sale_bill_items` row EXCEPT `bill_id` (added here); rows with a
  /// non-null 'item_id' also get their stock deducted.
  Future<int> createSaleBillAtomic({
    required Map<String, dynamic> bill,
    required List<Map<String, dynamic>> lineItems,
  }) async {
    final db = await database;
    final billNumber = bill['bill_number'] as String?;
    final nowIso = DateTime.now().toIso8601String();

    final billId = await db.transaction<int>((txn) async {
      final id = await txn.insert('sale_bills', bill,
          conflictAlgorithm: ConflictAlgorithm.abort);

      for (final line in lineItems) {
        await txn.insert('sale_bill_items', {...line, 'bill_id': id});

        final itemId = line['item_id'];
        final qty = (line['qty'] as num?)?.toInt() ?? 0;
        if (itemId is int && qty > 0) {
          final rows = await txn.query('items',
              columns: ['name', 'qty'], where: 'id = ?', whereArgs: [itemId]);
          if (rows.isNotEmpty) {
            final before = (rows.first['qty'] as int?) ?? 0;
            final after = (before - qty) < 0 ? 0 : before - qty;
            await txn.update('items', {'qty': after},
                where: 'id = ?', whereArgs: [itemId]);
            await txn.insert('stock_history', {
              'item_id': itemId,
              'item_name': rows.first['name'],
              'change_type': 'sale',
              'qty_change': -qty,
              'qty_before': before,
              'qty_after': after,
              'reference_no': billNumber,
              'created_at': nowIso,
            });
          }
        }
      }
      return id;
    });

    FirebaseSyncService.debouncedUpload();
    SubscriptionService.instance.incrementSaleBillCount().catchError((_) {});
    return billId;
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
      (await database).query('sale_bill_items', where: 'bill_id = ?', whereArgs: [billId]);

  Future<void> updateSaleBillStatus(int billId, String status) async {
    await (await database).update('sale_bills', {'payment_status': status}, where: 'id = ?', whereArgs: [billId]);
    FirebaseSyncService.debouncedUpload();
  }

  Future<void> deleteSaleBillWithStockRestore(int billId) async {
    final db = await database;
    final bill = await getSaleBillById(billId);
    final billNumber = bill?['bill_number'] as String?;
    final items = await getSaleBillItems(billId);
    for (final item in items) {
      final itemId = item['item_id'];
      final qty    = item['qty'];
      if (itemId != null && qty != null) {
        await restoreItemStock(itemId as int, qty as int,
            changeType: 'sale_cancel', referenceNo: billNumber);
      }
    }
    await db.delete('sale_bills', where: 'id = ?', whereArgs: [billId]);
    FirebaseSyncService.debouncedUpload();
  }

  Future<String> getSaleBillSummaryForAi() async {
    final bills = await getAllSaleBills();
    if (bills.isEmpty) return 'SALE_BILLS: none';
    return 'SALE_BILLS (${bills.length}):\n' +
        bills.take(15).map((b) => '  ${b['bill_number']} customer:"${b['customer_name'] ?? "?"}" total:${b['total_amount']} status:${b['payment_status']}').join('\n');
  }

  // ════════════════════════════════════════════════════════
  //  PURCHASE BILLS
  // ════════════════════════════════════════════════════════
  Future<String> generatePurchaseBillNumber() async {
    final db = await database;
    final year = DateTime.now().year;
    final prefix = 'PB-$year-';
    final result = await db.rawQuery(
      "SELECT MAX(CAST(SUBSTR(bill_number, ?) AS INTEGER)) as max_num FROM purchase_bills WHERE bill_number LIKE ?",
      [prefix.length + 1, '$prefix%'],
    );
    final maxNum = (result.first['max_num'] as int?) ?? 0;
    int nextNum = maxNum + 1;
    String candidate;
    do {
      candidate = '$prefix${nextNum.toString().padLeft(4, '0')}';
      final existing = await db.rawQuery('SELECT 1 FROM purchase_bills WHERE bill_number = ? LIMIT 1', [candidate]);
      if (existing.isEmpty) break;
      nextNum++;
    } while (true);
    return candidate;
  }

  Future<int> insertPurchaseBill(Map<String, dynamic> data) async {
    final result = await (await database).insert('purchase_bills', data);
    FirebaseSyncService.debouncedUpload();
    SubscriptionService.instance.incrementPurchaseBillCount().catchError((_) {});
    return result;
  }

  Future<int> insertPurchaseBillItem(Map<String, dynamic> data) async {
    final result = await (await database).insert('purchase_bill_items', data);
    FirebaseSyncService.debouncedUpload();
    return result;
  }

  /// Atomically create a purchase bill + line items + stock additions +
  /// stock-history rows in ONE transaction. Rolls back entirely on failure.
  ///
  /// [bill] must include 'bill_number'. Each entry in [lineItems] must be a
  /// full `purchase_bill_items` row EXCEPT `bill_id` (added here); rows with a
  /// non-null 'item_id' also get their stock increased.
  Future<int> createPurchaseBillAtomic({
    required Map<String, dynamic> bill,
    required List<Map<String, dynamic>> lineItems,
  }) async {
    final db = await database;
    final billNumber = bill['bill_number'] as String?;
    final nowIso = DateTime.now().toIso8601String();

    final billId = await db.transaction<int>((txn) async {
      final id = await txn.insert('purchase_bills', bill,
          conflictAlgorithm: ConflictAlgorithm.abort);

      for (final line in lineItems) {
        await txn.insert('purchase_bill_items', {...line, 'bill_id': id});

        final itemId = line['item_id'];
        final qty = (line['qty'] as num?)?.toInt() ?? 0;
        if (itemId is int && qty > 0) {
          final rows = await txn.query('items',
              columns: ['name', 'qty'], where: 'id = ?', whereArgs: [itemId]);
          if (rows.isNotEmpty) {
            final before = (rows.first['qty'] as int?) ?? 0;
            final after = before + qty;
            await txn.update('items', {'qty': after},
                where: 'id = ?', whereArgs: [itemId]);
            await txn.insert('stock_history', {
              'item_id': itemId,
              'item_name': rows.first['name'],
              'change_type': 'purchase',
              'qty_change': qty,
              'qty_before': before,
              'qty_after': after,
              'reference_no': billNumber,
              'created_at': nowIso,
            });
          }
        }
      }
      return id;
    });

    FirebaseSyncService.debouncedUpload();
    SubscriptionService.instance.incrementPurchaseBillCount().catchError((_) {});
    return billId;
  }

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
      (await database).query('purchase_bill_items', where: 'bill_id = ?', whereArgs: [billId]);

  Future<void> updatePurchaseBillStatus(int billId, String status) async {
    await (await database).update('purchase_bills', {'payment_status': status}, where: 'id = ?', whereArgs: [billId]);
    FirebaseSyncService.debouncedUpload();
  }

  Future<void> deletePurchaseBillWithStockDeduct(int billId) async {
    final db = await database;
    final billRow = await db.query('purchase_bills', where: 'id = ?', whereArgs: [billId]);
    final billNumber = billRow.isNotEmpty ? billRow.first['bill_number'] as String? : null;
    final items = await getPurchaseBillItems(billId);
    for (final item in items) {
      final itemId = item['item_id'];
      final qty    = item['qty'];
      if (itemId != null && qty != null) {
        await deductItemStock(itemId as int, qty as int,
            changeType: 'purchase_cancel', referenceNo: billNumber);
      }
    }
    await db.delete('purchase_bills', where: 'id = ?', whereArgs: [billId]);
    FirebaseSyncService.debouncedUpload();
  }

  Future<String> getPurchaseSummaryForAi() async {
    final bills = await getAllPurchaseBills();
    if (bills.isEmpty) return 'PURCHASE_BILLS: none';
    return 'PURCHASE_BILLS (${bills.length}):\n' +
        bills.take(10).map((b) => '  ${b['bill_number']} supplier:"${b['supplier_name'] ?? "?"}" total:${b['total_amount']}').join('\n');
  }

  // ════════════════════════════════════════════════════════
  //  FULL AI CONTEXT
  // ════════════════════════════════════════════════════════
  Future<String> getFullContextForAi() async {
    return '${await getItemSummaryForAi()}\n\n'
        '${await getCustomerSummaryForAi()}\n\n'
        '${await getSupplierSummaryForAi()}\n\n'
        '${await getSaleBillSummaryForAi()}\n\n'
        '${await getPurchaseSummaryForAi()}';
  }

  /// Compact structured snapshot for the Agent Gateway. The gateway has no
  /// business DB yet (Phase 7 sync), so the client ships this with each turn;
  /// gateway read-tools answer from it and write-tools return proposed actions.
  Future<Map<String, dynamic>> getBusinessContextForGateway() async {
    final items = await getAllItems();
    final customers = await getAllCustomers();
    final suppliers = await getAllSuppliers();
    final bills = await getAllSaleBills();

    final today = await getTodaySaleSummary();
    final month = await getDateRangeSaleSummary(30);
    final unpaid = await getUnpaidBills();
    final lowStock = await getLowStockItemsByAlert();
    final receivable = await getYouWillReceiveAmount();
    final payable = await getYouWillPayAmount();
    final unpaidTotal = unpaid.fold<double>(
        0, (s, b) => s + ((b['total_amount'] as num?)?.toDouble() ?? 0));

    return {
      'items': items
          .take(200)
          .map((i) => {
                'id': i.id,
                'name': i.name,
                'qty': i.qty,
                'price': i.price,
              })
          .toList(),
      'customers': customers
          .take(300)
          .map((c) => {'id': c.id, 'name': c.name, 'phone': c.phone})
          .toList(),
      'suppliers': suppliers
          .take(200)
          .map((s) => {'id': s.id, 'name': s.name, 'phone': s.phone})
          .toList(),
      'recentBills': bills
          .take(30)
          .map((b) => {
                'billNumber': b['bill_number'],
                'customerName': b['customer_name'],
                'total': b['total_amount'],
                'status': b['payment_status'],
              })
          .toList(),
      'analytics': {
        'todaySale': today['total_sale'],
        'todayBillCount': today['bill_count'],
        'monthSale': month['total_sale'],
        'monthBillCount': month['bill_count'],
        'monthCustomers': month['unique_customers'],
        'unpaidTotal': double.parse(unpaidTotal.toStringAsFixed(2)),
        'unpaidCount': unpaid.length,
        'lowStockCount': lowStock.length,
        'receivable': receivable,
        'payable': payable,
        'itemCount': items.length,
        'customerCount': customers.length,
      },
    };
  }

  // ════════════════════════════════════════════════════════
  //  ANALYTICS
  // ════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> getTodaySaleSummary() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final result = await db.rawQuery('''
      SELECT COUNT(*) as bill_count,
             COALESCE(SUM(total_amount), 0) as total_sale,
             COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total_amount ELSE 0 END), 0) as paid_amount,
             COALESCE(SUM(CASE WHEN payment_status = 'unpaid' THEN total_amount ELSE 0 END), 0) as unpaid_amount
      FROM sale_bills WHERE bill_date = ?
    ''', [today]);
    return result.first;
  }

  Future<Map<String, dynamic>> getDateRangeSaleSummary(int days) async {
    final db = await database;
    final fromStr = DateTime.now().subtract(Duration(days: days)).toIso8601String().split('T')[0];
    final result = await db.rawQuery('''
      SELECT COUNT(*) as bill_count,
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
    return db.rawQuery('''
      SELECT strftime('%Y-%m', bill_date) as month,
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
    return (await database).rawQuery('''
      SELECT sb.bill_number, sb.bill_date, sb.total_amount,
             sb.payment_mode, c.name as customer_name, c.phone as customer_phone
      FROM sale_bills sb
      LEFT JOIN customers c ON sb.customer_id = c.id
      WHERE sb.payment_status = 'unpaid' OR sb.payment_status = 'partial'
      ORDER BY sb.bill_date DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getTopSellingItems({int limit = 5}) async {
    return (await database).rawQuery('''
      SELECT sbi.item_name, SUM(sbi.qty) as total_qty_sold, SUM(sbi.line_total) as total_revenue
      FROM sale_bill_items sbi
      JOIN sale_bills sb ON sbi.bill_id = sb.id
      GROUP BY sbi.item_name
      ORDER BY total_revenue DESC LIMIT ?
    ''', [limit]);
  }

  Future<List<Map<String, dynamic>>> getLowStockItems({int threshold = 5}) async {
    return (await database).rawQuery('''
      SELECT name, qty, price FROM items WHERE qty IS NOT NULL AND qty <= ? ORDER BY qty ASC
    ''', [threshold]);
  }

  Future<String> getAnalyticsContextForAi() async {
    final today  = await getTodaySaleSummary();
    final month  = await getDateRangeSaleSummary(30);
    final unpaid = await getUnpaidBills();
    return '''
ANALYTICS:
  Today: bills:${today['bill_count']} total:₹${today['total_sale']} paid:₹${today['paid_amount']} unpaid:₹${today['unpaid_amount']}
  Last 30 days: bills:${month['bill_count']} total:₹${month['total_sale']} customers:${month['unique_customers']}
  Unpaid bills: ${unpaid.length} pending''';
  }

  Future<List<Map<String, dynamic>>> getAllExpenses() async => [];

  Future<double> getYouWillReceiveAmount() async {
    final result = await (await database).rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as total FROM sale_bills
      WHERE payment_status IN ('unpaid', 'partial')
    ''');
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getYouWillPayAmount() async {
    final result = await (await database).rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as total FROM purchase_bills
      WHERE payment_status IN ('unpaid', 'partial')
    ''');
    return (result.first['total'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getTopCustomers({int limit = 10}) async {
    return (await database).rawQuery('''
      SELECT c.name as customer_name, c.phone, COUNT(sb.id) as bill_count,
             COALESCE(SUM(sb.total_amount), 0) as total_spent,
             COALESCE(SUM(CASE WHEN sb.payment_status IN ('unpaid','partial') THEN sb.total_amount ELSE 0 END), 0) as pending_amount
      FROM customers c LEFT JOIN sale_bills sb ON sb.customer_id = c.id
      GROUP BY c.id, c.name, c.phone ORDER BY total_spent DESC LIMIT ?
    ''', [limit]);
  }

  Future<List<Map<String, dynamic>>> getCustomersWithPending() async {
    return (await database).rawQuery('''
      SELECT c.name as customer_name, c.phone, COUNT(sb.id) as unpaid_count,
             COALESCE(SUM(sb.total_amount), 0) as pending_amount
      FROM customers c JOIN sale_bills sb ON sb.customer_id = c.id
      WHERE sb.payment_status IN ('unpaid','partial')
      GROUP BY c.id, c.name, c.phone ORDER BY pending_amount DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getCustomerTransactions(String customerName) async {
    final customer = await getCustomerByName(customerName) ?? await getCustomerFuzzy(customerName);
    if (customer == null) return [];
    return (await database).rawQuery('''
      SELECT sb.bill_number, sb.bill_date, sb.total_amount, sb.payment_mode, sb.payment_status,
             GROUP_CONCAT(sbi.item_name || ' x' || sbi.qty, ', ') as items
      FROM sale_bills sb LEFT JOIN sale_bill_items sbi ON sbi.bill_id = sb.id
      WHERE sb.customer_id = ? GROUP BY sb.id ORDER BY sb.bill_date DESC
    ''', [customer.id]);
  }

  Future<List<Map<String, dynamic>>> getTopSuppliers({int limit = 10}) async {
    return (await database).rawQuery('''
      SELECT s.name as supplier_name, s.phone, COUNT(pb.id) as bill_count,
             COALESCE(SUM(pb.total_amount), 0) as total_purchased,
             COALESCE(SUM(CASE WHEN pb.payment_status IN ('unpaid','partial') THEN pb.total_amount ELSE 0 END), 0) as pending_amount
      FROM suppliers s LEFT JOIN purchase_bills pb ON pb.supplier_id = s.id
      GROUP BY s.id, s.name, s.phone ORDER BY total_purchased DESC LIMIT ?
    ''', [limit]);
  }

  Future<List<Map<String, dynamic>>> getSuppliersWithPending() async {
    return (await database).rawQuery('''
      SELECT s.name as supplier_name, s.phone, COUNT(pb.id) as unpaid_count,
             COALESCE(SUM(pb.total_amount), 0) as pending_amount
      FROM suppliers s JOIN purchase_bills pb ON pb.supplier_id = s.id
      WHERE pb.payment_status IN ('unpaid','partial')
      GROUP BY s.id, s.name, s.phone ORDER BY pending_amount DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getSupplierTransactions(String supplierName) async {
    final supplier = await getSupplierByName(supplierName) ?? await getSupplierFuzzy(supplierName);
    if (supplier == null) return [];
    return (await database).rawQuery('''
      SELECT pb.bill_number, pb.bill_date, pb.total_amount, pb.payment_mode, pb.payment_status,
             GROUP_CONCAT(pbi.item_name || ' x' || pbi.qty, ', ') as items
      FROM purchase_bills pb LEFT JOIN purchase_bill_items pbi ON pbi.bill_id = pb.id
      WHERE pb.supplier_id = ? GROUP BY pb.id ORDER BY pb.bill_date DESC
    ''', [supplier.id]);
  }

  Future<List<Map<String, dynamic>>> getUnpaidPurchaseBills() async {
    return (await database).rawQuery('''
      SELECT pb.bill_number, pb.bill_date, pb.total_amount, pb.payment_mode,
             s.name as supplier_name, s.phone as supplier_phone
      FROM purchase_bills pb LEFT JOIN suppliers s ON pb.supplier_id = s.id
      WHERE pb.payment_status IN ('unpaid','partial') ORDER BY pb.bill_date DESC
    ''');
  }

  Future<Map<String, dynamic>> getPurchaseSummaryByDays(int days) async {
    final fromStr = DateTime.now().subtract(Duration(days: days)).toIso8601String().split('T')[0];
    final result = await (await database).rawQuery('''
      SELECT COUNT(*) as bill_count,
             COALESCE(SUM(total_amount), 0) as total_purchase,
             COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total_amount ELSE 0 END), 0) as paid_amount,
             COALESCE(SUM(CASE WHEN payment_status = 'unpaid' THEN total_amount ELSE 0 END), 0) as unpaid_amount
      FROM purchase_bills WHERE bill_date >= ?
    ''', [fromStr]);
    return result.first;
  }

  Future<List<Map<String, dynamic>>> getMostProfitableItems({int limit = 10}) async {
    return (await database).rawQuery('''
      SELECT sbi.item_name, SUM(sbi.qty) as total_qty_sold,
             SUM(sbi.line_total) as total_revenue, AVG(sbi.unit_price) as avg_price
      FROM sale_bill_items sbi JOIN sale_bills sb ON sbi.bill_id = sb.id
      GROUP BY sbi.item_name ORDER BY total_revenue DESC LIMIT ?
    ''', [limit]);
  }

  Future<Map<String, dynamic>> getCashVsCreditSales() async {
    final result = await (await database).rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN LOWER(payment_mode) = 'cash' THEN total_amount ELSE 0 END), 0) as cash_total,
             COALESCE(SUM(CASE WHEN LOWER(payment_mode) IN ('upi','gpay','phonepay','online') THEN total_amount ELSE 0 END), 0) as upi_total,
             COALESCE(SUM(CASE WHEN LOWER(payment_mode) IN ('credit','udhaar','cheque') THEN total_amount ELSE 0 END), 0) as credit_total
      FROM sale_bills
    ''');
    return result.first;
  }

  Future<Map<String, dynamic>?> getItemStock(String name) async {
    final item = await getItemByName(name) ?? await getItemFuzzy(name);
    if (item == null) return null;
    return {'name': item.name, 'qty': item.qty ?? 0, 'price': item.price ?? 0};
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

  MapEntry<String, T>? _fuzzyFind<T>(String query, List<MapEntry<String, T>> entries) {
    if (entries.isEmpty) return null;
    final q = query.toLowerCase();
    MapEntry<String, T>? best;
    int bestDist = 999;
    for (final e in entries) {
      final d = _levenshtein(q, e.key.toLowerCase());
      if (d < bestDist) { bestDist = d; best = e; }
    }
    return bestDist <= 2 ? best : null;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));
    for (int i = 0; i <= a.length; i++) m[i][0] = i;
    for (int j = 0; j <= b.length; j++) m[0][j] = j;
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i-1] == b[j-1] ? 0 : 1;
        m[i][j] = [m[i-1][j]+1, m[i][j-1]+1, m[i-1][j-1]+cost].reduce((x, y) => x < y ? x : y);
      }
    }
    return m[a.length][b.length];
  }
}