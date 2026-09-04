// lib/core/widgets/common_widgets/app_sidebar.dart

import 'package:apnaca/features/supplier/presentation/pages/supplier_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/services/sync_service.dart';
import '../../../database/app_database.dart';
import '../../../features/auth/presentation/pages/auth_screen.dart';
import '../../../features/company/model/company_model.dart';
import '../../../features/company/presentation/pages/company_screen.dart';
import '../../../features/company/service/company_service.dart';
import '../../../features/contact_us/contactus_screen.dart';
import '../../../features/customer/presentation/pages/customer_screen.dart';
import '../../../features/feedback/feedback_screen.dart';
import '../../../features/other/nav_bar.dart';
import '../../../features/profile/presentation/pages/profile_screen.dart';
import '../../../features/setting/presentation/pages/setting_screen.dart';
import '../../../features/subscription/model/subscription_model.dart';
import '../../../features/subscription/presentation/pages/subscription_screen.dart';
import '../../../features/subscription/service/subscription_service.dart';
import '../../../features/warehouse/presentation/pages/warehouse_screen.dart';
import '../../services/permission_service.dart';

class AppSideBar extends StatefulWidget {
  final VoidCallback? onRefreshAll;
  const AppSideBar({super.key, this.onRefreshAll});

  @override
  State<AppSideBar> createState() => _AppSideBarState();
}

class _AppSideBarState extends State<AppSideBar> {
  Map<String, dynamic>? userData;
  SubscriptionModel? _sub;
  List<CompanyModel> _companies = [];
  String? _activeCompanyId;
  bool _loadingCompanies = false;
  bool _switching = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _resolveActiveCompany();
    await Future.wait([_fetchUser(), _fetchSubAndCompanies()]);
  }

  Future<void> _resolveActiveCompany() async {
    final runtimeId = AppDatabase.activeCompanyId;
    if (runtimeId != null) {
      _activeCompanyId = runtimeId;
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('active_company_$uid');
      if (savedId != null && savedId.isNotEmpty) {
        await AppDatabase.switchCompany(savedId);
        _activeCompanyId = savedId;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() { userData = doc.data(); isLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchSubAndCompanies() async {
    try {
      final sub = await SubscriptionService.instance.getSubscription();
      if (mounted) setState(() => _sub = sub);
    } catch (_) {}
    await _fetchCompanies();
  }

  Future<void> _fetchCompanies() async {
    if (mounted) setState(() => _loadingCompanies = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final list = await CompanyService.instance.getMyCompanies();
      String? confirmedActive = _activeCompanyId;
      if (confirmedActive != null) {
        final stillExists = list.any((c) => c.id == confirmedActive);
        if (!stillExists) confirmedActive = list.isNotEmpty ? list.first.id : null;
      } else if (list.isNotEmpty) {
        confirmedActive = list.first.id;
        if (AppDatabase.activeCompanyId != confirmedActive) {
          await AppDatabase.switchCompany(confirmedActive);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('active_company_$uid', confirmedActive!);
        }
      }
      if (mounted) {
        setState(() {
          _companies = list;
          _activeCompanyId = confirmedActive;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingCompanies = false);
  }

  Future<void> _switchTo(String? companyId) async {
    if (_switching || companyId == _activeCompanyId) return;
    setState(() => _switching = true);
    try {
      await CompanyService.instance.switchToCompany(companyId);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final prefs = await SharedPreferences.getInstance();
        if (companyId != null) {
          await prefs.setString('active_company_$uid', companyId);
        } else {
          await prefs.remove('active_company_$uid');
        }
      }
      if (mounted) {
        setState(() {
          _activeCompanyId = companyId;
          _switching = false;
        });
        Navigator.pop(context);
        context.visitAncestorElements((el) {
          if (el.widget is NavBar) {
            ((el as StatefulElement).state as NavBarState?)?.refreshAllScreens();
            return false;
          }
          return true;
        });
        widget.onRefreshAll?.call();
        final name = companyId == null
            ? 'Default'
            : _companies
            .firstWhere((c) => c.id == companyId,
            orElse: () => CompanyModel(
                id: '', ownerUid: '', name: '?',
                createdAt: DateTime.now()))
            .name;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8.w),
            Text('Switched to "$name"',
                style: const TextStyle(color: Colors.white)),
          ]),
          backgroundColor: const Color(0xFF15CA20),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _switching = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Switch failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _manualBackup(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final ok = await FirebaseSyncService.uploadDatabase();
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Backup successful!' : 'Backup failed'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _restoreData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Data?'),
        content: const Text('This will replace local data with cloud backup.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final ok = await FirebaseSyncService.downloadDatabase();
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Data restored!' : 'No backup found'),
        backgroundColor: ok ? Colors.green : Colors.orange,
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  LOGOUT — FIXED
  //  1. uploadBeforeLogout has a 5s timeout so it never hangs
  //  2. Drawer is closed BEFORE navigation to avoid context issues
  //  3. pushAndRemoveUntil uses root navigator to clear full stack
  // ─────────────────────────────────────────────────────────────
  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // Show loading overlay
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      // 1. Upload with timeout — never hang on slow network
      await FirebaseSyncService.uploadBeforeLogout()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);

      // 2. Clear local DB
      await AppDatabase.instance.clearAllData();

      // 3. Clear caches
      SubscriptionService.instance.clearCache();

      // 4. Firebase sign out
      await FirebaseAuth.instance.signOut();

      // 5. Reset sync service
      FirebaseSyncService.setCurrentUser('');
    } catch (e) {
      debugPrint('Logout cleanup error: $e');
      // Even if cleanup fails, we still sign out
      try { await FirebaseAuth.instance.signOut(); } catch (_) {}
    }

    // 6. Navigate — use root navigator to clear entire stack
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
            (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = userData?['first_name'] ?? '';
    final lastName  = userData?['last_name']  ?? '';
    final fullName  = '$firstName $lastName'.trim();
    final email     = userData?['email'] ?? '';
    final photoUrl  = userData?['photo_url'];
    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0].toUpperCase();
    if (lastName.isNotEmpty)  initials += lastName[0].toUpperCase();

    // Company name display:
    // - Owner: active company name from _companies list
    // - Team member: company name from teamAccess (owner ki company)
    String companyDisplayName = '';
    if (PermissionService.instance.isTeamMember) {
      // Team member — find company name from loaded companies or teamAccess
      final companyId = PermissionService.instance.teamAccess?.companyId ?? '';
      final match = _companies.where((c) => c.id == companyId).toList();
      if (match.isNotEmpty) {
        companyDisplayName = match.first.name;
      } else {
        // Fallback: fetch from Firestore inline would be async, so use cached
        companyDisplayName = userData?['company_name'] ?? '';
      }
    } else {
      // Owner — show active company
      if (_activeCompanyId != null) {
        final match = _companies.where((c) => c.id == _activeCompanyId).toList();
        if (match.isNotEmpty) companyDisplayName = match.first.name;
      }
      // Fallback to user's default company_name
      if (companyDisplayName.isEmpty) {
        companyDisplayName = userData?['company_name'] ?? '';
      }
    }

    return Drawer(
      width: 260.w,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: app_colors.table_header_bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────
          Theme(
            data: Theme.of(context).copyWith(
              dividerTheme: const DividerThemeData(color: Colors.transparent),
            ),
            child: DrawerHeader(
              decoration: BoxDecoration(color: app_colors.table_header_bg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 25.r,
                    backgroundColor: Colors.white,
                    backgroundImage:
                    photoUrl != null && photoUrl.toString().isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null || photoUrl.toString().isEmpty
                        ? Text(
                      initials.isEmpty ? 'U' : initials,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: app_colors.black,
                      ),
                    )
                        : null,
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    fullName.isEmpty ? 'User' : fullName,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16.sp,
                      fontFamily: app_fonts.Medium,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 10.sp,
                      fontFamily: app_fonts.Regular,
                    ),
                  ),
                  // Company name below email
                  if (companyDisplayName.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(Icons.business_outlined,
                            size: 11.sp, color: Colors.black45),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            companyDisplayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 11.sp,
                              fontFamily: app_fonts.Medium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_companies.isNotEmpty) ...[
            _CompanySwitcherSection(
              companies: _companies,
              activeCompanyId: _activeCompanyId,
              loading: _loadingCompanies || _switching,
              onSwitch: _switchTo,
            ),
          ],

          Container(
            width: double.infinity,
            height: 1,
            color: Colors.grey.shade400,
          ),

          // ── Menu Items ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTile(
                    icon: Icons.people_outline,
                    label: 'Customers',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CustomerScreen())),
                  ),
                  _buildTile(
                    icon: Icons.local_shipping_outlined,
                    label: 'Suppliers',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SupplierScreen())),
                  ),
                  _buildTile(
                    icon: Icons.business_outlined,
                    label: 'Companies',
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const CompanyScreen()));
                      _fetchCompanies();
                    },
                  ),
                  _buildTile(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Subscription',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
                  ),
                  _buildTile(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  ),
                  _buildTile(
                    icon: Icons.backup_outlined,
                    label: 'Backup Now',
                    onTap: () => _manualBackup(context),
                  ),
                  _buildTile(
                    icon: Icons.restore_outlined,
                    label: 'Restore Data',
                    onTap: () => _restoreData(context),
                  ),
                  _buildTile(
                    icon: Icons.contact_support_outlined,
                    label: 'Contact Us',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ContactUsScreen())),
                  ),
                  _buildTile(
                    icon: Icons.star_outline,
                    label: 'Feedback',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const FeedbackScreen())),
                  ),
                  _buildLogoutTile(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        child: Icon(icon, color: app_colors.black, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14.sp,
          fontFamily: app_fonts.Regular,
          color: app_colors.black,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return ListTile(
      leading: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        child: const Icon(Icons.logout, color: Colors.red, size: 20),
      ),
      title: Text(
        'Logout',
        style: TextStyle(
          fontSize: 14.sp,
          fontFamily: app_fonts.Regular,
          color: Colors.red,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () => _logout(context),
    );
  }
}

// ── Company Switcher Section ──────────────────────────────────────
class _CompanySwitcherSection extends StatelessWidget {
  final List<CompanyModel> companies;
  final String? activeCompanyId;
  final bool loading;
  final Future<void> Function(String?) onSwitch;

  const _CompanySwitcherSection({
    required this.companies,
    required this.activeCompanyId,
    required this.loading,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: app_colors.table_header_bg,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business_outlined, size: 13.sp, color: Colors.black54),
              SizedBox(width: 5.w),
              Text(
                'Active Company',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.black54,
                  fontFamily: app_fonts.Regular,
                  letterSpacing: 0.3,
                ),
              ),
              if (loading) ...[
                const Spacer(),
                SizedBox(
                  width: 12.w, height: 12.h,
                  child: const CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black54),
                ),
              ],
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: companies.map((company) {
              final isActive = company.id == activeCompanyId;
              return GestureDetector(
                onTap: (loading || isActive) ? null : () => onSwitch(company.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isActive ? Colors.black : Colors.grey.shade400,
                      width: isActive ? 1.5 : 1,
                    ),
                    boxShadow: isActive
                        ? [BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive) ...[
                        Icon(Icons.check, size: 12.sp, color: Colors.white),
                        SizedBox(width: 4.w),
                      ],
                      Text(
                        company.name,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isActive ? Colors.white : Colors.black87,
                          fontFamily: isActive ? app_fonts.Medium : app_fonts.Regular,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}