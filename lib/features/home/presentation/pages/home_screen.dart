// lib/features/home/presentation/pages/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/widgets/common_widgets/app_status_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../database/app_database.dart';
import '../bloc/home_bloc.dart';
import '../widgets/app_home_container.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onAiAssistantTap;

  const HomeScreen({super.key, this.onAiAssistantTap});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {

  late HomeBloc _homeBloc;

  @override
  void initState() {
    super.initState();

    _homeBloc = HomeBloc(AppDatabase.instance)
      ..add(FetchHomeData());
  }

  void refreshHome() {
    _homeBloc.add(FetchHomeData());
  }

  @override
  void dispose() {
    _homeBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return BlocProvider.value(
      value: _homeBloc,

      child: AppStatusBarUtils(
        color: app_colors.table_header_bg,

        child: Scaffold(
          backgroundColor: app_colors.white,

          body: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {

              if (state is HomeLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (state is HomeError) {

                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),

                      SizedBox(height: 16.h),

                      Text('Error: ${state.message}'),

                      ElevatedButton(
                        onPressed: () {
                          _homeBloc.add(FetchHomeData());
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state is HomeLoaded) {

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Padding(
                        padding: const EdgeInsets.only(
                            top: 18,
                            left: 8,
                            right: 8),
                        child: _AiAssistantCard(
                          onTap: widget.onAiAssistantTap,
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(
                            top: 18,
                            left: 8,
                            right: 8),
                        child: AppHomeContainer(
                          title: "You'll Receive",
                          icon: Icons.arrow_upward,
                          iconColor: app_colors.GreenColor,
                          iconBackgroundColor:
                          app_colors.LightGreen,
                          amount: state.youWillReceive,
                          thisMonthAmount:
                          state.saleThisMonth,
                          lastMonthAmount:
                          state.saleLastMonth,
                          percentageChange:
                          state.percentageChangeSale,
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(
                            top: 18,
                            left: 8,
                            right: 8),
                        child: AppHomeContainer(
                          title: "You'll Pay",
                          icon: Icons.arrow_downward,
                          iconColor: app_colors.c_danger,
                          iconBackgroundColor:
                          app_colors.RedColor,
                          amount: state.youWillPay,
                          thisMonthAmount: 0,
                          lastMonthAmount: 0,
                          percentageChange: 0,
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(
                            top: 18,
                            left: 8,
                            right: 8),
                        child: AppHomeContainer(
                          title: "Sale",
                          icon: Icons.arrow_upward,
                          iconColor: app_colors.GreenColor,
                          iconBackgroundColor:
                          app_colors.LightGreen,
                          amount: state.totalSale,
                          thisMonthAmount:
                          state.saleThisMonth,
                          lastMonthAmount:
                          state.saleLastMonth,
                          percentageChange:
                          state.percentageChangeSale,
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(
                            top: 18,
                            left: 8,
                            right: 8),
                        child: AppHomeContainer(
                          title: "Purchase",
                          icon:
                          Icons.shopping_bag_outlined,
                          iconColor: app_colors.c_primary,
                          iconBackgroundColor:
                          app_colors.LightBlue,
                          amount: state.totalPurchase,
                          thisMonthAmount:
                          state.purchaseThisMonth,
                          lastMonthAmount:
                          state.purchaseLastMonth,
                          percentageChange:
                          state.percentageChangePurchase,
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//  AI ASSISTANT CARD — Same structure/colors as AppHomeContainer:
//  outer Dbackgroun_color box → inner white card (title + icon
//  badge) → light Dbackgroun_color footer with quick-prompt chips.
// ────────────────────────────────────────────────────────────────
class _AiAssistantCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _AiAssistantCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: app_colors.Dbackgroun_color,
        border: Border.all(color: app_colors.Dborder_color),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        children: [
          /// Inner white box — tappable, opens chat
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(10.r),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: app_colors.Dborder_color),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38.w,
                      height: 38.h,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: app_colors.LightBlue,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: app_colors.c_primary,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "AI Assistant",
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.black,
                                  fontFamily: app_fonts.Regular,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                                decoration: BoxDecoration(
                                  color: app_colors.LightOrange,
                                  border: Border.all(color: app_colors.OrangeColor),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "NEW",
                                  style: TextStyle(
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    fontFamily: app_fonts.Medium,
                                    color: app_colors.OrangeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            "Ask about your business.",
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontFamily: app_fonts.Regular,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 30.w,
                      height: 30.h,
                      decoration: BoxDecoration(
                        color: app_colors.LightBlue,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(Icons.arrow_forward_rounded, color: app_colors.c_primary, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: 8.h),

          /// Quick-prompt chips section — same look as "Monthly Summary"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: app_colors.Dbackgroun_color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(child: _AiSuggestionChip(icon: Icons.inventory_2_outlined, label: "Stock check", onTap: onTap)),
                SizedBox(width: 8.w),
                Expanded(child: _AiSuggestionChip(icon: Icons.bar_chart_rounded, label: "Today sale", onTap: onTap)),
                SizedBox(width: 8.w),
                Expanded(child: _AiSuggestionChip(icon: Icons.receipt_long_outlined, label: "Make Bill", onTap: onTap)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small pill-shaped quick-prompt chip used inside the AI card ───
class _AiSuggestionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _AiSuggestionChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
          decoration: BoxDecoration(
            border: Border.all(color: app_colors.Dborder_color),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: app_colors.c_primary),
              SizedBox(height: 4.h),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5.sp,
                  fontFamily: app_fonts.Regular,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}