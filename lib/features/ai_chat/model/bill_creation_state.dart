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

  // ── Logo & Signature branding ─────────────────────────────────────────────
  /// null  = not yet checked from Firebase Storage
  /// ''    = checked and NOT found in Storage (first time user)
  /// 'url' = Firebase Storage download URL (already uploaded)
  final String? companyLogoUrl;
  final String? signatureUrl;

  /// Whether user said "nahi" to branding question this session
  final bool brandingSkipped;

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
    this.companyLogoUrl,
    this.signatureUrl,
    this.brandingSkipped = false,
  });

  bool get isActive => step != BillStep.idle;
  bool get isReady  => step == BillStep.ready;

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
    String? companyLogoUrl,
    String? signatureUrl,
    bool? brandingSkipped,
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
        companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
        signatureUrl: signatureUrl ?? this.signatureUrl,
        brandingSkipped: brandingSkipped ?? this.brandingSkipped,
      );

  static const BillCreationState empty = BillCreationState(step: BillStep.idle);
}

enum BillStep {
  idle,
  collectingItems,
  askingDiscount,       // "Discount dena hai? haan/nahi"
  collectingDiscount,   // "Kitna discount?"
  askingTax,
  askingPayment,
  askingBranding,       // "Kya aap logo/signature add karna chahte hain?"
  collectingLogo,       // Waiting for logo image upload
  collectingSignature,  // Waiting for signature image upload
  ready,
}
