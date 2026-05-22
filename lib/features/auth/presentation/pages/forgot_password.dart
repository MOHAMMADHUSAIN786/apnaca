import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_status_bar.dart';
import '../widgets/app_login_btn.dart';
import '../widgets/app_login_textfield.dart';

class ForgotPassword extends StatelessWidget {
  const ForgotPassword({super.key});


  @override
  Widget build(BuildContext context) {


    return AppStatusBarUtils(
      color: app_colors.button_bg,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180.h,
              width: double.infinity,
              color: app_colors.button_bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 48.h, left: 18.w),
                    child: CircleAvatar(
                      backgroundColor: app_colors.white,
                      radius: 20.r,
                      child: Center(
                        child: IconButton(
                          onPressed: () => Get.back(),
                          icon: Icon(Icons.arrow_back, color: app_colors.button_bg),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 18.w, top: 16.h),
                    child: Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: app_colors.white,
                        fontSize: 24.sp,
                        fontFamily: app_fonts.Medium,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 18.w, bottom: 18.h , top: 2.h),
                    child: Text(
                      "Enter your registered email ID to reset the password.",
                      style: TextStyle(
                        color: app_colors.white,
                        fontSize: 12.sp,
                        fontFamily: app_fonts.Regular,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppLoginTextfield.textField(
              labelText: "Email",
            ),
            Padding(
              padding: EdgeInsets.only(top: 24.w, left: 28.w, right: 28.w),
              child: LoginAppButton.appButton(
                label: "Send",
                height: 40.h,
                onPressed: () {},
              ),
            ),


          ],
        ),
      ),
    );
  }
}
