
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';

class LoginAppButton {
  static Widget appButton({
    required String label,
    required VoidCallback onPressed,
    Color backgroundColor = app_colors.button_bg,
    Color textColor = Colors.white,
    double borderRadius = 8,
    double fontSize = 16,
    double height = 40, // 👈 pass this when calling
  }) {
    return SizedBox(
      height: height, // 👈 controls button height
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: EdgeInsets.zero, // 👈 don't forget this
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 0,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontFamily: app_fonts.Regular,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

}
