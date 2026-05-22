import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart';

import '../../../../database/database_helper.dart';
import '../../../other/nav_bar.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {

  final AuthRepository authRepository;

  AuthBloc({
    required this.authRepository,
  }) : super(AuthInitial()) {

    on<SignupRequested>((event, emit) async {

      emit(AuthLoading());

      if (event.firstName.isEmpty ||
          event.lastName.isEmpty ||
          event.username.isEmpty ||
          event.email.isEmpty ||
          event.mobile.isEmpty ||
          event.password.isEmpty ||
          event.confirmPassword.isEmpty) {

        emit(AuthFailure("Please fill all fields"));
        return;
      }

      if (!event.email.contains("@")) {
        emit(AuthFailure("Invalid email"));
        return;
      }

      if (event.password.length < 6) {
        emit(AuthFailure(
            "Password must be at least 6 characters"));
        return;
      }

      if (event.password != event.confirmPassword) {
        emit(AuthFailure("Passwords do not match"));
        return;
      }

      final response = await authRepository.signup(
        firstName: event.firstName,
        lastName: event.lastName,
        username: event.username,
        email: event.email,
        mobile: event.mobile,
        password: event.password,
      );

      if (response == "Signup Successful") {
        emit(AuthSuccess(response));
      } else {
        emit(AuthFailure(response));
      }
    });

    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());

      if (event.email.isEmpty || event.password.isEmpty) {
        emit(AuthFailure("Please enter email and password"));
        return;
      }

      final response = await authRepository.login(
        email: event.email,
        password: event.password,
      );

      if (response == "Login Successful") {


        // ✅ Firebase से current user लें
        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {

          // ✅ Database initialize करें (tables create होंगे)
          final dbHelper = DatabaseHelper.instance;
          await dbHelper.database; // यह call onCreate को trigger करेगा

          Navigator.pushReplacement(
            context as BuildContext,
            MaterialPageRoute(
              builder: (_) =>
              const NavBar(),
            ),
          );


          // ✅ User table में डिटेल्स insert करें
          await dbHelper.insertOrUpdateUser({
            'firebaseUid': currentUser.uid,
            'email': currentUser.email ?? event.email,
            'displayName': currentUser.displayName ?? '',
            'createdAt': DateTime.now().toIso8601String(),
          });
        } else {
          // अगर किसी कारण से currentUser null है, तो भी आप event.email से store कर सकते हैं
          // लेकिन यह स्थिति rare है
        }

        emit(AuthSuccess(response));
      } else {
        emit(AuthFailure(response));
      }
    });
  }
}