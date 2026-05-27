/// Tracks partial bill creation state across multiple conversation turns.
/// Lives in ChatBloc memory — resets when bill is created or chat is cleared.
class BillCreationState {
  final String? customerName;
  final List<Map<String, dynamic>> items;
  final String? discountType;   // 'percent' | 'amount' | 'none'
  final double? discountValue;
  final String? taxType;        // 'inclusive' | 'exclusive'
  final double taxRate;
  final String? paymentMode;
  final String? paymentStatus;
  final BillStep step;

  const BillCreationState({
    this.customerName,
    this.items = const [],
    this.discountType,
    this.discountValue,
    this.taxType,
    this.taxRate = 0.0,
    this.paymentMode,
    this.paymentStatus,
    this.step = BillStep.idle,
  });

  bool get isActive => step != BillStep.idle;
  bool get isReady => step == BillStep.ready;

  BillCreationState copyWith({
    String? customerName,
    List<Map<String, dynamic>>? items,
    String? discountType,
    double? discountValue,
    String? taxType,
    double? taxRate,
    String? paymentMode,
    String? paymentStatus,
    BillStep? step,
  }) =>
      BillCreationState(
        customerName: customerName ?? this.customerName,
        items: items ?? this.items,
        discountType: discountType ?? this.discountType,
        discountValue: discountValue ?? this.discountValue,
        taxType: taxType ?? this.taxType,
        taxRate: taxRate ?? this.taxRate,
        paymentMode: paymentMode ?? this.paymentMode,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        step: step ?? this.step,
      );

  static const BillCreationState empty =
  BillCreationState(step: BillStep.idle);
}

enum BillStep {
  idle,
  collectingItems,
  askingDiscount,    // "Discount dena hai? haan/nahi"
  collectingDiscount,// "Kitna discount?"
  askingTax,
  askingPayment,
  ready,
}
