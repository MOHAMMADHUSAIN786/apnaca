import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_database.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // User table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebaseUid TEXT UNIQUE,
        email TEXT,
        displayName TEXT,
        createdAt TEXT
      )
    ''');

    // Item table
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        qty INTEGER,
        price REAL,
        hsn_code TEXT
      )
    ''');
  }

  // Insert or update user after login
  Future<void> insertOrUpdateUser(Map<String, dynamic> userData) async {
    final db = await database;
    await db.insert(
      'users',
      userData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Item table ke liye CRUD methods (example)
  Future<int> insertItem(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert('items', item);
  }

  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await database;
    return await db.query('items');
  }

// ... update, delete, etc.
}