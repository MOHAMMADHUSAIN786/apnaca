import 'package:shared_preferences/shared_preferences.dart';
import '../../database/app_database.dart';

/// Small demo-data loader to populate the app database with sample
/// companies, warehouses and a few items. Run with:
///
/// dart run lib/tools/demo_data.dart
///
/// Note: this script assumes you run it from the project root where
/// Flutter/Dart SDK is available.
Future<void> main() async {
  // Switch to a deterministic demo DB name so it's easy to find
  await AppDatabase.switchUser('demo_company');
  final db = await AppDatabase.instance.database;

  // Create a sample company row (if companies table exists)
  try {
    final companies = await db.query('companies', where: 'name = ?', whereArgs: ['Demo Co']);
    if (companies.isEmpty) {
      await db.insert('companies', {
        'name': 'Demo Co',
        'db_name': 'demo_company',
        'branding': '{"primaryColor":"#1976D2"}',
      });
    }
  } catch (_) {}

  // Add two warehouses
  try {
    final w1 = await db.query('warehouses', where: 'name = ?', whereArgs: ['Main Warehouse']);
    if (w1.isEmpty) {
      await db.insert('warehouses', {'name': 'Main Warehouse', 'code': 'WH-1'});
    }
    final w2 = await db.query('warehouses', where: 'name = ?', whereArgs: ['Retail Outlet']);
    if (w2.isEmpty) {
      await db.insert('warehouses', {'name': 'Retail Outlet', 'code': 'WH-2'});
    }
  } catch (_) {}

  // Add a few items
  try {
    final items = await db.query('items');
    if (items.isEmpty) {
      await db.insert('items', {'name': 'Apple iPhone (Demo)', 'qty': 10, 'price': 499.0, 'barcode': '111222333'});
      await db.insert('items', {'name': 'Demo USB Cable', 'qty': 50, 'price': 5.99, 'barcode': '222333444'});
      await db.insert('items', {'name': 'Thermal Paper Roll', 'qty': 100, 'price': 1.5, 'barcode': '333444555'});
    }
  } catch (_) {}

  // Ensure a default current warehouse is saved for the demo (first warehouse id)
  try {
    final whRows = await db.query('warehouses', orderBy: 'id ASC', limit: 1);
    if (whRows.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_warehouse_id', whRows.first['id'] as int);
    }
  } catch (_) {}

  print('Demo data installed for DB: demo_company');
}
