// lib/features/home/presentation/pages/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_status_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../database/app_database.dart';
import '../bloc/home_bloc.dart';
import '../widgets/app_home_container.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

                      Padding(
                        padding: const EdgeInsets.only(
                            top: 18,
                            left: 8,
                            right: 8,
                            bottom: 48),
                        child: AppHomeContainer(
                          title: "Expense",
                          icon: Icons.wallet,
                          iconColor:
                          app_colors.OrangeColor,
                          iconBackgroundColor:
                          app_colors.LightOrange,
                          amount: state.totalExpense,
                          thisMonthAmount:
                          state.expenseThisMonth,
                          lastMonthAmount:
                          state.expenseLastMonth,
                          percentageChange:
                          state.percentageChangeExpense,
                        ),
                      ),

                      const SizedBox(height: 80),
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