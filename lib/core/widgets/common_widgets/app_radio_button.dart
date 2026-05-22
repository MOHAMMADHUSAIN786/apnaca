import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTermsRadioButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  static const Color buttonBg = Color.fromRGBO(244, 124, 78, 1);

  const AppTermsRadioButton({
    Key? key,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Icon(
          isSelected ? Icons.check_box : Icons.check_box_outline_blank,
          color: isSelected ? buttonBg : Colors.black,
          size: 20.w,
        ),
      ),
    );
  }
}
