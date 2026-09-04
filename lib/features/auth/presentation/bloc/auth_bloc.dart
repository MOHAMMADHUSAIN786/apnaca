// lib/features/auth/presentation/bloc/auth_bloc.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/sync_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../database/app_database.dart';
import '../../../company/service/company_service.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {

    // ══════════════════════════════════════════════════════════
    //  SIGNUP
    // ══════════════════════════════════════════════════════════
    on<SignupRequested>((event, emit) async {
      emit(AuthLoading());

      // Validation
      if (event.firstName.isEmpty ||
          event.lastName.isEmpty  ||
          event.username.isEmpty  ||
          event.email.isEmpty     ||
          event.mobile.isEmpty    ||
          event.password.isEmpty  ||
          event.companyName.isEmpty ||
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

      // Step 1: Firebase Auth + Firestore user doc
      final response = await authRepository.signup(
        firstName:   event.firstName,
        lastName:    event.lastName,
        username:    event.username,
        email:       event.email,
        mobile:      event.mobile,
        password:    event.password,
        companyName: event.companyName,
      );

      if (response != "Signup Successful") {
        emit(AuthFailure(response));
        return;
      }

      // Step 2: Create default company + setup DB
      try {
        final user = FirebaseAuth.instance.currentUser!;
        FirebaseSyncService.setCurrentUser(user.uid);

        // ── CREATE DEFAULT COMPANY ──────────────────────────────
        // Signup ke companyName se pehli company Firestore mein banao
        // aur us company ki SQLite DB file switch karo
        await CompanyService.instance.createDefaultCompany(
          uid:         user.uid,
          companyName: event.companyName,
        );
        // After this: AppDatabase.activeCompanyId != null
        // DB file: billnex_{uid}_{companyId}.db
        // ────────────────────────────────────────────────────────

        // Step 3: Save user profile to SQLite (active company DB mein)
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = userDoc.data();
        await AppDatabase.instance.insertOrUpdateUser({
          'firebaseUid': user.uid,
          'email':       data?['email'] ?? '',
          'displayName': "${data?['first_name'] ?? ''} ${data?['last_name'] ?? ''}".trim(),
          'companyName': data?['company_name'] ?? '',
          'mobile':      data?['mobile'] ?? '',
          'username':    data?['username'] ?? '',
          'photo_url':   data?['photo_url'] ?? '',
          'createdAt':   DateTime.now().toIso8601String(),
        });

        // Step 4: Upload fresh DB to Firebase Storage
        await FirebaseSyncService.uploadDatabase();

      } catch (e) {
        // Don't fail signup — user can use the app
        print('⚠️ Post-signup setup error: $e');
      }

      emit(AuthSuccess(response));
    });

    // ══════════════════════════════════════════════════════════
    //  LOGIN
    // ══════════════════════════════════════════════════════════
    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());

      if (event.email.isEmpty || event.password.isEmpty) {
        emit(AuthFailure("Please enter email and password"));
        return;
      }

      final response = await authRepository.login(
        email:    event.email,
        password: event.password,
      );

      if (response != "Login Successful") {
        emit(AuthFailure(response));
        return;
      }

      try {
        final user = FirebaseAuth.instance.currentUser!;

        // Set sync user
        FirebaseSyncService.setCurrentUser(user.uid);

        // Permission check (team member?)
        await PermissionService.instance.init();

        // Switch user DB (default temporarily)
        await AppDatabase.switchUser(user.uid);

        // Save user profile
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = userDoc.data();
        await AppDatabase.instance.insertOrUpdateUser({
          'firebaseUid': user.uid,
          'email':       data?['email'] ?? '',
          'displayName': "${data?['first_name'] ?? ''} ${data?['last_name'] ?? ''}".trim(),
          'companyName': data?['company_name'] ?? '',
          'mobile':      data?['mobile'] ?? '',
          'username':    data?['username'] ?? '',
          'photo_url':   data?['photo_url'] ?? '',
          'createdAt':   DateTime.now().toIso8601String(),
        });

        // Splash screen will load the correct company DB
        // (see splash_screen.dart)

        emit(AuthSuccess(response));

      } catch (e) {
        emit(AuthFailure("Login failed: $e"));
      }
    });
  }
}