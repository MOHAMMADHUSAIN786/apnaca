// lib/features/subscription/service/subscription_service.dart
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

  static const int silverPriceRs = 99;
  static const int goldPriceRs   = 199;

  // ─────────────────────────────────────────────────
  //  FETCH
  // ─────────────────────────────────────────────────
  Future<SubscriptionModel> getSubscription() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return SubscriptionModel(plan: SubscriptionPlan.free, billsUsed: 0);
    }
    try {
      final doc = await _firestore.collection('subscriptions').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        final fresh = SubscriptionModel(plan: SubscriptionPlan.free, billsUsed: 0);
        _cached = fresh;
        return fresh;
      }
      final model = SubscriptionModel.fromMap(doc.data()!);
      _cached = model;
      return model;
    } catch (e) {
      return _cached ?? SubscriptionModel(plan: SubscriptionPlan.free, billsUsed: 0);
    }
  }

  SubscriptionModel? get cachedSubscription => _cached;

  // ─────────────────────────────────────────────────
  //  CHECK
  // ─────────────────────────────────────────────────
  Future<bool> canCreateBill() async {
    final sub = await getSubscription();
    return sub.canCreateBill;
  }

  // ─────────────────────────────────────────────────
  //  INCREMENT
  // ─────────────────────────────────────────────────
  Future<void> incrementBillCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('subscriptions').doc(uid).set(
      {'bills_used': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
    if (_cached != null) {
      _cached = _cached!.copyWith(billsUsed: _cached!.billsUsed + 1);
    }
  }

  // ─────────────────────────────────────────────────
  //  ACTIVATE (called from SubscriptionScreen after payment)
  // ─────────────────────────────────────────────────
  Future<void> activateSubscription({
    required SubscriptionPlan plan,
    required String razorpayPaymentId,
    required String razorpayOrderId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final expiry = plan == SubscriptionPlan.gold
        ? now.add(const Duration(days: 365))
        : now.add(const Duration(days: 183));

    await _firestore.collection('subscriptions').doc(uid).set({
      'plan': plan.name,
      'expiry_date': expiry.toIso8601String(),
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_order_id': razorpayOrderId,
      'activated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _cached = (_cached ?? SubscriptionModel(plan: plan, billsUsed: 0))
        .copyWith(plan: plan, expiryDate: expiry);
  }

  // Cache invalidate karo (logout pe)
  void clearCache() {
    _cached = null;
  }
}