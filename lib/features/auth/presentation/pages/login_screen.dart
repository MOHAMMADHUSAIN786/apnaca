import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../other/nav_bar.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/app_login_btn.dart';
import '../widgets/app_login_textfield.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isPasswordHidden = true;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          // ✅ Navigate only on successful login
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
              labelText: "Email",
              controller: emailController,
            ),
            AppLoginTextfield.textField(
              labelText: "Password",
              controller: passwordController,
              obscureText: isPasswordHidden,
              isPasswordField: true,
              onToggleVisibility: () {
                setState(() {
                  isPasswordHidden = !isPasswordHidden;
                });
              },
            ),
            Padding(
              padding: EdgeInsets.only(top: 14.h, right: 28.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      // TODO: Forgot password logic
                    },
                    child: Text(
                      "Forgot Password?",
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
                top: 24.w,
                left: 28.w,
                right: 28.w,
              ),
              child: LoginAppButton.appButton(
                label: "Sign in",
                height: 40.h,
                onPressed: () {
                  // ✅ Dispatch login event – no context passed
                  context.read<AuthBloc>().add(
                    LoginRequested(
                      email: emailController.text.trim(),
                      password: passwordController.text.trim(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}