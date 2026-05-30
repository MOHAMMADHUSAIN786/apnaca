// lib/features/auth/presentation/pages/login_screen.dart
//
// CHANGES:
//   - Admin ab Firebase Auth se login karta hai (local check nahi)
//   - Firestore rules mein email-based isAdmin() function hai
//   - Admin login hone ke baad AdminScreen pe jaata hai
//
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

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ── Admin Login – Firebase Auth se ──────────────────────────────
  Future<void> _handleLogin() async {
    final email    = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email aur password daalo')),
      );
      return;
    }

    // Admin email detect karo
    if (email.toLowerCase() == _adminEmail) {
      setState(() => _isAdminLoading = true);
      try {
        // Firebase Auth se admin login (Firestore rules ke liye zaruri)
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminScreen()),
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        String msg = 'Login failed';
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          msg = 'Admin password galat hai';
        } else if (e.code == 'user-not-found') {
          msg = 'Admin account Firebase mein nahi hai — neeche setup dekho';
        } else {
          msg = e.message ?? msg;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      } finally {
        if (mounted) setState(() => _isAdminLoading = false);
      }
      return;
    }

    // Normal user login via BLoC
    context.read<AuthBloc>().add(
      LoginRequested(email: email, password: password),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
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
            ),
            AppLoginTextfield.textField(
              labelText: 'Password',
              controller: passwordController,
              obscureText: _isPasswordHidden,
              isPasswordField: true,
              onToggleVisibility: () =>
                  setState(() => _isPasswordHidden = !_isPasswordHidden),
            ),
            Padding(
              padding: EdgeInsets.only(top: 14.h, right: 28.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () { /* TODO: Forgot password */ },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: app_colors.black,
                        fontSize: 14.sp,
                        fontFamily: app_fonts.Regular,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  top: 24.w, left: 28.w, right: 28.w),
              child: _isAdminLoading
                  ? const Center(child: CircularProgressIndicator())
                  : LoginAppButton.appButton(
                label: 'Sign in',
                height: 40.h,
                onPressed: _handleLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}