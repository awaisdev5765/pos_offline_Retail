import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/database_service.dart';

const allowOpeningStockOnProductCreateSettingKey =
    'allow_opening_stock_on_product_create';

final inventorySettingsProvider =
    StateNotifierProvider<InventorySettingsNotifier, InventorySettings>((ref) {
  return InventorySettingsNotifier(ref);
});

class InventorySettings {
  final bool allowOpeningStockOnProductCreate;

  const InventorySettings({
    this.allowOpeningStockOnProductCreate = false,
  });

  InventorySettings copyWith({bool? allowOpeningStockOnProductCreate}) {
    return InventorySettings(
      allowOpeningStockOnProductCreate: allowOpeningStockOnProductCreate ??
          this.allowOpeningStockOnProductCreate,
    );
  }
}

class InventorySettingsNotifier extends StateNotifier<InventorySettings> {
  InventorySettingsNotifier(this._ref) : super(const InventorySettings()) {
    _load();
  }

  Ref? _ref;
  bool _isDisposed = false;

  Future<void> _load() async {
    try {
      final databaseService = _ref?.read(databaseServiceProvider);
      if (databaseService == null) return;
      final stored = await databaseService.getSetting(
        allowOpeningStockOnProductCreateSettingKey,
      );
      if (_isDisposed) return;
      state = InventorySettings(
        allowOpeningStockOnProductCreate: stored == 'true',
      );
    } catch (_) {
      // The safe default keeps stock entry restricted to purchase invoices.
    }
  }

  Future<void> setAllowOpeningStockOnProductCreate(bool enabled) async {
    final previous = state;
    state = state.copyWith(allowOpeningStockOnProductCreate: enabled);
    try {
      final databaseService = _ref?.read(databaseServiceProvider);
      if (databaseService == null) return;
      await databaseService.setSetting(
        allowOpeningStockOnProductCreateSettingKey,
        enabled.toString(),
      );
    } catch (_) {
      if (!_isDisposed) state = previous;
      rethrow;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _ref = null;
    super.dispose();
  }
}
