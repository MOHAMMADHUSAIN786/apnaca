// lib/features/team/presentation/pages/team_member_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../model/team_member_model.dart';
import '../../service/team_service.dart';
import '../../../company/model/company_model.dart';
import '../../../subscription/model/subscription_model.dart';
import '../../../subscription/presentation/pages/subscription_screen.dart';
import '../../../subscription/service/subscription_service.dart';

class TeamMemberScreen extends StatefulWidget {
  final CompanyModel company;

  const TeamMemberScreen({
    super.key,
    required this.company,
  });

  @override
  State<TeamMemberScreen> createState() => _TeamMemberScreenState();
}

class _TeamMemberScreenState extends State<TeamMemberScreen> {
  List<TeamMemberModel> _members = [];
  bool _loading = true;
  SubscriptionModel? _sub;

  int get _maxMembers => _sub?.maxTeamMembers ?? 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _sub     = await SubscriptionService.instance.getSubscription();
      _members = await TeamService.instance.getCompanyMembers(widget.company.id);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // ════════════════════════════════════════════════════════════
  //  ADD MEMBER DIALOG
  //  Owner naam, email, password, role enter karta hai
  //  Password se Firebase account create hota hai (Secondary App)
  //  Member seedha login kar sakta hai — signup ki zaroorat nahi
  // ════════════════════════════════════════════════════════════
  Future<void> _showAddMemberDialog() async {
    if (_sub?.hasMultiUser != true) {
      _showUpgradeDialog();
      return;
    }
    if (_members.length >= _maxMembers) {
      _showError('Maximum $_maxMembers members allowed.\nRemove a member first.');
      return;
    }

    final nameCtrl     = TextEditingController();
    final emailCtrl    = TextEditingController();
    final passwordCtrl = TextEditingController();
    TeamRole selectedRole = TeamRole.viewer;
    bool passwordVisible  = false;
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            'Add Team Member',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Slot counter ────────────────────────────
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(children: [
                      Icon(Icons.group, size: 16.sp, color: app_colors.black),
                      SizedBox(width: 6.w),
                      Text(
                        '${_members.length} / $_maxMembers slots used',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                      ),
                    ]),
                  ),
                  SizedBox(height: 16.h),

                  // ── Name ─────────────────────────────────────
                  _buildField(
                    controller: nameCtrl,
                    label: 'Member Name *',
                    icon: Icons.person_outline,
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  SizedBox(height: 12.h),

                  // ── Email ─────────────────────────────────────
                  _buildField(
                    controller: emailCtrl,
                    label: 'Email *',
                    icon: Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),

                  // ── Password ──────────────────────────────────
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: !passwordVisible,
                    style: TextStyle(fontSize: 14.sp, color: app_colors.black),
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      hintText: 'Min 6 characters',
                      prefixIcon: Icon(Icons.lock_outline, size: 18.sp),
                      // Toggle show/hide password
                      suffixIcon: IconButton(
                        icon: Icon(
                          passwordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18.sp,
                          color: Colors.grey,
                        ),
                        onPressed: () =>
                            setS(() => passwordVisible = !passwordVisible),
                      ),
                      helperText: 'Share this password with the member',
                      helperStyle: TextStyle(fontSize: 11.sp, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 12.h),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: app_colors.Dborder_color),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(
                            color: app_colors.table_header_bg, width: 1.4),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Password is required';
                      if (v.trim().length < 6)
                        return 'Minimum 6 characters';
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),

                  // ── Role selector ─────────────────────────────
                  Text(
                    'Select Role:',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: app_colors.black,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _RoleTile(
                    role: TeamRole.viewer,
                    selected: selectedRole == TeamRole.viewer,
                    onTap: () => setS(() => selectedRole = TeamRole.viewer),
                  ),
                  SizedBox(height: 6.h),
                  _RoleTile(
                    role: TeamRole.editor,
                    selected: selectedRole == TeamRole.editor,
                    onTap: () => setS(() => selectedRole = TeamRole.editor),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: app_colors.table_header_bg,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                if (!formKey.currentState!.validate()) return;
                setS(() => saving = true);

                final result = await TeamService.instance.addTeamMember(
                  companyId:        widget.company.id,
                  memberEmail:      emailCtrl.text.trim(),
                  memberPassword:   passwordCtrl.text.trim(),
                  memberName:       nameCtrl.text.trim(),
                  role:             selectedRole,
                  maxMembersAllowed: _maxMembers,
                );

                setS(() => saving = false);
                if (!mounted) return;
                Navigator.pop(ctx);

                if (result.isSuccess) {
                  _load();
                  // Show success with credentials to share
                  _showCredentialsDialog(
                    name:     nameCtrl.text.trim(),
                    email:    emailCtrl.text.trim(),
                    password: passwordCtrl.text.trim(),
                  );
                } else {
                  _showError(result.error ?? 'Failed to add member');
                }
              },
              child: saving
                  ? SizedBox(
                  width: 20.w, height: 20.h,
                  child: const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text('Add Member',
                  style:
                  TextStyle(color: app_colors.black, fontSize: 14.sp)),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  CREDENTIALS DIALOG — owner ko share karne ke liye
  // ════════════════════════════════════════════════════════════
  void _showCredentialsDialog({
    required String name,
    required String email,
    required String password,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(children: [
          Icon(Icons.check_circle, color: const Color(0xFF15CA20), size: 22.sp),
          SizedBox(width: 8.w),
          Text('Member Added!',
              style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.bold,
                  color: app_colors.black)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name has been added to ${widget.company.name}.',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
            ),
            SizedBox(height: 16.h),
            Text('Share these credentials with them:',
                style: TextStyle(
                    fontSize: 13.sp, fontWeight: FontWeight.w600,
                    color: app_colors.black)),
            SizedBox(height: 10.h),
            // Credential box
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: app_colors.Dborder_color),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _credRow(Icons.email_outlined, 'Email', email),
                  SizedBox(height: 8.h),
                  _credRow(Icons.lock_outline, 'Password', password),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, size: 16.sp, color: const Color(0xFF856404)),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'They just need to login — no signup needed.',
                    style: TextStyle(
                        fontSize: 12.sp, color: const Color(0xFF856404)),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: app_colors.table_header_bg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child:
            Text('Got it', style: TextStyle(color: app_colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _credRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15.sp, color: Colors.grey),
        SizedBox(width: 8.w),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13.sp, color: app_colors.black),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontFamily: app_fonts.Medium,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  PERMISSIONS EDIT DIALOG
  // ════════════════════════════════════════════════════════════
  Future<void> _showPermissionDialog(TeamMemberModel member) async {
    TeamPermissions perms    = member.permissions;
    TeamRole selectedRole    = member.role;
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Permissions',
                  style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.bold,
                      color: app_colors.black)),
              Text(member.memberName,
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Role:',
                      style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: app_colors.black)),
                  SizedBox(height: 8.h),
                  _RoleTile(
                    role: TeamRole.viewer,
                    selected: selectedRole == TeamRole.viewer,
                    onTap: () => setS(() {
                      selectedRole = TeamRole.viewer;
                      perms = TeamPermissions.viewerDefault();
                    }),
                  ),
                  SizedBox(height: 6.h),
                  _RoleTile(
                    role: TeamRole.editor,
                    selected: selectedRole == TeamRole.editor,
                    onTap: () => setS(() {
                      selectedRole = TeamRole.editor;
                      perms = TeamPermissions.editorFull();
                    }),
                  ),
                  SizedBox(height: 16.h),
                  const Divider(),
                  SizedBox(height: 8.h),
                  Text('Custom Permissions:',
                      style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: app_colors.black)),
                  Text('(Changing role resets these)',
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                  SizedBox(height: 10.h),
                  _PermSection(title: 'View', icon: Icons.visibility_outlined, tiles: [
                    _PermTile('Sale Bills',     perms.canViewSaleBills,     (v) => setS(() => perms = perms.copyWith(canViewSaleBills: v))),
                    _PermTile('Purchase Bills', perms.canViewPurchaseBills, (v) => setS(() => perms = perms.copyWith(canViewPurchaseBills: v))),
                    _PermTile('Items',          perms.canViewItems,         (v) => setS(() => perms = perms.copyWith(canViewItems: v))),
                    _PermTile('Customers',      perms.canViewCustomers,     (v) => setS(() => perms = perms.copyWith(canViewCustomers: v))),
                    _PermTile('Suppliers',      perms.canViewSuppliers,     (v) => setS(() => perms = perms.copyWith(canViewSuppliers: v))),
                    _PermTile('Reports',        perms.canViewReports,       (v) => setS(() => perms = perms.copyWith(canViewReports: v))),
                  ]),
                  _PermSection(title: 'Sale Bills', icon: Icons.receipt_long_outlined, tiles: [
                    _PermTile('Create',  perms.canCreateSaleBills,   (v) => setS(() => perms = perms.copyWith(canCreateSaleBills: v))),
                    _PermTile('Edit',    perms.canEditSaleBills,     (v) => setS(() => perms = perms.copyWith(canEditSaleBills: v))),
                    _PermTile('Delete',  perms.canDeleteSaleBills,   (v) => setS(() => perms = perms.copyWith(canDeleteSaleBills: v))),
                  ]),
                  _PermSection(title: 'Purchase Bills', icon: Icons.shopping_bag_outlined, tiles: [
                    _PermTile('Create',  perms.canCreatePurchaseBills, (v) => setS(() => perms = perms.copyWith(canCreatePurchaseBills: v))),
                    _PermTile('Edit',    perms.canEditPurchaseBills,   (v) => setS(() => perms = perms.copyWith(canEditPurchaseBills: v))),
                    _PermTile('Delete',  perms.canDeletePurchaseBills, (v) => setS(() => perms = perms.copyWith(canDeletePurchaseBills: v))),
                  ]),
                  _PermSection(title: 'Manage', icon: Icons.settings_outlined, tiles: [
                    _PermTile('Items',      perms.canManageItems,     (v) => setS(() => perms = perms.copyWith(canManageItems: v))),
                    _PermTile('Customers',  perms.canManageCustomers, (v) => setS(() => perms = perms.copyWith(canManageCustomers: v))),
                    _PermTile('Suppliers',  perms.canManageSuppliers, (v) => setS(() => perms = perms.copyWith(canManageSuppliers: v))),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: app_colors.table_header_bg,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                setS(() => saving = true);
                final result =
                await TeamService.instance.updateMemberPermissions(
                  companyId:      widget.company.id,
                  memberId:       member.id,
                  newRole:        selectedRole,
                  newPermissions: perms,
                );
                setS(() => saving = false);
                Navigator.pop(ctx);
                if (result.isSuccess) {
                  _load();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Permissions updated!'),
                          backgroundColor: Color(0xFF15CA20)),
                    );
                } else {
                  _showError(result.error ?? 'Update failed');
                }
              },
              child: saving
                  ? SizedBox(
                  width: 20.w, height: 20.h,
                  child: const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text('Save',
                  style:
                  TextStyle(color: app_colors.black, fontSize: 14.sp)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeMember(TeamMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('Remove Member?'),
        content: Text(
          'Remove "${member.memberName}" from ${widget.company.name}?\n\n'
              'They will lose access immediately.',
          style: TextStyle(fontSize: 13.sp),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await TeamService.instance.removeMember(
      companyId: widget.company.id,
      memberId:  member.id,
      memberUid: member.memberUid,
    );

    if (result.isSuccess) {
      _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${member.memberName}" removed'),
          backgroundColor: Colors.red,
        ));
    } else {
      _showError(result.error ?? 'Remove failed');
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('Gold Plan Required'),
        content: Text(
          'Team Members feature requires Gold Plan.\n\n'
              '✅ Up to 5 members per company\n'
              '✅ Viewer / Editor roles\n'
              '✅ Custom permissions per member\n'
              '✅ Members login with email & password',
          style: TextStyle(fontSize: 13.sp),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: app_colors.table_header_bg),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen()));
            },
            child: Text('Upgrade',
                style: TextStyle(color: app_colors.black)),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      style: TextStyle(color: app_colors.black, fontSize: 14.sp),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18.sp),
        filled: true, fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: app_colors.Dborder_color),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide:
          BorderSide(color: app_colors.table_header_bg, width: 1.4),
        ),
      ),
      validator: validator,
    );
  }

  InputDecoration _inputDecor(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18.sp),
      filled: true, fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: app_colors.Dborder_color),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: app_colors.table_header_bg, width: 1.4),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Team Members',
                style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                    color: app_colors.black)),
            Text(widget.company.name,
                style: TextStyle(fontSize: 11.sp, color: Colors.black54)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add, color: app_colors.black, size: 24.sp),
            onPressed: _showAddMemberDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_sub?.hasMultiUser != true) return _buildUpgradePrompt();

    return Column(
      children: [
        // Slot counter
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          color: Colors.white,
          child: Row(
            children: [
              Icon(Icons.group, color: app_colors.black, size: 20.sp),
              SizedBox(width: 8.w),
              Text('${_members.length} / $_maxMembers members',
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: app_colors.black)),
              const Spacer(),
              Container(
                padding:
                EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _members.length < _maxMembers
                      ? const Color(0xFFE1FFE7)
                      : const Color(0xFFFFE8E8),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  _members.length < _maxMembers ? 'Slots Available' : 'Full',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: _members.length < _maxMembers
                        ? const Color(0xFF15CA20)
                        : Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _members.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_add,
                    size: 64.sp, color: Colors.grey.shade300),
                SizedBox(height: 14.h),
                Text('No team members yet',
                    style: TextStyle(
                        fontSize: 16.sp, color: Colors.grey)),
                SizedBox(height: 8.h),
                Text('Tap + to add your first member',
                    style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade500)),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: EdgeInsets.all(14.w),
              itemCount: _members.length,
              itemBuilder: (ctx, i) => _MemberCard(
                member: _members[i],
                onEditPermissions: () =>
                    _showPermissionDialog(_members[i]),
                onRemove: () => _removeMember(_members[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradePrompt() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          SizedBox(height: 32.h),
          Icon(Icons.group_outlined,
              size: 70.sp, color: app_colors.table_header_bg),
          SizedBox(height: 20.h),
          Text('Team Members Feature',
              style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: app_colors.black),
              textAlign: TextAlign.center),
          SizedBox(height: 12.h),
          Text('Upgrade to Gold Plan to add team members.',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
              textAlign: TextAlign.center),
          SizedBox(height: 20.h),
          _featRow(Icons.group, 'Up to 5 members per company'),
          _featRow(Icons.visibility, 'Viewer — view only, no edits'),
          _featRow(Icons.edit, 'Editor — full access'),
          _featRow(Icons.lock_open, 'Custom permissions per member'),
          _featRow(Icons.login, 'Members login directly — no signup'),
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
                  MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen())),
              child: Text(
                  'Get Gold Plan — ₹${SubscriptionModel.goldMonthlyPriceRs}/month',
                  style: TextStyle(
                      color: app_colors.black,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featRow(IconData icon, String text) => Padding(
    padding: EdgeInsets.symmetric(vertical: 6.h),
    child: Row(children: [
      Container(
        width: 32.w, height: 32.h,
        decoration: BoxDecoration(
          color: app_colors.table_header_bg.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16.sp, color: app_colors.black),
      ),
      SizedBox(width: 12.w),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 14.sp, color: app_colors.black))),
    ]),
  );
}

// ── Role Tile ─────────────────────────────────────────────────────
class _RoleTile extends StatelessWidget {
  final TeamRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isViewer = role == TeamRole.viewer;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: selected
              ? app_colors.table_header_bg.withOpacity(0.15)
              : Colors.white,
          border: Border.all(
            color: selected
                ? app_colors.table_header_bg
                : app_colors.Dborder_color,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          children: [
            Icon(
              isViewer ? Icons.visibility : Icons.edit,
              size: 20.sp,
              color: selected ? app_colors.black : Colors.grey,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isViewer ? 'Viewer' : 'Editor',
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: app_colors.black),
                  ),
                  Text(
                    isViewer
                        ? 'Can view bills, items, customers — no edits'
                        : 'Can create, edit and delete — full access',
                    style: TextStyle(
                        fontSize: 11.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle,
                  color: app_colors.black, size: 20.sp),
          ],
        ),
      ),
    );
  }
}

// ── Permission Section ────────────────────────────────────────────
class _PermSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> tiles;

  const _PermSection({
    required this.title,
    required this.icon,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10.h),
        Row(children: [
          Icon(icon, size: 14.sp, color: Colors.grey[600]),
          SizedBox(width: 5.w),
          Text(title,
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700])),
        ]),
        SizedBox(height: 4.h),
        ...tiles,
      ],
    );
  }
}

class _PermTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermTile(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label,
          style: TextStyle(fontSize: 13.sp, color: app_colors.black)),
      value: value,
      activeColor: app_colors.black,
      onChanged: onChanged,
    );
  }
}

// ── Member Card ───────────────────────────────────────────────────
class _MemberCard extends StatelessWidget {
  final TeamMemberModel member;
  final VoidCallback onEditPermissions;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.member,
    required this.onEditPermissions,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isViewer = member.role == TeamRole.viewer;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: app_colors.Dborder_color),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22.r,
            backgroundColor: isViewer
                ? const Color(0xFFFFF3CD)
                : const Color(0xFFE1FFE7),
            child: Icon(
              isViewer ? Icons.visibility : Icons.edit,
              size: 18.sp,
              color: isViewer
                  ? const Color(0xFF856404)
                  : const Color(0xFF15CA20),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.memberName,
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: app_colors.black)),
                Text(member.memberEmail,
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: 4.h),
                Row(children: [
                  _Badge(
                    label: isViewer ? 'Viewer' : 'Editor',
                    bg: isViewer
                        ? const Color(0xFFFFF3CD)
                        : const Color(0xFFE1FFE7),
                    fg: isViewer
                        ? const Color(0xFF856404)
                        : const Color(0xFF15CA20),
                  ),
                  SizedBox(width: 6.w),
                  _Badge(
                    label: member.status == 'active' ? 'Active' : 'Pending',
                    bg: member.status == 'active'
                        ? const Color(0xFFE1FFE7)
                        : const Color(0xFFF5F5F5),
                    fg: member.status == 'active'
                        ? const Color(0xFF15CA20)
                        : Colors.grey,
                  ),
                ]),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: Colors.white,
            icon: Icon(Icons.more_vert, color: app_colors.black),
            onSelected: (v) {
              if (v == 'permissions') onEditPermissions();
              if (v == 'remove') onRemove();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'permissions',
                child: Row(children: [
                  Icon(Icons.lock_open, size: 18, color: app_colors.black),
                  SizedBox(width: 8.w),
                  const Text('Edit Permissions'),
                ]),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Row(children: [
                  Icon(Icons.person_remove, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remove', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20.r)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.sp,
              color: fg,
              fontWeight: FontWeight.w500)),
    );
  }
}