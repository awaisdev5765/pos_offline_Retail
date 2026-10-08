import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/database_service.dart';

class DashboardAppearanceSettings {
  final bool useCustomGradient;
  final Color gradientStart;
  final Color gradientEnd;

  const DashboardAppearanceSettings({
    required this.useCustomGradient,
    required this.gradientStart,
    required this.gradientEnd,
  });

  DashboardAppearanceSettings copyWith({
    bool? useCustomGradient,
    Color? gradientStart,
    Color? gradientEnd,
  }) {
    return DashboardAppearanceSettings(
      useCustomGradient: useCustomGradient ?? this.useCustomGradient,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'useCustomGradient': useCustomGradient,
      'gradientStart': gradientStart.value,
      'gradientEnd': gradientEnd.value,
    };
  }

  factory DashboardAppearanceSettings.fromMap(Map<String, dynamic> map) {
    return DashboardAppearanceSettings(
      useCustomGradient: map['useCustomGradient'] == true,
      gradientStart: Color(map['gradientStart'] ?? 0xFF206BC4),
      gradientEnd: Color(map['gradientEnd'] ?? 0xFF1D4E8F),
    );
  }

  static const defaultLightStart = Color(0xFF206BC4);
  static const defaultLightEnd = Color(0xFF1D4E8F);
}

class DashboardAppearanceNotifier
    extends StateNotifier<DashboardAppearanceSettings> {
  DashboardAppearanceNotifier(this._databaseService)
      : super(const DashboardAppearanceSettings(
          useCustomGradient: false,
          gradientStart: DashboardAppearanceSettings.defaultLightStart,
          gradientEnd: DashboardAppearanceSettings.defaultLightEnd,
        )) {
    _load();
  }

  final DatabaseService _databaseService;
  static const _dbKey = 'dashboard_gradient_settings';

  Future<void> _load() async {
    try {
      final saved = await _databaseService.getSetting(_dbKey);
      if (saved == null || saved.isEmpty) return;
      final Map<String, dynamic> data = jsonDecode(saved);
      state = DashboardAppearanceSettings.fromMap(data);
    } catch (_) {
      // Ignore corrupt data and keep defaults
    }
  }

  Future<void> _persist() async {
    try {
      await _databaseService.setSetting(_dbKey, jsonEncode(state.toMap()));
    } catch (_) {
      // best effort persist
    }
  }

  Future<void> setUseCustomGradient(bool enabled) async {
    state = state.copyWith(useCustomGradient: enabled);
    await _persist();
  }

  Future<void> updateGradientColors(Color start, Color end) async {
    state = state.copyWith(
      gradientStart: start,
      gradientEnd: end,
      useCustomGradient: true,
    );
    await _persist();
  }

  Future<void> resetToDefault() async {
    state = const DashboardAppearanceSettings(
      useCustomGradient: false,
      gradientStart: DashboardAppearanceSettings.defaultLightStart,
      gradientEnd: DashboardAppearanceSettings.defaultLightEnd,
    );
    await _persist();
  }
}

final dashboardAppearanceProvider = StateNotifierProvider<
    DashboardAppearanceNotifier, DashboardAppearanceSettings>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return DashboardAppearanceNotifier(db);
});



