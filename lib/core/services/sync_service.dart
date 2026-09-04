// lib/core/services/sync_service.dart
// UPDATED: Per-company Firebase Storage backup
// Storage paths:
//   Owner default DB  → database_backups/user_{uid}.db
//   Company-specific  → database_backups/user_{uid}_comp_{companyId}.db

import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../database/app_database.dart';

class FirebaseSyncService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static String? _currentUserId;
  static Timer? _debounceTimer;

  // ─────────────────────────────────────────────────────────
  //  SET USER
  // ─────────────────────────────────────────────────────────
  static void setCurrentUser(String userId) {
    _currentUserId = userId.isEmpty ? null : userId;
  }

  static String get _userId {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      throw Exception('User not logged in.');
    }
    return _currentUserId!;
  }

  // ─────────────────────────────────────────────────────────
  //  STORAGE PATH — company-aware
  //  No company   → database_backups/user_{uid}.db
  //  With company → database_backups/user_{uid}_comp_{compId}.db
  // ─────────────────────────────────────────────────────────
  static String _storageRef(String uid, String? companyId) {
    if (companyId == null || companyId.isEmpty) {
      return 'database_backups/user_$uid.db';
    }
    final safeId = companyId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'database_backups/user_${uid}_comp_$safeId.db';
  }

  // ─────────────────────────────────────────────────────────
  //  UPLOAD — current active DB (owner or company)
  // ─────────────────────────────────────────────────────────
  static Future<bool> uploadDatabase() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;

    final uid        = _currentUserId!;
    final companyId  = AppDatabase.activeCompanyId;

    try {
      // Flush WAL
      try {
        final db = await AppDatabase.instance.database;
        await db.execute('PRAGMA wal_checkpoint(FULL)');
      } catch (_) {}

      final localPath = await AppDatabase.getDbPath(uid, companyId);
      final dbFile    = File(localPath);

      if (!await dbFile.exists()) {
        print('⚠️ No local DB file found — nothing to backup');
        return false;
      }

      final fileSize = await dbFile.length();
      if (fileSize == 0) {
        print('⚠️ DB file is empty — skipping backup');
        return false;
      }

      final storagePath = _storageRef(uid, companyId);
      final ref = _storage.ref().child(storagePath);

      await ref.putFile(
        dbFile,
        SettableMetadata(
          customMetadata: {
            'uid':         uid,
            'companyId':   companyId ?? 'default',
            'uploaded_at': DateTime.now().toIso8601String(),
            'size_kb':     (fileSize / 1024).toStringAsFixed(2),
          },
        ),
      );

      print('✅ Backup uploaded: $storagePath (${(fileSize/1024).toStringAsFixed(1)} KB)');
      return true;
    } catch (e) {
      print('❌ Upload failed: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  //  UPLOAD ALL COMPANY DBs — call on logout to backup everything
  // ─────────────────────────────────────────────────────────
  static Future<void> uploadAllCompanyDbs(List<String> companyIds) async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;

    final uid        = _currentUserId!;
    final activeComp = AppDatabase.activeCompanyId;

    // Upload default DB
    await uploadDatabase();

    // Upload each company DB
    for (final compId in companyIds) {
      try {
        final localPath = await AppDatabase.getDbPath(uid, compId);
        final dbFile    = File(localPath);
        if (!await dbFile.exists()) continue;

        final fileSize = await dbFile.length();
        if (fileSize == 0) continue;

        final ref = _storage.ref().child(_storageRef(uid, compId));
        await ref.putFile(
          dbFile,
          SettableMetadata(customMetadata: {
            'uid': uid, 'companyId': compId,
            'uploaded_at': DateTime.now().toIso8601String(),
          }),
        );
        print('✅ Company DB uploaded: $compId');
      } catch (e) {
        print('❌ Company DB upload failed for $compId: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  //  DOWNLOAD — for current active company (or default)
  // ─────────────────────────────────────────────────────────
  static Future<bool> downloadDatabase() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;

    final uid       = _currentUserId!;
    final companyId = AppDatabase.activeCompanyId;

    try {
      final storagePath = _storageRef(uid, companyId);
      final ref = _storage.ref().child(storagePath);

      // Check if backup exists
      try { await ref.getMetadata(); } catch (_) {
        print('ℹ️ No cloud backup found for ${companyId ?? "default"}');
        return false;
      }

      final bytes = await ref.getData();
      if (bytes == null || bytes.isEmpty) return false;

      // Close DB before overwriting
      await AppDatabase.instance.close();

      final localPath = await AppDatabase.getDbPath(uid, companyId);
      final dbFile    = File(localPath);
      await dbFile.writeAsBytes(bytes, flush: true);

      // Re-open
      await AppDatabase.instance.database;

      print('✅ DB restored: ${companyId ?? "default"} (${(bytes.length/1024).toStringAsFixed(1)} KB)');
      return true;
    } catch (e) {
      print('❌ Download failed: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  //  DOWNLOAD SPECIFIC COMPANY DB
  //  Call this when user switches to a company for the first time
  // ─────────────────────────────────────────────────────────
  static Future<bool> downloadCompanyDb(String uid, String companyId) async {
    try {
      final storagePath = _storageRef(uid, companyId);
      print('📥 Downloading DB: $storagePath');
      final ref = _storage.ref().child(storagePath);

      // Check metadata first
      try {
        final meta = await ref.getMetadata();
        print('📦 Found backup: ${meta.size} bytes, updated: ${meta.updated}');
      } catch (e) {
        print('ℹ️ No backup for $storagePath — $e');
        return false;
      }

      // Download bytes (max 50MB)
      final bytes = await ref.getData(50 * 1024 * 1024);
      if (bytes == null || bytes.isEmpty) {
        print('⚠️ Downloaded empty bytes for $storagePath');
        return false;
      }

      // Close current DB before overwriting
      await AppDatabase.instance.close();

      // Write to exact path that AppDatabase will open
      final localPath = await AppDatabase.getDbPath(uid, companyId);
      final dbFile = File(localPath);
      await dbFile.parent.create(recursive: true);
      await dbFile.writeAsBytes(bytes, flush: true);

      // Re-open DB
      await AppDatabase.instance.database;

      print('✅ Company DB downloaded: $companyId (${(bytes.length/1024).toStringAsFixed(1)} KB) → $localPath');
      return true;
    } catch (e) {
      print('❌ Company DB download failed for $uid/$companyId: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  //  LOGOUT BACKUP — uploads current active DB
  // ─────────────────────────────────────────────────────────
  static Future<bool> uploadBeforeLogout() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    return await uploadDatabase();
  }

  // ─────────────────────────────────────────────────────────
  //  DEBOUNCED AUTO-SYNC
  // ─────────────────────────────────────────────────────────
  static void debouncedUpload() {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      uploadDatabase();
    });
  }

  // ─────────────────────────────────────────────────────────
  //  BACKUP INFO — current active DB
  // ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getBackupInfo() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return null;
    try {
      final uid       = _currentUserId!;
      final companyId = AppDatabase.activeCompanyId;
      final ref       = _storage.ref().child(_storageRef(uid, companyId));
      final metadata  = await ref.getMetadata();
      return {
        'fileName':     _storageRef(uid, companyId),
        'size':         metadata.size ?? 0,
        'lastModified': metadata.updated,
      };
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────
  //  DELETE REMOTE BACKUP
  // ─────────────────────────────────────────────────────────
  static Future<bool> deleteRemoteBackup() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;
    try {
      final uid       = _currentUserId!;
      final companyId = AppDatabase.activeCompanyId;
      await _storage.ref().child(_storageRef(uid, companyId)).delete();
      return true;
    } catch (e) {
      print('❌ Delete failed: $e');
      return false;
    }
  }
}