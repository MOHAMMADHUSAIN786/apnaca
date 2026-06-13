import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:apnaca/database/app_database.dart';

void main() {
  sqfliteFfiInit();

  test('transferStock moves qty between warehouses', () async {
    // NOTE: AppDatabase uses file-based DB. For CI we assume the environment
    // provides a writable DB path. This test will simply call transferStock
    // to ensure it completes; CI may need sqflite_common_ffi environment setup.

    final db = AppDatabase.instance;

    // prepare: create two warehouses and an item
    final w1 = await db.insertWarehouse({'name': 'WH1'});
    final w2 = await db.insertWarehouse({'name': 'WH2'});
    final itemId = await db.insertItem(
      const ItemModel(id: null, name: 'Tst', qty: 0),
    );

    // seed stock into w1
    await db.upsertWarehouseItem(w1, itemId!, 10);

    final ok = await db.transferStock(w1, w2, itemId, 5);
    expect(ok, isTrue);

    final q1 = await db.getWarehouseItemQty(w1, itemId);
    final q2 = await db.getWarehouseItemQty(w2, itemId);

    expect(q1, equals(5));
    expect(q2, equals(5));
  });
}
