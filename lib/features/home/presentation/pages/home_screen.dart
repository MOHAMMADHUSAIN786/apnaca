import 'package:flutter/material.dart';
import '../../../../../core/constants/app_status_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/app_home_container.dart';
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {


    return AppStatusBarUtils(
      color: app_colors.table_header_bg,
      child: Scaffold(
        backgroundColor: app_colors.white,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 18 , left: 8 , right: 8),
                child: AppHomeContainer(
                  title: "You'll Receive",
                  icon: Icons.arrow_upward,
                  iconColor: app_colors.GreenColor,
                  iconBackgroundColor: app_colors.LightGreen,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18 , left: 8 , right: 8),
                child: AppHomeContainer(
                  title: "You'll Pay",
                  icon: Icons.arrow_downward,
                  iconColor: app_colors.c_danger,
                  iconBackgroundColor: app_colors.RedColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18 , left: 8 , right: 8),
                child: AppHomeContainer(
                  title: "Sale",
                  icon: Icons.arrow_upward,
                  iconColor: app_colors.GreenColor,
                  iconBackgroundColor: app_colors.LightGreen,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18 , left: 8 , right: 8),
                child: AppHomeContainer(
                  title: "Purchase",
                  icon: Icons.shopping_bag_outlined,
                  iconColor: app_colors.c_primary,
                  iconBackgroundColor: app_colors.LightBlue,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18 , left: 8 , right: 8 , bottom: 48),
                child: AppHomeContainer(
                  title: "Expense",
                  icon: Icons.wallet,
                  iconColor: app_colors.OrangeColor,
                  iconBackgroundColor: app_colors.LightOrange,
                ),
              ),
              const SizedBox(height: 80), // for FAB space
            ],
          ),
        ),
      ),
    );
  }
}
