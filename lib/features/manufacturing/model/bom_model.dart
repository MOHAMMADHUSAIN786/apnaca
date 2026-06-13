class BomModel {
  final int? id;
  final int finishedItemId;
  final String name;
  final String? notes;
  final String? createdAt;

  BomModel({
    this.id,
    required this.finishedItemId,
    required this.name,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'finished_item_id': finishedItemId,
      'name': name,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  factory BomModel.fromMap(Map<String, dynamic> map) {
    return BomModel(
      id: map['id'],
      finishedItemId: map['finished_item_id'],
      name: map['name'],
      notes: map['notes'],
      createdAt: map['created_at'],
    );
  }
}

class BomItemModel {
  final int? id;
  final int bomId;
  final int rawItemId;
  final double qty;

  BomItemModel({
    this.id,
    required this.bomId,
    required this.rawItemId,
    required this.qty,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bom_id': bomId,
      'raw_item_id': rawItemId,
      'qty': qty,
    };
  }

  factory BomItemModel.fromMap(Map<String, dynamic> map) {
    return BomItemModel(
      id: map['id'],
      bomId: map['bom_id'],
      rawItemId: map['raw_item_id'],
      qty: (map['qty'] as num).toDouble(),
    );
  }
}
