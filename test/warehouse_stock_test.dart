import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:apnaca/database/app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('upsertWarehouseItem increases and decreases qty', () async {
    await AppDatabase.switchUser('test_warehouse');
    final db = await AppDatabase.instance.database;
    // clean tables
    await db.delete('warehouse_items');
    await db.delete('warehouses');
    await db.delete('items');

    // create warehouse
    final whId = await db.insert('warehouses', {'name': 'W1'});
    // create item
    final itemId = await db.insert('items', {'name': 'I1', 'qty': 0, 'price': 10});

    // increase by 5
    await AppDatabase.instance.upsertWarehouseItem(whId, itemId, 5);
    var rows = await db.rawQuery('SELECT qty FROM warehouse_items WHERE warehouse_id = ? AND item_id = ?', [whId, itemId]);
    expect(rows.isNotEmpty, true);
    expect((rows.first['qty'] as num).toDouble(), 5.0);

    // decrease by 2
    await AppDatabase.instance.upsertWarehouseItem(whId, itemId, -2);
    rows = await db.rawQuery('SELECT qty FROM warehouse_items WHERE warehouse_id = ? AND item_id = ?', [whId, itemId]);
    expect((rows.first['qty'] as num).toDouble(), 3.0);
  });
}
