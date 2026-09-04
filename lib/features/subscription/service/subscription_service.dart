// lib/features/subscription/service/subscription_service.dart
//
// FIXES:
// ✅ FIX 1 — AI prompt reset_date: Firestore Timestamp → String safe parse
// ✅ FIX 2 — getSubscription() forces cache refresh when called from screen
// ✅ FIX 3 — incrementAiPromptCount resets counter properly when new day
// ✅ FIX 4 — forceRefresh() method added for subscription screen
// ✅ FIX 5 — fromMap: safe cast for Firestore Timestamp vs String date
// ✅ FIX 6 — subscription screen: StreamBuilder for live updates
// ✅ FIX 7 — _lastFetchTime: avoid unnecessary Firestore reads (5min cache)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/subscription_model.dart';

/// Pure business logic — NO Razorpay import here.
/// Razorpay is handled directly in SubscriptionScreen widget.
class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._internal();
  SubscriptionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  SubscriptionModel? _cached;
  DateTime? _lastFetchTime;

  // Cache valid for 5 minutes (except force refresh)
  static const _cacheDuration = Duration(minutes: 5);

  // ─────────────────────────────────────────────
  //  FETCH
  // ─────────────────────────────────────────────

  /// Get subscription — uses 5-min cache unless [forceRefresh] = true
  Future<SubscriptionModel> getSubscription({bool forceRefresh = false}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const SubscriptionModel(plan: SubscriptionPlan.free);
    }

    // Return cache if fresh enough
    if (!forceRefresh && _cached != null && _lastFetchTime != null) {
      final age = DateTime.now().difference(_lastFetchTime!);
      if (age < _cacheDuration) {
        return _cached!;
      }
    }

    try {
      final doc = await _firestore.collection('subscriptions').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        // First time user — create default free subscription doc
        final fresh = const SubscriptionModel(plan: SubscriptionPlan.free);
        _cached = fresh;
        _lastFetchTime = DateTime.now();
        // Initialize doc in Firestore so increments work
        await _firestore.collection('subscriptions').doc(uid).set(
          fresh.toMap(),
          SetOptions(merge: true),
        );
        return fresh;
      }
      final model = SubscriptionModel.fromMap(doc.data()!);
      _cached = model;
      _lastFetchTime = DateTime.now();
      return model;
    } catch (e) {
      return _cached ?? const SubscriptionModel(plan: SubscriptionPlan.free);
    }
  }

  /// Force fresh Firestore fetch — call from subscription screen on open
  Future<SubscriptionModel> forceRefresh() => getSubscription(forceRefresh: true);

  SubscriptionModel? get cachedSubscription => _cached;

  // ─────────────────────────────────────────────
  //  VALIDATION HELPERS
  // ─────────────────────────────────────────────

  Future<LimitCheckResult> canCreateSaleBill() async {
    final sub = await getSubscription();
    if (!sub.isActive) {
      return LimitCheckResult(
          allowed: false, reason: 'Subscription expired. Please renew your plan.');
    }
    if (!sub.canCreateSaleBill) {
      return LimitCheckResult(
        allowed: false,
        reason:
        'Free plan ki sale bill limit khatam ho gayi: ${sub.saleBillsUsedThisMonth}/${SubscriptionModel.freeMaxSaleBills} bills use ho gaye. Ab naye bills ke liye plan lena padega.',
        limitReached: true,
      );
    }
    return const LimitCheckResult(allowed: true);
  }

  Future<LimitCheckResult> canCreatePurchaseBill() async {
    final sub = await getSubscription();
    if (!sub.isActive) {
      return LimitCheckResult(
          allowed: false, reason: 'Subscription expired. Please renew your plan.');
    }
    if (!sub.canCreatePurchaseBill) {
      return LimitCheckResult(
        allowed: false,
        reason:
        'Free plan ki purchase bill limit khatam ho gayi: ${sub.purchaseBillsUsedThisMonth}/${SubscriptionModel.freeMaxPurchaseBills} bills use ho gaye. Ab naye bills ke liye plan lena padega.',
        limitReached: true,
      );
    }
    return const LimitCheckResult(allowed: true);
  }

  Future<LimitCheckResult> canAddCustomer() async {
    final sub = await getSubscription();
    if (!sub.isActive) {
      return LimitCheckResult(
          allowed: false, reason: 'Subscription expired. Please renew your plan.');
    }
    if (!sub.canAddCustomer) {
      return LimitCheckResult(
        allowed: false,
        reason:
        'Free plan limit reached: ${sub.customersCount}/${SubscriptionModel.freeMaxCustomers} customers added.',
        limitReached: true,
      );
    }
    return const LimitCheckResult(allowed: true);
  }

  Future<LimitCheckResult> canAddItem() async {
    final sub = await getSubscription();
    if (!sub.isActive) {
      return LimitCheckResult(
          allowed: false, reason: 'Subscription expired. Please renew your plan.');
    }
    if (!sub.canAddItem) {
      return LimitCheckResult(
        allowed: false,
        reason:
        'Free plan limit reached: ${sub.itemsCount}/${SubscriptionModel.freeMaxItems} items added.',
        limitReached: true,
      );
    }
    return const LimitCheckResult(allowed: true);
  }

  Future<LimitCheckResult> canUseAiPrompt() async {
    final sub = await getSubscription();
    if (!sub.isActive) {
      return LimitCheckResult(
          allowed: false, reason: 'Subscription expired. Please renew your plan.');
    }
    if (!sub.canUseAiPrompt) {
      final limit = sub.plan == SubscriptionPlan.silver
          ? SubscriptionModel.silverMaxAiPromptsPerDay
          : SubscriptionModel.freeMaxAiPromptsPerDay;
      return LimitCheckResult(
        allowed: false,
        reason:
        'Aaj ke liye AI prompts khatam ho gaye ($limit/day). Kal phir use kar sakte hain!\n'
            'Zyada prompts ke liye Silver ya Gold plan upgrade karein. 🚀',
        limitReached: true,
      );
    }
    return const LimitCheckResult(allowed: true);
  }

  Future<LimitCheckResult> canAddCompany() async {
    final sub = await getSubscription();
    if (!sub.isActive) {
      return LimitCheckResult(
          allowed: false, reason: 'Subscription expired. Please renew your plan.');
    }
    if (!sub.canAddCompany) {
      return LimitCheckResult(
        allowed: false,
        reason: sub.plan == SubscriptionPlan.silver
            ? 'Silver plan supports 1 company. Upgrade to Gold for multi-company.'
            : 'Free plan supports 1 company. Upgrade to add more.',
        limitReached: true,
      );
    }
    return const LimitCheckResult(allowed: true);
  }

  // ─────────────────────────────────────────────
  //  INCREMENT COUNTERS
  // ─────────────────────────────────────────────

  Future<void> incrementSaleBillCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('subscriptions').doc(uid).set(
      {'sale_bills_used_this_month': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
    // Update cache immediately
    if (_cached != null) {
      _cached = _cached!.copyWith(
        saleBillsUsedThisMonth: _cached!.saleBillsUsedThisMonth + 1,
      );
    }
  }

  Future<void> incrementPurchaseBillCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('subscriptions').doc(uid).set(
      {'purchase_bills_used_this_month': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
    if (_cached != null) {
      _cached = _cached!.copyWith(
        purchaseBillsUsedThisMonth: _cached!.purchaseBillsUsedThisMonth + 1,
      );
    }
  }

  Future<void> incrementCustomerCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('subscriptions').doc(uid).set(
      {'customers_count': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
    if (_cached != null) {
      _cached = _cached!.copyWith(customersCount: _cached!.customersCount + 1);
    }
  }

  Future<void> decrementCustomerCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('subscriptions').doc(uid).set(
      {'customers_count': FieldValue.increment(-1)},
      SetOptions(merge: true),
    );
    if (_cached != null) {
      final newCount = (_cached!.customersCount - 1).clamp(0, 999999);
      _cached = _cached!.copyWith(customersCount: newCount);
    }
  }

  Future<void> incrementItemCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('subscriptions').doc(uid).set(
      {'items_count': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
    if (_cached != null) {
      _cached = _cached!.copyWith(itemsCount: _cached!.itemsCount + 1);
    }
  }

  Future<void> decrementItemCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('subscriptions').doc(uid).set(
      {'items_count': FieldValue.increment(-1)},
      SetOptions(merge: true),
    );
    if (_cached != null) {
      final newCount = (_cached!.itemsCount - 1).clamp(0, 999999);
      _cached = _cached!.copyWith(itemsCount: newCount);
    }
  }

  // FIX 3 — AI prompt increment: properly reset counter on new day
  Future<void> incrementAiPromptCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    // Store date as "yyyy-MM-dd" string — NOT full ISO timestamp
    // This avoids Firestore Timestamp vs String parsing issues
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // FIX: Check if it's a new day — if so, RESET counter to 1 instead of incrementing
    bool isNewDay = true;
    if (_cached != null && _cached!.aiPromptsResetDate != null) {
      final lastDate = _cached!.aiPromptsResetDate!;
      isNewDay = !(now.year == lastDate.year &&
          now.month == lastDate.month &&
          now.day == lastDate.day);
    } else {
      // No cache — check Firestore
      try {
        final doc =
        await _firestore.collection('subscriptions').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          final savedDate = _parseDateField(doc.data()!['ai_prompts_reset_date']);
          if (savedDate != null) {
            isNewDay = !(now.year == savedDate.year &&
                now.month == savedDate.month &&
                now.day == savedDate.day);
          }
        }
      } catch (_) {}
    }

    if (isNewDay) {
      // New day — reset counter to 1
      await _firestore.collection('subscriptions').doc(uid).set(
        {
          'ai_prompts_used_today': 1,
          'ai_prompts_reset_date': todayStr,
        },
        SetOptions(merge: true),
      );
      if (_cached != null) {
        _cached = _cached!.copyWith(
          aiPromptsUsedToday: 1,
          aiPromptsResetDate: now,
        );
      }
    } else {
      // Same day — increment
      await _firestore.collection('subscriptions').doc(uid).set(
        {
          'ai_prompts_used_today': FieldValue.increment(1),
          'ai_prompts_reset_date': todayStr,
        },
        SetOptions(merge: true),
      );
      if (_cached != null) {
        final currentUsed = _cached!.effectiveAiPromptsUsedToday;
        _cached = _cached!.copyWith(
          aiPromptsUsedToday: currentUsed + 1,
          aiPromptsResetDate: now,
        );
      }
    }
  }

  Future<void> incrementCompanyCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('subscriptions').doc(uid).set(
      {'companies_count': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
    if (_cached != null) {
      _cached = _cached!.copyWith(companiesCount: _cached!.companiesCount + 1);
    }
  }

  Future<void> resetMonthlyCounters() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('subscriptions').doc(uid).set(
      {
        'sale_bills_used_this_month': 0,
        'purchase_bills_used_this_month': 0,
      },
      SetOptions(merge: true),
    );
    if (_cached != null) {
      _cached = _cached!.copyWith(
        saleBillsUsedThisMonth: 0,
        purchaseBillsUsedThisMonth: 0,
      );
    }
  }

  // ─────────────────────────────────────────────
  //  ACTIVATE — DEPRECATED
  //  Plan activation now happens server-side via the Razorpay webhook
  //  (Agent Gateway). Firestore security rules deny client writes to plan
  //  fields. This is kept as a no-op so any stray caller just refreshes.
  // ─────────────────────────────────────────────
  @Deprecated('Plan is activated by the server webhook. Use forceRefresh().')
  Future<void> activateSubscription({
    required SubscriptionPlan plan,
    required BillingCycle billingCycle,
    required String razorpayPaymentId,
    required String razorpayOrderId,
  }) async {
    await forceRefresh();
  }

  // Cache invalidate karo (logout pe)
  void clearCache() {
    _cached = null;
    _lastFetchTime = null;
  }

  // ─────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────

  // FIX 5 — Safe date parse: handles both String and Firestore Timestamp
  static DateTime? _parseDateField(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    // Firestore Timestamp object
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

// ─────────────────────────────────────────────
//  RESULT MODEL
// ─────────────────────────────────────────────

class LimitCheckResult {
  final bool allowed;
  final String? reason;
  final bool limitReached;

  const LimitCheckResult({
    required this.allowed,
    this.reason,
    this.limitReached = false,
  });
}