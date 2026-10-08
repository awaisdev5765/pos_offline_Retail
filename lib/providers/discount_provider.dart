import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';

// Provider to control discount settings
final discountSettingsProvider =
    StateNotifierProvider<DiscountSettingsNotifier, DiscountSettings>((ref) {
  return DiscountSettingsNotifier(ref);
});

class DiscountSettings {
  final bool overallDiscountEnabled;
  final bool itemDiscountEnabled;

  const DiscountSettings({
    this.overallDiscountEnabled = true,
    this.itemDiscountEnabled = true,
  });

  DiscountSettings copyWith({
    bool? overallDiscountEnabled,
    bool? itemDiscountEnabled,
  }) {
    return DiscountSettings(
      overallDiscountEnabled:
          overallDiscountEnabled ?? this.overallDiscountEnabled,
      itemDiscountEnabled: itemDiscountEnabled ?? this.itemDiscountEnabled,
    );
  }
}

class DiscountSettingsNotifier extends StateNotifier<DiscountSettings> {
  final Ref _ref;

  DiscountSettingsNotifier(this._ref) : super(const DiscountSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final databaseService = _ref.read(databaseServiceProvider);

      final overallDiscountEnabled =
          await databaseService.getSetting('overall_discount_enabled');
      final itemDiscountEnabled =
          await databaseService.getSetting('item_discount_enabled');

      state = DiscountSettings(
        overallDiscountEnabled:
            overallDiscountEnabled == null || overallDiscountEnabled == 'true',
        itemDiscountEnabled:
            itemDiscountEnabled == null || itemDiscountEnabled == 'true',
      );
    } catch (e) {
      // If error, use defaults
      state = const DiscountSettings();
    }
  }

  Future<void> toggleOverallDiscount() async {
    final newValue = !state.overallDiscountEnabled;
    state = state.copyWith(overallDiscountEnabled: newValue);

    try {
      final databaseService = _ref.read(databaseServiceProvider);
      await databaseService.setSetting(
          'overall_discount_enabled', newValue.toString());
    } catch (e) {
      // Revert on error
      state = state.copyWith(overallDiscountEnabled: !newValue);
    }
  }

  Future<void> toggleItemDiscount() async {
    final newValue = !state.itemDiscountEnabled;
    state = state.copyWith(itemDiscountEnabled: newValue);

    try {
      final databaseService = _ref.read(databaseServiceProvider);
      await databaseService.setSetting(
          'item_discount_enabled', newValue.toString());
    } catch (e) {
      // Revert on error
      state = state.copyWith(itemDiscountEnabled: !newValue);
    }
  }
}
