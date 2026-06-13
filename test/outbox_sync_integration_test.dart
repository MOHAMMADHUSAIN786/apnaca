import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:apnaca/core/services/outbox_sync_service.dart';
import 'package:apnaca/database/app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('OutboxSyncService uploads pending outbox rows and deletes them', () async {
    // Use test DB user
    await AppDatabase.switchUser('test_sync');
    // Ensure DB created
    final db = await AppDatabase.instance.database;

    // Insert an outbox row
    await AppDatabase.instance.addOutbox('sale', 'create', jsonEncode({'foo': 'bar'}), entityId: '123');

    // Mock HTTP to return success
    final mockClient = MockClient((req) async {
      return http.Response('ok', 200);
    });
    OutboxSyncService.instance.httpClient = mockClient;

    // Run process
    await OutboxSyncService.instance.processOutbox();

    // Verify outbox table is empty
    final rows = await db.rawQuery('SELECT * FROM outbox');
    expect(rows.length, 0);
  });
}
