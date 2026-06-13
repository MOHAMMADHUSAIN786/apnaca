class ItemModel {
  final int? id;
  final String name;
  final int? qty;
  final double? price;
  final String? hsnCode;
  final String? barcode;

  const ItemModel({
    this.id,
    required this.name,
    this.qty,
    this.price,
    this.hsnCode,
    this.barcode,
  });

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      qty: map['qty'] as int?,
      price: map['price'] as double?,
      hsnCode: map['hsn_code'] as String?,
      barcode: map['barcode'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'qty': qty,
      'price': price,
      'hsn_code': hsnCode,
      'barcode': barcode,
    };
  }

  ItemModel copyWith({
    int? id,
    String? name,
    int? qty,
    double? price,
    String? hsnCode,
    String? barcode,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      hsnCode: hsnCode ?? this.hsnCode,
      barcode: barcode ?? this.barcode,
    );
  }
}
