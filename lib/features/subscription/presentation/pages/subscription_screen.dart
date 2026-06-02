// lib/features/subscription/presentation/pages/subscription_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../model/subscription_model.dart';
import '../../service/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  final bool limitReached;
  final String? limitMessage;

  const SubscriptionScreen({
    super.key,
    this.limitReached = false,
    this.limitMessage,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionModel? _current;
  bool _loading = true;
  bool _paying = false;

  SubscriptionPlan? _pendingPlan;
  BillingCycle? _pendingCycle;

  // Billing toggle — default monthly
  BillingCycle _selectedCycle = BillingCycle.monthly;

  late final Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadSubscription();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadSubscription() async {
    // FIX: Always force fresh fetch when screen opens
    final sub = await SubscriptionService.instance.forceRefresh();
    if (mounted) {
      setState(() {
        _current = sub;
        _loading = false;
        // Pre-select cycle that matches current plan if active
        if (sub.billingCycle != null) {
          _selectedCycle = sub.billingCycle!;
        }
      });
    }
  }

  int _getAmountForPlan(SubscriptionPlan plan, BillingCycle cycle) {
    if (plan == SubscriptionPlan.silver) {
      return cycle == BillingCycle.yearly
          ? SubscriptionModel.silverYearlyPriceRs
          : SubscriptionModel.silverMonthlyPriceRs;
    }
    // gold
    return cycle == BillingCycle.yearly
        ? SubscriptionModel.goldYearlyPriceRs
        : SubscriptionModel.goldMonthlyPriceRs;
  }

  Future<void> _startPayment(SubscriptionPlan plan, BillingCycle cycle) async {
    setState(() {
      _paying = true;
      _pendingPlan = plan;
      _pendingCycle = cycle;
    });

    final amountPaise = _getAmountForPlan(plan, cycle) * 100;
    final apiKey = dotenv.env['TEST_RAZORPAY_API_KEY'] ?? '';

    final planLabel = plan == SubscriptionPlan.silver ? 'Silver' : 'Gold';
    final cycleLabel = cycle == BillingCycle.yearly ? 'Yearly' : 'Monthly';

    final options = {
      'key': apiKey,
      'amount': amountPaise,
      'name': 'ApnaCA',
      'description': '$planLabel Plan - $cycleLabel',
      'prefill': {},
      'theme': {'color': '#2490EF'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _paying = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open payment gateway: $e'),
            backgroundColor: app_colors.c_danger,
          ),
        );
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_pendingPlan != null && _pendingCycle != null) {
      await SubscriptionService.instance.activateSubscription(
        plan: _pendingPlan!,
        billingCycle: _pendingCycle!,
        razorpayPaymentId: response.paymentId ?? '',
        razorpayOrderId: response.orderId ?? '',
      );
    }

    setState(() => _paying = false);
    await _loadSubscription();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Subscription activated successfully!'),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
    Navigator.of(context).pop(true);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      _paying = false;
      _pendingPlan = null;
      _pendingCycle = null;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message ?? "Please try again"}'),
        backgroundColor: app_colors.c_danger,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() => _paying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        backgroundColor: app_colors.table_header_bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: app_colors.title),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          'Choose Your Plan',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: app_colors.title,
          ),
        ),
      ),
      body: _loading
          ? Center(
        child: Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: const CircularProgressIndicator(),
        ),
      )
          : Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Limit Banner ──
                if (widget.limitReached) ...[
                  _buildLimitBanner(),
                  SizedBox(height: 20.h),
                ],

                Text(
                  'Grow with ApnaCA',
                  style: TextStyle(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w800,
                    color: app_colors.title,
                    letterSpacing: -.5,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Simple plans for every business. Upgrade anytime.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),

                SizedBox(height: 22.h),

                // ── Billing Cycle Toggle ──
                _BillingToggle(
                  selected: _selectedCycle,
                  onChanged: (c) => setState(() => _selectedCycle = c),
                ),

                SizedBox(height: 24.h),

                // ── FREE PLAN ──
                _PlanCard(
                  title: 'Free',
                  emoji: '🆓',
                  priceLabel: '₹0',
                  durationLabel: 'Forever',
                  color: const Color(0xFF6B7280),
                  gradientColors: const [Color(0xFF9CA3AF), Color(0xFF6B7280)],
                  targetLabel: 'Students · Small Shops · Testing',
                  features: const [
                    _Feature('50 Customers', true),
                    _Feature('50 Items', true),
                    _Feature('10 Sale Bills (lifetime)', true),
                    _Feature('10 Purchase Bills (lifetime)', true),
                    _Feature('Basic Reports', true),
                    _Feature('10 AI Prompts / day', true),
                    _Feature('1 Company', true),
                  ],
                  isCurrent: _current?.plan == SubscriptionPlan.free,
                  isFreePlan: true,
                  badge: null,
                  onTap: null,
                ),

                SizedBox(height: 18.h),

                // ── SILVER PLAN ──
                _PlanCard(
                  title: 'Silver',
                  emoji: '🥈',
                  priceLabel: _selectedCycle == BillingCycle.yearly
                      ? '₹${SubscriptionModel.silverYearlyPriceRs}'
                      : '₹${SubscriptionModel.silverMonthlyPriceRs}',
                  durationLabel: _selectedCycle == BillingCycle.yearly
                      ? 'per year'
                      : 'per month',
                  color: const Color(0xFF2490EF),
                  gradientColors: const [Color(0xFF3BA7FF), Color(0xFF1B7FDE)],
                  targetLabel: 'Kirana · Mobile Shop · Medical',
                  features: const [
                    _Feature('Unlimited Customers', true),
                    _Feature('Unlimited Items', true),
                    _Feature('Unlimited Bills', true),
                    _Feature('GST Billing', true),
                    _Feature('PDF Export', true),
                    _Feature('Inventory Management', true),
                    _Feature('Payment Tracking', true),
                    _Feature('Business Reports', true),
                    _Feature('100 AI Prompts / day', true),
                    _Feature('1 Company', true),
                  ],
                  isCurrent: _current?.plan == SubscriptionPlan.silver &&
                      (_current?.isActive ?? false),
                  isFreePlan: false,
                  badge: 'POPULAR',
                  onTap: () => _startPayment(SubscriptionPlan.silver, _selectedCycle),
                ),

                SizedBox(height: 18.h),

                // ── GOLD PLAN ──
                _PlanCard(
                  title: 'Gold',
                  emoji: '🥇',
                  priceLabel: _selectedCycle == BillingCycle.yearly
                      ? '₹${SubscriptionModel.goldYearlyPriceRs}'
                      : '₹${SubscriptionModel.goldMonthlyPriceRs}',
                  durationLabel: _selectedCycle == BillingCycle.yearly
                      ? 'per year'
                      : 'per month',
                  color: const Color(0xFFF59E0B),
                  gradientColors: const [Color(0xFFFFC53D), Color(0xFFE8920A)],
                  targetLabel: 'Growing Business · CA Firms · Distributors',
                  features: const [
                    _Feature('Everything in Silver', true),
                    _Feature('Multi User', true),
                    _Feature('Multi Company', true),
                    _Feature('Advanced AI Insights', true),
                    _Feature('Profit Analysis', true),
                    _Feature('Sales Forecast', true),
                    _Feature('Supplier Analytics', true),
                    _Feature('Customer Analytics', true),
                    _Feature('Unlimited AI Prompts (fair use)', true),
                    _Feature('Priority Support', true),
                  ],
                  isCurrent: _current?.plan == SubscriptionPlan.gold &&
                      (_current?.isActive ?? false),
                  isFreePlan: false,
                  badge: 'BEST VALUE',
                  onTap: () => _startPayment(SubscriptionPlan.gold, _selectedCycle),
                ),

                SizedBox(height: 22.h),

                if (_current != null) _buildCurrentPlanInfo(),

                SizedBox(height: 30.h),
              ],
            ),
          ),

          if (_paying)
            Container(
              color: Colors.black26,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLimitBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.3),
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEDD5),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('⚠️', style: TextStyle(fontSize: 22))),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Limit Reached',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.sp,
                    color: const Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  widget.limitMessage ??
                      'You have reached your free plan limit. Upgrade to continue.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanInfo() {
    final sub = _current!;

    if (sub.plan == SubscriptionPlan.free) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: app_colors.border_color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4FF),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: const Icon(Icons.info_outline_rounded, color: app_colors.c_primary),
                ),
                SizedBox(width: 12.w),
                Text(
                  'Free Plan Usage',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: app_colors.title,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            _UsageRow(
              label: 'Sale Bills (lifetime)',
              used: sub.saleBillsUsedThisMonth,
              max: SubscriptionModel.freeMaxSaleBills,
            ),
            SizedBox(height: 8.h),
            _UsageRow(
              label: 'Purchase Bills (lifetime)',
              used: sub.purchaseBillsUsedThisMonth,
              max: SubscriptionModel.freeMaxPurchaseBills,
            ),
            SizedBox(height: 8.h),
            _UsageRow(
              label: 'Customers',
              used: sub.customersCount,
              max: SubscriptionModel.freeMaxCustomers,
            ),
            SizedBox(height: 8.h),
            _UsageRow(
              label: 'Items',
              used: sub.itemsCount,
              max: SubscriptionModel.freeMaxItems,
            ),
            SizedBox(height: 8.h),
            _UsageRow(
              label: 'AI Prompts Today',
              used: sub.effectiveAiPromptsUsedToday,
              max: SubscriptionModel.freeMaxAiPromptsPerDay,
            ),
          ],
        ),
      );
    }

    final expiry = sub.expiryDate;
    final daysLeft = expiry != null ? expiry.difference(DateTime.now()).inDays : 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFF34D399)),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: const Icon(Icons.verified_rounded, color: Color(0xFF059669)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sub.planName} Plan Active',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.sp,
                    color: const Color(0xFF065F46),
                  ),
                ),
                SizedBox(height: 3.h),
                if (expiry != null)
                  Text(
                    '$daysLeft days remaining · Expires ${expiry.day}/${expiry.month}/${expiry.year}',
                    style: TextStyle(fontSize: 12.sp, color: const Color(0xFF065F46)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BILLING TOGGLE
// ─────────────────────────────────────────────

class _BillingToggle extends StatelessWidget {
  final BillingCycle selected;
  final ValueChanged<BillingCycle> onChanged;

  const _BillingToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: app_colors.border_color),
        ),
        padding: EdgeInsets.all(4.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleBtn(
              label: 'Monthly',
              isSelected: selected == BillingCycle.monthly,
              onTap: () => onChanged(BillingCycle.monthly),
            ),
            SizedBox(width: 4.w),
            _ToggleBtn(
              label: 'Yearly  🎉 Save ~15%',
              isSelected: selected == BillingCycle.yearly,
              onTap: () => onChanged(BillingCycle.yearly),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleBtn({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? app_colors.c_primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  FEATURE DATA
// ─────────────────────────────────────────────

class _Feature {
  final String label;
  final bool included;
  const _Feature(this.label, this.included);
}

// ─────────────────────────────────────────────
//  PLAN CARD
// ─────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final String title;
  final String emoji;
  final String priceLabel;
  final String durationLabel;
  final Color color;
  final List<Color> gradientColors;
  final String targetLabel;
  final List<_Feature> features;
  final bool isCurrent;
  final bool isFreePlan;
  final VoidCallback? onTap;
  final String? badge;

  const _PlanCard({
    required this.title,
    required this.emoji,
    required this.priceLabel,
    required this.durationLabel,
    required this.color,
    required this.gradientColors,
    required this.targetLabel,
    required this.features,
    required this.isCurrent,
    required this.isFreePlan,
    required this.onTap,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isCurrent ? color : app_colors.border_color,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 20.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24.r),
                topRight: Radius.circular(24.r),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(emoji, style: TextStyle(fontSize: 22.sp)),
                        SizedBox(width: 8.w),
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          priceLabel,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          durationLabel,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (badge != null) ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.22),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 8.h),
                Text(
                  targetLabel,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.8),
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),

          // ── Features ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
            child: Column(
              children: [
                ...features.map(
                      (f) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: Row(
                      children: [
                        Icon(
                          f.included
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: f.included
                              ? (isFreePlan ? const Color(0xFF6B7280) : color)
                              : Colors.grey.shade300,
                          size: 20.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            f.label,
                            style: TextStyle(
                              fontSize: 13.sp,
                              height: 1.4,
                              color: f.included
                                  ? (isFreePlan
                                  ? const Color(0xFF4B5563)
                                  : const Color(0xFF374151))
                                  : Colors.grey.shade400,
                              fontWeight: isFreePlan ? FontWeight.w500 : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10.h),

                // ── Button ──
                if (isCurrent)
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: color),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        '✓ Current Plan',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  )
                else if (onTap != null)
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        'Get $title Plan',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.sp),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  USAGE ROW (free plan info)
// ─────────────────────────────────────────────

class _UsageRow extends StatelessWidget {
  final String label;
  final int used;
  final int max;

  const _UsageRow({required this.label, required this.used, required this.max});

  @override
  Widget build(BuildContext context) {
    final pct = (used / max).clamp(0.0, 1.0);
    final isAlmostFull = pct >= 0.8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: app_colors.title,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$used / $max',
              style: TextStyle(
                fontSize: 12.sp,
                color: isAlmostFull ? const Color(0xFFDC2626) : app_colors.title,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 5.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6.h,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(
              isAlmostFull ? const Color(0xFFDC2626) : app_colors.c_primary,
            ),
          ),
        ),
      ],
    );
  }
}