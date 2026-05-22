import 'package:apnaca/features/auth/presentation/pages/singup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_status_bar.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';

import '../widgets/app_login_image.dart';

import 'login_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {

  bool isSignUpSelected = false;

  @override
  Widget build(BuildContext context) {

    return BlocConsumer<AuthBloc, AuthState>(

      listener: (context, state) {

        if (state is AuthLoading) {

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state is AuthSuccess) {

          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
        }

        if (state is AuthFailure) {

          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },

      builder: (context, state) {

        return AppStatusBarUtils(

          color: app_colors.white,

          child: Scaffold(

            backgroundColor: app_colors.white,

            body: SafeArea(

              child: SingleChildScrollView(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    AppLoginImage(
                      imagePath: app_images.app_logo,
                      width: 68.w,
                      height: 68.h,
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Center(
                        child: Text(
                          app_strings.app_name,
                          style: TextStyle(
                            color: app_colors.black,
                            fontSize: 28.sp,
                            fontFamily: app_fonts.Medium,
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Center(
                        child: Text(
                          app_strings.auth_title,
                          style: TextStyle(
                            color: app_colors.black,
                            fontSize: 12.sp,
                            fontFamily: app_fonts.Regular,
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.only(top: 24.w),
                      child: Center(
                        child: Container(
                          width: 300.w,
                          height: 50.w,
                          decoration: BoxDecoration(
                            color: app_colors.conatiner_bg,
                            borderRadius: BorderRadius.circular(40.r),
                          ),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [

                              InkWell(

                                splashColor: Colors.transparent,

                                highlightColor: Colors.transparent,

                                overlayColor:
                                WidgetStateProperty.all(
                                    Colors.transparent),

                                onTap: () {

                                  setState(() {

                                    isSignUpSelected = true;

                                  });
                                },

                                child: Container(
                                  width: 140.w,
                                  height: 50.w,
                                  decoration: BoxDecoration(
                                    color: isSignUpSelected
                                        ? app_colors.button_bg
                                        : Colors.transparent,
                                    borderRadius:
                                    BorderRadius.circular(40.r),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "Sign-Up",
                                      style: TextStyle(
                                        color: isSignUpSelected
                                            ? app_colors.white
                                            : app_colors.black,
                                        fontSize: 18.sp,
                                        fontFamily:
                                        app_fonts.Medium,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              InkWell(

                                splashColor: Colors.transparent,

                                highlightColor: Colors.transparent,

                                overlayColor:
                                WidgetStateProperty.all(
                                    Colors.transparent),

                                onTap: () {

                                  setState(() {

                                    isSignUpSelected = false;

                                  });
                                },

                                child: Container(
                                  width: 140.w,
                                  height: 50.w,
                                  decoration: BoxDecoration(
                                    color: !isSignUpSelected
                                        ? app_colors.button_bg
                                        : Colors.transparent,
                                    borderRadius:
                                    BorderRadius.circular(40.r),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "Sign-in",
                                      style: TextStyle(
                                        color: !isSignUpSelected
                                            ? app_colors.white
                                            : app_colors.black,
                                        fontSize: 18.sp,
                                        fontFamily:
                                        app_fonts.Medium,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    isSignUpSelected
                        ? SignupScreen()
                        : const LoginScreen(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}