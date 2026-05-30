import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Handles company logo & signature images in Firebase Storage.
///
/// Storage paths (per user):
///   users/{uid}/branding/company_logo.jpg
///   users/{uid}/branding/signature.jpg
class BrandingStorageService {
  static final _storage = FirebaseStorage.instance;
  static final _auth    = FirebaseAuth.instance;

  // ── Path helpers ────────────────────────────────────────────────────────────
  static String? get _uid => _auth.currentUser?.uid;

  static Reference? get _logoRef => _uid != null
      ? _storage.ref('users/$_uid/branding/company_logo.jpg')
      : null;

  static Reference? get _sigRef => _uid != null
      ? _storage.ref('users/$_uid/branding/signature.jpg')
      : null;

  // ── Check if branding assets exist in Storage ───────────────────────────────
  /// Returns download URL string if file exists, empty string '' if not found.
  static Future<String> checkLogoUrl() async {
    try {
      return await _logoRef?.getDownloadURL() ?? '';
    } on FirebaseException {
      return ''; // object-not-found → first time user
    }
  }

  static Future<String> checkSignatureUrl() async {
    try {
      return await _sigRef?.getDownloadURL() ?? '';
    } on FirebaseException {
      return '';
    }
  }

  /// Checks both at once. Returns map with 'logo' and 'signature' keys.
  /// Values are download URLs or '' if not uploaded yet.
  static Future<Map<String, String>> checkBothUrls() async {
    final results = await Future.wait([checkLogoUrl(), checkSignatureUrl()]);
    return {'logo': results[0], 'signature': results[1]};
  }

  // ── Upload ──────────────────────────────────────────────────────────────────
  /// Uploads logo to Firebase Storage, returns download URL.
  static Future<String> uploadLogo(File imageFile) async {
    if (_logoRef == null) throw Exception('User not logged in');
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await _logoRef!.putFile(imageFile, metadata);
    return await _logoRef!.getDownloadURL();
  }

  /// Uploads signature to Firebase Storage, returns download URL.
  static Future<String> uploadSignature(File imageFile) async {
    if (_sigRef == null) throw Exception('User not logged in');
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await _sigRef!.putFile(imageFile, metadata);
    return await _sigRef!.getDownloadURL();
  }

  // ── Delete (optional, for settings screen) ─────────────────────────────────
  static Future<void> deleteLogo() async {
    try { await _logoRef?.delete(); } catch (_) {}
  }

  static Future<void> deleteSignature() async {
    try { await _sigRef?.delete(); } catch (_) {}
  }
}
