// lib/features/sale/model/sale_bill_model.dart
class SaleBillModel {
  final int id;
  final String billNumber;
  final int? customerId;
  final String customerName;
  final String billDate;
  final String? dueDate;
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final String paymentMode;
  final String paymentStatus;
  final String? notes;
  final String? createdAt;

  SaleBillModel({
    required this.id,
    required this.billNumber,
    this.customerId,
    required this.customerName,
    required this.billDate,
    this.dueDate,
    required this.subtotal,
    required this.gstAmount,
    required this.totalAmount,
    required this.paymentMode,
    required this.paymentStatus,
    this.notes,
    this.createdAt,
  });

  factory SaleBillModel.fromMap(Map<String, dynamic> map) {
    return SaleBillModel(
      id: map['id'] as int,
      billNumber: map['bill_number'] as String,
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String? ?? 'Walk-in Customer',
      billDate: map['bill_date'] as String,
      dueDate: map['due_date'] as String?,
      subtotal: (map['subtotal'] as num).toDouble(),
      gstAmount: (map['gst_amount'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      paymentMode: map['payment_mode'] as String? ?? 'cash',
      paymentStatus: map['payment_status'] as String? ?? 'paid',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }
}