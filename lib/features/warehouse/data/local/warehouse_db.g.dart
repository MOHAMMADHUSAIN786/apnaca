// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'warehouse_db.dart';

// ignore_for_file: type=lint
class $WarehousesTable extends Warehouses
    with TableInfo<$WarehousesTable, Warehouse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WarehousesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 250,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, code, location, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'warehouses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Warehouse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Warehouse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Warehouse(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WarehousesTable createAlias(String alias) {
    return $WarehousesTable(attachedDatabase, alias);
  }
}

class Warehouse extends DataClass implements Insertable<Warehouse> {
  final int id;
  final String name;
  final String? code;
  final String? location;
  final String createdAt;
  const Warehouse({
    required this.id,
    required this.name,
    this.code,
    this.location,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  WarehousesCompanion toCompanion(bool nullToAbsent) {
    return WarehousesCompanion(
      id: Value(id),
      name: Value(name),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      createdAt: Value(createdAt),
    );
  }

  factory Warehouse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Warehouse(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String?>(json['code']),
      location: serializer.fromJson<String?>(json['location']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String?>(code),
      'location': serializer.toJson<String?>(location),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  Warehouse copyWith({
    int? id,
    String? name,
    Value<String?> code = const Value.absent(),
    Value<String?> location = const Value.absent(),
    String? createdAt,
  }) => Warehouse(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code.present ? code.value : this.code,
    location: location.present ? location.value : this.location,
    createdAt: createdAt ?? this.createdAt,
  );
  Warehouse copyWithCompanion(WarehousesCompanion data) {
    return Warehouse(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      location: data.location.present ? data.location.value : this.location,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Warehouse(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('location: $location, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, code, location, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Warehouse &&
          other.id == this.id &&
          other.name == this.name &&
          other.code == this.code &&
          other.location == this.location &&
          other.createdAt == this.createdAt);
}

class WarehousesCompanion extends UpdateCompanion<Warehouse> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> code;
  final Value<String?> location;
  final Value<String> createdAt;
  const WarehousesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.location = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WarehousesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.code = const Value.absent(),
    this.location = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Warehouse> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? code,
    Expression<String>? location,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (location != null) 'location': location,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WarehousesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? code,
    Value<String?>? location,
    Value<String>? createdAt,
  }) {
    return WarehousesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WarehousesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('location: $location, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $WarehouseItemsTable extends WarehouseItems
    with TableInfo<$WarehouseItemsTable, WarehouseItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WarehouseItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _warehouseIdMeta = const VerificationMeta(
    'warehouseId',
  );
  @override
  late final GeneratedColumn<int> warehouseId = GeneratedColumn<int>(
    'warehouse_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES warehouses (id)',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _reservedQtyMeta = const VerificationMeta(
    'reservedQty',
  );
  @override
  late final GeneratedColumn<double> reservedQty = GeneratedColumn<double>(
    'reserved_qty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<String> lastUpdated = GeneratedColumn<String>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    warehouseId,
    itemId,
    quantity,
    reservedQty,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'warehouse_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<WarehouseItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('warehouse_id')) {
      context.handle(
        _warehouseIdMeta,
        warehouseId.isAcceptableOrUnknown(
          data['warehouse_id']!,
          _warehouseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_warehouseIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('reserved_qty')) {
      context.handle(
        _reservedQtyMeta,
        reservedQty.isAcceptableOrUnknown(
          data['reserved_qty']!,
          _reservedQtyMeta,
        ),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {warehouseId, itemId},
  ];
  @override
  WarehouseItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WarehouseItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      warehouseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}warehouse_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      reservedQty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reserved_qty'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_updated'],
      )!,
    );
  }

  @override
  $WarehouseItemsTable createAlias(String alias) {
    return $WarehouseItemsTable(attachedDatabase, alias);
  }
}

class WarehouseItem extends DataClass implements Insertable<WarehouseItem> {
  final int id;
  final int warehouseId;
  final int itemId;
  final double quantity;
  final double reservedQty;
  final String lastUpdated;
  const WarehouseItem({
    required this.id,
    required this.warehouseId,
    required this.itemId,
    required this.quantity,
    required this.reservedQty,
    required this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['warehouse_id'] = Variable<int>(warehouseId);
    map['item_id'] = Variable<int>(itemId);
    map['quantity'] = Variable<double>(quantity);
    map['reserved_qty'] = Variable<double>(reservedQty);
    map['last_updated'] = Variable<String>(lastUpdated);
    return map;
  }

  WarehouseItemsCompanion toCompanion(bool nullToAbsent) {
    return WarehouseItemsCompanion(
      id: Value(id),
      warehouseId: Value(warehouseId),
      itemId: Value(itemId),
      quantity: Value(quantity),
      reservedQty: Value(reservedQty),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory WarehouseItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WarehouseItem(
      id: serializer.fromJson<int>(json['id']),
      warehouseId: serializer.fromJson<int>(json['warehouseId']),
      itemId: serializer.fromJson<int>(json['itemId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      reservedQty: serializer.fromJson<double>(json['reservedQty']),
      lastUpdated: serializer.fromJson<String>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'warehouseId': serializer.toJson<int>(warehouseId),
      'itemId': serializer.toJson<int>(itemId),
      'quantity': serializer.toJson<double>(quantity),
      'reservedQty': serializer.toJson<double>(reservedQty),
      'lastUpdated': serializer.toJson<String>(lastUpdated),
    };
  }

  WarehouseItem copyWith({
    int? id,
    int? warehouseId,
    int? itemId,
    double? quantity,
    double? reservedQty,
    String? lastUpdated,
  }) => WarehouseItem(
    id: id ?? this.id,
    warehouseId: warehouseId ?? this.warehouseId,
    itemId: itemId ?? this.itemId,
    quantity: quantity ?? this.quantity,
    reservedQty: reservedQty ?? this.reservedQty,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
  WarehouseItem copyWithCompanion(WarehouseItemsCompanion data) {
    return WarehouseItem(
      id: data.id.present ? data.id.value : this.id,
      warehouseId: data.warehouseId.present
          ? data.warehouseId.value
          : this.warehouseId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      reservedQty: data.reservedQty.present
          ? data.reservedQty.value
          : this.reservedQty,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WarehouseItem(')
          ..write('id: $id, ')
          ..write('warehouseId: $warehouseId, ')
          ..write('itemId: $itemId, ')
          ..write('quantity: $quantity, ')
          ..write('reservedQty: $reservedQty, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, warehouseId, itemId, quantity, reservedQty, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WarehouseItem &&
          other.id == this.id &&
          other.warehouseId == this.warehouseId &&
          other.itemId == this.itemId &&
          other.quantity == this.quantity &&
          other.reservedQty == this.reservedQty &&
          other.lastUpdated == this.lastUpdated);
}

class WarehouseItemsCompanion extends UpdateCompanion<WarehouseItem> {
  final Value<int> id;
  final Value<int> warehouseId;
  final Value<int> itemId;
  final Value<double> quantity;
  final Value<double> reservedQty;
  final Value<String> lastUpdated;
  const WarehouseItemsCompanion({
    this.id = const Value.absent(),
    this.warehouseId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.reservedQty = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  WarehouseItemsCompanion.insert({
    this.id = const Value.absent(),
    required int warehouseId,
    required int itemId,
    this.quantity = const Value.absent(),
    this.reservedQty = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  }) : warehouseId = Value(warehouseId),
       itemId = Value(itemId);
  static Insertable<WarehouseItem> custom({
    Expression<int>? id,
    Expression<int>? warehouseId,
    Expression<int>? itemId,
    Expression<double>? quantity,
    Expression<double>? reservedQty,
    Expression<String>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (warehouseId != null) 'warehouse_id': warehouseId,
      if (itemId != null) 'item_id': itemId,
      if (quantity != null) 'quantity': quantity,
      if (reservedQty != null) 'reserved_qty': reservedQty,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  WarehouseItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? warehouseId,
    Value<int>? itemId,
    Value<double>? quantity,
    Value<double>? reservedQty,
    Value<String>? lastUpdated,
  }) {
    return WarehouseItemsCompanion(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      reservedQty: reservedQty ?? this.reservedQty,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (warehouseId.present) {
      map['warehouse_id'] = Variable<int>(warehouseId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (reservedQty.present) {
      map['reserved_qty'] = Variable<double>(reservedQty.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<String>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WarehouseItemsCompanion(')
          ..write('id: $id, ')
          ..write('warehouseId: $warehouseId, ')
          ..write('itemId: $itemId, ')
          ..write('quantity: $quantity, ')
          ..write('reservedQty: $reservedQty, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class $StockTransfersTable extends StockTransfers
    with TableInfo<$StockTransfersTable, StockTransfer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockTransfersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fromWarehouseIdMeta = const VerificationMeta(
    'fromWarehouseId',
  );
  @override
  late final GeneratedColumn<int> fromWarehouseId = GeneratedColumn<int>(
    'from_warehouse_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES warehouses (id)',
    ),
  );
  static const VerificationMeta _toWarehouseIdMeta = const VerificationMeta(
    'toWarehouseId',
  );
  @override
  late final GeneratedColumn<int> toWarehouseId = GeneratedColumn<int>(
    'to_warehouse_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES warehouses (id)',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<double> qty = GeneratedColumn<double>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant('completed'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fromWarehouseId,
    toWarehouseId,
    itemId,
    qty,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_transfers';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockTransfer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('from_warehouse_id')) {
      context.handle(
        _fromWarehouseIdMeta,
        fromWarehouseId.isAcceptableOrUnknown(
          data['from_warehouse_id']!,
          _fromWarehouseIdMeta,
        ),
      );
    }
    if (data.containsKey('to_warehouse_id')) {
      context.handle(
        _toWarehouseIdMeta,
        toWarehouseId.isAcceptableOrUnknown(
          data['to_warehouse_id']!,
          _toWarehouseIdMeta,
        ),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockTransfer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockTransfer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fromWarehouseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}from_warehouse_id'],
      ),
      toWarehouseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}to_warehouse_id'],
      ),
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}qty'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StockTransfersTable createAlias(String alias) {
    return $StockTransfersTable(attachedDatabase, alias);
  }
}

class StockTransfer extends DataClass implements Insertable<StockTransfer> {
  final int id;
  final int? fromWarehouseId;
  final int? toWarehouseId;
  final int itemId;
  final double qty;
  final String status;
  final String createdAt;
  const StockTransfer({
    required this.id,
    this.fromWarehouseId,
    this.toWarehouseId,
    required this.itemId,
    required this.qty,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || fromWarehouseId != null) {
      map['from_warehouse_id'] = Variable<int>(fromWarehouseId);
    }
    if (!nullToAbsent || toWarehouseId != null) {
      map['to_warehouse_id'] = Variable<int>(toWarehouseId);
    }
    map['item_id'] = Variable<int>(itemId);
    map['qty'] = Variable<double>(qty);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  StockTransfersCompanion toCompanion(bool nullToAbsent) {
    return StockTransfersCompanion(
      id: Value(id),
      fromWarehouseId: fromWarehouseId == null && nullToAbsent
          ? const Value.absent()
          : Value(fromWarehouseId),
      toWarehouseId: toWarehouseId == null && nullToAbsent
          ? const Value.absent()
          : Value(toWarehouseId),
      itemId: Value(itemId),
      qty: Value(qty),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory StockTransfer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockTransfer(
      id: serializer.fromJson<int>(json['id']),
      fromWarehouseId: serializer.fromJson<int?>(json['fromWarehouseId']),
      toWarehouseId: serializer.fromJson<int?>(json['toWarehouseId']),
      itemId: serializer.fromJson<int>(json['itemId']),
      qty: serializer.fromJson<double>(json['qty']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fromWarehouseId': serializer.toJson<int?>(fromWarehouseId),
      'toWarehouseId': serializer.toJson<int?>(toWarehouseId),
      'itemId': serializer.toJson<int>(itemId),
      'qty': serializer.toJson<double>(qty),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  StockTransfer copyWith({
    int? id,
    Value<int?> fromWarehouseId = const Value.absent(),
    Value<int?> toWarehouseId = const Value.absent(),
    int? itemId,
    double? qty,
    String? status,
    String? createdAt,
  }) => StockTransfer(
    id: id ?? this.id,
    fromWarehouseId: fromWarehouseId.present
        ? fromWarehouseId.value
        : this.fromWarehouseId,
    toWarehouseId: toWarehouseId.present
        ? toWarehouseId.value
        : this.toWarehouseId,
    itemId: itemId ?? this.itemId,
    qty: qty ?? this.qty,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  StockTransfer copyWithCompanion(StockTransfersCompanion data) {
    return StockTransfer(
      id: data.id.present ? data.id.value : this.id,
      fromWarehouseId: data.fromWarehouseId.present
          ? data.fromWarehouseId.value
          : this.fromWarehouseId,
      toWarehouseId: data.toWarehouseId.present
          ? data.toWarehouseId.value
          : this.toWarehouseId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      qty: data.qty.present ? data.qty.value : this.qty,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockTransfer(')
          ..write('id: $id, ')
          ..write('fromWarehouseId: $fromWarehouseId, ')
          ..write('toWarehouseId: $toWarehouseId, ')
          ..write('itemId: $itemId, ')
          ..write('qty: $qty, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fromWarehouseId,
    toWarehouseId,
    itemId,
    qty,
    status,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockTransfer &&
          other.id == this.id &&
          other.fromWarehouseId == this.fromWarehouseId &&
          other.toWarehouseId == this.toWarehouseId &&
          other.itemId == this.itemId &&
          other.qty == this.qty &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class StockTransfersCompanion extends UpdateCompanion<StockTransfer> {
  final Value<int> id;
  final Value<int?> fromWarehouseId;
  final Value<int?> toWarehouseId;
  final Value<int> itemId;
  final Value<double> qty;
  final Value<String> status;
  final Value<String> createdAt;
  const StockTransfersCompanion({
    this.id = const Value.absent(),
    this.fromWarehouseId = const Value.absent(),
    this.toWarehouseId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.qty = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  StockTransfersCompanion.insert({
    this.id = const Value.absent(),
    this.fromWarehouseId = const Value.absent(),
    this.toWarehouseId = const Value.absent(),
    required int itemId,
    required double qty,
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : itemId = Value(itemId),
       qty = Value(qty);
  static Insertable<StockTransfer> custom({
    Expression<int>? id,
    Expression<int>? fromWarehouseId,
    Expression<int>? toWarehouseId,
    Expression<int>? itemId,
    Expression<double>? qty,
    Expression<String>? status,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fromWarehouseId != null) 'from_warehouse_id': fromWarehouseId,
      if (toWarehouseId != null) 'to_warehouse_id': toWarehouseId,
      if (itemId != null) 'item_id': itemId,
      if (qty != null) 'qty': qty,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  StockTransfersCompanion copyWith({
    Value<int>? id,
    Value<int?>? fromWarehouseId,
    Value<int?>? toWarehouseId,
    Value<int>? itemId,
    Value<double>? qty,
    Value<String>? status,
    Value<String>? createdAt,
  }) {
    return StockTransfersCompanion(
      id: id ?? this.id,
      fromWarehouseId: fromWarehouseId ?? this.fromWarehouseId,
      toWarehouseId: toWarehouseId ?? this.toWarehouseId,
      itemId: itemId ?? this.itemId,
      qty: qty ?? this.qty,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fromWarehouseId.present) {
      map['from_warehouse_id'] = Variable<int>(fromWarehouseId.value);
    }
    if (toWarehouseId.present) {
      map['to_warehouse_id'] = Variable<int>(toWarehouseId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (qty.present) {
      map['qty'] = Variable<double>(qty.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockTransfersCompanion(')
          ..write('id: $id, ')
          ..write('fromWarehouseId: $fromWarehouseId, ')
          ..write('toWarehouseId: $toWarehouseId, ')
          ..write('itemId: $itemId, ')
          ..write('qty: $qty, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$WarehouseDb extends GeneratedDatabase {
  _$WarehouseDb(QueryExecutor e) : super(e);
  $WarehouseDbManager get managers => $WarehouseDbManager(this);
  late final $WarehousesTable warehouses = $WarehousesTable(this);
  late final $WarehouseItemsTable warehouseItems = $WarehouseItemsTable(this);
  late final $StockTransfersTable stockTransfers = $StockTransfersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    warehouses,
    warehouseItems,
    stockTransfers,
  ];
}

typedef $$WarehousesTableCreateCompanionBuilder =
    WarehousesCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> code,
      Value<String?> location,
      Value<String> createdAt,
    });
typedef $$WarehousesTableUpdateCompanionBuilder =
    WarehousesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> code,
      Value<String?> location,
      Value<String> createdAt,
    });

final class $$WarehousesTableReferences
    extends BaseReferences<_$WarehouseDb, $WarehousesTable, Warehouse> {
  $$WarehousesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WarehouseItemsTable, List<WarehouseItem>>
  _warehouseItemsRefsTable(_$WarehouseDb db) => MultiTypedResultKey.fromTable(
    db.warehouseItems,
    aliasName: $_aliasNameGenerator(
      db.warehouses.id,
      db.warehouseItems.warehouseId,
    ),
  );

  $$WarehouseItemsTableProcessedTableManager get warehouseItemsRefs {
    final manager = $$WarehouseItemsTableTableManager(
      $_db,
      $_db.warehouseItems,
    ).filter((f) => f.warehouseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_warehouseItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WarehousesTableFilterComposer
    extends Composer<_$WarehouseDb, $WarehousesTable> {
  $$WarehousesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> warehouseItemsRefs(
    Expression<bool> Function($$WarehouseItemsTableFilterComposer f) f,
  ) {
    final $$WarehouseItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.warehouseItems,
      getReferencedColumn: (t) => t.warehouseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WarehouseItemsTableFilterComposer(
            $db: $db,
            $table: $db.warehouseItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WarehousesTableOrderingComposer
    extends Composer<_$WarehouseDb, $WarehousesTable> {
  $$WarehousesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WarehousesTableAnnotationComposer
    extends Composer<_$WarehouseDb, $WarehousesTable> {
  $$WarehousesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> warehouseItemsRefs<T extends Object>(
    Expression<T> Function($$WarehouseItemsTableAnnotationComposer a) f,
  ) {
    final $$WarehouseItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.warehouseItems,
      getReferencedColumn: (t) => t.warehouseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WarehouseItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.warehouseItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WarehousesTableTableManager
    extends
        RootTableManager<
          _$WarehouseDb,
          $WarehousesTable,
          Warehouse,
          $$WarehousesTableFilterComposer,
          $$WarehousesTableOrderingComposer,
          $$WarehousesTableAnnotationComposer,
          $$WarehousesTableCreateCompanionBuilder,
          $$WarehousesTableUpdateCompanionBuilder,
          (Warehouse, $$WarehousesTableReferences),
          Warehouse,
          PrefetchHooks Function({bool warehouseItemsRefs})
        > {
  $$WarehousesTableTableManager(_$WarehouseDb db, $WarehousesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WarehousesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WarehousesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WarehousesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
              }) => WarehousesCompanion(
                id: id,
                name: name,
                code: code,
                location: location,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> code = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
              }) => WarehousesCompanion.insert(
                id: id,
                name: name,
                code: code,
                location: location,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WarehousesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({warehouseItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (warehouseItemsRefs) db.warehouseItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (warehouseItemsRefs)
                    await $_getPrefetchedData<
                      Warehouse,
                      $WarehousesTable,
                      WarehouseItem
                    >(
                      currentTable: table,
                      referencedTable: $$WarehousesTableReferences
                          ._warehouseItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WarehousesTableReferences(
                            db,
                            table,
                            p0,
                          ).warehouseItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.warehouseId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WarehousesTableProcessedTableManager =
    ProcessedTableManager<
      _$WarehouseDb,
      $WarehousesTable,
      Warehouse,
      $$WarehousesTableFilterComposer,
      $$WarehousesTableOrderingComposer,
      $$WarehousesTableAnnotationComposer,
      $$WarehousesTableCreateCompanionBuilder,
      $$WarehousesTableUpdateCompanionBuilder,
      (Warehouse, $$WarehousesTableReferences),
      Warehouse,
      PrefetchHooks Function({bool warehouseItemsRefs})
    >;
typedef $$WarehouseItemsTableCreateCompanionBuilder =
    WarehouseItemsCompanion Function({
      Value<int> id,
      required int warehouseId,
      required int itemId,
      Value<double> quantity,
      Value<double> reservedQty,
      Value<String> lastUpdated,
    });
typedef $$WarehouseItemsTableUpdateCompanionBuilder =
    WarehouseItemsCompanion Function({
      Value<int> id,
      Value<int> warehouseId,
      Value<int> itemId,
      Value<double> quantity,
      Value<double> reservedQty,
      Value<String> lastUpdated,
    });

final class $$WarehouseItemsTableReferences
    extends BaseReferences<_$WarehouseDb, $WarehouseItemsTable, WarehouseItem> {
  $$WarehouseItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WarehousesTable _warehouseIdTable(_$WarehouseDb db) =>
      db.warehouses.createAlias(
        $_aliasNameGenerator(db.warehouseItems.warehouseId, db.warehouses.id),
      );

  $$WarehousesTableProcessedTableManager get warehouseId {
    final $_column = $_itemColumn<int>('warehouse_id')!;

    final manager = $$WarehousesTableTableManager(
      $_db,
      $_db.warehouses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_warehouseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WarehouseItemsTableFilterComposer
    extends Composer<_$WarehouseDb, $WarehouseItemsTable> {
  $$WarehouseItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get reservedQty => $composableBuilder(
    column: $table.reservedQty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );

  $$WarehousesTableFilterComposer get warehouseId {
    final $$WarehousesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.warehouseId,
      referencedTable: $db.warehouses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WarehousesTableFilterComposer(
            $db: $db,
            $table: $db.warehouses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WarehouseItemsTableOrderingComposer
    extends Composer<_$WarehouseDb, $WarehouseItemsTable> {
  $$WarehouseItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get reservedQty => $composableBuilder(
    column: $table.reservedQty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );

  $$WarehousesTableOrderingComposer get warehouseId {
    final $$WarehousesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.warehouseId,
      referencedTable: $db.warehouses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WarehousesTableOrderingComposer(
            $db: $db,
            $table: $db.warehouses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WarehouseItemsTableAnnotationComposer
    extends Composer<_$WarehouseDb, $WarehouseItemsTable> {
  $$WarehouseItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get reservedQty => $composableBuilder(
    column: $table.reservedQty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );

  $$WarehousesTableAnnotationComposer get warehouseId {
    final $$WarehousesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.warehouseId,
      referencedTable: $db.warehouses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WarehousesTableAnnotationComposer(
            $db: $db,
            $table: $db.warehouses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WarehouseItemsTableTableManager
    extends
        RootTableManager<
          _$WarehouseDb,
          $WarehouseItemsTable,
          WarehouseItem,
          $$WarehouseItemsTableFilterComposer,
          $$WarehouseItemsTableOrderingComposer,
          $$WarehouseItemsTableAnnotationComposer,
          $$WarehouseItemsTableCreateCompanionBuilder,
          $$WarehouseItemsTableUpdateCompanionBuilder,
          (WarehouseItem, $$WarehouseItemsTableReferences),
          WarehouseItem,
          PrefetchHooks Function({bool warehouseId})
        > {
  $$WarehouseItemsTableTableManager(
    _$WarehouseDb db,
    $WarehouseItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WarehouseItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WarehouseItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WarehouseItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> warehouseId = const Value.absent(),
                Value<int> itemId = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<double> reservedQty = const Value.absent(),
                Value<String> lastUpdated = const Value.absent(),
              }) => WarehouseItemsCompanion(
                id: id,
                warehouseId: warehouseId,
                itemId: itemId,
                quantity: quantity,
                reservedQty: reservedQty,
                lastUpdated: lastUpdated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int warehouseId,
                required int itemId,
                Value<double> quantity = const Value.absent(),
                Value<double> reservedQty = const Value.absent(),
                Value<String> lastUpdated = const Value.absent(),
              }) => WarehouseItemsCompanion.insert(
                id: id,
                warehouseId: warehouseId,
                itemId: itemId,
                quantity: quantity,
                reservedQty: reservedQty,
                lastUpdated: lastUpdated,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WarehouseItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({warehouseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (warehouseId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.warehouseId,
                                referencedTable: $$WarehouseItemsTableReferences
                                    ._warehouseIdTable(db),
                                referencedColumn:
                                    $$WarehouseItemsTableReferences
                                        ._warehouseIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WarehouseItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$WarehouseDb,
      $WarehouseItemsTable,
      WarehouseItem,
      $$WarehouseItemsTableFilterComposer,
      $$WarehouseItemsTableOrderingComposer,
      $$WarehouseItemsTableAnnotationComposer,
      $$WarehouseItemsTableCreateCompanionBuilder,
      $$WarehouseItemsTableUpdateCompanionBuilder,
      (WarehouseItem, $$WarehouseItemsTableReferences),
      WarehouseItem,
      PrefetchHooks Function({bool warehouseId})
    >;
typedef $$StockTransfersTableCreateCompanionBuilder =
    StockTransfersCompanion Function({
      Value<int> id,
      Value<int?> fromWarehouseId,
      Value<int?> toWarehouseId,
      required int itemId,
      required double qty,
      Value<String> status,
      Value<String> createdAt,
    });
typedef $$StockTransfersTableUpdateCompanionBuilder =
    StockTransfersCompanion Function({
      Value<int> id,
      Value<int?> fromWarehouseId,
      Value<int?> toWarehouseId,
      Value<int> itemId,
      Value<double> qty,
      Value<String> status,
      Value<String> createdAt,
    });

final class $$StockTransfersTableReferences
    extends BaseReferences<_$WarehouseDb, $StockTransfersTable, StockTransfer> {
  $$StockTransfersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WarehousesTable _fromWarehouseIdTable(_$WarehouseDb db) =>
      db.warehouses.createAlias(
        $_aliasNameGenerator(
          db.stockTransfers.fromWarehouseId,
          db.warehouses.id,
        ),
      );

  $$WarehousesTableProcessedTableManager? get fromWarehouseId {
    final $_column = $_itemColumn<int>('from_warehouse_id');
    if ($_column == null) return null;
    final manager = $$WarehousesTableTableManager(
      $_db,
      $_db.warehouses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fromWarehouseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WarehousesTable _toWarehouseIdTable(_$WarehouseDb db) =>
      db.warehouses.createAlias(
        $_aliasNameGenerator(db.stockTransfers.toWarehouseId, db.warehouses.id),
      );

  $$WarehousesTableProcessedTableManager? get toWarehouseId {
    final $_column = $_itemColumn<int>('to_warehouse_id');
    if ($_column == null) return null;
    final manager = $$WarehousesTableTableManager(
      $_db,
      $_db.warehouses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_toWarehouseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StockTransfersTableFilterComposer
    extends Composer<_$WarehouseDb, $StockTransfersTable> {
  $$StockTransfersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WarehousesTableFilterComposer get fromWarehouseId {
    final $$WarehousesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromWarehouseId,
      referencedTable: $db.warehouses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WarehousesTableFilterComposer(
            $db: $db,
            $table: $db.warehouses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WarehousesTableFilterComposer get toWarehouseId {
    final $$WarehousesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toWarehouseId,
      referencedTable: $db.warehouses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WarehousesTableFilterComposer(
            $db: $db,
            $table: $db.warehouses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockTransfersTableOrderingComposer
    extends Composer<_$WarehouseDb, $StockTransfersTable> {
  $$StockTransfersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WarehousesTableOrderingComposer get fromWarehouseId {
    final $$WarehousesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromWarehouseId,
      referencedTable: $db.warehouses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WarehousesTableOrderingComposer(
            $db: $db,
            $table: $db.warehouses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WarehousesTableOrderingComposer get toWarehouseId {
    final $$WarehousesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toWarehouseId,
      referencedTable: $db.warehouses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WarehousesTableOrderingComposer(
            $db: $db,
            $table: $db.warehouses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockTransfersTableAnnotationComposer
    extends Composer<_$WarehouseDb, $StockTransfersTable> {
  $$StockTransfersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<double> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$WarehousesTableAnnotationComposer get fromWarehouseId {
    final $$WarehousesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromWarehouseId,
      referencedTable: $db.warehouses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WarehousesTableAnnotationComposer(
            $db: $db,
            $table: $db.warehouses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WarehousesTableAnnotationComposer get toWarehouseId {
    final $$WarehousesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toWarehouseId,
      referencedTable: $db.warehouses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WarehousesTableAnnotationComposer(
            $db: $db,
            $table: $db.warehouses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockTransfersTableTableManager
    extends
        RootTableManager<
          _$WarehouseDb,
          $StockTransfersTable,
          StockTransfer,
          $$StockTransfersTableFilterComposer,
          $$StockTransfersTableOrderingComposer,
          $$StockTransfersTableAnnotationComposer,
          $$StockTransfersTableCreateCompanionBuilder,
          $$StockTransfersTableUpdateCompanionBuilder,
          (StockTransfer, $$StockTransfersTableReferences),
          StockTransfer,
          PrefetchHooks Function({bool fromWarehouseId, bool toWarehouseId})
        > {
  $$StockTransfersTableTableManager(
    _$WarehouseDb db,
    $StockTransfersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockTransfersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockTransfersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockTransfersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> fromWarehouseId = const Value.absent(),
                Value<int?> toWarehouseId = const Value.absent(),
                Value<int> itemId = const Value.absent(),
                Value<double> qty = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
              }) => StockTransfersCompanion(
                id: id,
                fromWarehouseId: fromWarehouseId,
                toWarehouseId: toWarehouseId,
                itemId: itemId,
                qty: qty,
                status: status,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> fromWarehouseId = const Value.absent(),
                Value<int?> toWarehouseId = const Value.absent(),
                required int itemId,
                required double qty,
                Value<String> status = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
              }) => StockTransfersCompanion.insert(
                id: id,
                fromWarehouseId: fromWarehouseId,
                toWarehouseId: toWarehouseId,
                itemId: itemId,
                qty: qty,
                status: status,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StockTransfersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({fromWarehouseId = false, toWarehouseId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (fromWarehouseId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.fromWarehouseId,
                                    referencedTable:
                                        $$StockTransfersTableReferences
                                            ._fromWarehouseIdTable(db),
                                    referencedColumn:
                                        $$StockTransfersTableReferences
                                            ._fromWarehouseIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (toWarehouseId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.toWarehouseId,
                                    referencedTable:
                                        $$StockTransfersTableReferences
                                            ._toWarehouseIdTable(db),
                                    referencedColumn:
                                        $$StockTransfersTableReferences
                                            ._toWarehouseIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$StockTransfersTableProcessedTableManager =
    ProcessedTableManager<
      _$WarehouseDb,
      $StockTransfersTable,
      StockTransfer,
      $$StockTransfersTableFilterComposer,
      $$StockTransfersTableOrderingComposer,
      $$StockTransfersTableAnnotationComposer,
      $$StockTransfersTableCreateCompanionBuilder,
      $$StockTransfersTableUpdateCompanionBuilder,
      (StockTransfer, $$StockTransfersTableReferences),
      StockTransfer,
      PrefetchHooks Function({bool fromWarehouseId, bool toWarehouseId})
    >;

class $WarehouseDbManager {
  final _$WarehouseDb _db;
  $WarehouseDbManager(this._db);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db, _db.warehouses);
  $$WarehouseItemsTableTableManager get warehouseItems =>
      $$WarehouseItemsTableTableManager(_db, _db.warehouseItems);
  $$StockTransfersTableTableManager get stockTransfers =>
      $$StockTransfersTableTableManager(_db, _db.stockTransfers);
}
