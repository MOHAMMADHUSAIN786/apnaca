// lib/features/auth/presentation/pages/forgot_password.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/widgets/common_widgets/app_status_bar.dart';
import '../widgets/app_login_btn.dart';
import '../widgets/app_login_textfield.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final _emailController = TextEditingController();
  bool _isLoading  = false;
  bool _emailSent  = false; // email bhej diya — success UI dikhao
  String? _errorMsg;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    // ── Validation ──────────────────────────────────────────────────────────
    if (email.isEmpty) {
      setState(() => _errorMsg = 'Please enter your email address.');
      return;
    }
    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(email)) {
      setState(() => _errorMsg = 'Please enter a valid email address.');
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    try {
      // ── Firebase sends the reset link ─────────────────────────────────────
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) setState(() { _isLoading = false; _emailSent = true; });

    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'No account found with this email.';
          break;
        case 'invalid-email':
          msg = 'Invalid email address.';
          break;
        case 'too-many-requests':
          msg = 'Too many requests. Please try again later.';
          break;
        default:
          msg = e.message ?? 'Something went wrong. Please try again.';
      }
      if (mounted) setState(() { _isLoading = false; _errorMsg = msg; });

    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _errorMsg = 'Something went wrong. Please try again.'; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: app_colors.button_bg,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
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
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back, color: app_colors.button_bg),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 18.w, top: 16.h),
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: app_colors.white,
                        fontSize: 24.sp,
                        fontFamily: app_fonts.Medium,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 18.w, bottom: 18.h, top: 2.h),
                    child: Text(
                      'Enter your registered email to reset the password.',
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

            // ── Body ───────────────────────────────────────────────────────
            Expanded(
              child: _emailSent ? _buildSuccessView() : _buildFormView(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form: email input + Send button ───────────────────────────────────────
  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email field using your existing widget
        AppLoginTextfield.textField(
          labelText: 'Email',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),

        // Error message
        if (_errorMsg != null)
          Padding(
            padding: EdgeInsets.only(left: 28.w, right: 28.w, top: 8.h),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 16.sp),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    _errorMsg!,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12.sp,
                      fontFamily: app_fonts.Regular,
                    ),
                  ),
                ),
              ],
            ),
          ),

        SizedBox(height: 24.h),

        // Send button
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: _isLoading
              ? Center(
            child: CircularProgressIndicator(color: app_colors.button_bg),
          )
              : LoginAppButton.appButton(
            label: 'Send Reset Link',
            height: 50.h,
            onPressed: _sendResetEmail,
          ),
        ),

        SizedBox(height: 16.h),

        // Back to login
        Center(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text.rich(
              TextSpan(
                text: 'Remember your password? ',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey,
                  fontFamily: app_fonts.Regular,
                ),
                children: [
                  TextSpan(
                    text: 'Login',
                    style: TextStyle(
                      color: app_colors.button_bg,
                      fontFamily: app_fonts.Medium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Success: email sent confirmation ──────────────────────────────────────
  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Email icon
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: app_colors.button_bg.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_read_outlined,
                size: 60.sp,
                color: app_colors.button_bg,
              ),
            ),

            SizedBox(height: 24.h),

            Text(
              'Email Sent!',
              style: TextStyle(
                fontSize: 24.sp,
                fontFamily: app_fonts.Medium,
                color: app_colors.button_bg,
              ),
            ),

            SizedBox(height: 12.h),

            Text(
              'We sent a password reset link to',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey,
                fontFamily: app_fonts.Regular,
              ),
            ),

            SizedBox(height: 6.h),

            Text(
              _emailController.text.trim(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.sp,
                fontFamily: app_fonts.Medium,
                color: Colors.black87,
              ),
            ),

            SizedBox(height: 8.h),

            Text(
              'Check your inbox and click the link to reset your password.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey,
                fontFamily: app_fonts.Regular,
                height: 1.5,
              ),
            ),

            SizedBox(height: 32.h),

            // Resend option
            GestureDetector(
              onTap: () => setState(() { _emailSent = false; _errorMsg = null; }),
              child: Text.rich(
                TextSpan(
                  text: "Didn't receive the email? ",
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey,
                    fontFamily: app_fonts.Regular,
                  ),
                  children: [
                    TextSpan(
                      text: 'Resend',
                      style: TextStyle(
                        color: app_colors.button_bg,
                        fontFamily: app_fonts.Medium,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20.h),

            // Back to login
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 0),
              child: LoginAppButton.appButton(
                label: 'Back to Login',
                height: 50.h,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
