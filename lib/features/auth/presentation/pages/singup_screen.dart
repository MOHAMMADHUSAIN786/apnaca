import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';

import '../../../../core/widgets/common_widgets/app_radio_button.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';

import '../widgets/app_login_btn.dart';
import '../widgets/app_login_textfield.dart';

class SignupScreen extends StatefulWidget {
  SignupScreen({super.key});

  @override
  State<SignupScreen> createState() =>
      _SignupScreenState();
}

class _SignupScreenState
    extends State<SignupScreen> {

  final TextEditingController firstNameController =
  TextEditingController();

  final TextEditingController lastNameController =
  TextEditingController();

  final TextEditingController referenceNameController =
  TextEditingController();

  final TextEditingController usernameController =
  TextEditingController();

  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController mobileController =
  TextEditingController();

  final TextEditingController passwordController =
  TextEditingController();

  final TextEditingController
  confirmPasswordController =
  TextEditingController();

  bool isPasswordHidden = true;

  bool isConfirmPasswordHidden = true;

  bool isAgreed = false;

  @override
  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.only(top: 0),

      child: Column(

        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          AppLoginTextfield.textField(
            labelText: "First Name",
            controller: firstNameController,
          ),

          AppLoginTextfield.textField(
            labelText: "Last Name",
            controller: lastNameController,
          ),

          AppLoginTextfield.textField(
            labelText: "Reference Name (Optional)",
            controller: referenceNameController,
          ),

          AppLoginTextfield.textField(
            labelText: "Username",
            controller: usernameController,
          ),

          AppLoginTextfield.textField(
            labelText: "Email Address",
            controller: emailController,
          ),

          AppLoginTextfield.textField(
            labelText: "Mobile Number",
            controller: mobileController,
          ),

          AppLoginTextfield.textField(

            labelText: "Password",

            controller: passwordController,

            obscureText: isPasswordHidden,

            isPasswordField: true,

            onToggleVisibility: () {

              setState(() {

                isPasswordHidden =
                !isPasswordHidden;

              });
            },
          ),

          AppLoginTextfield.textField(

            labelText: "Confirm Password",

            controller:
            confirmPasswordController,

            obscureText:
            isConfirmPasswordHidden,

            isPasswordField: true,

            onToggleVisibility: () {

              setState(() {

                isConfirmPasswordHidden =
                !isConfirmPasswordHidden;

              });
            },
          ),

          Padding(

            padding: EdgeInsets.only(
              top: 18.w,
              left: 28.w,
              right: 28.w,
            ),

            child: Row(

              children: [

                AppTermsRadioButton(

                  isSelected: isAgreed,

                  onTap: () {

                    setState(() {

                      isAgreed = !isAgreed;

                    });
                  },
                ),

                RichText(

                  text: TextSpan(

                    style: TextStyle(

                      fontSize: 12.sp,

                      color: Colors.black,

                      fontFamily:
                      app_fonts.Regular,
                    ),

                    children: [

                      const TextSpan(
                        text:
                        "I read and agree to ",
                      ),

                      TextSpan(

                        text:
                        "Terms & Conditions",

                        style: const TextStyle(

                          decoration:
                          TextDecoration
                              .underline,

                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(

            padding: EdgeInsets.only(
              top: 18.w,
              left: 28.w,
              right: 28.w,
              bottom: 28.w,
            ),

            child: LoginAppButton.appButton(

              label: "Sign up",

              height: 40.h,

              onPressed: () {

                if (!isAgreed) {

                  ScaffoldMessenger.of(context)
                      .showSnackBar(

                    const SnackBar(

                      content: Text(
                        "Please accept Terms & Conditions",
                      ),
                    ),
                  );

                  return;
                }

                context.read<AuthBloc>().add(

                  SignupRequested(

                    firstName:
                    firstNameController
                        .text
                        .trim(),

                    lastName:
                    lastNameController
                        .text
                        .trim(),

                    username:
                    usernameController
                        .text
                        .trim(),

                    email:
                    emailController.text
                        .trim(),

                    mobile:
                    mobileController.text
                        .trim(),

                    password:
                    passwordController
                        .text
                        .trim(),

                    confirmPassword:
                    confirmPasswordController
                        .text
                        .trim(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}