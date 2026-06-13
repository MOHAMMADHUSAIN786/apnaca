class RepairJob {
  final int id;
  final String customerName;
  final String deviceModel;
  final String deviceIssue;
  final DateTime receivedDate;
  final DateTime? completedDate;
  final double serviceCharge;
  final double partsCost;
  final RepairStatus status;

  RepairJob({
    required this.id,
    required this.customerName,
    required this.deviceModel,
    required this.deviceIssue,
    required this.receivedDate,
    this.completedDate,
    required this.serviceCharge,
    required this.partsCost,
    required this.status,
  });
}

enum RepairStatus { inProgress, completed, delivered }