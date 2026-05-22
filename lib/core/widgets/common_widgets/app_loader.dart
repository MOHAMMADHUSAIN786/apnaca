import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../constants/app_colors.dart';



class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SpinKitFadingCircle(
        color: app_colors.button_bg,
        size: 36.0,
      ),
    );
  }
}


class Loader extends StatelessWidget {
  const Loader({super.key});

  @override
  Widget build(BuildContext context) {
    return  Center(
      child: SpinKitFadingCircle(
        color: app_colors.button_bg,
        size: 50.0,
      ),
    );
  }
}
