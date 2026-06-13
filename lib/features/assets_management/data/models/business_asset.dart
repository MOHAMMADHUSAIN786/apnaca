class BusinessAsset {
  final int id;
  final String name;
  final String description;
  final AssetCategory category;
  final double purchasePrice;
  final DateTime purchaseDate;
  final double currentValue;
  final double depreciationRate;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;

  BusinessAsset({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.purchasePrice,
    required this.purchaseDate,
    required this.currentValue,
    required this.depreciationRate,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
  });
}

enum AssetCategory { machinery, vehicle, equipment, furniture, other }