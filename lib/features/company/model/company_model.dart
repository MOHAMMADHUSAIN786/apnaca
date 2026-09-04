// lib/features/company/model/company_model.dart

class CompanyModel {
  final String id;          // Firestore doc ID (UUID)
  final String ownerUid;    // Firebase Auth UID of the owner
  final String name;
  final String? address;
  final String? gstin;
  final String? phone;
  final String? email;
  final DateTime createdAt;

  const CompanyModel({
    required this.id,
    required this.ownerUid,
    required this.name,
    this.address,
    this.gstin,
    this.phone,
    this.email,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id':        id,
    'ownerUid':  ownerUid,
    'name':      name,
    'address':   address,
    'gstin':     gstin,
    'phone':     phone,
    'email':     email,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CompanyModel.fromMap(Map<String, dynamic> m) => CompanyModel(
    id:        m['id']        as String? ?? '',
    ownerUid:  m['ownerUid']  as String? ?? '',
    name:      m['name']      as String? ?? '',
    address:   m['address']   as String?,
    gstin:     m['gstin']     as String?,
    phone:     m['phone']     as String?,
    email:     m['email']     as String?,
    createdAt: _parseDate(m['createdAt']) ?? DateTime.now(),
  );

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    try { return (v as dynamic).toDate() as DateTime; } catch (_) { return null; }
  }

  CompanyModel copyWith({
    String? name, String? address, String? gstin,
    String? phone, String? email,
  }) => CompanyModel(
    id: id, ownerUid: ownerUid,
    name:      name      ?? this.name,
    address:   address   ?? this.address,
    gstin:     gstin     ?? this.gstin,
    phone:     phone     ?? this.phone,
    email:     email     ?? this.email,
    createdAt: createdAt,
  );
}