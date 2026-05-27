// lib/features/subscription/model/subscription_model.dart

enum SubscriptionPlan { free, silver, gold }

class SubscriptionModel {
  final SubscriptionPlan plan;
  final DateTime? expiryDate;
  final int billsUsed; // total sale+purchase bills created

  const SubscriptionModel({
    required this.plan,
    this.expiryDate,
    required this.billsUsed,
  });

  /// Free plan: max 10 bills (sale + purchase combined)
  static const int freeBillLimit = 10;

  bool get isActive {
    if (plan == SubscriptionPlan.free) return true;
    if (expiryDate == null) return false;
    return DateTime.now().isBefore(expiryDate!);
  }

  bool get canCreateBill {
    if (plan == SubscriptionPlan.free) {
      return billsUsed < freeBillLimit;
    }
    return isActive; // silver/gold: unlimited if not expired
  }

  int get remainingFreeBills {
    if (plan != SubscriptionPlan.free) return -1; // unlimited
    final remaining = freeBillLimit - billsUsed;
    return remaining < 0 ? 0 : remaining;
  }

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

  Map<String, dynamic> toMap() => {
    'plan': plan.name,
    'expiry_date': expiryDate?.toIso8601String(),
    'bills_used': billsUsed,
  };

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    final planStr = map['plan'] as String? ?? 'free';
    final plan = SubscriptionPlan.values.firstWhere(
          (p) => p.name == planStr,
      orElse: () => SubscriptionPlan.free,
    );
    return SubscriptionModel(
      plan: plan,
      expiryDate: map['expiry_date'] != null
          ? DateTime.tryParse(map['expiry_date'] as String)
          : null,
      billsUsed: (map['bills_used'] as int?) ?? 0,
    );
  }

  SubscriptionModel copyWith({
    SubscriptionPlan? plan,
    DateTime? expiryDate,
    int? billsUsed,
  }) =>
      SubscriptionModel(
        plan: plan ?? this.plan,
        expiryDate: expiryDate ?? this.expiryDate,
        billsUsed: billsUsed ?? this.billsUsed,
      );
}
