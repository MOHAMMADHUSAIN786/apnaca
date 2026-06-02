// lib/features/subscription/model/subscription_model.dart

enum SubscriptionPlan { free, silver, gold }

enum BillingCycle { monthly, yearly }

class SubscriptionModel {
  final SubscriptionPlan plan;
  final DateTime? expiryDate;
  final BillingCycle? billingCycle;

  // Monthly usage counters (reset each month — Silver/Gold tracking only)
  // For FREE plan: these are LIFETIME counters — never reset
  final int saleBillsUsedThisMonth;
  final int purchaseBillsUsedThisMonth;
  final int customersCount;
  final int itemsCount;

  // Daily usage counters (reset each day)
  final int aiPromptsUsedToday;
  final DateTime? aiPromptsResetDate;

  // Company count
  final int companiesCount;

  const SubscriptionModel({
    required this.plan,
    this.expiryDate,
    this.billingCycle,
    this.saleBillsUsedThisMonth = 0,
    this.purchaseBillsUsedThisMonth = 0,
    this.customersCount = 0,
    this.itemsCount = 0,
    this.aiPromptsUsedToday = 0,
    this.aiPromptsResetDate,
    this.companiesCount = 1,
  });

  // ─────────────────────────────────────────────
  //  FREE PLAN LIMITS (bills = LIFETIME, never reset)
  // ─────────────────────────────────────────────
  static const int freeMaxCustomers = 50;
  static const int freeMaxItems = 50;
  static const int freeMaxSaleBills = 10;       // lifetime, no reset
  static const int freeMaxPurchaseBills = 10;   // lifetime, no reset
  static const int freeMaxAiPromptsPerDay = 10;
  static const int freeMaxCompanies = 1;

  // ─────────────────────────────────────────────
  //  SILVER PLAN LIMITS
  // ─────────────────────────────────────────────
  static const int silverMaxAiPromptsPerDay = 100;
  // Unlimited: customers, items, bills, 1 company

  // ─────────────────────────────────────────────
  //  GOLD PLAN LIMITS
  // ─────────────────────────────────────────────
  // Unlimited AI prompts (fair use), multi-user, multi-company

  // ─────────────────────────────────────────────
  //  PRICING
  // ─────────────────────────────────────────────
  static const int silverMonthlyPriceRs = 99;
  static const int silverYearlyPriceRs = 999;
  static const int goldMonthlyPriceRs = 299;
  static const int goldYearlyPriceRs = 2999;

  // ─────────────────────────────────────────────
  //  ACTIVE CHECK
  // ─────────────────────────────────────────────
  bool get isActive {
    if (plan == SubscriptionPlan.free) return true;
    if (expiryDate == null) return false;
    return DateTime.now().isBefore(expiryDate!);
  }

  // ─────────────────────────────────────────────
  //  AI PROMPTS
  // ─────────────────────────────────────────────
  bool get _isAiResetDue {
    if (aiPromptsResetDate == null) return true;
    final now = DateTime.now();
    final reset = aiPromptsResetDate!;
    return now.year != reset.year || now.month != reset.month || now.day != reset.day;
  }

  int get effectiveAiPromptsUsedToday => _isAiResetDue ? 0 : aiPromptsUsedToday;

  bool get canUseAiPrompt {
    if (!isActive) return false;
    if (plan == SubscriptionPlan.gold) return true; // unlimited (fair use)
    final used = effectiveAiPromptsUsedToday;
    if (plan == SubscriptionPlan.silver) return used < silverMaxAiPromptsPerDay;
    return used < freeMaxAiPromptsPerDay; // free
  }

  int get remainingAiPromptsToday {
    if (plan == SubscriptionPlan.gold) return -1; // unlimited
    final used = effectiveAiPromptsUsedToday;
    if (plan == SubscriptionPlan.silver) {
      final r = silverMaxAiPromptsPerDay - used;
      return r < 0 ? 0 : r;
    }
    final r = freeMaxAiPromptsPerDay - used;
    return r < 0 ? 0 : r;
  }

  // ─────────────────────────────────────────────
  //  SALE BILLS (free = lifetime, no reset)
  // ─────────────────────────────────────────────
  bool get canCreateSaleBill {
    if (!isActive) return false;
    if (plan != SubscriptionPlan.free) return true;
    return saleBillsUsedThisMonth < freeMaxSaleBills;
  }

  int get remainingSaleBills {
    if (plan != SubscriptionPlan.free) return -1; // unlimited
    final r = freeMaxSaleBills - saleBillsUsedThisMonth;
    return r < 0 ? 0 : r;
  }

  // ─────────────────────────────────────────────
  //  PURCHASE BILLS (free = lifetime, no reset)
  // ─────────────────────────────────────────────
  bool get canCreatePurchaseBill {
    if (!isActive) return false;
    if (plan != SubscriptionPlan.free) return true;
    return purchaseBillsUsedThisMonth < freeMaxPurchaseBills;
  }

  int get remainingPurchaseBills {
    if (plan != SubscriptionPlan.free) return -1;
    final r = freeMaxPurchaseBills - purchaseBillsUsedThisMonth;
    return r < 0 ? 0 : r;
  }

  // ─────────────────────────────────────────────
  //  CUSTOMERS
  // ─────────────────────────────────────────────
  bool get canAddCustomer {
    if (!isActive) return false;
    if (plan != SubscriptionPlan.free) return true;
    return customersCount < freeMaxCustomers;
  }

  int get remainingCustomers {
    if (plan != SubscriptionPlan.free) return -1;
    final r = freeMaxCustomers - customersCount;
    return r < 0 ? 0 : r;
  }

  // ─────────────────────────────────────────────
  //  ITEMS
  // ─────────────────────────────────────────────
  bool get canAddItem {
    if (!isActive) return false;
    if (plan != SubscriptionPlan.free) return true;
    return itemsCount < freeMaxItems;
  }

  int get remainingItems {
    if (plan != SubscriptionPlan.free) return -1;
    final r = freeMaxItems - itemsCount;
    return r < 0 ? 0 : r;
  }

  // ─────────────────────────────────────────────
  //  COMPANIES
  // ─────────────────────────────────────────────
  bool get canAddCompany {
    if (!isActive) return false;
    if (plan == SubscriptionPlan.gold) return true; // multi-company
    return companiesCount < freeMaxCompanies; // free & silver: 1 company
  }

  bool get hasMultiUser => plan == SubscriptionPlan.gold && isActive;
  bool get hasMultiCompany => plan == SubscriptionPlan.gold && isActive;
  bool get hasGstBilling => plan != SubscriptionPlan.free && isActive;
  bool get hasPdfExport => plan != SubscriptionPlan.free && isActive;
  bool get hasAdvancedReports => plan != SubscriptionPlan.free && isActive;
  bool get hasProfitAnalysis => plan == SubscriptionPlan.gold && isActive;
  bool get hasSalesForecast => plan == SubscriptionPlan.gold && isActive;
  bool get hasSupplierAnalytics => plan == SubscriptionPlan.gold && isActive;
  bool get hasCustomerAnalytics => plan == SubscriptionPlan.gold && isActive;
  bool get hasPrioritySupport => plan == SubscriptionPlan.gold && isActive;
  bool get hasPaymentTracking => plan != SubscriptionPlan.free && isActive;

  // ─────────────────────────────────────────────
  //  DISPLAY HELPERS
  // ─────────────────────────────────────────────
  String get planName {
    switch (plan) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.silver:
        return 'Silver';
      case SubscriptionPlan.gold:
        return 'Gold';
    }
  }

  // ─────────────────────────────────────────────
  //  SERIALIZATION
  // ─────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'plan': plan.name,
    'expiry_date': expiryDate?.toIso8601String(),
    'billing_cycle': billingCycle?.name,
    'sale_bills_used_this_month': saleBillsUsedThisMonth,
    'purchase_bills_used_this_month': purchaseBillsUsedThisMonth,
    'customers_count': customersCount,
    'items_count': itemsCount,
    'ai_prompts_used_today': aiPromptsUsedToday,
    'ai_prompts_reset_date': aiPromptsResetDate?.toIso8601String(),
    'companies_count': companiesCount,
  };

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    final planStr = map['plan'] as String? ?? 'free';
    final plan = SubscriptionPlan.values.firstWhere(
          (p) => p.name == planStr,
      orElse: () => SubscriptionPlan.free,
    );

    final cycleStr = map['billing_cycle'] as String?;
    final cycle = cycleStr != null
        ? BillingCycle.values.firstWhere(
          (c) => c.name == cycleStr,
      orElse: () => BillingCycle.monthly,
    )
        : null;

    return SubscriptionModel(
      plan: plan,
      expiryDate: _parseDateSafe(map['expiry_date']),
      billingCycle: cycle,
      saleBillsUsedThisMonth: (map['sale_bills_used_this_month'] as int?) ?? 0,
      purchaseBillsUsedThisMonth: (map['purchase_bills_used_this_month'] as int?) ?? 0,
      customersCount: (map['customers_count'] as int?) ?? 0,
      itemsCount: (map['items_count'] as int?) ?? 0,
      aiPromptsUsedToday: (map['ai_prompts_used_today'] as int?) ?? 0,
      aiPromptsResetDate: _parseDateSafe(map['ai_prompts_reset_date']),
      companiesCount: (map['companies_count'] as int?) ?? 1,
    );
  }

  SubscriptionModel copyWith({
    SubscriptionPlan? plan,
    DateTime? expiryDate,
    BillingCycle? billingCycle,
    int? saleBillsUsedThisMonth,
    int? purchaseBillsUsedThisMonth,
    int? customersCount,
    int? itemsCount,
    int? aiPromptsUsedToday,
    DateTime? aiPromptsResetDate,
    int? companiesCount,
  }) =>
      SubscriptionModel(
        plan: plan ?? this.plan,
        expiryDate: expiryDate ?? this.expiryDate,
        billingCycle: billingCycle ?? this.billingCycle,
        saleBillsUsedThisMonth: saleBillsUsedThisMonth ?? this.saleBillsUsedThisMonth,
        purchaseBillsUsedThisMonth: purchaseBillsUsedThisMonth ?? this.purchaseBillsUsedThisMonth,
        customersCount: customersCount ?? this.customersCount,
        itemsCount: itemsCount ?? this.itemsCount,
        aiPromptsUsedToday: aiPromptsUsedToday ?? this.aiPromptsUsedToday,
        aiPromptsResetDate: aiPromptsResetDate ?? this.aiPromptsResetDate,
        companiesCount: companiesCount ?? this.companiesCount,
      );

  /// Safe date parse: handles both String ("2025-06-01") and Firestore Timestamp
  static DateTime? _parseDateSafe(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    // Firestore Timestamp — has toDate() method
    try {
      return (value as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }
}