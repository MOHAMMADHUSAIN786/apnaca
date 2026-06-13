import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../database/app_database.dart';

class OutboxSyncService {
  OutboxSyncService._internal();
  static final OutboxSyncService instance = OutboxSyncService._internal();
  
  /// Optional HTTP client for easier testing/mocking. Defaults to `http.Client()`.
  http.Client httpClient = http.Client();

  /// Status notifier for UI widgets to show sync state.
  /// Map keys: `state` = 'idle'|'syncing'|'error', `lastSynced` = ISO string or null, `error` = message or null
  final ValueNotifier<Map<String, dynamic>> statusNotifier = ValueNotifier({
    'state': 'idle',
    'lastSynced': null,
    'error': null,
  });

  ValueListenable<Map<String, dynamic>> get statusListenable => statusNotifier;

  Timer? _timer;
  bool _running = false;

  /// Start periodic background sync every [periodSeconds].
  void startPeriodicSync({int periodSeconds = 30}) {
    stop();
    _timer = Timer.periodic(Duration(seconds: periodSeconds), (_) => processOutbox());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Process pending outbox rows.
  Future<void> processOutbox() async {
    if (_running) return;
    _running = true;
    // update status
    statusNotifier.value = {
      'state': 'syncing',
      'lastSynced': statusNotifier.value['lastSynced'],
      'error': null,
    };
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.rawQuery('SELECT * FROM outbox WHERE status = ?', ['pending']);
      final now = DateTime.now();

      for (final row in rows) {
        try {
          final id = row['id'] as int;
          final lastTry = row['last_try'] as String?;
          if (lastTry != null) {
            // simple backoff: skip if last try was within 10 seconds
            final parsed = DateTime.tryParse(lastTry);
            if (parsed != null && now.difference(parsed).inSeconds < 10) continue;
          }

          final payload = {
            'entity_type': row['entity_type'],
            'entity_id': row['entity_id'],
            'action': row['action'],
            'payload': jsonDecode((row['payload'] as String?) ?? 'null'),
            'created_at': row['created_at'],
          };

          final ok = await _sendToServer(payload);
          if (ok) {
            await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
            // update lastSynced time
            statusNotifier.value = {
              'state': 'idle',
              'lastSynced': now.toIso8601String(),
              'error': null,
            };
            // log success
            try {
              await AppDatabase.instance.addSyncLog('success', 'outbox id:$id uploaded');
            } catch (_) {}
          } else {
            await db.update('outbox', {'last_try': now.toIso8601String()}, where: 'id = ?', whereArgs: [id]);
            statusNotifier.value = {
              'state': 'error',
              'lastSynced': statusNotifier.value['lastSynced'],
              'error': 'upload failed',
            };
            try {
              await AppDatabase.instance.addSyncLog('failure', 'outbox id:$id upload failed');
            } catch (_) {}
          }
        } catch (e) {
          // individual row failure — update last_try so we don't busy-loop
          try {
            final id = row['id'] as int;
            await db.update('outbox', {'last_try': now.toIso8601String()}, where: 'id = ?', whereArgs: [id]);
            statusNotifier.value = {
              'state': 'error',
              'lastSynced': statusNotifier.value['lastSynced'],
              'error': e.toString(),
            };
            try {
              await AppDatabase.instance.addSyncLog('error', 'outbox id:$id error: ${e.toString()}');
            } catch (_) {}
          } catch (_) {}
        }
      }
    } catch (e) {
      // top-level error — publish status
      statusNotifier.value = {
        'state': 'error',
        'lastSynced': statusNotifier.value['lastSynced'],
        'error': e.toString(),
      };
      try {
        await AppDatabase.instance.addSyncLog('error', 'processOutbox error: ${e.toString()}');
      } catch (_) {}
    } finally {
      _running = false;
    }
  }

  /// Replace this with your real upload endpoint and auth.
  Future<bool> _sendToServer(Map<String, dynamic> payload) async {
    try {
      final endpoint = dotenv.env['SYNC_ENDPOINT']?.trim() ?? 'https://api.example.com/sync';
      final token = dotenv.env['SYNC_AUTH_TOKEN']?.trim();
      final uri = Uri.parse(endpoint);
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

        final resp = await httpClient
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      return false;
    }
  }
}
