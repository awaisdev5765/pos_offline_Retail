import 'dart:io';
import 'package:flutter/services.dart';

/// Service for accessing Windows-specific features
class WindowsFeaturesService {
  static const MethodChannel _channel = MethodChannel('windows_features');

  /// Check if running on Windows
  static bool get isWindows => Platform.isWindows;

  /// Show a Windows toast notification
  /// 
  /// [title] - The title of the notification
  /// [message] - The message body
  static Future<bool> showToastNotification({
    required String title,
    required String message,
  }) async {
    if (!isWindows) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>(
        'showToastNotification',
        {
          'title': title,
          'message': message,
        },
      );
      return result ?? false;
    } catch (e) {
      print('Error showing toast notification: $e');
      return false;
    }
  }

  /// Read a value from Windows Registry
  /// 
  /// [key] - Registry key path (e.g., "Software\\MyApp")
  /// [value] - Value name
  /// [hive] - Registry hive ("HKEY_CURRENT_USER" or "HKEY_LOCAL_MACHINE")
  static Future<dynamic> readRegistryValue({
    required String key,
    required String value,
    String hive = 'HKEY_CURRENT_USER',
  }) async {
    if (!isWindows) return null;
    
    try {
      final result = await _channel.invokeMethod<dynamic>(
        'readRegistryValue',
        {
          'key': key,
          'value': value,
          'hive': hive,
        },
      );
      return result;
    } catch (e) {
      print('Error reading registry value: $e');
      return null;
    }
  }

  /// Write a value to Windows Registry
  /// 
  /// [key] - Registry key path
  /// [value] - Value name
  /// [data] - Data to write (String or int)
  /// [hive] - Registry hive
  static Future<bool> writeRegistryValue({
    required String key,
    required String value,
    required dynamic data,
    String hive = 'HKEY_CURRENT_USER',
  }) async {
    if (!isWindows) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>(
        'writeRegistryValue',
        {
          'key': key,
          'value': value,
          'data': data,
          'hive': hive,
        },
      );
      return result ?? false;
    } catch (e) {
      print('Error writing registry value: $e');
      return false;
    }
  }

  /// Write to Windows Event Log
  /// 
  /// [message] - Event message
  /// [level] - Event level ("INFO", "WARNING", "ERROR")
  static Future<bool> writeEventLog({
    required String message,
    String level = 'INFO',
  }) async {
    if (!isWindows) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>(
        'writeEventLog',
        {
          'message': message,
          'level': level,
        },
      );
      return result ?? false;
    } catch (e) {
      print('Error writing event log: $e');
      return false;
    }
  }

  /// Register a file association
  /// 
  /// [extension] - File extension (e.g., ".pos")
  /// [progId] - Program identifier (e.g., "POSFile")
  static Future<bool> registerFileAssociation({
    required String extension,
    required String progId,
  }) async {
    if (!isWindows) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>(
        'registerFileAssociation',
        {
          'extension': extension,
          'progId': progId,
        },
      );
      return result ?? false;
    } catch (e) {
      print('Error registering file association: $e');
      return false;
    }
  }

  /// Update Windows Jump List
  /// 
  /// [tasks] - List of task items to add
  static Future<bool> updateJumpList({
    required List<Map<String, dynamic>> tasks,
  }) async {
    if (!isWindows) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>(
        'updateJumpList',
        {
          'tasks': tasks,
        },
      );
      return result ?? false;
    } catch (e) {
      print('Error updating jump list: $e');
      return false;
    }
  }

  /// Get Windows print queue information
  static Future<List<Map<String, dynamic>>> getPrintQueue() async {
    if (!isWindows) return [];
    
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getPrintQueue',
      );
      if (result != null) {
        return result.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error getting print queue: $e');
      return [];
    }
  }

  /// Request UAC elevation (requires manifest configuration)
  static Future<bool> requestUACElevation() async {
    if (!isWindows) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestUACElevation',
      );
      return result ?? false;
    } catch (e) {
      print('Error requesting UAC elevation: $e');
      return false;
    }
  }

  /// Get Windows performance counters
  static Future<Map<String, dynamic>> getPerformanceCounters() async {
    if (!isWindows) return {};
    
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getPerformanceCounters',
      );
      if (result != null) {
        return result.cast<String, dynamic>();
      }
      return {};
    } catch (e) {
      print('Error getting performance counters: $e');
      return {};
    }
  }

  /// Create a scheduled task
  /// 
  /// [name] - Task name
  /// [command] - Command to execute
  /// [schedule] - Schedule configuration
  static Future<bool> createScheduledTask({
    required String name,
    required String command,
    required Map<String, dynamic> schedule,
  }) async {
    if (!isWindows) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>(
        'createScheduledTask',
        {
          'name': name,
          'command': command,
          'schedule': schedule,
        },
      );
      return result ?? false;
    } catch (e) {
      print('Error creating scheduled task: $e');
      return false;
    }
  }
}

