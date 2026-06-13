import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:apnaca/database/app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('transferStock moves qty between warehouses and updates item total', () async {
    await AppDatabase.switchUser('test_transfer');
    final db = await AppDatabase.instance.database;
    // clean
    await db.delete('stock_transfers').catchError((_) {});
    await db.delete('warehouse_items').catchError((_) {});
    await db.delete('warehouses').catchError((_) {});
    await db.delete('items').catchError((_) {});

    // create item and warehouses
    final itemId = await db.insert('items', {'name': 'TItem', 'qty': 0, 'price': 10});
    final w1 = await db.insert('warehouses', {'name': 'W1'});
    final w2 = await db.insert('warehouses', {'name': 'W2'});

    // give w1 quantity 10
    await AppDatabase.instance.upsertWarehouseItem(w1, itemId, 10);

    // transfer 4 from w1 to w2
    final ok = await AppDatabase.instance.transferStock(w1, w2, itemId, 4);
    expect(ok, true);

    // check quantities
    final rowsW1 = await db.rawQuery('SELECT quantity FROM warehouse_items WHERE warehouse_id = ? AND item_id = ?', [w1, itemId]);
    final rowsW2 = await db.rawQuery('SELECT quantity FROM warehouse_items WHERE warehouse_id = ? AND item_id = ?', [w2, itemId]);
    expect(rowsW1.first['quantity'], 6);
    expect(rowsW2.first['quantity'], 4);

    // global item qty should be sum = 10
    final itemRow = await db.rawQuery('SELECT qty FROM items WHERE id = ?', [itemId]);
    expect(itemRow.first['qty'], 10);
  });

  test('deleteSaleBillWithStockRestore restores warehouse qty and removes bill', () async {
    await AppDatabase.switchUser('test_delete_sale');
    final db = await AppDatabase.instance.database;
    // clean
    await db.delete('sale_bill_items').catchError((_) {});
    await db.delete('sale_bills').catchError((_) {});
    await db.delete('warehouse_items').catchError((_) {});
    await db.delete('warehouses').catchError((_) {});
    await db.delete('items').catchError((_) {});

    // create warehouse and item
    final itemId = await db.insert('items', {'name': 'SItem', 'qty': 0, 'price': 5});
    final wh = await db.insert('warehouses', {'name': 'WSale'});

    // give warehouse qty 10
    await AppDatabase.instance.upsertWarehouseItem(wh, itemId, 10);

    // create sale bill and item (this will deduct stock)
    final billNumber = await AppDatabase.instance.generateBillNumber();
    final billId = await AppDatabase.instance.insertSaleBill({
      'bill_number': billNumber,
      'customer_id': null,
      'warehouse_id': wh,
      'bill_date': DateTime.now().toIso8601String().split('T')[0],
      'subtotal': 50,
      'gst_amount': 0,
      'total_amount': 50,
      'payment_mode': 'cash',
      'payment_status': 'paid',
    });

    await AppDatabase.instance.insertSaleBillItem({
      'bill_id': billId,
      'item_id': itemId,
      'item_name': 'SItem',
      'qty': 3,
      'unit_price': 5,
      'tax_rate': 0,
      'tax_amount': 0,
      'line_total': 15,
    });

    // after insertion, warehouse should have 7
    var rows = await db.rawQuery('SELECT quantity FROM warehouse_items WHERE warehouse_id = ? AND item_id = ?', [wh, itemId]);
    expect(rows.first['quantity'], 7);

    // delete bill with restore
    await AppDatabase.instance.deleteSaleBillWithStockRestore(billId);

    // warehouse qty should be restored to 10
    rows = await db.rawQuery('SELECT quantity FROM warehouse_items WHERE warehouse_id = ? AND item_id = ?', [wh, itemId]);
    expect(rows.first['quantity'], 10);

    // sale_bills should be deleted
    final bills = await db.rawQuery('SELECT COUNT(1) as c FROM sale_bills');
    expect(bills.first['c'], 0);
  });

  test('deletePurchaseBillWithStockDeduct deducts added stock and removes bill', () async {
    await AppDatabase.switchUser('test_delete_purchase');
    final db = await AppDatabase.instance.database;
    // clean
    await db.delete('purchase_bill_items').catchError((_) {});
    await db.delete('purchase_bills').catchError((_) {});
    await db.delete('warehouse_items').catchError((_) {});
    await db.delete('warehouses').catchError((_) {});
    await db.delete('items').catchError((_) {});

    // create warehouse and item
    final itemId = await db.insert('items', {'name': 'PItem', 'qty': 0, 'price': 7});
    final wh = await db.insert('warehouses', {'name': 'WPurchase'});

    // give warehouse qty 5
    await AppDatabase.instance.upsertWarehouseItem(wh, itemId, 5);

    // create purchase bill and item (this will add stock)
    final billNumber = await AppDatabase.instance.generatePurchaseBillNumber();
    final billId = await AppDatabase.instance.insertPurchaseBill({
      'bill_number': billNumber,
      'supplier_id': 1,
      'warehouse_id': wh,
      'bill_date': DateTime.now().toIso8601String().split('T')[0],
      'subtotal': 28,
      'tax_amount': 0,
      'total_amount': 28,
      'payment_mode': 'cash',
      'payment_status': 'paid',
    });

    await AppDatabase.instance.insertPurchaseBillItem({
      'bill_id': billId,
      'item_id': itemId,
      'item_name': 'PItem',
      'qty': 4,
      'unit_price': 7,
      'tax_rate': 0,
      'tax_amount': 0,
      'line_total': 28,
    });

    // after insertion, warehouse should have 9
    var rows = await db.rawQuery('SELECT quantity FROM warehouse_items WHERE warehouse_id = ? AND item_id = ?', [wh, itemId]);
    expect(rows.first['quantity'], 9);

    // delete purchase bill which should deduct 4
    await AppDatabase.instance.deletePurchaseBillWithStockDeduct(billId);

    // warehouse qty should be back to 5
    rows = await db.rawQuery('SELECT quantity FROM warehouse_items WHERE warehouse_id = ? AND item_id = ?', [wh, itemId]);
    expect(rows.first['quantity'], 5);

    // purchase_bills should be deleted
    final bills = await db.rawQuery('SELECT COUNT(1) as c FROM purchase_bills');
    expect(bills.first['c'], 0);
  });
}
