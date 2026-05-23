import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../features/customer/model/customer_model.dart';
import '../features/item/model/item_model.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _db;

  AppDatabase._internal();

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'billnex.db');
    return await openDatabase(
      path,
      version: 2, // ← bumped from 1 to 2 (customers table added)
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Fresh install
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        firebaseUid TEXT    UNIQUE,
        email       TEXT,
        displayName TEXT,
        createdAt   TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE items (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        name     TEXT NOT NULL,
        qty      INTEGER,
        price    REAL,
        hsn_code TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        email       TEXT,
        phone       TEXT,
        address     TEXT,
        gst_number  TEXT,
        state       TEXT
      )
    ''');
  }

  // Existing install upgrade (v1 → v2 adds customers table)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          name        TEXT NOT NULL,
          email       TEXT,
          phone       TEXT,
          address     TEXT,
          gst_number  TEXT,
          state       TEXT
        )
      ''');
    }
  }

  // ════════════════════════════════════════════════════════
  //  USER METHODS
  // ════════════════════════════════════════════════════════

  Future<void> insertOrUpdateUser(Map<String, dynamic> userData) async {
    final db = await database;
    await db.insert('users', userData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ════════════════════════════════════════════════════════
  //  ITEM METHODS
  // ════════════════════════════════════════════════════════

  Future<int> insertItem(ItemModel item) async {
    final db = await database;
    return await db.insert('items', item.toMap());
  }

  Future<List<ItemModel>> getAllItems() async {
    final db = await database;
    final rows = await db.query('items', orderBy: 'id DESC');
    return rows.map(ItemModel.fromMap).toList();
  }

  Future<ItemModel?> getItemById(int id) async {
    final db = await database;
    final rows = await db.query('items', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ItemModel.fromMap(rows.first);
  }

  Future<ItemModel?> getItemByName(String name) async {
    final db = await database;
    final rows = await db.query('items',
        where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    if (rows.isEmpty) return null;
    return ItemModel.fromMap(rows.first);
  }

  Future<int> updateItem(ItemModel item) async {
    final db = await database;
    return await db.update('items', item.toMap(),
        where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> getItemSummaryForAi() async {
    final items = await getAllItems();
    if (items.isEmpty) return 'ITEMS: none';
    final lines = items.take(30).map((i) =>
    '  id:${i.id} name:"${i.name}" qty:${i.qty ?? "?"} price:${i.price ?? "?"} hsn:${i.hsnCode ?? "?"}').join('\n');
    return 'ITEMS (${items.length} total):\n$lines';
  }

  // ════════════════════════════════════════════════════════
  //  CUSTOMER METHODS
  // ════════════════════════════════════════════════════════

  Future<int> insertCustomer(CustomerModel customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap());
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    final db = await database;
    final rows = await db.query('customers', orderBy: 'id DESC');
    return rows.map(CustomerModel.fromMap).toList();
  }

  Future<CustomerModel?> getCustomerById(int id) async {
    final db = await database;
    final rows =
    await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return CustomerModel.fromMap(rows.first);
  }

  Future<CustomerModel?> getCustomerByName(String name) async {
    final db = await database;
    final rows = await db.query('customers',
        where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    if (rows.isEmpty) return null;
    return CustomerModel.fromMap(rows.first);
  }

  Future<int> updateCustomer(CustomerModel customer) async {
    final db = await database;
    return await db.update('customers', customer.toMap(),
        where: 'id = ?', whereArgs: [customer.id]);
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> getCustomerSummaryForAi() async {
    final customers = await getAllCustomers();
    if (customers.isEmpty) return 'CUSTOMERS: none';
    final lines = customers.take(30).map((c) =>
    '  id:${c.id} name:"${c.name}" phone:${c.phone ?? "?"} gst:${c.gstNumber ?? "?"}').join('\n');
    return 'CUSTOMERS (${customers.length} total):\n$lines';
  }

  // Combined context for AI (items + customers)
  Future<String> getFullContextForAi() async {
    final itemCtx = await getItemSummaryForAi();
    final customerCtx = await getCustomerSummaryForAi();
    return '$itemCtx\n\n$customerCtx';
  }
}
