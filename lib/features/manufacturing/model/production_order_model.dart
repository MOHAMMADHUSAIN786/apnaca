class ProductionOrderModel {
  final int? id;
  final String orderNumber;
  final int bomId;
  final double qtyToProduce;
  final String status; // 'pending', 'completed', 'cancelled'
  final String orderDate;
  final String? notes;
  final String? createdAt;

  ProductionOrderModel({
    this.id,
    required this.orderNumber,
    required this.bomId,
    required this.qtyToProduce,
    this.status = 'pending',
    required this.orderDate,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_number': orderNumber,
      'bom_id': bomId,
      'qty_to_produce': qtyToProduce,
      'status': status,
      'order_date': orderDate,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  factory ProductionOrderModel.fromMap(Map<String, dynamic> map) {
    return ProductionOrderModel(
      id: map['id'],
      orderNumber: map['order_number'],
      bomId: map['bom_id'],
      qtyToProduce: (map['qty_to_produce'] as num).toDouble(),
      status: map['status'] ?? 'pending',
      orderDate: map['order_date'],
      notes: map['notes'],
      createdAt: map['created_at'],
    );
  }
}
