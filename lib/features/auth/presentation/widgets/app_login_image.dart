import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppLoginImage extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;

  const AppLoginImage({
    Key? key,
    required this.imagePath,
    this.width = 88,
    this.height = 88,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8.w , left: 28.w , right: 28.w),
      child: Center(
        child: Image.asset(
          imagePath,
          width: width.w,
          height: height.h,
        ),
      ),
    );
  }
}
