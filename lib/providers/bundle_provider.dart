import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_bundle.dart';
import '../services/database_service.dart';

// Bundle providers
final bundlesProvider = FutureProvider<List<ProductBundleModel>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getAllBundles();
});

final bundleByIdProvider =
    FutureProvider.family<ProductBundleModel?, int>((ref, id) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getBundleById(id);
});

final bundlesByCategoryProvider =
    FutureProvider.family<List<ProductBundleModel>, String>((ref, category) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getBundlesByCategory(category);
});

// Bundle state notifier for CRUD operations
final bundleNotifierProvider =
    StateNotifierProvider<BundleNotifier, AsyncValue<void>>((ref) {
  return BundleNotifier(ref);
});

class BundleNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  BundleNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> createBundle(ProductBundleModel bundle) async {
    state = const AsyncValue.loading();
    try {
      final databaseService = _ref.read(databaseServiceProvider);
      await databaseService.insertBundle(bundle);
      _ref.invalidate(bundlesProvider);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateBundle(ProductBundleModel bundle) async {
    state = const AsyncValue.loading();
    try {
      final databaseService = _ref.read(databaseServiceProvider);
      await databaseService.updateBundle(bundle);
      _ref.invalidate(bundlesProvider);
      if (bundle.id != null) {
        _ref.invalidate(bundleByIdProvider(bundle.id!));
      }
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteBundle(int id) async {
    state = const AsyncValue.loading();
    try {
      final databaseService = _ref.read(databaseServiceProvider);
      await databaseService.deleteBundle(id);
      _ref.invalidate(bundlesProvider);
      _ref.invalidate(bundleByIdProvider(id));
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

