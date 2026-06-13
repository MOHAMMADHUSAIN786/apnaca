import 'package:apnaca/features/warehouse/data/local/warehouse_db.dart';
import 'package:drift/drift.dart';
import 'package:apnaca/database/app_database.dart';
import 'package:apnaca/features/warehouse/data/remote/warehouse_sync_service.dart';

class WarehouseRepository {
  WarehouseRepository._internal();
  static final WarehouseRepository instance = WarehouseRepository._internal();

  WarehouseDb? _db;

  Future<WarehouseDb> _getDb() async {
    _db ??= await WarehouseDb.getInstance();
    return _db!;
  }

  Future<List<Map<String, dynamic>>> getAllWarehouses() async {
    final db = await _getDb();
    final rows = await db.getAllWarehouses();
    return rows.map((r) => {'id': r.id, 'name': r.name, 'code': r.code, 'location': r.location, 'createdAt': r.createdAt}).toList();
  }

  Future<int> createWarehouse(String name, {String? code, String? location}) async {
    final db = await _getDb();
    final now = DateTime.now().toIso8601String();
    final id = await db.createWarehouse(WarehousesCompanion(
      name: Value(name),
      code: Value(code),
      location: Value(location),
      createdAt: Value(now),
    ));
    // push to firestore
    await WarehouseSyncService.instance.pushWarehouse({'id': id, 'name': name, 'code': code, 'location': location, 'createdAt': DateTime.now().toIso8601String()});
    return id;
  }

  Future<int> updateWarehouse(int id, String name, {String? code, String? location}) async {
    final db = await _getDb();
    final w = await db.getWarehouseById(id);
    if (w == null) return 0;
    final entry = WarehousesCompanion(
      id: Value(id),
      name: Value(name),
      code: Value(code),
      location: Value(location),
      createdAt: Value(w.createdAt),
    );
    final res = await db.updateWarehouseEntry(entry);
    await WarehouseSyncService.instance.pushWarehouse({'id': id, 'name': name, 'code': code, 'location': location, 'createdAt': w.createdAt});
    return res;
  }

  Future<int> deleteWarehouse(int id) async {
    final db = await _getDb();
    final res = await db.deleteWarehouseById(id);
    // push a tombstone to firestore
    await WarehouseSyncService.instance.pushWarehouse({'id': id, 'deleted': true});
    return res;
  }

  Future<double> getWarehouseItemQty(int warehouseId, int itemId) async {
    final db = await _getDb();
    return db.getWarehouseItemQty(warehouseId, itemId);
  }

  Future<int> transferStock({int? fromWarehouseId, int? toWarehouseId, required int itemId, required double qty}) async {
    final db = await _getDb();
    // update global items if necessary via AppDatabase
    if (fromWarehouseId == null) {
      await AppDatabase.instance.deductItemStock(itemId, qty.toInt());
    }
    if (toWarehouseId == null) {
      await AppDatabase.instance.addItemStock(itemId, qty.toInt());
    }
    final id = await db.createTransfer(fromWarehouseId: fromWarehouseId, toWarehouseId: toWarehouseId, itemId: itemId, qty: qty);
    await WarehouseSyncService.instance.pushTransfer({'id': id, 'from': fromWarehouseId, 'to': toWarehouseId, 'item_id': itemId, 'qty': qty, 'createdAt': DateTime.now().toIso8601String()});
    return id;
  }

  Future<List<Map<String, dynamic>>> getTransferHistory({int limit = 200}) async {
    final db = await _getDb();
    final rows = await db.getTransferHistory(limit: limit);
    return rows.map((r) => {'id': r.id, 'from': r.fromWarehouseId, 'to': r.toWarehouseId, 'item_id': r.itemId, 'qty': r.qty, 'status': r.status, 'createdAt': r.createdAt}).toList();
  }
}
