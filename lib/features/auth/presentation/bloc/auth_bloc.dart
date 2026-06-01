import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../database/app_database.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {

    on<SignupRequested>((event, emit) async {
      emit(AuthLoading());

      if (event.firstName.isEmpty ||
          event.lastName.isEmpty ||
          event.username.isEmpty ||
          event.email.isEmpty ||
          event.mobile.isEmpty ||
          event.password.isEmpty ||
          event.companyName.isEmpty||
          event.confirmPassword.isEmpty) {
        emit(AuthFailure("Please fill all fields"));
        return;
      }
      if (!event.email.contains("@")) {
        emit(AuthFailure("Invalid email"));
        return;
      }
      if (event.password.length < 6) {
        emit(AuthFailure("Password must be at least 6 characters"));
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
        companyName: event.companyName,
      );

      if (response == "Signup Successful") {
        emit(AuthSuccess(response));
      } else {
        emit(AuthFailure(response));
      }
    });

    on<LoginRequested>((event, emit) async {

      emit(AuthLoading());

      if (event.email.isEmpty ||
          event.password.isEmpty) {

        emit(AuthFailure(
            "Please enter email and password"));

        return;
      }

      final response =
      await authRepository.login(
        email: event.email,
        password: event.password,
      );

      if (response == "Login Successful") {

        try {

          final User? currentUser =
              FirebaseAuth.instance.currentUser;

          if (currentUser != null) {

            // ─────────────────────────────
            // SWITCH LOCAL DB TO THIS USER
            // (prevents old user's data leaking to new user)
            // ─────────────────────────────
            await AppDatabase.switchUser(currentUser.uid);

            // ─────────────────────────────
            // FIRESTORE USER FETCH
            // ─────────────────────────────

            final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();

            final data = userDoc.data();

            // ─────────────────────────────
            // SQLITE SAVE
            // ─────────────────────────────

            await AppDatabase.instance
                .insertOrUpdateUser({

              'firebaseUid':
              currentUser.uid,

              'email':
              data?['email'] ?? '',

              'displayName':
              "${data?['first_name'] ?? ''} ${data?['last_name'] ?? ''}"
                  .trim(),

              'companyName':
              data?['company_name'] ?? '',

              'mobile':
              data?['mobile'] ?? '',

              'username':
              data?['username'] ?? '',

              'photo_url':
              data?['photo_url'] ?? '',

              'createdAt':
              DateTime.now()
                  .toIso8601String(),
            });

            // ─────────────────────────────
            // SYNC SERVICE
            // ─────────────────────────────

            FirebaseSyncService
                .setCurrentUser(
                currentUser.uid);

            final hasBackup =
            await FirebaseSyncService
                .downloadDatabase();

            if (!hasBackup) {

              await FirebaseSyncService
                  .uploadDatabase();
            }
          }

          emit(AuthSuccess(response));

        } catch (e) {

          emit(AuthFailure(
              "Login sync failed: $e"));
        }

      } else {

        emit(AuthFailure(response));
      }
    });
  }
}