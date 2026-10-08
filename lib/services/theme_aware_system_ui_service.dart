import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// Service to update system UI overlay style based on theme
class ThemeAwareSystemUIService {
  /// Update system UI overlay style based on theme brightness
  static void updateSystemUIOverlayStyle(BuildContext? context, Brightness brightness) {
    if (context == null) return;
    
    final isDark = brightness == Brightness.dark;
    
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark 
            ? const Color(0xFF1C2128) // Dark background
            : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  /// Update system UI overlay style based on theme mode
  static void updateSystemUIOverlayStyleFromThemeMode(
    BuildContext? context,
    ThemeMode themeMode,
  ) {
    if (context == null) return;
    
    final brightness = _getBrightnessFromThemeMode(context, themeMode);
    updateSystemUIOverlayStyle(context, brightness);
  }

  /// Get brightness from theme mode
  static Brightness _getBrightnessFromThemeMode(
    BuildContext context,
    ThemeMode themeMode,
  ) {
    switch (themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return MediaQuery.of(context).platformBrightness;
    }
  }

  /// Initialize system UI for Android (called on app start)
  static void initializeForAndroid() {
    if (!Platform.isAndroid) return;
    
    // Enable edge-to-edge display
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
    
    // Set initial system UI style for Android
    // This will be updated when theme is loaded
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }
}

