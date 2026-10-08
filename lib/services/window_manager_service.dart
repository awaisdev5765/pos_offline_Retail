import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowManagerService {
  static bool _isInitialized = false;

  /// Initialize window manager for desktop platforms
  static Future<void> initialize() async {
    if (_isInitialized || !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }

    try {
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(1280, 720),
        minimumSize: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      _isInitialized = true;
      debugPrint('✅ Window manager initialized');
    } catch (e) {
      debugPrint('⚠️ Window manager initialization failed: $e');
    }
  }

  /// Minimize the window
  static Future<void> minimize() async {
    if (!_isInitialized) return;
    try {
      await windowManager.minimize();
    } catch (e) {
      debugPrint('Error minimizing window: $e');
    }
  }

  /// Maximize the window
  static Future<void> maximize() async {
    if (!_isInitialized) return;
    try {
      await windowManager.maximize();
    } catch (e) {
      debugPrint('Error maximizing window: $e');
    }
  }

  /// Restore the window from minimized/maximized state
  static Future<void> restore() async {
    if (!_isInitialized) return;
    try {
      await windowManager.restore();
    } catch (e) {
      debugPrint('Error restoring window: $e');
    }
  }

  /// Check if window is maximized
  static Future<bool> isMaximized() async {
    if (!_isInitialized) return false;
    try {
      return await windowManager.isMaximized();
    } catch (e) {
      debugPrint('Error checking if maximized: $e');
      return false;
    }
  }

  /// Toggle maximize/restore
  static Future<void> toggleMaximize() async {
    if (!_isInitialized) return;
    try {
      final isMax = await windowManager.isMaximized();
      if (isMax) {
        await windowManager.restore();
      } else {
        await windowManager.maximize();
      }
    } catch (e) {
      debugPrint('Error toggling maximize: $e');
    }
  }

  /// Close the window
  static Future<void> close() async {
    if (!_isInitialized) return;
    try {
      await windowManager.close();
    } catch (e) {
      debugPrint('Error closing window: $e');
    }
  }

  /// Hide the window (minimize to tray)
  static Future<void> hide() async {
    if (!_isInitialized) return;
    try {
      await windowManager.hide();
    } catch (e) {
      debugPrint('Error hiding window: $e');
    }
  }

  /// Show the window
  static Future<void> show() async {
    if (!_isInitialized) return;
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('Error showing window: $e');
    }
  }

  /// Check if window is visible
  static Future<bool> isVisible() async {
    if (!_isInitialized) return false;
    try {
      return await windowManager.isVisible();
    } catch (e) {
      debugPrint('Error checking visibility: $e');
      return false;
    }
  }

  /// Set window title
  static Future<void> setTitle(String title) async {
    if (!_isInitialized) return;
    try {
      await windowManager.setTitle(title);
    } catch (e) {
      debugPrint('Error setting title: $e');
    }
  }
}

