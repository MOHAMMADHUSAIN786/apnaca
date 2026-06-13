import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/app_database.dart';

class CompanyService {
  static const _currentCompanyKey = 'current_company_db';

  static Future<List<Map<String, dynamic>>> getAllCompanies() async {
    final db = await AppDatabase.instance.database;
    return await db.query('companies', orderBy: 'id DESC');
  }

  static Future<int> createCompany(String name, {Map<String, dynamic>? branding}) async {
    final db = await AppDatabase.instance.database;
    final dbName = 'company_${DateTime.now().millisecondsSinceEpoch}';
    final data = {
      'name': name,
      'db_name': dbName,
      'branding': branding != null ? jsonEncode(branding) : null,
      'created_at': DateTime.now().toIso8601String(),
    };
    final id = await db.insert('companies', data);
    return id;
  }

  static Future<void> switchCompany(String dbName) async {
    // Persist selected company DB name
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentCompanyKey, dbName);
    // use AppDatabase.switchUser to switch to per-company DB file
    await AppDatabase.switchUser(dbName);
  }

  static Future<void> updateBranding(int companyId, Map<String, dynamic> branding) async {
    final db = await AppDatabase.instance.database;
    await db.update('companies', {'branding': jsonEncode(branding)}, where: 'id = ?', whereArgs: [companyId]);
  }

  static Future<Map<String, dynamic>?> getBrandingForDb(String dbName) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('companies', where: 'db_name = ?', whereArgs: [dbName]);
    if (rows.isEmpty) return null;
    final b = rows.first['branding'] as String?;
    if (b == null) return null;
    try {
      return jsonDecode(b) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getCurrentCompanyDbName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentCompanyKey);
  }
}
