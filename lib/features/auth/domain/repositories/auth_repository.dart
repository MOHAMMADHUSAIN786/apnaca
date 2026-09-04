// lib/features/auth/domain/repositories/auth_repository.dart
// UPDATED: activatePendingInvite added in signup — team member invite accept

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../features/team/service/team_service.dart'; // ← NEW

class AuthRepository {

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> signup({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String mobile,
    required String password,
    required String companyName,
  }) async {

    try {

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore
          .collection("users")
          .doc(credential.user!.uid)
          .set({
        "uid": credential.user!.uid,
        "first_name": firstName,
        "last_name": lastName,
        "username": username,
        "email": email.toLowerCase(),
        "mobile": mobile,
        'company_name': companyName,
        "created_at": FieldValue.serverTimestamp(),
      });

      // ─────────────────────────────────────────────────────────
      // TEAM INVITE ACTIVATE — agar ye email kisi company mein
      // invite tha toh automatically active kar do
      // ─────────────────────────────────────────────────────────
      await TeamService.instance.activatePendingInvite(
        credential.user!.uid,
        email.toLowerCase(),
      );

      return "Signup Successful";

    } on FirebaseAuthException catch (e) {

      if (e.code == 'email-already-in-use') return "Email already exists";
      if (e.code == 'invalid-email')         return "Invalid email address";
      if (e.code == 'weak-password')         return "Password is too weak";
      return e.message ?? "Signup Failed";

    } catch (e) {
      return e.toString();
    }
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {

    try {

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return "Login Successful";

    } on FirebaseAuthException catch (e) {

      if (e.code == 'user-not-found')  return "User not found";
      if (e.code == 'wrong-password')  return "Wrong password";
      if (e.code == 'invalid-email')   return "Invalid email";
      return e.message ?? "Login Failed";

    } catch (e) {
      return e.toString();
    }
  }
}
