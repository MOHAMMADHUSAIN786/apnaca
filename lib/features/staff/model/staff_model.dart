class StaffModel {
  final int? id;
  final String name;
  final String role; // 'admin', 'staff'
  final String? phone;
  final String? pin; // for POS lock
  final double? salary;
  final String? createdAt;

  StaffModel({
    this.id,
    required this.name,
    this.role = 'staff',
    this.phone,
    this.pin,
    this.salary,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'role': role,
      'phone': phone,
      'pin': pin,
      'salary': salary,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  factory StaffModel.fromMap(Map<String, dynamic> map) {
    return StaffModel(
      id: map['id'],
      name: map['name'],
      role: map['role'] ?? 'staff',
      phone: map['phone'],
      pin: map['pin'],
      salary: map['salary'] != null ? (map['salary'] as num).toDouble() : null,
      createdAt: map['created_at'],
    );
  }
}

class StaffAttendanceModel {
  final int? id;
  final int staffId;
  final String date;
  final String status; // 'present', 'absent', 'half-day'
  final String? notes;
  final String? createdAt;

  StaffAttendanceModel({
    this.id,
    required this.staffId,
    required this.date,
    required this.status,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'staff_id': staffId,
      'date': date,
      'status': status,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  factory StaffAttendanceModel.fromMap(Map<String, dynamic> map) {
    return StaffAttendanceModel(
      id: map['id'],
      staffId: map['staff_id'],
      date: map['date'],
      status: map['status'],
      notes: map['notes'],
      createdAt: map['created_at'],
    );
  }
}
