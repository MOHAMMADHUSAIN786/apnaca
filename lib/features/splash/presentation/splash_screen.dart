import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/constants/app_status_bar.dart';
import '../../../../core/widgets/common_widgets/app_loader.dart';
import '../../../core/services/sync_service.dart';
import '../../admin/presentation/pages/admin_screen.dart';
import '../../auth/presentation/pages/auth_screen.dart';
import '../../other/nav_bar.dart';

const String _adminEmail = 'admin@gmail.com';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 2));

    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    if (user != null) {
      // Set user in sync service
      FirebaseSyncService.setCurrentUser(user.uid);

      // ✅ Admin check — same as login screen
      if (user.email?.toLowerCase() == _adminEmail) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminScreen()),
        );
        return;
      }

      // Normal user — sync then go to NavBar
      await FirebaseSyncService.downloadDatabase();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NavBar()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: Colors.white,
      child: Scaffold(
        backgroundColor: app_colors.white,
        body: Column(
          children: [
            const Spacer(),
            Center(
              child: SvgPicture.asset(
                app_images.splash_logo,
                width: 190.w,
                height: 190.h,
              ),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.only(bottom: 30.h),
              child: const AppLoader(),
            ),
          ],
        ),
      ),
    );
  }
}