class QuotationModel {
  final int? id;
  final String quotationNumber;
  final int? customerId;
  final String? customerName;
  final String quotationDate;
  final String? expiryDate;
  final String? taxType;
  final String? discountType;
  final double discountValue;
  final double discountAmount;
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final String status; // 'draft' | 'sent' | 'accepted' | 'rejected' | 'converted'
  final String? notes;
  final String? createdAt;

  const QuotationModel({
    this.id,
    required this.quotationNumber,
    this.customerId,
    this.customerName,
    required this.quotationDate,
    this.expiryDate,
    this.taxType = 'exclusive',
    this.discountType = 'none',
    this.discountValue = 0,
    this.discountAmount = 0,
    required this.subtotal,
    required this.gstAmount,
    required this.totalAmount,
    this.status = 'draft',
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'quotation_number': quotationNumber,
        'customer_id': customerId,
        'customer_name': customerName,
        'quotation_date': quotationDate,
        'expiry_date': expiryDate,
        'tax_type': taxType,
        'discount_type': discountType,
        'discount_value': discountValue,
        'discount_amount': discountAmount,
        'subtotal': subtotal,
        'gst_amount': gstAmount,
        'total_amount': totalAmount,
        'status': status,
        'notes': notes,
        'created_at': createdAt,
      };

  factory QuotationModel.fromMap(Map<String, dynamic> m) => QuotationModel(
        id: m['id'] as int?,
        quotationNumber: m['quotation_number'] as String? ?? '',
        customerId: m['customer_id'] as int?,
        customerName: m['customer_name'] as String?,
        quotationDate: m['quotation_date'] as String? ?? '',
        expiryDate: m['expiry_date'] as String?,
        taxType: m['tax_type'] as String? ?? 'exclusive',
        discountType: m['discount_type'] as String? ?? 'none',
        discountValue: (m['discount_value'] as num?)?.toDouble() ?? 0,
        discountAmount: (m['discount_amount'] as num?)?.toDouble() ?? 0,
        subtotal: (m['subtotal'] as num?)?.toDouble() ?? 0,
        gstAmount: (m['gst_amount'] as num?)?.toDouble() ?? 0,
        totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0,
        status: m['status'] as String? ?? 'draft',
        notes: m['notes'] as String?,
        createdAt: m['created_at'] as String?,
      );

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.tryParse(expiryDate!)?.isBefore(DateTime.now()) ?? false;
  }

  bool get isConverted => status == 'converted';
}

class QuotationItemModel {
  final int? id;
  final int quotationId;
  final int? itemId;
  final String itemName;
  final double qty;
  final double unitPrice;
  final double discountAmount;
  final double taxRate;
  final double taxAmount;
  final double lineTotal;

  const QuotationItemModel({
    this.id,
    required this.quotationId,
    this.itemId,
    required this.itemName,
    required this.qty,
    required this.unitPrice,
    this.discountAmount = 0,
    this.taxRate = 0,
    this.taxAmount = 0,
    required this.lineTotal,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'quotation_id': quotationId,
        'item_id': itemId,
        'item_name': itemName,
        'qty': qty,
        'unit_price': unitPrice,
        'discount_amount': discountAmount,
        'tax_rate': taxRate,
        'tax_amount': taxAmount,
        'line_total': lineTotal,
      };

  factory QuotationItemModel.fromMap(Map<String, dynamic> m) =>
      QuotationItemModel(
        id: m['id'] as int?,
        quotationId: m['quotation_id'] as int? ?? 0,
        itemId: m['item_id'] as int?,
        itemName: m['item_name'] as String? ?? '',
        qty: (m['qty'] as num?)?.toDouble() ?? 0,
        unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0,
        discountAmount: (m['discount_amount'] as num?)?.toDouble() ?? 0,
        taxRate: (m['tax_rate'] as num?)?.toDouble() ?? 0,
        taxAmount: (m['tax_amount'] as num?)?.toDouble() ?? 0,
        lineTotal: (m['line_total'] as num?)?.toDouble() ?? 0,
      );
}
