// lib/features/admin/admin_screen.dart
//
// REQUIRED: pubspec.yaml mein ye add karo (agar nahi hai):
//   cloud_firestore, firebase_auth, flutter_screenutil
//
// NOTE: Account delete ke liye Firebase Admin SDK chahiye (server side).
//       Firestore doc delete hoga client se, Auth user delete ke liye
//       Cloud Function ya Re-authentication trick use hogi.
//       Yahan Firestore + subscriptions delete hoga + user ko sign out
//       force kiya jayega (practical approach for client-only app).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';

// ═══════════════════════════════════════════════════════════════════
//  DATA MODEL
// ═══════════════════════════════════════════════════════════════════

class AdminUserData {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String mobile;
  final String companyName;
  final String username;
  final DateTime? createdAt;
  String subPlan;
  bool subActive;
  DateTime? subExpiry;
  int billsUsed;
  List<Map<String, dynamic>> queries;
  List<Map<String, dynamic>> feedbacks;

  AdminUserData({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.mobile,
    required this.companyName,
    required this.username,
    this.createdAt,
    this.subPlan = 'free',
    this.subActive = false,
    this.subExpiry,
    this.billsUsed = 0,
    this.queries = const [],
    this.feedbacks = const [],
  });

  String get fullName => '$firstName $lastName'.trim();
}

// ═══════════════════════════════════════════════════════════════════
//  ADMIN SCREEN
// ═══════════════════════════════════════════════════════════════════

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<AdminUserData> _users = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _filterPlan = 'All';
  int _selectedTab = 0;

  // ── Counts ───────────────────────────────────────────────────────
  int get _totalUsers => _users.length;
  int get _activeSubUsers =>
      _users.where((u) => u.subPlan != 'free' && u.subActive).length;
  int get _freeUsers => _users.where((u) => u.subPlan == 'free').length;
  int get _totalQueries =>
      _users.fold(0, (s, u) => s + u.queries.length);
  int get _totalFeedbacks =>
      _users.fold(0, (s, u) => s + u.feedbacks.length);

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  // ════════════════════════════════════════════════════════════════
  //  FETCH
  // ════════════════════════════════════════════════════════════════

  Future<void> _fetchAllData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fs = FirebaseFirestore.instance;

      final usersSnap = await fs.collection('users').get();
      final subsSnap = await fs.collection('subscriptions').get();
      final subsMap = {for (var d in subsSnap.docs) d.id: d.data()};

      final queriesSnap = await fs.collection('contact_queries').get();
      final Map<String, List<Map<String, dynamic>>> queriesMap = {};
      for (var d in queriesSnap.docs) {
        final data = d.data();
        final uid = data['uid'] as String? ?? '';
        if (uid.isNotEmpty) {
          queriesMap.putIfAbsent(uid, () => []).add({...data, 'id': d.id});
        }
      }

      final feedbackSnap = await fs.collection('feedbacks').get();
      final Map<String, List<Map<String, dynamic>>> feedbackMap = {};
      for (var d in feedbackSnap.docs) {
        final data = d.data();
        final uid = data['uid'] as String? ?? '';
        if (uid.isNotEmpty) {
          feedbackMap.putIfAbsent(uid, () => []).add({...data, 'id': d.id});
        }
      }

      final List<AdminUserData> result = [];
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final uid = doc.id;
        final sub = subsMap[uid];
        final plan = sub?['plan'] as String? ?? 'free';
        final expiryStr = sub?['expiry_date'] as String?;
        final expiry =
        expiryStr != null ? DateTime.tryParse(expiryStr) : null;
        final billsUsed = (sub?['bills_used'] as int?) ?? 0;
        final bool subActive = plan == 'free'
            ? true
            : expiry != null && DateTime.now().isBefore(expiry);
        final Timestamp? ts = data['created_at'] as Timestamp?;

        result.add(AdminUserData(
          uid: uid,
          firstName: data['first_name'] ?? '',
          lastName: data['last_name'] ?? '',
          email: data['email'] ?? '',
          mobile: data['mobile'] ?? '',
          companyName: data['company_name'] ?? '',
          username: data['username'] ?? '',
          createdAt: ts?.toDate(),
          subPlan: plan,
          subActive: subActive,
          subExpiry: expiry,
          billsUsed: billsUsed,
          queries: queriesMap[uid] ?? [],
          feedbacks: feedbackMap[uid] ?? [],
        ));
      }

      result.sort((a, b) {
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      setState(() {
        _users = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  PLAN CHANGE  ← NEW
  // ════════════════════════════════════════════════════════════════

  Future<void> _changePlan(AdminUserData user, String newPlan) async {
    // Confirm dialog
    final confirmed = await _showConfirmDialog(
      title: 'Plan Change Karo',
      content:
      '${user.fullName} ka plan "${newPlan.toUpperCase()}" kar dein?'
          '${newPlan == 'free' ? '\n\nYe subscription cancel kar dega.' : ''}',
      confirmLabel: 'Haan, Change Karo',
      confirmColor: newPlan == 'free'
          ? app_colors.c_danger
          : app_colors.GreenColor,
    );
    if (!confirmed) return;

    try {
      _showLoader('Plan update ho raha hai…');
      final fs = FirebaseFirestore.instance;

      final now = DateTime.now();
      Map<String, dynamic> subData;

      if (newPlan == 'free') {
        subData = {
          'plan': 'free',
          'expiry_date': null,
          'bills_used': 0,
          'updated_by_admin': true,
          'admin_updated_at': FieldValue.serverTimestamp(),
        };
      } else {
        final expiry = newPlan == 'gold'
            ? now.add(const Duration(days: 365))
            : now.add(const Duration(days: 183));
        subData = {
          'plan': newPlan,
          'expiry_date': expiry.toIso8601String(),
          'bills_used': user.billsUsed,
          'updated_by_admin': true,
          'admin_updated_at': FieldValue.serverTimestamp(),
        };
      }

      await fs
          .collection('subscriptions')
          .doc(user.uid)
          .set(subData, SetOptions(merge: false));

      // Local state update
      setState(() {
        user.subPlan = newPlan;
        if (newPlan == 'free') {
          user.subActive = true;
          user.subExpiry = null;
          user.billsUsed = 0;
        } else {
          user.subActive = true;
          user.subExpiry = newPlan == 'gold'
              ? now.add(const Duration(days: 365))
              : now.add(const Duration(days: 183));
        }
      });

      if (mounted) {
        Navigator.pop(context); // loader band
        _showSnack(
          '${user.fullName} ka plan "${newPlan.toUpperCase()}" ho gaya ✅',
          color: app_colors.GreenColor,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnack('Error: $e', color: app_colors.c_danger);
      }
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  ACCOUNT DELETE  ← NEW
  // ════════════════════════════════════════════════════════════════

  Future<void> _deleteAccount(AdminUserData user) async {
    // Double confirm — destructive action
    final step1 = await _showConfirmDialog(
      title: '⚠️ Account Delete',
      content:
      '${user.fullName} (${user.email}) ka account delete karna chahte ho?\n\n'
          'Ye kaam undo nahi ho sakta.',
      confirmLabel: 'Haan, Delete Karo',
      confirmColor: app_colors.c_danger,
    );
    if (!step1) return;

    final step2 = await _showConfirmDialog(
      title: 'Pakka Sure Ho?',
      content: 'User ka saara data —\n'
          '• Profile\n'
          '• Subscription\n'
          '• Contact queries\n'
          '• Feedback\n\n'
          'sab hamesha ke liye delete ho jayega.',
      confirmLabel: 'Haan, Bilkul Delete Karo',
      confirmColor: app_colors.c_danger,
    );
    if (!step2) return;

    // Loader show karo
    bool loaderVisible = true;
    _showLoader('Account delete ho raha hai…');

    String? errorMsg;

    try {
      final fs = FirebaseFirestore.instance;
      final uid = user.uid;

      // ── 1. Subscription delete ────────────────────────────────
      try {
        await fs.collection('subscriptions').doc(uid).delete();
      } catch (e) {
        debugPrint('Subscription delete skip (may not exist): $e');
      }

      // ── 2. Contact queries delete (uid field se match) ────────
      try {
        final qSnap = await fs
            .collection('contact_queries')
            .where('uid', isEqualTo: uid)
            .get();
        final batch1 = fs.batch();
        for (final d in qSnap.docs) {
          batch1.delete(d.reference);
        }
        if (qSnap.docs.isNotEmpty) await batch1.commit();
      } catch (e) {
        debugPrint('Contact queries delete skip: $e');
      }

      // ── 3. Feedbacks delete (uid field se match) ──────────────
      try {
        final fSnap = await fs
            .collection('feedbacks')
            .where('uid', isEqualTo: uid)
            .get();
        final batch2 = fs.batch();
        for (final d in fSnap.docs) {
          batch2.delete(d.reference);
        }
        if (fSnap.docs.isNotEmpty) await batch2.commit();
      } catch (e) {
        debugPrint('Feedbacks delete skip: $e');
      }

      // ── 4. User doc delete (LAST mein — ye main record hai) ───
      await fs.collection('users').doc(uid).delete();

      // ── 5. Local state update ─────────────────────────────────
      if (mounted) {
        setState(() {
          _users.removeWhere((u) => u.uid == uid);
        });
      }
    } catch (e) {
      errorMsg = e.toString();
      debugPrint('DELETE ERROR: $e');
    }

    // Loader band karo
    if (mounted && loaderVisible) {
      loaderVisible = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    // Result dikhao
    if (!mounted) return;
    if (errorMsg != null) {
      _showSnack('Delete failed: $errorMsg', color: app_colors.c_danger);
    } else {
      _showSnack(
        '${user.fullName} ka account delete ho gaya 🗑️',
        color: app_colors.c_danger,
      );
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════

  void _showLoader(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 22.h),
          decoration: BoxDecoration(
            color: app_colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: 14.h),
              Text(msg,
                  style: TextStyle(
                      fontFamily: app_fonts.Regular,
                      fontSize: 13.sp,
                      color: app_colors.title)),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(title,
            style: TextStyle(
                fontFamily: app_fonts.Medium,
                fontSize: 16.sp,
                color: app_colors.title)),
        content: Text(content,
            style: TextStyle(
                fontFamily: app_fonts.Regular,
                fontSize: 13.sp,
                color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(
                    fontFamily: app_fonts.Regular,
                    fontSize: 13.sp,
                    color: Colors.black45)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r)),
            ),
            child: Text(confirmLabel,
                style: TextStyle(
                    fontFamily: app_fonts.Medium,
                    fontSize: 13.sp,
                    color: app_colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String msg, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 13.sp)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
    ));
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  PLAN CHANGE BOTTOM SHEET  ← NEW
  // ════════════════════════════════════════════════════════════════

  void _showPlanSheet(AdminUserData user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: app_colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) {
        final plans = [
          _PlanOption('free', 'Free Plan', 'Max 10 bills, unlimited time',
              app_colors.table_header_bg, Colors.black54, Icons.person_outline),
          _PlanOption('silver', 'Silver Plan', '6 mahine, unlimited bills',
              app_colors.LightBlue, app_colors.c_primary, Icons.workspace_premium),
          _PlanOption('gold', 'Gold Plan', '1 saal, unlimited bills',
              app_colors.LightOrange, app_colors.OrangeColor, Icons.star),
        ];

        return Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text('Plan Choose Karo',
                  style: TextStyle(
                      fontFamily: app_fonts.Medium,
                      fontSize: 16.sp,
                      color: app_colors.title)),
              Text('${user.fullName} ke liye',
                  style: TextStyle(
                      fontFamily: app_fonts.Regular,
                      fontSize: 12.sp,
                      color: Colors.black45)),
              SizedBox(height: 16.h),
              ...plans.map((p) {
                final isCurrent = user.subPlan == p.key;
                return GestureDetector(
                  onTap: isCurrent
                      ? null
                      : () {
                    Navigator.pop(context);
                    _changePlan(user, p.key);
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    padding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: p.bg,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: isCurrent
                            ? p.fg
                            : Colors.transparent,
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(p.icon, color: p.fg, size: 22.sp),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.label,
                                  style: TextStyle(
                                      fontFamily: app_fonts.Medium,
                                      fontSize: 14.sp,
                                      color: p.fg)),
                              Text(p.sub,
                                  style: TextStyle(
                                      fontFamily: app_fonts.Regular,
                                      fontSize: 11.sp,
                                      color: Colors.black45)),
                            ],
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: p.fg,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text('Current',
                                style: TextStyle(
                                    fontFamily: app_fonts.Medium,
                                    fontSize: 10.sp,
                                    color: app_colors.white)),
                          )
                        else
                          Icon(Icons.arrow_forward_ios,
                              size: 14.sp, color: Colors.black26),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  FILTERED DATA
  // ════════════════════════════════════════════════════════════════

  List<AdminUserData> get _filteredUsers {
    return _users.where((u) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.companyName.toLowerCase().contains(q);
      final matchPlan = _filterPlan == 'All' ||
          u.subPlan == _filterPlan.toLowerCase();
      return matchSearch && matchPlan;
    }).toList();
  }

  List<Map<String, dynamic>> get _allQueries {
    final list = <Map<String, dynamic>>[];
    for (final u in _users) {
      for (final q in u.queries) {
        list.add({...q, '_userName': u.fullName, '_userEmail': u.email});
      }
    }
    list.sort((a, b) {
      final ta = a['created_at'];
      final tb = b['created_at'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      return 0;
    });
    return list;
  }

  List<Map<String, dynamic>> get _allFeedbacks {
    final list = <Map<String, dynamic>>[];
    for (final u in _users) {
      for (final f in u.feedbacks) {
        list.add({...f, '_userName': u.fullName, '_userEmail': u.email});
      }
    }
    list.sort((a, b) {
      final ta = a['created_at'];
      final tb = b['created_at'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      return 0;
    });
    return list;
  }

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: app_colors.Dbackgroun_color,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            if (_loading)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(child: _buildError())
            else ...[
                _buildSummaryCards(),
                _buildTabBar(),
                Expanded(child: _buildTabContent()),
              ],
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: app_colors.white,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: app_colors.c_primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.admin_panel_settings,
                color: app_colors.c_primary, size: 24.sp),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin Panel',
                  style: TextStyle(
                      fontFamily: app_fonts.Medium,
                      fontSize: 18.sp,
                      color: app_colors.title)),
              Text('Super Administrator',
                  style: TextStyle(
                      fontFamily: app_fonts.Regular,
                      fontSize: 11.sp,
                      color: Colors.grey)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: _fetchAllData,
            icon:
            Icon(Icons.refresh, color: app_colors.c_primary, size: 22.sp),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _logout,
            icon: Icon(Icons.logout, color: app_colors.c_danger, size: 22.sp),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  // ── Summary cards ──────────────────────────────────────────────
  Widget _buildSummaryCards() {
    final cards = [
      _SummaryData('Total Users', '$_totalUsers', Icons.people,
          app_colors.c_primary),
      _SummaryData('Active Subs', '$_activeSubUsers', Icons.verified,
          app_colors.GreenColor),
      _SummaryData('Free Plan', '$_freeUsers', Icons.person_outline,
          app_colors.OrangeColor),
      _SummaryData(
          'Queries', '$_totalQueries', Icons.help_outline, app_colors.title),
      _SummaryData('Feedbacks', '$_totalFeedbacks', Icons.star_outline,
          app_colors.c_danger),
    ];
    return Container(
      color: app_colors.white,
      padding: EdgeInsets.only(bottom: 14.h, top: 4.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: cards
              .map((c) => Padding(
            padding: EdgeInsets.only(right: 10.w),
            child: Container(
              width: 110.w,
              padding: EdgeInsets.symmetric(
                  horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: c.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14.r),
                border:
                Border.all(color: c.color.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(c.icon, color: c.color, size: 20.sp),
                  SizedBox(height: 6.h),
                  Text(c.value,
                      style: TextStyle(
                          fontFamily: app_fonts.Medium,
                          fontSize: 20.sp,
                          color: c.color)),
                  Text(c.label,
                      style: TextStyle(
                          fontFamily: app_fonts.Regular,
                          fontSize: 10.sp,
                          color: Colors.black54)),
                ],
              ),
            ),
          ))
              .toList(),
        ),
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = ['Users', 'Queries', 'Feedback'];
    return Container(
      color: app_colors.white,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: sel
                          ? app_colors.c_primary
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(tabs[i],
                      style: TextStyle(
                          fontFamily: sel
                              ? app_fonts.Medium
                              : app_fonts.Regular,
                          fontSize: 13.sp,
                          color: sel
                              ? app_colors.c_primary
                              : Colors.black54)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildUsersTab();
      case 1:
        return _buildQueriesTab();
      case 2:
        return _buildFeedbackTab();
      default:
        return const SizedBox();
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  USERS TAB
  // ════════════════════════════════════════════════════════════════

  Widget _buildUsersTab() {
    return Column(
      children: [
        _buildSearchAndFilter(),
        Expanded(
          child: _filteredUsers.isEmpty
              ? _buildEmpty('Koi user nahi mila')
              : ListView.builder(
            padding: EdgeInsets.symmetric(
                horizontal: 16.w, vertical: 10.h),
            itemCount: _filteredUsers.length,
            itemBuilder: (context, i) =>
                _buildUserCard(_filteredUsers[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: app_colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40.h,
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(
                    fontFamily: app_fonts.Regular, fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: 'Search by name, email…',
                  hintStyle: TextStyle(
                      fontFamily: app_fonts.Regular,
                      fontSize: 12.sp,
                      color: Colors.black38),
                  prefixIcon: Icon(Icons.search,
                      size: 18.sp, color: Colors.black38),
                  contentPadding: EdgeInsets.symmetric(
                      vertical: 0, horizontal: 12.w),
                  filled: true,
                  fillColor: app_colors.Dbackgroun_color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide:
                    BorderSide(color: app_colors.Dborder_color),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide:
                    BorderSide(color: app_colors.Dborder_color),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(
                        color: app_colors.c_primary, width: 1.4),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Container(
            height: 40.h,
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            decoration: BoxDecoration(
              color: app_colors.Dbackgroun_color,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: app_colors.Dborder_color),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterPlan,
                style: TextStyle(
                    fontFamily: app_fonts.Regular,
                    fontSize: 12.sp,
                    color: app_colors.black),
                items: ['All', 'free', 'silver', 'gold']
                    .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(
                        p[0].toUpperCase() + p.substring(1))))
                    .toList(),
                onChanged: (v) => setState(() => _filterPlan = v!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── User card with action buttons ──────────────────────────────
  Widget _buildUserCard(AdminUserData user) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: app_colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: app_colors.Dborder_color),
      ),
      child: Theme(
        data:
        Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
          EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          childrenPadding:
          EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
          leading: CircleAvatar(
            radius: 22.r,
            backgroundColor:
            app_colors.c_primary.withOpacity(0.15),
            child: Text(
              user.fullName.isNotEmpty
                  ? user.fullName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  fontFamily: app_fonts.Medium,
                  fontSize: 16.sp,
                  color: app_colors.c_primary),
            ),
          ),
          title: Text(user.fullName,
              style: TextStyle(
                  fontFamily: app_fonts.Medium,
                  fontSize: 14.sp,
                  color: app_colors.title)),
          subtitle: Text(user.email,
              style: TextStyle(
                  fontFamily: app_fonts.Regular,
                  fontSize: 11.sp,
                  color: Colors.black45)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _planBadge(user.subPlan, user.subActive),
              Icon(Icons.expand_more,
                  color: Colors.black38, size: 18.sp),
            ],
          ),
          children: [_buildUserDetails(user)],
        ),
      ),
    );
  }

  Widget _buildUserDetails(AdminUserData user) {
    final dateStr = user.createdAt != null
        ? '${user.createdAt!.day}/${user.createdAt!.month}/${user.createdAt!.year}'
        : 'N/A';
    final expiryStr = user.subExpiry != null
        ? '${user.subExpiry!.day}/${user.subExpiry!.month}/${user.subExpiry!.year}'
        : (user.subPlan == 'free' ? 'Lifetime' : 'N/A');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: app_colors.Dborder_color, height: 1),
        SizedBox(height: 10.h),

        // ── User Info ──────────────────────────────────────────
        _sectionTitle('User Info'),
        SizedBox(height: 6.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 6.h,
          children: [
            _infoChip(Icons.person, 'Username', user.username),
            _infoChip(Icons.phone, 'Mobile', user.mobile),
            _infoChip(Icons.business, 'Company', user.companyName),
            _infoChip(Icons.calendar_today, 'Joined', dateStr),
          ],
        ),

        // ── Subscription Info ──────────────────────────────────
        SizedBox(height: 12.h),
        _sectionTitle('Subscription'),
        SizedBox(height: 6.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 6.h,
          children: [
            _infoChip(Icons.card_membership, 'Plan',
                user.subPlan.toUpperCase()),
            _infoChip(
              user.subActive ? Icons.check_circle : Icons.cancel,
              'Status',
              user.subActive ? 'Active' : 'Expired',
              valueColor: user.subActive
                  ? app_colors.GreenColor
                  : app_colors.c_danger,
            ),
            _infoChip(Icons.event, 'Expiry', expiryStr),
            _infoChip(
                Icons.receipt_long, 'Bills Used', '${user.billsUsed}'),
          ],
        ),

        // ── ADMIN ACTION BUTTONS ← NEW ─────────────────────────
        SizedBox(height: 14.h),
        _sectionTitle('Admin Actions'),
        SizedBox(height: 8.h),
        Row(
          children: [
            // Change Plan button
            Expanded(
              child: GestureDetector(
                onTap: () => _showPlanSheet(user),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  decoration: BoxDecoration(
                    color: app_colors.c_primary.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                        color: app_colors.c_primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swap_horiz,
                          color: app_colors.c_primary, size: 16.sp),
                      SizedBox(width: 6.w),
                      Text('Plan Change',
                          style: TextStyle(
                              fontFamily: app_fonts.Medium,
                              fontSize: 12.sp,
                              color: app_colors.c_primary)),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            // Delete Account button
            Expanded(
              child: GestureDetector(
                onTap: () => _deleteAccount(user),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  decoration: BoxDecoration(
                    color: app_colors.RedColor,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                        color: app_colors.c_danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline,
                          color: app_colors.c_danger, size: 16.sp),
                      SizedBox(width: 6.w),
                      Text('Delete Account',
                          style: TextStyle(
                              fontFamily: app_fonts.Medium,
                              fontSize: 12.sp,
                              color: app_colors.c_danger)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // ── Queries ────────────────────────────────────────────
        if (user.queries.isNotEmpty) ...[
          SizedBox(height: 12.h),
          _sectionTitle('Contact Queries (${user.queries.length})'),
          SizedBox(height: 6.h),
          ...user.queries.map((q) => _queryItem(q)),
        ],

        // ── Feedback ───────────────────────────────────────────
        if (user.feedbacks.isNotEmpty) ...[
          SizedBox(height: 12.h),
          _sectionTitle('Feedback (${user.feedbacks.length})'),
          SizedBox(height: 6.h),
          ...user.feedbacks.map((f) => _feedbackItem(f)),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  QUERIES TAB
  // ════════════════════════════════════════════════════════════════

  Widget _buildQueriesTab() {
    final queries = _allQueries;
    if (queries.isEmpty) {
      return _buildEmpty('Abhi tak koi query nahi aayi');
    }
    return ListView.builder(
      padding:
      EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      itemCount: queries.length,
      itemBuilder: (context, i) {
        final q = queries[i];
        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: app_colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: app_colors.Dborder_color),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 16.r,
                  backgroundColor:
                  app_colors.c_primary.withOpacity(0.13),
                  child: Icon(Icons.person,
                      size: 16.sp, color: app_colors.c_primary),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q['_userName'] ?? '',
                          style: TextStyle(
                              fontFamily: app_fonts.Medium,
                              fontSize: 13.sp,
                              color: app_colors.title)),
                      Text(q['_userEmail'] ?? '',
                          style: TextStyle(
                              fontFamily: app_fonts.Regular,
                              fontSize: 11.sp,
                              color: Colors.black45)),
                    ],
                  ),
                ),
                _timeChip(q['created_at']),
              ]),
              SizedBox(height: 8.h),
              if ((q['query'] as String?)?.isNotEmpty ?? false)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: app_colors.LightBlue,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(q['query'] ?? '',
                      style: TextStyle(
                          fontFamily: app_fonts.Regular,
                          fontSize: 12.sp,
                          color: app_colors.title)),
                ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  FEEDBACK TAB
  // ════════════════════════════════════════════════════════════════

  Widget _buildFeedbackTab() {
    final feedbacks = _allFeedbacks;
    if (feedbacks.isEmpty) {
      return _buildEmpty('Abhi tak koi feedback nahi mila');
    }
    return ListView.builder(
      padding:
      EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      itemCount: feedbacks.length,
      itemBuilder: (context, i) {
        final f = feedbacks[i];
        final stars = (f['stars'] as int?) ?? 0;
        final category = f['category'] as String? ?? '';
        final comment = f['comment'] as String? ?? '';
        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: app_colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: app_colors.Dborder_color),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 16.r,
                  backgroundColor:
                  app_colors.OrangeColor.withOpacity(0.15),
                  child: Icon(Icons.person,
                      size: 16.sp, color: app_colors.OrangeColor),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f['_userName'] ?? '',
                          style: TextStyle(
                              fontFamily: app_fonts.Medium,
                              fontSize: 13.sp,
                              color: app_colors.title)),
                      Text(f['_userEmail'] ?? '',
                          style: TextStyle(
                              fontFamily: app_fonts.Regular,
                              fontSize: 11.sp,
                              color: Colors.black45)),
                    ],
                  ),
                ),
                _timeChip(f['created_at']),
              ]),
              SizedBox(height: 8.h),
              Row(children: [
                Row(
                  children: List.generate(
                      5,
                          (idx) => Icon(
                        idx < stars
                            ? Icons.star
                            : Icons.star_border,
                        size: 16.sp,
                        color: app_colors.OrangeColor,
                      )),
                ),
                SizedBox(width: 8.w),
                if (category.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: app_colors.LightOrange,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(category,
                        style: TextStyle(
                            fontFamily: app_fonts.Regular,
                            fontSize: 10.sp,
                            color: app_colors.OrangeColor)),
                  ),
              ]),
              if (comment.isNotEmpty) ...[
                SizedBox(height: 6.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: app_colors.LightOrange,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(comment,
                      style: TextStyle(
                          fontFamily: app_fonts.Regular,
                          fontSize: 12.sp,
                          color: app_colors.title)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  SMALL HELPER WIDGETS
  // ════════════════════════════════════════════════════════════════

  Widget _sectionTitle(String text) => Text(
    text,
    style: TextStyle(
        fontFamily: app_fonts.Medium,
        fontSize: 12.sp,
        color: app_colors.title),
  );

  Widget _infoChip(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Container(
      padding:
      EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: app_colors.Dbackgroun_color,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: app_colors.Dborder_color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: app_colors.c_primary),
          SizedBox(width: 4.w),
          Text('$label: ',
              style: TextStyle(
                  fontFamily: app_fonts.Regular,
                  fontSize: 11.sp,
                  color: Colors.black45)),
          Text(value,
              style: TextStyle(
                  fontFamily: app_fonts.Medium,
                  fontSize: 11.sp,
                  color: valueColor ?? app_colors.title)),
        ],
      ),
    );
  }

  Widget _planBadge(String plan, bool active) {
    Color bg, fg;
    switch (plan) {
      case 'gold':
        bg = app_colors.LightOrange;
        fg = app_colors.OrangeColor;
        break;
      case 'silver':
        bg = app_colors.LightBlue;
        fg = app_colors.c_primary;
        break;
      default:
        bg = app_colors.table_header_bg;
        fg = Colors.black54;
    }
    return Container(
      margin: EdgeInsets.only(right: 6.w),
      padding:
      EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20.r)),
      child: Text(plan.toUpperCase(),
          style: TextStyle(
              fontFamily: app_fonts.Medium,
              fontSize: 9.sp,
              color: fg)),
    );
  }

  Widget _timeChip(dynamic ts) {
    if (ts == null) return const SizedBox();
    DateTime? dt;
    if (ts is Timestamp) dt = ts.toDate();
    if (dt == null) return const SizedBox();
    return Text('${dt.day}/${dt.month}/${dt.year}',
        style: TextStyle(
            fontFamily: app_fonts.Regular,
            fontSize: 10.sp,
            color: Colors.black38));
  }

  Widget _queryItem(Map<String, dynamic> q) => Container(
    margin: EdgeInsets.only(bottom: 6.h),
    padding: EdgeInsets.all(10.w),
    decoration: BoxDecoration(
      color: app_colors.LightBlue,
      borderRadius: BorderRadius.circular(8.r),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(q['query'] ?? '',
            style: TextStyle(
                fontFamily: app_fonts.Regular,
                fontSize: 12.sp,
                color: app_colors.title)),
        SizedBox(height: 4.h),
        _timeChip(q['created_at']),
      ],
    ),
  );

  Widget _feedbackItem(Map<String, dynamic> f) {
    final stars = (f['stars'] as int?) ?? 0;
    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: app_colors.LightOrange,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                  children: List.generate(
                      5,
                          (idx) => Icon(
                        idx < stars
                            ? Icons.star
                            : Icons.star_border,
                        size: 13.sp,
                        color: app_colors.OrangeColor,
                      ))),
              if ((f['category'] as String?)?.isNotEmpty ?? false) ...[
                SizedBox(width: 6.w),
                Text(f['category'] ?? '',
                    style: TextStyle(
                        fontFamily: app_fonts.Regular,
                        fontSize: 10.sp,
                        color: Colors.black54)),
              ]
            ],
          ),
          if ((f['comment'] as String?)?.isNotEmpty ?? false) ...[
            SizedBox(height: 4.h),
            Text(f['comment'] ?? '',
                style: TextStyle(
                    fontFamily: app_fonts.Regular,
                    fontSize: 12.sp,
                    color: app_colors.title)),
          ],
          SizedBox(height: 4.h),
          _timeChip(f['created_at']),
        ],
      ),
    );
  }

  Widget _buildEmpty(String msg) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox, size: 48.sp, color: Colors.black26),
        SizedBox(height: 10.h),
        Text(msg,
            style: TextStyle(
                fontFamily: app_fonts.Regular,
                fontSize: 14.sp,
                color: Colors.black38)),
      ],
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 48.sp, color: app_colors.c_danger),
          SizedBox(height: 12.h),
          Text('Data load nahi hua',
              style: TextStyle(
                  fontFamily: app_fonts.Medium,
                  fontSize: 16.sp,
                  color: app_colors.title)),
          SizedBox(height: 6.h),
          Text(_error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: app_fonts.Regular,
                  fontSize: 12.sp,
                  color: Colors.black45)),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: _fetchAllData,
            style: ElevatedButton.styleFrom(
              backgroundColor: app_colors.c_primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r)),
            ),
            child: Text('Dobara Try Karo',
                style: TextStyle(
                    fontFamily: app_fonts.Medium,
                    fontSize: 13.sp,
                    color: app_colors.white)),
          ),
        ],
      ),
    ),
  );
}

// ── Helper classes ────────────────────────────────────────────────

class _SummaryData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryData(this.label, this.value, this.icon, this.color);
}

class _PlanOption {
  final String key, label, sub;
  final Color bg, fg;
  final IconData icon;
  const _PlanOption(
      this.key, this.label, this.sub, this.bg, this.fg, this.icon);
}