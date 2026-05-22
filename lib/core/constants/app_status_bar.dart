import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppStatusBarUtils extends StatelessWidget {
  final Color color;
  final Brightness iconBrightness;
  final Widget child;

  const AppStatusBarUtils({
    super.key,
    required this.color,
    this.iconBrightness = Brightness.dark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: color,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: iconBrightness,
      ),
      child: child,
    );
  }
}
