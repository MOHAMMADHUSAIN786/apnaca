class BankAccountModel {
  final int? id;
  final String bankName;
  final String accountName;
  final String? accountNumber;
  final String? ifscCode;
  final double openingBalance;
  final String? createdAt;

  BankAccountModel({
    this.id,
    required this.bankName,
    required this.accountName,
    this.accountNumber,
    this.ifscCode,
    this.openingBalance = 0,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bank_name': bankName,
      'account_name': accountName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'opening_balance': openingBalance,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  factory BankAccountModel.fromMap(Map<String, dynamic> map) {
    return BankAccountModel(
      id: map['id'],
      bankName: map['bank_name'],
      accountName: map['account_name'],
      accountNumber: map['account_number'],
      ifscCode: map['ifsc_code'],
      openingBalance: (map['opening_balance'] as num).toDouble(),
      createdAt: map['created_at'],
    );
  }
}

class BankTransactionModel {
  final int? id;
  final int bankAccountId;
  final String date;
  final String type; // 'deposit', 'withdrawal'
  final double amount;
  final String? reference;
  final String? notes;
  final String? createdAt;

  BankTransactionModel({
    this.id,
    required this.bankAccountId,
    required this.date,
    required this.type,
    required this.amount,
    this.reference,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bank_account_id': bankAccountId,
      'date': date,
      'type': type,
      'amount': amount,
      'reference': reference,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  factory BankTransactionModel.fromMap(Map<String, dynamic> map) {
    return BankTransactionModel(
      id: map['id'],
      bankAccountId: map['bank_account_id'],
      date: map['date'],
      type: map['type'],
      amount: (map['amount'] as num).toDouble(),
      reference: map['reference'],
      notes: map['notes'],
      createdAt: map['created_at'],
    );
  }
}
