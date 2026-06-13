import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:apnaca/database/app_database.dart';
import 'package:apnaca/features/item/model/item_model.dart';

void main() {
  sqfliteFfiInit();

  test('getItemByBarcode returns inserted item', () async {
    final db = AppDatabase.instance;

    // create item
    final item = ItemModel(id: null, name: 'BarcodeItem', qty: 10, price: 99.0, hsnCode: null, barcode: 'BC12345');
    final id = await db.insertItem(item);
    expect(id, isNonZero);

    final found = await db.getItemByBarcode('BC12345');
    expect(found, isNotNull);
    expect(found!.name, equals('BarcodeItem'));
    expect(found.barcode, equals('BC12345'));
  });
}
