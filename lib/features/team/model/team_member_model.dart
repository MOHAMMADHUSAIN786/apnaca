// lib/features/team/model/team_member_model.dart

// ─── ROLE ENUM ────────────────────────────────────────────────────
enum TeamRole { viewer, editor }

extension TeamRoleExt on TeamRole {
  String get name {
    switch (this) {
      case TeamRole.viewer: return 'viewer';
      case TeamRole.editor: return 'editor';
    }
  }

  String get label {
    switch (this) {
      case TeamRole.viewer: return 'Viewer (Sirf Dekhna)';
      case TeamRole.editor: return 'Editor (Edit bhi kar sakta)';
    }
  }

  static TeamRole fromString(String s) {
    switch (s) {
      case 'editor': return TeamRole.editor;
      default: return TeamRole.viewer;
    }
  }
}

// ─── PERMISSIONS ─────────────────────────────────────────────────
class TeamPermissions {
  final bool canViewSaleBills;
  final bool canViewPurchaseBills;
  final bool canViewItems;
  final bool canViewCustomers;
  final bool canViewSuppliers;
  final bool canViewReports;
  final bool canCreateSaleBills;
  final bool canEditSaleBills;
  final bool canDeleteSaleBills;
  final bool canCreatePurchaseBills;
  final bool canEditPurchaseBills;
  final bool canDeletePurchaseBills;
  final bool canManageItems;
  final bool canManageCustomers;
  final bool canManageSuppliers;

  const TeamPermissions({
    this.canViewSaleBills = true,
    this.canViewPurchaseBills = true,
    this.canViewItems = true,
    this.canViewCustomers = true,
    this.canViewSuppliers = true,
    this.canViewReports = false,
    this.canCreateSaleBills = false,
    this.canEditSaleBills = false,
    this.canDeleteSaleBills = false,
    this.canCreatePurchaseBills = false,
    this.canEditPurchaseBills = false,
    this.canDeletePurchaseBills = false,
    this.canManageItems = false,
    this.canManageCustomers = false,
    this.canManageSuppliers = false,
  });

  factory TeamPermissions.viewerDefault() => const TeamPermissions(
    canViewSaleBills: true, canViewPurchaseBills: true,
    canViewItems: true, canViewCustomers: true, canViewSuppliers: true,
    canViewReports: false,
    canCreateSaleBills: false, canEditSaleBills: false, canDeleteSaleBills: false,
    canCreatePurchaseBills: false, canEditPurchaseBills: false, canDeletePurchaseBills: false,
    canManageItems: false, canManageCustomers: false, canManageSuppliers: false,
  );

  factory TeamPermissions.editorFull() => const TeamPermissions(
    canViewSaleBills: true, canViewPurchaseBills: true,
    canViewItems: true, canViewCustomers: true, canViewSuppliers: true,
    canViewReports: true,
    canCreateSaleBills: true, canEditSaleBills: true, canDeleteSaleBills: true,
    canCreatePurchaseBills: true, canEditPurchaseBills: true, canDeletePurchaseBills: true,
    canManageItems: true, canManageCustomers: true, canManageSuppliers: true,
  );

  Map<String, dynamic> toMap() => {
    'canViewSaleBills': canViewSaleBills,
    'canViewPurchaseBills': canViewPurchaseBills,
    'canViewItems': canViewItems,
    'canViewCustomers': canViewCustomers,
    'canViewSuppliers': canViewSuppliers,
    'canViewReports': canViewReports,
    'canCreateSaleBills': canCreateSaleBills,
    'canEditSaleBills': canEditSaleBills,
    'canDeleteSaleBills': canDeleteSaleBills,
    'canCreatePurchaseBills': canCreatePurchaseBills,
    'canEditPurchaseBills': canEditPurchaseBills,
    'canDeletePurchaseBills': canDeletePurchaseBills,
    'canManageItems': canManageItems,
    'canManageCustomers': canManageCustomers,
    'canManageSuppliers': canManageSuppliers,
  };

  factory TeamPermissions.fromMap(Map<String, dynamic> m) => TeamPermissions(
    canViewSaleBills: m['canViewSaleBills'] as bool? ?? true,
    canViewPurchaseBills: m['canViewPurchaseBills'] as bool? ?? true,
    canViewItems: m['canViewItems'] as bool? ?? true,
    canViewCustomers: m['canViewCustomers'] as bool? ?? true,
    canViewSuppliers: m['canViewSuppliers'] as bool? ?? true,
    canViewReports: m['canViewReports'] as bool? ?? false,
    canCreateSaleBills: m['canCreateSaleBills'] as bool? ?? false,
    canEditSaleBills: m['canEditSaleBills'] as bool? ?? false,
    canDeleteSaleBills: m['canDeleteSaleBills'] as bool? ?? false,
    canCreatePurchaseBills: m['canCreatePurchaseBills'] as bool? ?? false,
    canEditPurchaseBills: m['canEditPurchaseBills'] as bool? ?? false,
    canDeletePurchaseBills: m['canDeletePurchaseBills'] as bool? ?? false,
    canManageItems: m['canManageItems'] as bool? ?? false,
    canManageCustomers: m['canManageCustomers'] as bool? ?? false,
    canManageSuppliers: m['canManageSuppliers'] as bool? ?? false,
  );

  TeamPermissions copyWith({
    bool? canViewSaleBills, bool? canViewPurchaseBills,
    bool? canViewItems, bool? canViewCustomers, bool? canViewSuppliers,
    bool? canViewReports,
    bool? canCreateSaleBills, bool? canEditSaleBills, bool? canDeleteSaleBills,
    bool? canCreatePurchaseBills, bool? canEditPurchaseBills, bool? canDeletePurchaseBills,
    bool? canManageItems, bool? canManageCustomers, bool? canManageSuppliers,
  }) => TeamPermissions(
    canViewSaleBills: canViewSaleBills ?? this.canViewSaleBills,
    canViewPurchaseBills: canViewPurchaseBills ?? this.canViewPurchaseBills,
    canViewItems: canViewItems ?? this.canViewItems,
    canViewCustomers: canViewCustomers ?? this.canViewCustomers,
    canViewSuppliers: canViewSuppliers ?? this.canViewSuppliers,
    canViewReports: canViewReports ?? this.canViewReports,
    canCreateSaleBills: canCreateSaleBills ?? this.canCreateSaleBills,
    canEditSaleBills: canEditSaleBills ?? this.canEditSaleBills,
    canDeleteSaleBills: canDeleteSaleBills ?? this.canDeleteSaleBills,
    canCreatePurchaseBills: canCreatePurchaseBills ?? this.canCreatePurchaseBills,
    canEditPurchaseBills: canEditPurchaseBills ?? this.canEditPurchaseBills,
    canDeletePurchaseBills: canDeletePurchaseBills ?? this.canDeletePurchaseBills,
    canManageItems: canManageItems ?? this.canManageItems,
    canManageCustomers: canManageCustomers ?? this.canManageCustomers,
    canManageSuppliers: canManageSuppliers ?? this.canManageSuppliers,
  );
}

// ─── TEAM MEMBER MODEL ────────────────────────────────────────────
class TeamMemberModel {
  final String id;
  final String companyId;
  final String ownerUid;
  final String memberEmail;
  final String memberName;
  final String? memberUid;
  final TeamRole role;
  final TeamPermissions permissions;
  final String status; // 'invited' | 'active' | 'removed'
  final DateTime invitedAt;

  const TeamMemberModel({
    required this.id,
    required this.companyId,
    required this.ownerUid,
    required this.memberEmail,
    required this.memberName,
    this.memberUid,
    required this.role,
    required this.permissions,
    this.status = 'invited',
    required this.invitedAt,
  });

  bool get isActive => status == 'active';
  bool get isViewer => role == TeamRole.viewer;
  bool get isEditor => role == TeamRole.editor;

  Map<String, dynamic> toMap() => {
    'id': id, 'companyId': companyId, 'ownerUid': ownerUid,
    'memberEmail': memberEmail, 'memberName': memberName,
    'memberUid': memberUid, 'role': role.name,
    'permissions': permissions.toMap(),
    'status': status, 'invitedAt': invitedAt.toIso8601String(),
  };

  factory TeamMemberModel.fromMap(Map<String, dynamic> m) {
    final roleStr = m['role'] as String? ?? 'viewer';
    final permMap = m['permissions'] as Map<String, dynamic>? ?? {};
    return TeamMemberModel(
      id: m['id'] as String? ?? '',
      companyId: m['companyId'] as String? ?? '',
      ownerUid: m['ownerUid'] as String? ?? '',
      memberEmail: m['memberEmail'] as String? ?? '',
      memberName: m['memberName'] as String? ?? '',
      memberUid: m['memberUid'] as String?,
      role: TeamRoleExt.fromString(roleStr),
      permissions: permMap.isNotEmpty
          ? TeamPermissions.fromMap(permMap)
          : (roleStr == 'editor' ? TeamPermissions.editorFull() : TeamPermissions.viewerDefault()),
      status: m['status'] as String? ?? 'invited',
      invitedAt: _parseDate(m['invitedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    try { return (v as dynamic).toDate() as DateTime; } catch (_) { return null; }
  }

  TeamMemberModel copyWith({
    String? id, String? companyId, String? ownerUid,
    String? memberEmail, String? memberName, String? memberUid,
    TeamRole? role, TeamPermissions? permissions, String? status,
  }) => TeamMemberModel(
    id: id ?? this.id, companyId: companyId ?? this.companyId,
    ownerUid: ownerUid ?? this.ownerUid, memberEmail: memberEmail ?? this.memberEmail,
    memberName: memberName ?? this.memberName, memberUid: memberUid ?? this.memberUid,
    role: role ?? this.role, permissions: permissions ?? this.permissions,
    status: status ?? this.status, invitedAt: invitedAt,
  );
}

// ─── TEAM ACCESS INFO (login pe load hota hai) ───────────────────
class TeamAccessInfo {
  final String companyId;
  final String ownerUid;
  final TeamRole role;
  final TeamPermissions permissions;
  final String memberName;

  const TeamAccessInfo({
    required this.companyId, required this.ownerUid,
    required this.role, required this.permissions, required this.memberName,
  });

  bool get isViewer => role == TeamRole.viewer;
  bool get isEditor => role == TeamRole.editor;

  factory TeamAccessInfo.fromMap(Map<String, dynamic> m) {
    final permMap = m['permissions'] as Map<String, dynamic>? ?? {};
    return TeamAccessInfo(
      companyId: m['companyId'] as String? ?? '',
      ownerUid: m['ownerUid'] as String? ?? '',
      role: TeamRoleExt.fromString(m['role'] as String? ?? 'viewer'),
      permissions: permMap.isNotEmpty
          ? TeamPermissions.fromMap(permMap)
          : TeamPermissions.viewerDefault(),
      memberName: m['memberName'] as String? ?? '',
    );
  }
}

// ─── SERVICE RESULT ───────────────────────────────────────────────
class TeamServiceResult<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;

  const TeamServiceResult._({this.data, this.error});
  factory TeamServiceResult.success(T? data) => TeamServiceResult._(data: data);
  factory TeamServiceResult.error(String msg) => TeamServiceResult._(error: msg);
}
