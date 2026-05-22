
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';

class AppHomeContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconBackgroundColor;
  final Color iconColor; // 🆕 New parameter

  const AppHomeContainer({
    super.key,
    required this.title,
    required this.icon,
    this.iconBackgroundColor = const Color(0xFFFFEBEE),
    this.iconColor = Colors.red, // 🆕 Default icon color
  });

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
          /// 🟩 Inner white box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: app_colors.Dborder_color),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              children: [
                /// Row 1: Title + Icon
                Row(
                  children: [
                    Text(
                      title,
                      style:  TextStyle(
                        fontSize: 14.sp,
                        color: Colors.black,
                        fontFamily: app_fonts.Regular,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 38.w,
                      height: 38.h,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: iconBackgroundColor,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor, // 🆕 Icon color from parameter
                        size: 16,
                      ),
                    ),
                  ],
                ),
                 SizedBox(height: 0.h),

                /// Row 2: Amount + % change
                Row(
                  children: [
                     Text(
                      "0.00",
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontFamily: app_fonts.Regular,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                     SizedBox(width: 6.w),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: app_colors.LightGreen,
                        border: Border.all(color: app_colors.GreenColor),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children:  [
                          Icon(Icons.arrow_upward, size: 12, color: app_colors.GreenColor),
                          SizedBox(width: 2.w),
                          Text(
                            "0%",
                            style: TextStyle(fontSize: 12.sp, color: app_colors.GreenColor , fontFamily: app_fonts.Regular),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),

           SizedBox(height: 8.h),

          /// 📦 Monthly Summary Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            decoration: BoxDecoration(
              color: app_colors.Dbackgroun_color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children:  [
                Row(
                  children: [
                    Text(
                      "0.00",
                      style: TextStyle(fontSize: 13.sp , fontFamily: app_fonts.Regular),
                    ),
                    SizedBox(width: 4.h),
                    Text(
                      "This Month",
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500 , fontFamily: app_fonts.Regular),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(
                      "0.00",
                      style: TextStyle(fontSize: 13.sp , fontFamily: app_fonts.Regular),
                    ),
                    SizedBox(width: 4),
                    Text(
                      "Last Month",
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500 , fontFamily: app_fonts.Regular),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
