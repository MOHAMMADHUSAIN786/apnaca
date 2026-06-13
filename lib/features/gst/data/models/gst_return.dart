class GSTReturn {
  final int id;
  final DateTime period;
  final double totalSales;
  final double totalPurchases;
  final double totalTaxPayable;
  final double totalTaxCredit;
  final double netTaxPayable;
  final GSTReturnStatus status;

  GSTReturn({
    required this.id,
    required this.period,
    required this.totalSales,
    required this.totalPurchases,
    required this.totalTaxPayable,
    required this.totalTaxCredit,
    required this.netTaxPayable,
    required this.status,
  });
}

enum GSTReturnStatus { draft, filed, amended }