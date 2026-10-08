import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../theme/app_theme.dart';

// Theme mode provider with initialization
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// Provider to ensure theme is loaded before app builds
final themeModeInitializedProvider = FutureProvider<bool>((ref) async {
  final notifier = ref.read(themeModeProvider.notifier);
  await notifier.ensureInitialized();
  return true;
});

// Dark mode boolean provider
final isDarkModeProvider = Provider<bool>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  return themeMode == ThemeMode.dark;
});

// Current theme provider
final currentThemeProvider = Provider<ThemeData>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  return themeMode == ThemeMode.dark ? AppTheme.darkTheme : AppTheme.lightTheme;
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _themeKey = 'theme_mode';
  static const String _darkModeKey = 'dark_mode'; // Android-specific key
  bool _isInitialized = false;

  ThemeModeNotifier() : super(ThemeMode.system) {
    // Start loading theme immediately
    _loadTheme();
  }

  /// Ensure theme is loaded before app builds
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await _loadTheme();
  }

  Future<void> _loadTheme() async {
    if (_isInitialized) return;
    
    try {
      // Initialize SharedPreferences - especially important for Android
      final prefs = await SharedPreferences.getInstance();
      
      // Try to load theme mode first (newer approach)
      final themeIndex = prefs.getInt(_themeKey);
      
      if (themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
        state = ThemeMode.values[themeIndex];
        _isInitialized = true;
        return;
      }
      
      // Fallback: Check for old dark mode boolean (Android compatibility)
      final isDarkMode = prefs.getBool(_darkModeKey);
      if (isDarkMode != null) {
        state = isDarkMode ? ThemeMode.dark : ThemeMode.light;
        // Migrate to new format
        await prefs.setInt(_themeKey, state.index);
        await prefs.remove(_darkModeKey);
        _isInitialized = true;
        return;
      }
      
      // Default to system theme if nothing is saved
      state = ThemeMode.system;
      _isInitialized = true;
    } catch (e) {
      // If there's an error, default to system theme
      // On Android, SharedPreferences might fail on first access
      debugPrint('Error loading theme: $e');
      state = ThemeMode.system;
      _isInitialized = true;
    }
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save theme mode
      await prefs.setInt(_themeKey, themeMode.index);
      
      // Also save as boolean for Android compatibility (legacy support)
      final isDark = themeMode == ThemeMode.dark;
      await prefs.setBool(_darkModeKey, isDark);
      
      // Ensure preferences are committed (important for Android)
      if (Platform.isAndroid) {
        await prefs.reload();
      }
      
      state = themeMode;
      _isInitialized = true;
    } catch (e) {
      // If there's an error, still update the state
      debugPrint('Error saving theme: $e');
      state = themeMode;
      _isInitialized = true;
    }
  }

  void toggleTheme() {
    if (state == ThemeMode.light) {
      setTheme(ThemeMode.dark);
    } else {
      setTheme(ThemeMode.light);
    }
  }

  void setLightTheme() {
    setTheme(ThemeMode.light);
  }

  void setDarkTheme() {
    setTheme(ThemeMode.dark);
  }

  void setSystemTheme() {
    setTheme(ThemeMode.system);
  }
}

// Brand customization provider
final brandCustomizationProvider =
    StateNotifierProvider<BrandCustomizationNotifier, BrandCustomization>(
        (ref) {
  return BrandCustomizationNotifier();
});

class BrandCustomization {
  final String? logoPath;
  final String? businessName;
  final Color primaryColor;
  final Color secondaryColor;
  final String? customFontFamily;
  final bool useCustomColors;
  final bool useCustomLogo;

  const BrandCustomization({
    this.logoPath,
    this.businessName,
    this.primaryColor = const Color(0xFF3B82F6),
    this.secondaryColor = const Color(0xFF10B981),
    this.customFontFamily,
    this.useCustomColors = false,
    this.useCustomLogo = false,
  });

  BrandCustomization copyWith({
    String? logoPath,
    String? businessName,
    Color? primaryColor,
    Color? secondaryColor,
    String? customFontFamily,
    bool? useCustomColors,
    bool? useCustomLogo,
  }) {
    return BrandCustomization(
      logoPath: logoPath ?? this.logoPath,
      businessName: businessName ?? this.businessName,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      customFontFamily: customFontFamily ?? this.customFontFamily,
      useCustomColors: useCustomColors ?? this.useCustomColors,
      useCustomLogo: useCustomLogo ?? this.useCustomLogo,
    );
  }
}

class BrandCustomizationNotifier extends StateNotifier<BrandCustomization> {
  static const String _logoKey = 'brand_logo';
  static const String _businessNameKey = 'business_name';
  static const String _primaryColorKey = 'primary_color';
  static const String _secondaryColorKey = 'secondary_color';
  static const String _fontFamilyKey = 'font_family';
  static const String _useCustomColorsKey = 'use_custom_colors';
  static const String _useCustomLogoKey = 'use_custom_logo';

  BrandCustomizationNotifier() : super(const BrandCustomization()) {
    _loadCustomization();
  }

  Future<void> _loadCustomization() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logoPath = prefs.getString(_logoKey);
      final businessName = prefs.getString(_businessNameKey);
      final primaryColorValue = prefs.getInt(_primaryColorKey);
      final secondaryColorValue = prefs.getInt(_secondaryColorKey);
      final fontFamily = prefs.getString(_fontFamilyKey);
      final useCustomColors = prefs.getBool(_useCustomColorsKey) ?? false;
      final useCustomLogo = prefs.getBool(_useCustomLogoKey) ?? false;

      state = BrandCustomization(
        logoPath: logoPath,
        businessName: businessName,
        primaryColor: primaryColorValue != null
            ? Color(primaryColorValue)
            : const Color(0xFF3B82F6),
        secondaryColor: secondaryColorValue != null
            ? Color(secondaryColorValue)
            : const Color(0xFF10B981),
        customFontFamily: fontFamily,
        useCustomColors: useCustomColors,
        useCustomLogo: useCustomLogo,
      );
    } catch (e) {
      // If there's an error, keep default values
    }
  }

  Future<void> updateLogo(String? logoPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (logoPath != null) {
        await prefs.setString(_logoKey, logoPath);
        await prefs.setBool(_useCustomLogoKey, true);
      } else {
        await prefs.remove(_logoKey);
        await prefs.setBool(_useCustomLogoKey, false);
      }
      state =
          state.copyWith(logoPath: logoPath, useCustomLogo: logoPath != null);
    } catch (e) {
      // If there's an error, still update the state
      state =
          state.copyWith(logoPath: logoPath, useCustomLogo: logoPath != null);
    }
  }

  Future<void> updateBusinessName(String? businessName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (businessName != null) {
        await prefs.setString(_businessNameKey, businessName);
      } else {
        await prefs.remove(_businessNameKey);
      }
      state = state.copyWith(businessName: businessName);
    } catch (e) {
      state = state.copyWith(businessName: businessName);
    }
  }

  Future<void> updateColors(Color primaryColor, Color secondaryColor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_primaryColorKey,
          primaryColor.value); // Keep using .value for compatibility
      await prefs.setInt(_secondaryColorKey,
          secondaryColor.value); // Keep using .value for compatibility
      await prefs.setBool(_useCustomColorsKey, true);
      state = state.copyWith(
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        useCustomColors: true,
      );
    } catch (e) {
      state = state.copyWith(
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        useCustomColors: true,
      );
    }
  }

  Future<void> updateFontFamily(String? fontFamily) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (fontFamily != null) {
        await prefs.setString(_fontFamilyKey, fontFamily);
      } else {
        await prefs.remove(_fontFamilyKey);
      }
      state = state.copyWith(customFontFamily: fontFamily);
    } catch (e) {
      state = state.copyWith(customFontFamily: fontFamily);
    }
  }

  Future<void> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logoKey);
      await prefs.remove(_businessNameKey);
      await prefs.remove(_primaryColorKey);
      await prefs.remove(_secondaryColorKey);
      await prefs.remove(_fontFamilyKey);
      await prefs.remove(_useCustomColorsKey);
      await prefs.remove(_useCustomLogoKey);
      state = const BrandCustomization();
    } catch (e) {
      state = const BrandCustomization();
    }
  }
}
