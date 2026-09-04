// lib/features/auth/presentation/pages/login_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../admin/presentation/pages/admin_screen.dart';
import '../../../other/nav_bar.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/app_login_btn.dart';
import '../widgets/app_login_textfield.dart';
import 'forgot_password.dart';

const String _adminEmail = 'admin@gmail.com';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isPasswordHidden = true;
  bool _isAdminLoading   = false;

  // ── Firebase error codes → user-friendly Hinglish messages ──────────────
  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
    // Wrong credentials
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-password':
        return 'Wrong password. Please try again.';

    // Email issues
      case 'user-not-found':
        return 'Yeh email registered nahi hai.';
      case 'email-already-in-use':
        return 'Yeh email pehle se registered hai. Login karein.';
      case 'invalid-email':
        return 'Email address sahi format mein nahi hai.';

    // Account status
      case 'user-disabled':
        return 'Yeh account disable kar diya gaya hai.';
      case 'account-exists-with-different-credential':
        return 'Yeh email doosre login method se registered hai.';

    // Too many attempts
      case 'too-many-requests':
        return 'Bahut zyada galat attempts. Kuch der baad try karein.';

    // Network
      case 'network-request-failed':
        return 'Internet connection check karein aur dobara try karein.';

    // Token / session
      case 'user-token-expired':
      case 'requires-recent-login':
        return 'Session expire ho gaya. Dobara login karein.';

      default:
        return 'Kuch galat ho gaya. Dobara try karein.';
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email    = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Email aur password dono bharen.');
      return;
    }

    if (email.toLowerCase() == _adminEmail) {
      setState(() => _isAdminLoading = true);
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, password: password,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminScreen()),
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        _showSnackBar(_getFirebaseErrorMessage(e));
      } finally {
        if (mounted) setState(() => _isAdminLoading = false);
      }
      return;
    }

    context.read<AuthBloc>().add(
      LoginRequested(email: email, password: password),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const NavBar()),
          );
        } else if (state is AuthFailure) {
          // AuthBloc ka error bhi same map se pass karo
          _showSnackBar(state.message);
        }
      },
      child: Padding(
        padding: EdgeInsets.only(top: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppLoginTextfield.textField(
              labelText: 'Email',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            AppLoginTextfield.textField(
              labelText: 'Password',
              controller: passwordController,
              obscureText: _isPasswordHidden,
              isPasswordField: true,
              onToggleVisibility: () =>
                  setState(() => _isPasswordHidden = !_isPasswordHidden),
            ),

            // ── Forgot Password link ───────────────────────────────────────
            Padding(
              padding: EdgeInsets.only(top: 14.h, right: 28.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ForgotPassword()),
                    ),
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: app_colors.button_bg,
                        fontSize: 14.sp,
                        fontFamily: app_fonts.Medium,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.only(top: 24.h, left: 28.w, right: 28.w),
              child: _isAdminLoading
                  ? const Center(child: CircularProgressIndicator())
                  : LoginAppButton.appButton(
                label: 'Sign in',
                height: 50.h,
                onPressed: _handleLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}