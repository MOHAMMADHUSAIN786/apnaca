// lib/features/company/presentation/pages/company_screen.dart
//
// KEY CHANGES:
//  • After creating a company, immediately switches to that company's DB
//  • _switchCompany saves to SharedPreferences + triggers NavBar refresh via callback
//  • Active company shows filled card, others show outlined
//  • "Switch" button on each card

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../database/app_database.dart';
import '../../../subscription/model/subscription_model.dart';
import '../../../subscription/presentation/pages/subscription_screen.dart';
import '../../../subscription/service/subscription_service.dart';
import '../../model/company_model.dart';
import '../../service/company_service.dart';
import '../../../team/presentation/pages/team_member_screen.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});
  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  List<CompanyModel> _companies = [];
  bool _loading = true;
  bool _switching = false;
  SubscriptionModel? _sub;
  String? _activeCompanyId;

  @override
  void initState() {
    super.initState();
    _activeCompanyId = AppDatabase.activeCompanyId;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _sub       = await SubscriptionService.instance.getSubscription();
      _companies = await CompanyService.instance.getMyCompanies();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // ── Switch to a company's DB ───────────────────────────────────────────────
  Future<void> _switchCompany(String? companyId) async {
    if (_switching || companyId == _activeCompanyId) return;
    setState(() => _switching = true);

    try {
      await CompanyService.instance.switchToCompany(companyId);

      // Persist choice
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && companyId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_company_$uid', companyId);
      }

      setState(() {
        _activeCompanyId = companyId;
        _switching = false;
      });

      if (mounted) {
        final name = companyId == null
            ? 'Default'
            : _companies.firstWhere((c) => c.id == companyId).name;

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8.w),
              Text('"$name" is now active'),
            ],
          ),
          backgroundColor: const Color(0xFF15CA20),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));

        // Return true to NavBar so it calls refreshAll()
        // (Will be caught by .then() in sidebar or Navigator.pop result)
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _switching = false);
        _showError('Switch failed: $e');
      }
    }
  }

  // ── Add / Edit company dialog ──────────────────────────────────────────────
  Future<void> _showCompanyDialog({CompanyModel? existing}) async {
    final nameCtrl    = TextEditingController(text: existing?.name    ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final gstCtrl     = TextEditingController(text: existing?.gstin   ?? '');
    final phoneCtrl   = TextEditingController(text: existing?.phone   ?? '');
    final emailCtrl   = TextEditingController(text: existing?.email   ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            existing == null ? 'Add New Company' : 'Edit Company',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: app_colors.black,
            ),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(nameCtrl,    'Company Name *', Icons.business,      required: true),
                  SizedBox(height: 12.h),
                  _field(addressCtrl, 'Address',        Icons.location_on),
                  SizedBox(height: 12.h),
                  _field(gstCtrl,     'GSTIN',          Icons.receipt_long),
                  SizedBox(height: 12.h),
                  _field(phoneCtrl,   'Phone',          Icons.phone,         keyboard: TextInputType.phone),
                  SizedBox(height: 12.h),
                  _field(emailCtrl,   'Email',          Icons.email,         keyboard: TextInputType.emailAddress),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: app_colors.table_header_bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              onPressed: saving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setS(() => saving = true);

                CompanyResult result;
                if (existing == null) {
                  result = await CompanyService.instance.createCompany(
                    name:    nameCtrl.text.trim(),
                    address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                    gstin:   gstCtrl.text.trim().isEmpty    ? null : gstCtrl.text.trim(),
                    phone:   phoneCtrl.text.trim().isEmpty  ? null : phoneCtrl.text.trim(),
                    email:   emailCtrl.text.trim().isEmpty  ? null : emailCtrl.text.trim(),
                  );
                } else {
                  result = await CompanyService.instance.updateCompany(
                    existing.copyWith(
                      name:    nameCtrl.text.trim(),
                      address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                      gstin:   gstCtrl.text.trim().isEmpty    ? null : gstCtrl.text.trim(),
                      phone:   phoneCtrl.text.trim().isEmpty  ? null : phoneCtrl.text.trim(),
                      email:   emailCtrl.text.trim().isEmpty  ? null : emailCtrl.text.trim(),
                    ),
                  );
                }

                setS(() => saving = false);
                if (!mounted) return;
                Navigator.pop(ctx);

                if (result.isSuccess) {
                  await _load(); // refresh list

                  // If new company was created, auto-switch to it
                  if (existing == null && result.data != null) {
                    final newCompany = result.data as CompanyModel;
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('"${newCompany.name}" added — switching to it...'),
                        backgroundColor: const Color(0xFF15CA20),
                      ));
                      await _switchCompany(newCompany.id);
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Company updated!'),
                        backgroundColor: Color(0xFF15CA20),
                      ));
                    }
                  }
                } else {
                  _showError(result.error ?? 'Something went wrong');
                }
              },
              child: saving
                  ? SizedBox(
                  width: 20.w, height: 20.h,
                  child: const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text('Save', style: TextStyle(color: app_colors.black, fontSize: 14.sp)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
      TextEditingController ctrl,
      String label,
      IconData icon, {
        bool required = false,
        TextInputType keyboard = TextInputType.text,
      }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: TextStyle(color: app_colors.black, fontSize: 14.sp),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18.sp, color: app_colors.black),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: app_colors.Dborder_color),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: app_colors.table_header_bg, width: 1.4),
        ),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null
          : null,
    );
  }

  Future<void> _confirmDelete(CompanyModel company) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'Delete Company?',
          style: TextStyle(color: app_colors.black, fontFamily: app_fonts.Bold),
        ),
        content: Text(
          '"${company.name}" and all its team members will be permanently deleted.',
          style: TextStyle(fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // If deleting the active company, reset to default
      if (company.id == _activeCompanyId) {
        await CompanyService.instance.switchToDefault();
        setState(() => _activeCompanyId = null);
      }

      final result = await CompanyService.instance.deleteCompany(company.id);
      if (result.isSuccess) {
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${company.name}" deleted'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        _showError(result.error ?? 'Delete failed');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: app_colors.white,
      appBar: AppBar(
        backgroundColor: app_colors.table_header_bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: app_colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Companies',
          style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: app_colors.black),
        ),
        actions: [
          if (_sub?.hasMultiCompany == true)
            IconButton(
              icon: Icon(Icons.add_circle, color: app_colors.black, size: 28.sp),
              onPressed: _showCompanyDialog,
              tooltip: 'Add Company',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_sub?.hasMultiCompany != true) return _buildUpgradePrompt();
    if (_companies.isEmpty)            return _buildEmpty();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: _companies.length,
            itemBuilder: (ctx, i) {
              final company  = _companies[i];
              final isActive = company.id == _activeCompanyId;
              return _CompanyCard(
                company:      company,
                isActive:     isActive,
                onSwitch:     () => _switchCompany(company.id),
                onEdit:       () => _showCompanyDialog(existing: company),
                onDelete:     () => _confirmDelete(company),
                onManageTeam: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamMemberScreen(company: company),
                  ),
                ),
              );
            },
          ),
        ),
        if (_switching)
          Container(
            color: Colors.black26,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Switching company...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUpgradePrompt() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_center, size: 80.sp,
                color: app_colors.table_header_bg.withOpacity(0.6)),
            SizedBox(height: 20.h),
            Text('Multi-Company Feature',
                style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: app_colors.black)),
            SizedBox(height: 12.h),
            Text(
              'Manage multiple companies separately — each with its own bills, items, and data.',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 28.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: app_colors.table_header_bg,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
                child: Text(
                  'Get Gold Plan — ₹${SubscriptionModel.goldMonthlyPriceRs}/month',
                  style: TextStyle(
                      color: app_colors.black,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 80.sp, color: Colors.grey.shade300),
          SizedBox(height: 16.h),
          Text('No companies yet',
              style: TextStyle(fontSize: 18.sp, color: Colors.grey)),
          SizedBox(height: 8.h),
          Text('Tap + to add your first company',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

// ── Company Card ───────────────────────────────────────────────────────────────
class _CompanyCard extends StatelessWidget {
  final CompanyModel company;
  final bool isActive;
  final VoidCallback onSwitch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onManageTeam;

  const _CompanyCard({
    required this.company,
    required this.isActive,
    required this.onSwitch,
    required this.onEdit,
    required this.onDelete,
    required this.onManageTeam,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: isActive ? app_colors.table_header_bg : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isActive
              ? app_colors.table_header_bg
              : app_colors.Dborder_color,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isActive ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 44.w, height: 44.h,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.black.withOpacity(0.1)
                        : app_colors.table_header_bg.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isActive ? Icons.check_circle : Icons.business,
                    color: app_colors.black,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 12.w),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              company.name,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                fontFamily: app_fonts.Bold,
                                color: app_colors.black,
                              ),
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Text(
                                'Active',
                                style: TextStyle(
                                    fontSize: 10.sp, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      if (company.gstin != null && company.gstin!.isNotEmpty)
                        Text('GST: ${company.gstin}',
                            style: TextStyle(
                                fontSize: 11.sp, color: Colors.grey[600])),
                    ],
                  ),
                ),

                // 3-dot menu
                PopupMenuButton<String>(
                  color: Colors.white,
                  icon: Icon(Icons.more_vert, color: app_colors.black),
                  onSelected: (v) {
                    if (v == 'edit')   onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit, size: 18, color: app_colors.black),
                        SizedBox(width: 8.w),
                        const Text('Edit'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8.w),
                        const Text('Delete', style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),

            // Details
            if (company.phone != null && company.phone!.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Row(children: [
                Icon(Icons.phone, size: 13.sp, color: Colors.grey),
                SizedBox(width: 5.w),
                Text(company.phone!,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
              ]),
            ],
            if (company.address != null && company.address!.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Row(children: [
                Icon(Icons.location_on, size: 13.sp, color: Colors.grey),
                SizedBox(width: 5.w),
                Expanded(
                  child: Text(
                    company.address!,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                ),
              ]),
            ],

            SizedBox(height: 10.h),
            const Divider(height: 1),
            SizedBox(height: 8.h),
            // Switch — only for inactive companies
            if (!isActive) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: app_colors.table_header_bg),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r)),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                  ),
                  onPressed: onSwitch,
                  icon: Icon(Icons.swap_horiz,
                      size: 16.sp, color: app_colors.black),
                  label: Text(
                    'Switch to this Company',
                    style: TextStyle(color: app_colors.black, fontSize: 12.sp),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
            ],
            // Manage Team — ALWAYS visible
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: app_colors.Dborder_color),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r)),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                ),
                onPressed: onManageTeam,
                icon: Icon(Icons.group_outlined,
                    size: 16.sp, color: app_colors.black),
                label: Text(
                  'Manage Team Members',
                  style: TextStyle(color: app_colors.black, fontSize: 12.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}