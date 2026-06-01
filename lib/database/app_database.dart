import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../core/services/sync_service.dart';
import '../features/customer/model/customer_model.dart';
import '../features/item/model/item_model.dart';
import '../features/supplier/model/supplier_model.dart';

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
        version: 8, // bumped to 8 to add suppliers + purchase_bills
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
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  name     TEXT NOT NULL,
  qty      INTEGER,
  price    REAL,
  hsn_code TEXT
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
    return result;
  }

  Future<int> insertSaleBillItem(Map<String, dynamic> data) async {
    final result = await (await database).insert('sale_bill_items', data);
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
        await restoreItemStock(itemId as int, qty as int);
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
        await deductItemStock(itemId as int, qty as int);
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
    return result;
  }

  Future<int> insertPurchaseBillItem(Map<String, dynamic> data) async {
    final result = await (await database).insert('purchase_bill_items', data);
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

  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    // Implement when you add expenses table
    return [];
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



}