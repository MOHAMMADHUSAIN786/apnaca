import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'warehouse_db.g.dart';

// Tables
class Warehouses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 250)();
  TextColumn get code => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get createdAt => text().withDefault(Constant(''))();
}

class WarehouseItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get warehouseId => integer().references(Warehouses, #id)();
  // `items` table lives in the global AppDatabase (sqflite); avoid cross-db
  // foreign key here — store the `itemId` as a plain integer to prevent
  // referencing a table that isn't part of this Drift database.
  IntColumn get itemId => integer()();
  RealColumn get quantity => real().withDefault(Constant(0))();
  RealColumn get reservedQty => real().withDefault(Constant(0))();
  TextColumn get lastUpdated => text().withDefault(Constant(''))();
  @override
  List<Set<Column>> get uniqueKeys => [ {warehouseId, itemId} ];
}

class StockTransfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fromWarehouseId => integer().nullable().references(Warehouses, #id)();
  IntColumn get toWarehouseId => integer().nullable().references(Warehouses, #id)();
  // Referencing `items` is not possible across DB boundaries; keep plain int.
  IntColumn get itemId => integer()();
  RealColumn get qty => real()();
  TextColumn get status => text().withDefault(Constant('completed'))();
  TextColumn get createdAt => text().withDefault(Constant(''))();
}

@DriftDatabase(tables: [Warehouses, WarehouseItems, StockTransfers])
class WarehouseDb extends _$WarehouseDb {
  WarehouseDb._internal(QueryExecutor e) : super(e);

  static WarehouseDb? _instance;

  factory WarehouseDb() {
    throw StateError('Use getInstance');
  }

  static Future<WarehouseDb> getInstance() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationDocumentsDirectory();
    final dbFolder = Directory(p.join(dir.path, 'databases'));
    if (!await dbFolder.exists()) await dbFolder.create(recursive: true);
    final file = File(p.join(dbFolder.path, 'warehouse.db'));
    final executor = NativeDatabase(file);
    _instance = WarehouseDb._internal(executor);
    return _instance!;
  }

  @override
  int get schemaVersion => 1;

  // Warehouses CRUD
  Future<int> createWarehouse(Insertable<Warehouse> w) => into(warehouses).insert(w);
  Future<List<Warehouse>> getAllWarehouses() => (select(warehouses)..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)])).get();
  Future<Warehouse?> getWarehouseById(int id) async => (select(warehouses)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<int> updateWarehouseEntry(Insertable<Warehouse> w) async {
    final ok = await update(warehouses).replace(w);
    return ok ? 1 : 0;
  }
  Future<int> deleteWarehouseById(int id) => (delete(warehouses)..where((t) => t.id.equals(id))).go();

  // Warehouse Items
  Future<int> upsertWarehouseItem(int warehouseId, int itemId, double delta) async {
    final q = select(warehouseItems)..where((t) => t.warehouseId.equals(warehouseId) & t.itemId.equals(itemId));
    final existing = await q.getSingleOrNull();
    if (existing == null) {
      return into(warehouseItems).insert(WarehouseItemsCompanion(
        warehouseId: Value(warehouseId),
        itemId: Value(itemId),
        quantity: Value(delta),
        reservedQty: Value(0),
        lastUpdated: Value(DateTime.now().toIso8601String()),
      ));
    } else {
      final newQty = existing.quantity + delta;
      return (update(warehouseItems)..where((t) => t.id.equals(existing.id))).write(
        WarehouseItemsCompanion(
          quantity: Value(newQty),
          lastUpdated: Value(DateTime.now().toIso8601String()),
        ),
      );
    }
  }

  Future<double> getWarehouseItemQty(int warehouseId, int itemId) async {
    final row = await (select(warehouseItems)..where((t) => t.warehouseId.equals(warehouseId) & t.itemId.equals(itemId))).getSingleOrNull();
    return row?.quantity ?? 0.0;
  }

  // Transfers
  Future<int> createTransfer({int? fromWarehouseId, int? toWarehouseId, required int itemId, required double qty}) async {
    return transaction(() async {
      final now = DateTime.now().toIso8601String();
      // deduct from source
      if (fromWarehouseId != null) {
        await upsertWarehouseItem(fromWarehouseId, itemId, -qty);
      } else {
        // fallback: global items table decrement
        // we will call existing AppDatabase methods from repository layer
      }
      // add to destination
      if (toWarehouseId != null) {
        await upsertWarehouseItem(toWarehouseId, itemId, qty);
      }
      final id = await into(stockTransfers).insert(StockTransfersCompanion(
        fromWarehouseId: Value(fromWarehouseId),
        toWarehouseId: Value(toWarehouseId),
        itemId: Value(itemId),
        qty: Value(qty),
        status: Value('completed'),
        createdAt: Value(now),
      ));
      return id;
    });
  }

  Future<List<StockTransfer>> getTransferHistory({int limit = 100}) async {
    return (select(stockTransfers)..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)])..limit(limit)).get();
  }
}
