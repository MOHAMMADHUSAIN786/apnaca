// lib/core/services/in_app_review_service.dart
//
// IN-APP REVIEW SERVICE
// ─────────────────────────────────────────────────────────────────────────────
// Smart review prompt jo sirf tab dikhata hai jab:
//   • App 5+ baar open ho chuki ho
//   • User ne 3+ bills/invoices create kiye hon
//   • Pehle kabhi review nahi diya ya 90 din ho gaye hon
//
// USAGE:
//   // NavBar initState mein (bills create hone ke baad):
//   InAppReviewService.tryRequestReview(context);
//
//   // Bill successfully create hone ke baad:
//   await InAppReviewService.onBillCreated(context);
//
// pubspec.yaml mein add karo:
//   in_app_review: ^2.0.9

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../constants/app_fonts.dart';

class InAppReviewService {
  InAppReviewService._();

  // ── SharedPreferences keys ─────────────────────────────────────────────────
  static const String _keyAppOpenCount    = 'iar_app_open_count';
  static const String _keyBillCount       = 'iar_bill_count';
  static const String _keyLastReviewDate  = 'iar_last_review_date';
  static const String _keyReviewGiven     = 'iar_review_given';

  // ── Thresholds ─────────────────────────────────────────────────────────────
  static const int _minAppOpens  = 5;   // kitni baar app khule
  static const int _minBills     = 3;   // kitne bills bane
  static const int _reviewCooldownDays = 90; // dubara prompt kitne din baad

  // ── App open count increment ───────────────────────────────────────────────
  /// Call this every time NavBar loads (user ka new session)
  static Future<void> incrementAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_keyAppOpenCount) ?? 0) + 1;
    await prefs.setInt(_keyAppOpenCount, count);
    debugPrint('[Review] App open count: $count');
  }

  // ── Bill create hone par call karo ────────────────────────────────────────
  /// Call this after every successful bill/invoice creation
  /// Automatically tries to show review if conditions are met
  static Future<void> onBillCreated(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_keyBillCount) ?? 0) + 1;
    await prefs.setInt(_keyBillCount, count);
    debugPrint('[Review] Bill count: $count');

    // Threshold hit? Try review
    if (count >= _minBills) {
      await tryRequestReview(context);
    }
  }

  // ── Main review trigger ────────────────────────────────────────────────────
  /// Checks all conditions and shows review prompt if eligible
  static Future<void> tryRequestReview(BuildContext context) async {
    if (!Platform.isAndroid) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final appOpens  = prefs.getInt(_keyAppOpenCount) ?? 0;
      final billCount = prefs.getInt(_keyBillCount) ?? 0;
      final lastReviewMs = prefs.getInt(_keyLastReviewDate) ?? 0;
      final reviewGiven  = prefs.getBool(_keyReviewGiven) ?? false;

      // ── Condition 1: Enough app opens ──────────────────────────────
      if (appOpens < _minAppOpens) {
        debugPrint('[Review] Not enough opens ($appOpens < $_minAppOpens)');
        return;
      }

      // ── Condition 2: Enough bills ──────────────────────────────────
      if (billCount < _minBills) {
        debugPrint('[Review] Not enough bills ($billCount < $_minBills)');
        return;
      }

      // ── Condition 3: Cooldown check ────────────────────────────────
      if (reviewGiven || lastReviewMs > 0) {
        final lastDate = DateTime.fromMillisecondsSinceEpoch(lastReviewMs);
        final daysSince = DateTime.now().difference(lastDate).inDays;
        if (daysSince < _reviewCooldownDays) {
          debugPrint('[Review] Cooldown active ($daysSince days since last)');
          return;
        }
      }

      // ── All conditions met → Show review ──────────────────────────
      if (!context.mounted) return;
      await _showReviewFlow(context, prefs);
    } catch (e) {
      debugPrint('[Review] Error: $e');
    }
  }

  // ── Review flow ────────────────────────────────────────────────────────────
  static Future<void> _showReviewFlow(
      BuildContext context, SharedPreferences prefs) async {

    // Pehle custom dialog dikhao — "Kya aapko app pasand hai?"
    final liked = await _showLikeDialog(context);
    if (liked == null) return; // dismissed

    if (liked) {
      // User ko app pasand hai → in_app_review trigger
      await _triggerNativeReview(context, prefs);
    } else {
      // User ko kuch issue hai → feedback dialog
      if (context.mounted) {
        await _showFeedbackDialog(context);
      }
    }
  }

  // ── Native review ──────────────────────────────────────────────────────────
  static Future<void> _triggerNativeReview(
      BuildContext context, SharedPreferences prefs) async {
    try {
      final inAppReview = InAppReview.instance;
      final isAvailable = await inAppReview.isAvailable();

      if (isAvailable) {
        await inAppReview.requestReview();
      } else {
        // Fallback: Play Store khole
        await inAppReview.openStoreListing(appStoreId: '');
      }

      // Save timestamp
      await prefs.setInt(
        _keyLastReviewDate,
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setBool(_keyReviewGiven, true);
      debugPrint('[Review] Review requested successfully');
    } catch (e) {
      debugPrint('[Review] Native review error: $e');
    }
  }

  // ── "Kya app pasand hai?" dialog ───────────────────────────────────────────
  static Future<bool?> _showLikeDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top banner ─────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: const BoxDecoration(
                  color: app_colors.c_primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '😊',
                        style: TextStyle(fontSize: 32),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ApnaCA kaisa lag raha hai?',
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aapka feedback hamare liye bahut zaroori hai',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Buttons ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Yes button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: app_colors.GreenColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Text('👍', style: TextStyle(fontSize: 18)),
                        label: const Text(
                          'Haan, bahut achha hai!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // No button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: app_colors.c_danger,
                          side: BorderSide(
                              color: app_colors.c_danger.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Text('👎', style: TextStyle(fontSize: 18)),
                        label: const Text(
                          'Kuch sudhaar chahiye',
                          style: TextStyle(fontSize: 14),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: Text(
                        'Abhi nahi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Feedback dialog (jab user khush nahi) ─────────────────────────────────
  static Future<void> _showFeedbackDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: app_colors.LightOrange,
                  shape: BoxShape.circle,
                ),
                child: const Text('🙏', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 16),
              Text(
                'Aapka Feedback Sunna Chahte Hain',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: app_colors.title,
                  fontFamily: app_fonts.Bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Aap hamein batayein kya sudhaar kiya jaye — hum zaroor dhyan denge.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: app_colors.c_primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Theek Hai',
                    style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}