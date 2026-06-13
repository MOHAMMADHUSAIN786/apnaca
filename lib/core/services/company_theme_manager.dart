import 'package:flutter/material.dart';
import 'dart:ui';
import 'company_service.dart';

Color _colorFromHex(String hex) {
  final h = hex.replaceAll('#', '').padLeft(6, '0');
  return Color(int.parse('FF$h', radix: 16));
}

class CompanyThemeManager {
  CompanyThemeManager._internal();
  static final CompanyThemeManager instance = CompanyThemeManager._internal();

  final ValueNotifier<ThemeData> themeNotifier = ValueNotifier(ThemeData.light());

  Future<void> reload() async {
    try {
      final dbName = await CompanyService.getCurrentCompanyDbName();
      if (dbName == null) {
        themeNotifier.value = ThemeData.light();
        return;
      }
      final branding = await CompanyService.getBrandingForDb(dbName);
      if (branding == null || branding.isEmpty) {
        themeNotifier.value = ThemeData.light();
        return;
      }
      // simple: look for primaryColor hex in branding
      final primaryHex = (branding['primaryColor'] as String?) ?? branding['primary_color'] as String?;
      final primary = primaryHex != null ? _colorFromHex(primaryHex) : null;
      themeNotifier.value = ThemeData(
        primaryColor: primary ?? Colors.blue,
        colorScheme: (primary != null)
            ? ColorScheme.fromSeed(seedColor: primary)
            : null,
      );
    } catch (_) {
      themeNotifier.value = ThemeData.light();
    }
  }
}
