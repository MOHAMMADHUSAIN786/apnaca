class LedgerEntryModel {
  final int? id;
  final String partyType; // 'customer' | 'supplier'
  final int partyId;
  final String partyName;
  final String date;
  final double amount;
  final String type; // 'debit' | 'credit'
  final String? notes;
  final String? refBillNumber;
  final String? createdAt;

  const LedgerEntryModel({
    this.id,
    required this.partyType,
    required this.partyId,
    required this.partyName,
    required this.date,
    required this.amount,
    required this.type,
    this.notes,
    this.refBillNumber,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'party_type': partyType,
        'party_id': partyId,
        'party_name': partyName,
        'date': date,
        'amount': amount,
        'type': type,
        'notes': notes,
        'ref_bill_number': refBillNumber,
        'created_at': createdAt,
      };

  factory LedgerEntryModel.fromMap(Map<String, dynamic> m) => LedgerEntryModel(
        id: m['id'] as int?,
        partyType: m['party_type'] as String? ?? 'customer',
        partyId: m['party_id'] as int? ?? 0,
        partyName: m['party_name'] as String? ?? '',
        date: m['date'] as String? ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        type: m['type'] as String? ?? 'debit',
        notes: m['notes'] as String?,
        refBillNumber: m['ref_bill_number'] as String?,
        createdAt: m['created_at'] as String?,
      );

  bool get isDebit => type == 'debit';
  bool get isCredit => type == 'credit';
}
