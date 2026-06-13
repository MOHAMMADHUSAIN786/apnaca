class TallySync {
  final int id;
  final DateTime syncDate;
  final String syncStatus;
  final String syncMessage;

  TallySync({
    required this.id,
    required this.syncDate,
    required this.syncStatus,
    required this.syncMessage,
  });
}