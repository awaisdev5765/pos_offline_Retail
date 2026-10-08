import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/database_service.dart';

class QuickActionItem {
  final String id; // stable identifier persisted for ordering
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final String route;

  const QuickActionItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.gradient,
    required this.route,
  });
}

// Canonical list of supported quick actions (extendable without breaking persisted order).
const List<QuickActionItem> kAllQuickActions = [
  QuickActionItem(
    id: 'purchase_invoice',
    title: 'Purchase Invoice',
    icon: Icons.receipt,
    gradient: [Color(0xFF10B981), Color(0xFF059669)],
    route: '/purchase-invoice',
  ),
  QuickActionItem(
    id: 'stock_movement',
    title: 'Stock Movement',
    icon: Icons.swap_vert,
    gradient: [Color(0xFF14B8A6), Color(0xFF0D9488)],
    route: '/stock-movements',
  ),
];

final Map<String, QuickActionItem> _idToAction = {
  for (final a in kAllQuickActions) a.id: a,
};

class QuickActionsState {
  final List<String> orderedIds; // order of action ids
  final Map<String, List<Color>>
      customColors; // custom colors for each action id

  const QuickActionsState(this.orderedIds, [this.customColors = const {}]);

  List<QuickActionItem> get orderedActions {
    // Keep only known ids; append any new actions that aren't in saved order yet
    final known = orderedIds.where(_idToAction.containsKey).toList();
    final missing =
        _idToAction.keys.where((id) => !known.contains(id)).toList();
    return [...known, ...missing].map((id) {
      final action = _idToAction[id]!;
      // Use custom colors if available, otherwise use default
      final colors = customColors[id] ?? action.gradient;
      return QuickActionItem(
        id: action.id,
        title: action.title,
        icon: action.icon,
        gradient: colors,
        route: action.route,
      );
    }).toList();
  }

  QuickActionsState copyWith({
    List<String>? orderedIds,
    Map<String, List<Color>>? customColors,
  }) {
    return QuickActionsState(
      orderedIds ?? this.orderedIds,
      customColors ?? this.customColors,
    );
  }
}

class QuickActionsNotifier extends StateNotifier<QuickActionsState> {
  final DatabaseService _databaseService;
  static const String _dbKey = 'quick_actions_order';
  static const String _colorsKey = 'quick_actions_colors';

  QuickActionsNotifier(this._databaseService)
      : super(QuickActionsState(kAllQuickActions.map((e) => e.id).toList())) {
    _load();
  }

  Future<void> _load() async {
    try {
      // Load order
      final saved = await _databaseService.getSetting(_dbKey);
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> list = jsonDecode(saved);
        final ids = list.whereType<String>().toList();
        if (ids.isNotEmpty) {
          // Load colors
          final colorsSaved = await _databaseService.getSetting(_colorsKey);
          Map<String, List<Color>> customColors = {};
          if (colorsSaved != null && colorsSaved.isNotEmpty) {
            try {
              final colorsMap = jsonDecode(colorsSaved) as Map<String, dynamic>;
              customColors = colorsMap.map((key, value) {
                if (value is List) {
                  final colors = value.map((c) {
                    if (c is int) {
                      return Color(c);
                    } else if (c is Map && c.containsKey('value')) {
                      return Color(c['value'] as int);
                    }
                    return const Color(0xFF3B82F6);
                  }).toList();
                  return MapEntry(key, colors);
                }
                return MapEntry(key,
                    _idToAction[key]?.gradient ?? [const Color(0xFF3B82F6)]);
              });
            } catch (_) {
              // ignore parse errors
            }
          }
          state = QuickActionsState(ids, customColors);
        }
      }
    } catch (_) {
      // ignore parse errors and keep defaults
    }
  }

  Future<void> setOrder(List<String> newOrderedIds) async {
    state = state.copyWith(orderedIds: newOrderedIds);
    try {
      await _databaseService.setSetting(_dbKey, jsonEncode(newOrderedIds));
    } catch (_) {
      // best-effort persist
    }
  }

  Future<void> setActionColor(String actionId, List<Color> colors) async {
    final updatedColors = Map<String, List<Color>>.from(state.customColors);
    updatedColors[actionId] = colors;
    state = state.copyWith(customColors: updatedColors);
    try {
      final colorsMap = updatedColors.map(
          (key, value) => MapEntry(key, value.map((c) => c.value).toList()));
      await _databaseService.setSetting(_colorsKey, jsonEncode(colorsMap));
    } catch (_) {
      // best-effort persist
    }
  }

  Future<void> resetActionColor(String actionId) async {
    final updatedColors = Map<String, List<Color>>.from(state.customColors);
    updatedColors.remove(actionId);
    state = state.copyWith(customColors: updatedColors);
    try {
      if (updatedColors.isEmpty) {
        await _databaseService.setSetting(_colorsKey, '');
      } else {
        final colorsMap = updatedColors.map(
            (key, value) => MapEntry(key, value.map((c) => c.value).toList()));
        await _databaseService.setSetting(_colorsKey, jsonEncode(colorsMap));
      }
    } catch (_) {
      // best-effort persist
    }
  }
}

final quickActionsProvider =
    StateNotifierProvider<QuickActionsNotifier, QuickActionsState>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return QuickActionsNotifier(db);
});
