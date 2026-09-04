// lib/core/services/permission_service.dart
// UNCHANGED LOGIC — but init() now correctly handles re-init on logout

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../features/team/model/team_member_model.dart';
import '../../../features/team/service/team_service.dart';

class PermissionService {
  static final PermissionService instance = PermissionService._internal();
  PermissionService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  TeamAccessInfo? _cachedAccess; // null = current user is owner
  bool _initialized = false;

  Future<void> init() async {
    _initialized = false;
    _cachedAccess = null;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _cachedAccess = await TeamService.instance.getMyTeamAccess();
    _initialized = true;
  }

  void clear() {
    _cachedAccess = null;
    _initialized = false;
  }

  bool get isTeamMember  => _cachedAccess != null;
  bool get isOwner       => _cachedAccess == null;
  TeamAccessInfo? get teamAccess => _cachedAccess;

  /// Data reads should use this UID — owner's UID for team members
  String get dataOwnerUid {
    if (isOwner) return _auth.currentUser?.uid ?? '';
    return _cachedAccess!.ownerUid;
  }

  bool get canViewSaleBills       => isOwner || _p.canViewSaleBills;
  bool get canViewPurchaseBills   => isOwner || _p.canViewPurchaseBills;
  bool get canViewItems           => isOwner || _p.canViewItems;
  bool get canViewCustomers       => isOwner || _p.canViewCustomers;
  bool get canViewSuppliers       => isOwner || _p.canViewSuppliers;
  bool get canViewReports         => isOwner || _p.canViewReports;
  bool get canCreateSaleBills     => isOwner || _p.canCreateSaleBills;
  bool get canEditSaleBills       => isOwner || _p.canEditSaleBills;
  bool get canDeleteSaleBills     => isOwner || _p.canDeleteSaleBills;
  bool get canCreatePurchaseBills => isOwner || _p.canCreatePurchaseBills;
  bool get canEditPurchaseBills   => isOwner || _p.canEditPurchaseBills;
  bool get canDeletePurchaseBills => isOwner || _p.canDeletePurchaseBills;
  bool get canManageItems         => isOwner || _p.canManageItems;
  bool get canManageCustomers     => isOwner || _p.canManageCustomers;
  bool get canManageSuppliers     => isOwner || _p.canManageSuppliers;

  TeamPermissions get _p =>
      _cachedAccess?.permissions ?? TeamPermissions.viewerDefault();
}

// ── Permission Guard Widget ───────────────────────────────────────
class PermissionGuard extends StatelessWidget {
  final bool allowed;
  final Widget child;
  final bool hideCompletely;

  const PermissionGuard({
    super.key,
    required this.allowed,
    required this.child,
    this.hideCompletely = false,
  });

  @override
  Widget build(BuildContext context) {
    if (allowed) return child;
    if (hideCompletely) return const SizedBox.shrink();
    return Opacity(opacity: 0.35, child: IgnorePointer(child: child));
  }
}

// ── View Only Banner ──────────────────────────────────────────────
class ViewOnlyBanner extends StatelessWidget {
  const ViewOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final perm = PermissionService.instance;
    if (perm.isOwner) return const SizedBox.shrink();

    final isViewer = perm.teamAccess?.isViewer ?? true;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 7.h, horizontal: 14.w),
      color: isViewer ? const Color(0xFFFFF3CD) : const Color(0xFFE8F4FD),
      child: Row(
        children: [
          Icon(
            isViewer ? Icons.visibility : Icons.edit,
            size: 15.sp,
            color: isViewer ? const Color(0xFF856404) : const Color(0xFF0C63E4),
          ),
          SizedBox(width: 7.w),
          Expanded(
            child: Text(
              isViewer
                  ? '👁  View Only — you can view but not edit'
                  : '✏️  Editor Mode — you can create and edit',
              style: TextStyle(
                color: isViewer
                    ? const Color(0xFF856404)
                    : const Color(0xFF0C63E4),
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Permission Denied SnackBar ────────────────────────────────────
void showPermissionDeniedSnackBar(BuildContext context, String action) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.lock, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You don\'t have permission to $action. Contact the owner.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFDC3545),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}