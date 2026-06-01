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
  //  DB PATH — user-specific, matches AppDatabase
  // ─────────────────────────────────────────────────────────
  static Future<String> _getDbPath(String uid) async {
    final dbDir = await getDatabasesPath();
    return path.join(dbDir, 'billnex_$uid.db');
  }

  // ─────────────────────────────────────────────────────────
  //  UPLOAD — safe version with WAL flush + file existence check
  // ─────────────────────────────────────────────────────────
  static Future<bool> uploadDatabase() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;

    final uid = _currentUserId!;

    try {
      // 1. Flush WAL — ensure all pending writes are in the main DB file
      try {
        final db = await AppDatabase.instance.database;
        await db.execute('PRAGMA wal_checkpoint(FULL)');
      } catch (_) {
        // DB may already be closing — continue anyway, file still readable
      }

      // 2. Read the actual file from disk
      final localPath = await _getDbPath(uid);
      final dbFile    = File(localPath);

      if (!await dbFile.exists()) {
        print('⚠️ No local DB file found for user $uid — nothing to backup');
        return false;
      }

      final fileSize = await dbFile.length();
      if (fileSize == 0) {
        print('⚠️ DB file is empty — skipping backup');
        return false;
      }

      // 3. Upload to Firebase Storage
      final ref = _storage
          .ref()
          .child('database_backups/user_$uid.db');

      await ref.putFile(
        dbFile,
        SettableMetadata(
          customMetadata: {
            'uid':         uid,
            'uploaded_at': DateTime.now().toIso8601String(),
            'size_kb':     (fileSize / 1024).toStringAsFixed(2),
          },
        ),
      );

      print('✅ Backup uploaded: user_$uid.db (${(fileSize/1024).toStringAsFixed(1)} KB)');
      return true;
    } catch (e) {
      print('❌ Upload failed: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  //  LOGOUT BACKUP — guaranteed safe sequence
  //  Call this ONLY during logout, before clearAllData()
  // ─────────────────────────────────────────────────────────
  static Future<bool> uploadBeforeLogout() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;

    // Cancel any pending debounce timer — we're doing a full upload now
    _debounceTimer?.cancel();
    _debounceTimer = null;

    return await uploadDatabase();
  }

  // ─────────────────────────────────────────────────────────
  //  DEBOUNCED AUTO-SYNC (2 sec after any DB write)
  // ─────────────────────────────────────────────────────────
  static void debouncedUpload() {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      uploadDatabase();
    });
  }

  // ─────────────────────────────────────────────────────────
  //  DOWNLOAD — restore from Firebase Storage
  // ─────────────────────────────────────────────────────────
  static Future<bool> downloadDatabase() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;

    final uid = _currentUserId!;

    try {
      final ref = _storage
          .ref()
          .child('database_backups/user_$uid.db');

      // Check if backup exists
      try {
        await ref.getMetadata();
      } catch (_) {
        print('ℹ️ No cloud backup found for user $uid');
        return false;
      }

      // Download bytes
      final bytes = await ref.getData();
      if (bytes == null || bytes.isEmpty) return false;

      // Close DB connection before overwriting file
      await AppDatabase.instance.close();

      // Write to user-specific local path
      final localPath = await _getDbPath(uid);
      final dbFile    = File(localPath);
      await dbFile.writeAsBytes(bytes, flush: true);

      // Re-open (AppDatabase._currentUid is already set via switchUser)
      await AppDatabase.instance.database;

      print('✅ Database restored for user $uid (${(bytes.length/1024).toStringAsFixed(1)} KB)');
      return true;
    } catch (e) {
      print('❌ Download failed: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  //  BACKUP INFO
  // ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getBackupInfo() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return null;
    try {
      final ref      = _storage.ref().child('database_backups/user_$_userId.db');
      final metadata = await ref.getMetadata();
      return {
        'fileName':    'user_$_userId.db',
        'size':        metadata.size ?? 0,
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
      await _storage
          .ref()
          .child('database_backups/user_$_userId.db')
          .delete();
      return true;
    } catch (e) {
      print('❌ Delete failed: $e');
      return false;
    }
  }
}