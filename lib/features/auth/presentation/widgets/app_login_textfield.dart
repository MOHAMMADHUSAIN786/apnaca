
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_fonts.dart';
class AppLoginTextfield {
  static const Color _unfocusedBorderColor = Color.fromRGBO(220, 224, 228, 1);
  static const Color _focusedBorderColor = Colors.black;

  static Widget textField({
    required String labelText,
    TextEditingController? controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    bool isPasswordField = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: 24.w, left: 28.w, right: 28.w),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 12.sp, fontFamily: app_fonts.Regular),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: Colors.black,
            fontSize: 12.sp,
            fontFamily: app_fonts.Regular,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _unfocusedBorderColor),
            borderRadius: BorderRadius.circular(12.r),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _focusedBorderColor, width: 1.5),
            borderRadius: BorderRadius.circular(12.r),
          ),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: _unfocusedBorderColor),
            borderRadius: BorderRadius.circular(12.r),
          ),
          suffixIcon: isPasswordField
              ? IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: onToggleVisibility,
          )
              : null,
        ),
      ),
    );
  }
}
