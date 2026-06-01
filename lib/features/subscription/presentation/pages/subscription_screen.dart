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

  const SubscriptionScreen({
    super.key,
    this.limitReached = false,
  });

  @override
  State<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState
    extends State<SubscriptionScreen> {
  SubscriptionModel? _current;

  bool _loading = true;
  bool _paying = false;

  SubscriptionPlan? _pendingPlan;

  late final Razorpay _razorpay;

  @override
  void initState() {
    super.initState();

    _razorpay = Razorpay();

    _razorpay.on(
      Razorpay.EVENT_PAYMENT_SUCCESS,
      _handlePaymentSuccess,
    );

    _razorpay.on(
      Razorpay.EVENT_PAYMENT_ERROR,
      _handlePaymentError,
    );

    _razorpay.on(
      Razorpay.EVENT_EXTERNAL_WALLET,
      _handleExternalWallet,
    );

    _loadSubscription();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadSubscription() async {
    final sub =
    await SubscriptionService.instance.getSubscription();

    if (mounted) {
      setState(() {
        _current = sub;
        _loading = false;
      });
    }
  }

  Future<void> _startPayment(
      SubscriptionPlan plan,
      ) async {
    setState(() {
      _paying = true;
      _pendingPlan = plan;
    });

    final amountPaise =
        (plan == SubscriptionPlan.gold
            ? SubscriptionService.goldPriceRs
            : SubscriptionService.silverPriceRs) *
            100;

    final apiKey =
        dotenv.env['TEST_RAZORPAY_API_KEY'] ?? '';

    final options = {
      'key': apiKey,
      'amount': amountPaise,
      'name': 'ApnaCA',
      'description': plan == SubscriptionPlan.gold
          ? 'Gold Plan - 12 Months'
          : 'Silver Plan - 6 Months',
      'prefill': {
        },
      'theme': {
        'color': '#2490EF',
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() {
        _paying = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to open payment gateway: $e',
            ),
            backgroundColor: app_colors.c_danger,
          ),
        );
      }
    }
  }

  void _handlePaymentSuccess(
      PaymentSuccessResponse response,
      ) async {
    if (_pendingPlan != null) {
      await SubscriptionService.instance
          .activateSubscription(
        plan: _pendingPlan!,
        razorpayPaymentId:
        response.paymentId ?? '',
        razorpayOrderId:
        response.orderId ?? '',
      );
    }

    setState(() {
      _paying = false;
    });

    await _loadSubscription();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '🎉 Subscription activated successfully',
        ),
        backgroundColor: Color(0xFF22C55E),
      ),
    );

    Navigator.of(context).pop(true);
  }

  void _handlePaymentError(
      PaymentFailureResponse response,
      ) {
    setState(() {
      _paying = false;
      _pendingPlan = null;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment failed: ${response.message ?? "Please try again"}',
        ),
        backgroundColor: app_colors.c_danger,
      ),
    );
  }

  void _handleExternalWallet(
      ExternalWalletResponse response,
      ) {
    setState(() {
      _paying = false;
    });
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
          'Subscriptions',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: app_colors.title),
        ),
      ),

      body: _loading
          ? Center(
        child: Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(20.r),
          ),
          child:
          const CircularProgressIndicator(),
        ),
      )
          : Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 16.h,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                if (widget.limitReached) ...[
                  _buildLimitBanner(),
                  SizedBox(height: 20.h),
                ],

                Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w800,
                    color: app_colors.title,
                    letterSpacing: -.5,
                  ),
                ),

                SizedBox(height: 6.h),

                Text(
                  'Unlock unlimited billing and premium AI features',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color:
                    Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),

                SizedBox(height: 28.h),

                // FREE PLAN

                _PlanCard(
                  title: 'Free',
                  price: '₹0',
                  duration: 'Forever',

                  color:
                  const Color(0xFF6B7280),

                  isFreePlan: true,

                  gradientColors: const [
                    Color(0xFF9CA3AF),
                    Color(0xFF6B7280),
                  ],

                  features: const [
                    '10 Bills Included',
                    'Basic AI Assistant',
                    'Customer & Item Management',
                    'Sales Reports',
                  ],

                  isCurrent:
                  _current?.plan ==
                      SubscriptionPlan
                          .free,

                  onTap: null,
                  badge: null,
                ),

                SizedBox(height: 18.h),

                // SILVER PLAN

                _PlanCard(
                  title: 'Silver',
                  price: '₹99',
                  duration: '6 Months',

                  color:
                  const Color(0xFF2490EF),

                  isFreePlan: false,

                  gradientColors: const [
                    Color(0xFF3BA7FF),
                    Color(0xFF1B7FDE),
                  ],

                  features: const [
                    'Unlimited Bills',
                    'Unlimited AI Assistant',
                    'Customer & Supplier Management',
                    'Advanced Reports & Analytics',
                    'PDF Export',
                  ],

                  isCurrent:
                  _current?.plan ==
                      SubscriptionPlan
                          .silver &&
                      (_current?.isActive ??
                          false),

                  onTap: () {
                    _startPayment(
                      SubscriptionPlan
                          .silver,
                    );
                  },

                  badge: 'POPULAR',
                ),

                SizedBox(height: 18.h),

                // GOLD PLAN

                _PlanCard(
                  title: 'Gold',
                  price: '₹199',
                  duration: '12 Months',

                  color:
                  const Color(0xFFF59E0B),

                  isFreePlan: false,

                  gradientColors: const [
                    Color(0xFFFFC53D),
                    Color(0xFFF59E0B),
                  ],

                  features: const [
                    'Unlimited Bills',
                    'Unlimited AI Assistant',
                    'Priority Support',
                    'Advanced Reports & Analytics',
                    'PDF Export',
                    'Best Annual Value',
                  ],

                  isCurrent:
                  _current?.plan ==
                      SubscriptionPlan
                          .gold &&
                      (_current?.isActive ??
                          false),

                  onTap: () {
                    _startPayment(
                      SubscriptionPlan.gold,
                    );
                  },

                  badge: 'BEST VALUE',
                ),

                SizedBox(height: 22.h),

                if (_current != null)
                  _buildCurrentPlanInfo(),

                SizedBox(height: 30.h),
              ],
            ),
          ),

          if (_paying)
            Container(
              color: Colors.black26,
              child: Center(
                child: Container(
                  padding:
                  EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(
                      20.r,
                    ),
                  ),
                  child:
                  const CircularProgressIndicator(),
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

      padding: EdgeInsets.symmetric(
        horizontal: 18.w,
        vertical: 16.h,
      ),

      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius:
        BorderRadius.circular(18.r),
        border: Border.all(
          color: const Color(0xFFF59E0B),
          width: 1.3,
        ),
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

            child: const Center(
              child: Text(
                '⚠️',
                style: TextStyle(fontSize: 22),
              ),
            ),
          ),

          SizedBox(width: 14.w),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Free Limit Reached',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.sp,
                    color: const Color(0xFF92400E),
                  ),
                ),

                SizedBox(height: 4.h),

                Text(
                  'You have used all 10 free bills. Upgrade to continue creating bills.',
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

    if (sub.plan ==
        SubscriptionPlan.free) {
      return Container(
        width: double.infinity,

        padding: EdgeInsets.all(18.w),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(18.r),
          border: Border.all(
            color: app_colors.border_color,
          ),
        ),

        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,

              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                borderRadius:
                BorderRadius.circular(12.r),
              ),

              child: const Icon(
                Icons.info_outline_rounded,
                color: app_colors.c_primary,
              ),
            ),

            SizedBox(width: 12.w),

            Expanded(
              child: Text(
                'Free Plan: ${sub.billsUsed}/10 bills used',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: app_colors.title,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final expiry = sub.expiryDate;

    final daysLeft = expiry != null
        ? expiry
        .difference(DateTime.now())
        .inDays
        : 0;

    return Container(
      width: double.infinity,

      padding: EdgeInsets.all(18.w),

      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius:
        BorderRadius.circular(18.r),
        border: Border.all(
          color: const Color(0xFF34D399),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,

            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius:
              BorderRadius.circular(12.r),
            ),

            child: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF059669),
            ),
          ),

          SizedBox(width: 12.w),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
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
                    '$daysLeft days remaining (${expiry.day}/${expiry.month}/${expiry.year})',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFF065F46),
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

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String duration;

  final Color color;

  final List<Color> gradientColors;
  final List<String> features;

  final bool isCurrent;
  final bool isFreePlan;

  final VoidCallback? onTap;

  final String? badge;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.duration,
    required this.color,
    required this.gradientColors,
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

        borderRadius:
        BorderRadius.circular(24.r),

        border: Border.all(
          color: isCurrent
              ? color
              : app_colors.border_color,
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
          // HEADER

          Container(
            width: double.infinity,

            padding: EdgeInsets.symmetric(
              horizontal: 22.w,
              vertical: 22.h,
            ),

            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),

              borderRadius: BorderRadius.only(
                topLeft:
                Radius.circular(24.r),
                topRight:
                Radius.circular(24.r),
              ),
            ),

            child: Row(
              mainAxisAlignment:
              MainAxisAlignment
                  .spaceBetween,

              children: [
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.sp,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 4.h),

                    Text(
                      duration,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),

                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .end,

                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30.sp,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),

                    if (badge != null)
                      Container(
                        margin: EdgeInsets.only(
                          top: 4.h,
                        ),

                        padding:
                        EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),

                        decoration: BoxDecoration(
                          color: Colors.white
                              .withOpacity(.2),

                          borderRadius:
                          BorderRadius
                              .circular(
                            20.r,
                          ),
                        ),

                        child: Text(
                          badge!,
                          style: TextStyle(
                            color:
                            Colors.white,
                            fontSize: 10.sp,
                            fontWeight:
                            FontWeight
                                .w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // FEATURES

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 18.h,
            ),

            child: Column(
              children: [
                ...features.map(
                      (feature) => Padding(
                    padding: EdgeInsets.only(
                      bottom: 10.h,
                    ),

                    child: Row(
                      children: [
                        Icon(
                          Icons
                              .check_circle_rounded,

                          color: isFreePlan
                              ? const Color(
                              0xFF6B7280)
                              : color,

                          size: 20.sp,
                        ),

                        SizedBox(width: 12.w),

                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 13.sp,
                              height: 1.4,

                              color: isFreePlan
                                  ? const Color(
                                  0xFF4B5563)
                                  : const Color(
                                  0xFF374151),

                              fontWeight:
                              isFreePlan
                                  ? FontWeight
                                  .w500
                                  : FontWeight
                                  .w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 10.h),

                // BUTTON

                if (isCurrent)
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,

                    child: OutlinedButton(
                      onPressed: null,

                      style:
                      OutlinedButton
                          .styleFrom(
                        side: BorderSide(
                          color: color,
                        ),

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            14.r,
                          ),
                        ),
                      ),

                      child: Text(
                        'Current Plan',
                        style: TextStyle(
                          color: color,
                          fontWeight:
                          FontWeight.w700,
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

                      style:
                      ElevatedButton
                          .styleFrom(
                        backgroundColor:
                        color,

                        foregroundColor:
                        Colors.white,

                        elevation: 0,

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            14.r,
                          ),
                        ),
                      ),

                      child: Text(
                        'Get $title Plan',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.w700,
                          fontSize: 14.sp,
                        ),
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