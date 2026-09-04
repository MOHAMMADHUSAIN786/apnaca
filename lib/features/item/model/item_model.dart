class ItemModel {
  final int? id;
  final String name;
  final int? qty;
  final double? price;
  final String? hsnCode;

  // ── Inventory Management fields ──────────────────────────────
  final String? sku;
  final int? minStockAlert;
  final double? purchasePrice;

  const ItemModel({
    this.id,
    required this.name,
    this.qty,
    this.price,
    this.hsnCode,
    this.sku,
    this.minStockAlert,
    this.purchasePrice,
  });

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      qty: map['qty'] as int?,
      price: (map['price'] as num?)?.toDouble(),
      hsnCode: map['hsn_code'] as String?,
      sku: map['sku'] as String?,
      minStockAlert: map['min_stock_alert'] as int?,
      purchasePrice: (map['purchase_price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'qty': qty,
      'price': price,
      'hsn_code': hsnCode,
      'sku': sku,
      'min_stock_alert': minStockAlert,
      'purchase_price': purchasePrice,
    };
  }

  /// Current Inventory Value = Current Stock × Purchase Price
  /// (falls back to selling price if purchase price not set)
  double get inventoryValue => (qty ?? 0) * (purchasePrice ?? price ?? 0);

  /// Whether this item is below its low-stock threshold.
  /// Falls back to 5 if min_stock_alert is not set / 0.
  bool get isLowStock {
    final threshold = (minStockAlert == null || minStockAlert == 0) ? 5 : minStockAlert!;
    return (qty ?? 0) <= threshold;
  }

  ItemModel copyWith({
    int? id,
    String? name,
    int? qty,
    double? price,
    String? hsnCode,
    String? sku,
    int? minStockAlert,
    double? purchasePrice,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      hsnCode: hsnCode ?? this.hsnCode,
      sku: sku ?? this.sku,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      purchasePrice: purchasePrice ?? this.purchasePrice,
    );
  }
}
