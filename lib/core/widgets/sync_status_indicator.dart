import 'package:flutter/material.dart';
import '../../core/services/outbox_sync_service.dart';
import '../../database/app_database.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  String _formatLast(String? iso) {
    if (iso == null) return 'never';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (e) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: OutboxSyncService.instance.statusListenable,
      builder: (context, v, child) {
        final state = v['state'] as String? ?? 'idle';
        final last = v['lastSynced'] as String?;
        final error = v['error'] as String?;

        Color color;
        IconData icon;
        String tooltip;

        if (state == 'syncing') {
          color = Colors.orange;
          icon = Icons.sync;
          tooltip = 'Syncing...';
        } else if (state == 'error') {
          color = Colors.red;
          icon = Icons.error;
          tooltip = 'Sync error: ${error ?? 'unknown'}';
        } else {
          color = Colors.green;
          icon = Icons.check_circle;
          tooltip = 'Last: ${_formatLast(last)}';
        }

        return IconButton(
          icon: Icon(icon, color: color, size: 20),
          tooltip: tooltip,
          onPressed: () async {
            // show recent sync logs
            final logs = await AppDatabase.instance.getRecentSyncLogs(limit: 50);
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sync Log (recent)'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: logs.isEmpty
                      ? const Text('No sync attempts yet')
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: logs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (c, i) {
                            final row = logs[i];
                            final ts = row['created_at'] as String? ?? '';
                            final status = row['status'] as String? ?? '';
                            final msg = row['message'] as String? ?? '';
                            return ListTile(
                              dense: true,
                              title: Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(msg),
                              trailing: Text(ts.split(' ').first),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                  TextButton(onPressed: () => OutboxSyncService.instance.processOutbox().then((_) => Navigator.of(ctx).pop()), child: const Text('Retry Now')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
