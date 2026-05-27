import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../database/app_database.dart';

class FirebaseSyncService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static String? _currentUserId;
  static Timer? _debounceTimer;

  // Set current user ID (call after login)
  static void setCurrentUser(String userId) {
    _currentUserId = userId;
    print('👤 Current user set: $_currentUserId');
  }

  // Get current user ID
  static String get _userId {
    if (_currentUserId == null) {
      throw Exception('User not logged in. Call setCurrentUser() first.');
    }
    return _currentUserId!;
  }

  // Get database file path
  static Future<String> get _dbPath async {
    final dbPath = await getDatabasesPath();
    return path.join(dbPath, 'billnex.db');
  }

  // Upload database to Firebase Storage
  static Future<bool> uploadDatabase() async {
    if (_currentUserId == null) {
      print('⚠️ Cannot upload: No user logged in');
      return false;
    }

    try {
      final dbFile = File(await _dbPath);
      if (!await dbFile.exists()) {
        print('❌ Database file not found');
        return false;
      }

      final fileSize = await dbFile.length();
      final fileName = 'user_${_userId}.db';
      final ref = _storage.ref().child('database_backups/$fileName');

      print('📤 Uploading database...');
      print('   User: $_userId');
      print('   File: $fileName');
      print('   Size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      await ref.putFile(dbFile);
      print('✅ Database uploaded successfully: $fileName');
      return true;
    } catch (e) {
      print('❌ Upload failed: $e');
      return false;
    }
  }

  // Debounced upload (for auto-sync)
  static void debouncedUpload() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      print('🔄 Auto-sync triggered');
      uploadDatabase();
    });
  }

  // Download database from Firebase Storage
  static Future<bool> downloadDatabase() async {
    if (_currentUserId == null) {
      print('⚠️ Cannot download: No user logged in');
      return false;
    }

    try {
      final fileName = 'user_${_userId}.db';
      final ref = _storage.ref().child('database_backups/$fileName');

      print('📥 Checking for existing backup...');
      print('   User: $_userId');
      print('   File: $fileName');

      // Check if file exists
      try {
        await ref.getMetadata();
      } catch (e) {
        print('ℹ️ No backup found for user: $_userId');
        return false;
      }

      print('📥 Downloading database...');

      // Download file
      final bytes = await ref.getData();
      if (bytes == null) return false;

      print('📦 Downloaded ${bytes.length} bytes');

      // Close current database connection
      await AppDatabase.instance.close();

      // Replace local database
      final dbFile = File(await _dbPath);
      await dbFile.writeAsBytes(bytes);

      // Reopen database
      await AppDatabase.instance.database;

      print('✅ Database restored successfully: $fileName');
      return true;
    } catch (e) {
      print('❌ Download failed: $e');
      return false;
    }
  }

  // Get backup info
  static Future<Map<String, dynamic>?> getBackupInfo() async {
    if (_currentUserId == null) return null;

    try {
      final fileName = 'user_${_userId}.db';
      final ref = _storage.ref().child('database_backups/$fileName');
      final metadata = await ref.getMetadata();

      return {
        'fileName': fileName,
        'size': metadata.size,
        'lastModified': metadata.updated,
      };
    } catch (e) {
      print('❌ Get info failed: $e');
      return null;
    }
  }

  // Delete remote backup
  static Future<bool> deleteRemoteBackup() async {
    if (_currentUserId == null) return false;

    try {
      final fileName = 'user_${_userId}.db';
      final ref = _storage.ref().child('database_backups/$fileName');
      await ref.delete();
      print('✅ Remote backup deleted: $fileName');
      return true;
    } catch (e) {
      print('❌ Delete failed: $e');
      return false;
    }
  }
}