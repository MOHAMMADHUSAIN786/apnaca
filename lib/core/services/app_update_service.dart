import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_fonts.dart';

class AppUpdateService {
  AppUpdateService._();

  // ── Put your Play Store package ID here ─────────────────────────────────
  // Example: 'com.yourcompany.apnahisab'
  static const String _packageId = 'com.mg.apnaca.apnaca'; // ← CHANGE THIS

  // Play Store URL
  static String get _playStoreUrl =>
      'https://play.google.com/store/apps/details?id=$_packageId';

  // ── Main method: call from splash or home ──────────────────────────────────
  /// Checks if a new version is available on Play Store.
  /// [forceUpdate] = true: Cancel button will not appear (mandatory update)
  /// [forceUpdate] = false: user can skip
  static Future<void> checkForUpdate(
      BuildContext context, {
        bool forceUpdate = false,
      }) async {
    // Only check on Android
    if (!Platform.isAndroid) return;

    try {
      // 1. Fetch installed version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.2"

      // 2. Fetch latest version from Play Store
      final storeVersion = await _fetchStoreVersion();
      if (storeVersion == null) return; // fetch fail — silently skip

      // 3. Compare versions
      final hasUpdate = _isNewerVersion(storeVersion, currentVersion);

      if (hasUpdate && context.mounted) {
        _showUpdateDialog(
          context,
          currentVersion: currentVersion,
          storeVersion: storeVersion,
          forceUpdate: forceUpdate,
        );
      }
    } catch (e) {
      debugPrint('AppUpdateService error: $e');
      // Silent fail — app should not crash if update check fails
    }
  }

  // ── Fetch Play Store version ───────────────────────────────────────────────
  /// Scrapes current version from Google Play Store.
  static Future<String?> _fetchStoreVersion() async {
    try {
      final url = Uri.parse(
        'https://play.google.com/store/apps/details?id=$_packageId&hl=en',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // In Play Store HTML, the version is in this format:
        // "softwareVersion":"1.2.3"
        final pattern = RegExp(r'\[\[\["(\d+\.\d+[\.\d]*)"\]\]');
        final match = pattern.firstMatch(response.body);
        if (match != null) return match.group(1);

        // Fallback pattern
        final pattern2 = RegExp(r'"softwareVersion":"([\d.]+)"');
        final match2 = pattern2.firstMatch(response.body);
        if (match2 != null) return match2.group(1);
      }
    } catch (e) {
      debugPrint('Store version fetch error: $e');
    }
    return null;
  }

  // ── Version comparison ─────────────────────────────────────────────────────
  /// Returns true if [storeVersion] > [currentVersion]
  static bool _isNewerVersion(String storeVersion, String currentVersion) {
    try {
      final store = storeVersion.split('.').map(int.parse).toList();
      final current = currentVersion.split('.').map(int.parse).toList();

      // Pad to same length
      while (store.length < current.length) store.add(0);
      while (current.length < store.length) current.add(0);

      for (int i = 0; i < store.length; i++) {
        if (store[i] > current[i]) return true;
        if (store[i] < current[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  // ── Open Play Store ────────────────────────────────────────────────────────
  static Future<void> openPlayStore() async {
    // First try Play Store app, fallback to browser
    final playStoreAppUri = Uri.parse('market://details?id=$_packageId');
    final playStoreBrowserUri = Uri.parse(_playStoreUrl);

    try {
      if (await canLaunchUrl(playStoreAppUri)) {
        await launchUrl(playStoreAppUri);
      } else {
        await launchUrl(playStoreBrowserUri,
            mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(playStoreBrowserUri,
          mode: LaunchMode.externalApplication);
    }
  }

  // ── Update Dialog ──────────────────────────────────────────────────────────
  static void _showUpdateDialog(
      BuildContext context, {
        required String currentVersion,
        required String storeVersion,
        required bool forceUpdate,
      }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate, // on force update, cannot dismiss by tapping background
      builder: (_) => _UpdateDialog(
        currentVersion: currentVersion,
        storeVersion: storeVersion,
        forceUpdate: forceUpdate,
      ),
    );
  }
}

// ── Update Dialog Widget ───────────────────────────────────────────────────────
class _UpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String storeVersion;
  final bool forceUpdate;

  const _UpdateDialog({
    required this.currentVersion,
    required this.storeVersion,
    required this.forceUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !forceUpdate, // block back button on forceUpdate
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top blue banner ─────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: app_colors.c_primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'New Update Available!',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Update for a better experience',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Version info ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _versionBox(
                            label: 'Current Version',
                            version: 'v$currentVersion',
                            color: app_colors.c_danger.withOpacity(0.1),
                            textColor: app_colors.c_danger,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _versionBox(
                            label: 'New Version',
                            version: 'v$storeVersion',
                            color: app_colors.LightGreen,
                            textColor: app_colors.GreenColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // What's new section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: app_colors.Dborder_color),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  color: app_colors.c_primary, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'In this update:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: app_colors.title,
                                  fontFamily: app_fonts.Bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _bulletPoint('Bug fixes and performance improvements'),
                          _bulletPoint('New features or UI improvements'),
                          _bulletPoint('Security updates'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Buttons ─────────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: app_colors.c_primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: const Text(
                          'Update Now',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          AppUpdateService.openPlayStore();
                        },
                      ),
                    ),

                    if (!forceUpdate) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade500,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: app_colors.Dborder_color),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Later',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],

                    if (forceUpdate) ...[
                      const SizedBox(height: 10),
                      Text(
                        'You need to update the app to continue using it.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _versionBox({
    required String label,
    required String version,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            version,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 14, color: app_colors.GreenColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}