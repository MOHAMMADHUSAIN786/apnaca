class ExpenseModel {
  final int? id;
  final String category;
  final double amount;
  final String date;
  final String? notes;
  final String? createdAt;

  const ExpenseModel({
    this.id,
    required this.category,
    required this.amount,
    required this.date,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'category': category,
        'amount': amount,
        'date': date,
        'notes': notes,
        'created_at': createdAt,
      };

  factory ExpenseModel.fromMap(Map<String, dynamic> m) => ExpenseModel(
        id: m['id'] as int?,
        category: m['category'] as String? ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        date: m['date'] as String? ?? '',
        notes: m['notes'] as String?,
        createdAt: m['created_at'] as String?,
      );

  static const List<String> categories = [
    'Rent',
    'Salary',
    'Electricity',
    'Internet',
    'Transport',
    'Marketing',
    'Maintenance',
    'Purchase Return',
    'Miscellaneous',
  ];

  ExpenseModel copyWith({
    int? id,
    String? category,
    double? amount,
    String? date,
    String? notes,
  }) =>
      ExpenseModel(
        id: id ?? this.id,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
