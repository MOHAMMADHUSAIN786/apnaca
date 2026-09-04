
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../../../core/widgets/common_widgets/app_status_bar.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/widgets/common_widgets/app_loader.dart';
import '../../../../database/app_database.dart';
import '../../admin/presentation/pages/admin_screen.dart';
import '../../auth/presentation/pages/auth_screen.dart';
import '../../company/service/company_service.dart';
import '../../other/nav_bar.dart';
import '../../team/model/team_member_model.dart';
import '../../team/service/team_service.dart';

const String _adminEmail = 'admin@gmail.com';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null)   { _goTo(const AuthScreen());  return; }
    if (user.email?.toLowerCase() == _adminEmail) { _goTo(const AdminScreen()); return; }

    // Default sync user — will be overridden if team member
    FirebaseSyncService.setCurrentUser(user.uid);

    // Check team access
    // getMyTeamAccess() already tries server then cache internally
    // We give it enough time for both attempts
    TeamAccessInfo? teamAccess;
    try {
      teamAccess = await TeamService.instance
          .getMyTeamAccess()
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      print('⚠️ getMyTeamAccess timeout/error: $e');
      // teamAccess remains null → treated as owner
    }

    print('🔑 teamAccess=${teamAccess != null ? "MEMBER(${teamAccess.memberName})" : "OWNER"}');

    if (teamAccess != null) {
      await _initAsTeamMember(user.uid, teamAccess);
    } else {
      await _initAsOwner(user.uid);
    }

    if (!mounted) return;
    _goTo(const NavBar());
  }

  // ════════════════════════════════════════════════════════
  //  OWNER FLOW
  // ════════════════════════════════════════════════════════
  Future<void> _initAsOwner(String uid) async {
    final companies = await CompanyService.instance.getMyCompanies();
    final prefs     = await SharedPreferences.getInstance();
    final savedId   = prefs.getString('active_company_$uid');

    String? targetId;
    if (companies.isNotEmpty) {
      final exists = companies.any((c) => c.id == savedId);
      targetId = exists ? savedId : companies.first.id;
      if (!exists && targetId != null) {
        await prefs.setString('active_company_$uid', targetId);
      }
    }

    // Switch DB
    await AppDatabase.switchUser(uid);
    await AppDatabase.switchCompany(targetId);

    // Download
    try {
      if (targetId != null) {
        await FirebaseSyncService.downloadCompanyDb(uid, targetId)
            .timeout(const Duration(seconds: 10));
      } else {
        await FirebaseSyncService.downloadDatabase()
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {}

    await PermissionService.instance.init();
  }

  // ════════════════════════════════════════════════════════
  //  TEAM MEMBER FLOW
  //  CRITICAL STEPS (order matters):
  //  1. Override sync user to OWNER's uid
  //  2. switchUser(ownerUid) — DB now points to owner's folder
  //  3. switchCompany(companyId) — exact file: billnex_{ownerUid}_{compId}.db
  //  4. downloadCompanyDb(ownerUid, companyId) — download from owner's Storage path
  //  5. PermissionService.init() — caches role/permissions
  // ════════════════════════════════════════════════════════
  Future<void> _initAsTeamMember(String memberUid, TeamAccessInfo teamAccess) async {
    final ownerUid  = teamAccess.ownerUid;
    final companyId = teamAccess.companyId;

    print('👤 Team member login: ${teamAccess.memberName} '
        'owner=$ownerUid company=$companyId');

    // Step 1: Sync service must use OWNER's uid for all Storage operations
    FirebaseSyncService.setCurrentUser(ownerUid);

    // Step 2: Force DB switch to owner's uid — NO early return
    // (AppDatabase.switchUser was fixed to not early-return)
    await AppDatabase.switchUser(ownerUid);

    // Step 3: Switch to the specific company file
    await AppDatabase.switchCompany(companyId);

    // Step 4: Check if local DB file exists
    final dbDir  = await getDatabasesPath();
    final safeId = companyId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final dbName = 'billnex_${ownerUid}_$safeId.db';
    final dbPath = p.join(dbDir, dbName);
    final localExists = File(dbPath).existsSync();

    print('📁 Expected DB path: $dbPath (exists: $localExists)');

    // Step 5: Download owner's company DB from Firebase Storage
    try {
      final ok = await FirebaseSyncService
          .downloadCompanyDb(ownerUid, companyId)
          .timeout(const Duration(seconds: 15));
      print(ok ? '✅ Owner DB downloaded' : '⚠️ Download returned false');
    } catch (e) {
      print('⚠️ DB download failed: $e — using local if available');
    }

    // Step 6: Force DB open so subsequent reads work
    try {
      final db = await AppDatabase.instance.database;
      print('✅ DB opened successfully');
    } catch (e) {
      print('❌ DB open failed: $e');
    }

    // Step 7: Init permissions
    await PermissionService.instance.init();

    print('✅ Team member init complete: '
        'role=${teamAccess.role.name} '
        'canView=${teamAccess.permissions.canViewSaleBills}');
  }

  void _goTo(Widget screen) => Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => screen),
  );

  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: Colors.white,
      child: Scaffold(
        backgroundColor: app_colors.white,
        body: Column(
          children: [
            const Spacer(),
            Center(
              child: Image.asset(
                app_images.app_logo,
                width: 190.w,
                height: 190.h,
              ),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.only(bottom: 30.h),
              child: const AppLoader(),
            ),
          ],
        ),
      ),
    );
  }
}