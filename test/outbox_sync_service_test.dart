import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
import 'package:apnaca/database/app_database.dart';
import 'package:apnaca/core/services/outbox_sync_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    // Ensure dotenv has something (optional)
    dotenv.load();
  });

  test('processOutbox uploads pending row and logs success', () async {
    await AppDatabase.switchUser('test_outbox_success');
    final db = await AppDatabase.instance.database;
    // clean tables
    try { await db.delete('outbox'); } catch (_) {}
    try { await db.delete('sync_logs'); } catch (_) {}

    // insert pending outbox
    final id = await AppDatabase.instance.addOutbox('test','create','{"a":1}');
    expect(id, isNonZero);

    // mock http client returning 200
    OutboxSyncService.instance.httpClient = MockClient((req) async {
      return http.Response('ok', 200);
    });

    await OutboxSyncService.instance.processOutbox();

    // outbox row should be deleted
    final rows = await db.rawQuery('SELECT COUNT(1) as c FROM outbox');
    expect((rows.first['c'] as int), 0);

    // sync_logs should have at least one success entry
    final logs = await db.rawQuery('SELECT * FROM sync_logs ORDER BY id DESC LIMIT 1');
    expect(logs.isNotEmpty, true);
    expect((logs.first['status'] as String), 'success');
  });

  test('processOutbox handles server failure and updates last_try', () async {
    await AppDatabase.switchUser('test_outbox_fail');
    final db = await AppDatabase.instance.database;
    // clean
    try { await db.delete('outbox'); } catch (_) {}
    try { await db.delete('sync_logs'); } catch (_) {}

    final id = await AppDatabase.instance.addOutbox('test','create','{"b":2}');
    expect(id, isNonZero);

    // mock http client returning 500
    OutboxSyncService.instance.httpClient = MockClient((req) async {
      return http.Response('error', 500);
    });

    await OutboxSyncService.instance.processOutbox();

    // outbox row should still exist
    final rows = await db.rawQuery('SELECT id, last_try FROM outbox WHERE id = ?', [id]);
    expect(rows.isNotEmpty, true);
    expect(rows.first['last_try'], isNotNull);

    // sync_logs should have a failure entry
    final logs = await db.rawQuery('SELECT * FROM sync_logs ORDER BY id DESC LIMIT 1');
    expect(logs.isNotEmpty, true);
    expect((logs.first['status'] as String), isIn(['failure','error']));
  });
}
