import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier.dart';
import '../services/database_service.dart';
import '../services/auto_refresh_service.dart';

// Supplier Notifier for CRUD operations
class SupplierNotifier extends StateNotifier<AsyncValue<List<SupplierModel>>> {
  final DatabaseService _databaseService;
  Ref? _ref; // Store ref for auto-refresh

  SupplierNotifier(this._databaseService) : super(const AsyncValue.loading()) {
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      state = const AsyncValue.loading();
      final suppliers = await _databaseService.getAllSuppliers();
      state = AsyncValue.data(
          suppliers.map((e) => SupplierModel.fromSupplier(e)).toList());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addSupplier(SupplierModel supplier) async {
    try {
      await _databaseService.insertSupplier(supplier.toCompanion());
      await _loadSuppliers();
      
      // Auto-refresh related providers (use Future.microtask to avoid circular dependency)
      if (_ref != null) {
        Future.microtask(() {
          AutoRefreshService.refreshAfterSupplierOperation(_ref!, supplierId: supplier.id);
        });
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateSupplier(SupplierModel supplier) async {
    try {
      state = const AsyncValue.loading();
      await _databaseService.updateSupplier(supplier.toSupplier());
      await _loadSuppliers();
      
      // Auto-refresh related providers (use Future.microtask to avoid circular dependency)
      if (_ref != null) {
        Future.microtask(() {
          AutoRefreshService.refreshAfterSupplierOperation(_ref!, supplierId: supplier.id);
        });
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      // Don't rethrow to prevent navigation errors
    }
  }

  Future<void> deleteSupplier(int id) async {
    try {
      await _databaseService.deleteSupplier(id);
      await _loadSuppliers();
      
      // Auto-refresh related providers (use Future.microtask to avoid circular dependency)
      if (_ref != null) {
        Future.microtask(() {
          AutoRefreshService.refreshAfterSupplierOperation(_ref!, supplierId: id);
        });
      }
    } catch (error, stackTrace) {
      // Don't set error state - let errors propagate to UI (e.g., show a SnackBar)
      // This ensures the supplier list remains visible even if deletion fails
      rethrow;
    }
  }

  void refresh() {
    _loadSuppliers();
  }
}

final supplierNotifierProvider =
    StateNotifierProvider<SupplierNotifier, AsyncValue<List<SupplierModel>>>(
        (ref) {
  final notifier = SupplierNotifier(ref.watch(databaseServiceProvider));
  
  // Store ref in notifier for auto-refresh
  notifier._ref = ref;
  
  return notifier;
});

// Providers for filtered views - watch notifier but never invalidate this provider directly
// Only invalidate supplierNotifierProvider to avoid circular dependency
final suppliersProvider = Provider.autoDispose<AsyncValue<List<SupplierModel>>>((ref) {
  return ref.watch(supplierNotifierProvider);
});

final activeSuppliersProvider =
    FutureProvider<List<SupplierModel>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final suppliers = await databaseService.getActiveSuppliers();
  return suppliers.map((e) => SupplierModel.fromSupplier(e)).toList();
});

final supplierByIdProvider =
    FutureProvider.family<SupplierModel?, int>((ref, id) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final supplier = await databaseService.getSupplierById(id);
  return supplier != null ? SupplierModel.fromSupplier(supplier) : null;
});
