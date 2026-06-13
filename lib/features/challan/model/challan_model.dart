class ChallanModel {
  final int? id;
  final String challanNumber;
  final int? customerId;
  final String challanDate;
  final String? driverName;
  final String? vehicleNumber;
  final String status; // 'pending', 'delivered', 'converted'
  final String? notes;
  final String? createdAt;

  ChallanModel({
    this.id,
    required this.challanNumber,
    this.customerId,
    required this.challanDate,
    this.driverName,
    this.vehicleNumber,
    this.status = 'pending',
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'challan_number': challanNumber,
      'customer_id': customerId,
      'challan_date': challanDate,
      'driver_name': driverName,
      'vehicle_number': vehicleNumber,
      'status': status,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  factory ChallanModel.fromMap(Map<String, dynamic> map) {
    return ChallanModel(
      id: map['id'],
      challanNumber: map['challan_number'],
      customerId: map['customer_id'],
      challanDate: map['challan_date'],
      driverName: map['driver_name'],
      vehicleNumber: map['vehicle_number'],
      status: map['status'] ?? 'pending',
      notes: map['notes'],
      createdAt: map['created_at'],
    );
  }
}

class ChallanItemModel {
  final int? id;
  final int challanId;
  final int? itemId;
  final String itemName;
  final double qty;

  ChallanItemModel({
    this.id,
    required this.challanId,
    this.itemId,
    required this.itemName,
    required this.qty,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'challan_id': challanId,
      'item_id': itemId,
      'item_name': itemName,
      'qty': qty,
    };
  }

  factory ChallanItemModel.fromMap(Map<String, dynamic> map) {
    return ChallanItemModel(
      id: map['id'],
      challanId: map['challan_id'],
      itemId: map['item_id'],
      itemName: map['item_name'],
      qty: (map['qty'] as num).toDouble(),
    );
  }
}
