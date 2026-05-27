import 'sync_service.dart';

class AutoSync {
  // Call this after every create/update/delete operation
  static Future<void> syncAfterChange() async {
    // Wait 1 second to batch multiple operations
    await Future.delayed(const Duration(milliseconds: 500));
    await FirebaseSyncService.uploadDatabase();
    print('🔄 Auto-sync completed');
  }

  // For real-time sync (optional)
  static Future<void> syncNow() async {
    await FirebaseSyncService.uploadDatabase();
  }
}