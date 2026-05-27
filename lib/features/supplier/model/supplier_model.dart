class SupplierModel {
  final int? id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? gstNumber;
  final String? state;

  const SupplierModel({
    this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.gstNumber,
    this.state,
  });

  factory SupplierModel.fromMap(Map<String, dynamic> map) => SupplierModel(
    id: map['id'] as int?,
    name: map['name'] as String,
    email: map['email'] as String?,
    phone: map['phone'] as String?,
    address: map['address'] as String?,
    gstNumber: map['gst_number'] as String?,
    state: map['state'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'gst_number': gstNumber,
    'state': state,
  };

  SupplierModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? gstNumber,
    String? state,
  }) =>
      SupplierModel(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        gstNumber: gstNumber ?? this.gstNumber,
        state: state ?? this.state,
      );
}