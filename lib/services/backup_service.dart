import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../database/database.dart';

class BackupService {
  static const String _lastBackupKey = 'last_backup_timestamp';
  static const String _backupEnabledKey = 'backup_enabled';
  static const int _backupIntervalHours = 24; // Daily backup

  /// Check if backup is needed and perform it
  static Future<bool> checkAndPerformBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupEnabled = prefs.getBool(_backupEnabledKey) ?? true;

      if (!backupEnabled) {
        return false;
      }

      final lastBackup = prefs.getInt(_lastBackupKey);
      final now = DateTime.now().millisecondsSinceEpoch;
      final hoursSinceLastBackup = lastBackup != null
          ? (now - lastBackup) / (1000 * 60 * 60)
          : _backupIntervalHours + 1;

      if (hoursSinceLastBackup >= _backupIntervalHours) {
        return await performBackup();
      }

      return false;
    } catch (e) {
      print('Backup check error: $e');
      return false;
    }
  }

  /// Perform manual backup
  static Future<bool> performBackup() async {
    try {
      // Get database path directly
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dbFolder.path, 'pos_database.db');

      if (!File(dbPath).existsSync()) {
        print('Database file not found: $dbPath');
        return false;
      }

      // Get backup directory
      final backupDir = await _getBackupDirectory();
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // Create backup filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupFile = File('${backupDir.path}/backup_$timestamp.db');

      // Copy database file
      final sourceFile = File(dbPath);
      await sourceFile.copy(backupFile.path);

      // Update last backup timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);

      // Clean up old backups (keep last 30 days)
      await _cleanupOldBackups(backupDir);

      print('Backup created: ${backupFile.path}');
      return true;
    } catch (e) {
      print('Backup error: $e');
      return false;
    }
  }

  /// Restore from backup
  static Future<bool> restoreFromBackup(String backupFilePath) async {
    try {
      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found: $backupFilePath');
      }

      // Get database path directly
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dbFolder.path, 'pos_database.db');

      // Backup current database before restore
      final currentDb = File(dbPath);
      if (await currentDb.exists()) {
        final restoreBackupDir = await _getBackupDirectory();
        final restoreBackupFile = File(
            '${restoreBackupDir.path}/pre_restore_${DateTime.now().toIso8601String().replaceAll(':', '-')}.db');
        await currentDb.copy(restoreBackupFile.path);
      }

      // Restore from backup
      await backupFile.copy(dbPath);

      print('Database restored from: $backupFilePath');
      return true;
    } catch (e) {
      print('Restore error: $e');
      return false;
    }
  }

  /// Get list of available backups
  static Future<List<FileSystemEntity>> getAvailableBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      if (!await backupDir.exists()) {
        return [];
      }

      final backups = backupDir
          .listSync()
          .where((file) => file.path.endsWith('.db'))
          .toList();

      // Sort by modification time (newest first)
      backups.sort((a, b) {
        final aStat = File(a.path).statSync();
        final bStat = File(b.path).statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return backups;
    } catch (e) {
      print('Get backups error: $e');
      return [];
    }
  }

  /// Get backup directory
  static Future<Directory> _getBackupDirectory() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        return Directory('$appData/OfflinePOS/backups');
      }
    }

    // Fallback to application documents directory
    final documentsDir = await getApplicationDocumentsDirectory();
    return Directory('${documentsDir.path}/backups');
  }

  /// Clean up old backups (keep last 30 days)
  static Future<void> _cleanupOldBackups(Directory backupDir) async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final files = backupDir.listSync();

      for (final file in files) {
        if (file is File && file.path.endsWith('.db')) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            print('Deleted old backup: ${file.path}');
          }
        }
      }
    } catch (e) {
      print('Cleanup error: $e');
    }
  }

  /// Enable/disable automatic backups
  static Future<void> setBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backupEnabledKey, enabled);
  }

  /// Check if backups are enabled
  static Future<bool> isBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_backupEnabledKey) ?? true;
  }

  /// Get last backup timestamp
  static Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastBackupKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  /// Create backup (alias for performBackup for compatibility)
  static Future<bool> createBackup(AppDatabase database) async {
    return await performBackup();
  }

  /// Clear all data (dangerous operation - use with caution)
  static Future<bool> clearAllData(AppDatabase database) async {
    try {
      // This is a dangerous operation - should be confirmed by user
      // For now, we'll just return false to prevent accidental data loss
      // In production, implement proper data clearing with confirmation
      return false;
    } catch (e) {
      print('Error clearing data: $e');
      return false;
    }
  }
}
