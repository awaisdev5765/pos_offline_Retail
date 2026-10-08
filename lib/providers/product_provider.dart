import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/auto_refresh_service.dart';

// Product providers with keepAlive for better caching and performance
final productsProvider = FutureProvider.autoDispose<List<ProductModel>>((
  ref,
) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final products = await databaseService.getAllProducts();

  // Keep alive for 5 minutes to reduce unnecessary rebuilds
  ref.keepAlive();

  return products;
});

final productByIdProvider = FutureProvider.family<ProductModel?, int>((
  ref,
  id,
) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getProductById(id);
});

final productByBarcodeProvider = FutureProvider.family<ProductModel?, String>((
  ref,
  barcode,
) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getProductByBarcode(barcode);
});

final productsByCategoryProvider =
    FutureProvider.family<List<ProductModel>, String>((ref, category) async {
      final databaseService = ref.watch(databaseServiceProvider);
      return await databaseService.getProductsByCategory(category);
    });

final productLedgerProvider =
    FutureProvider.family<List<ProductLedgerEntry>, int>((
      ref,
      productId,
    ) async {
      final databaseService = ref.watch(databaseServiceProvider);
      return databaseService.getProductLedgerEntries(productId);
    });

final lowStockProductsProvider =
    FutureProvider.family<List<ProductModel>, double>((ref, threshold) async {
      final databaseService = ref.watch(databaseServiceProvider);
      return await databaseService.getLowStockProducts(threshold);
    });

// Product categories provider - fetch directly from database to avoid circular dependency
final productCategoriesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final products = await databaseService.getAllProducts();
  final categories = products.map((p) => p.category).toSet().toList();
  categories.sort();

  // Keep alive to cache results and reduce rebuilds
  ref.keepAlive();

  return categories;
});

// Product state notifier for CRUD operations
class ProductNotifier extends StateNotifier<AsyncValue<List<ProductModel>>> {
  final DatabaseService _databaseService;
  Ref? _ref; // Store ref for auto-refresh
  bool _isDisposed = false;

  ProductNotifier(this._databaseService) : super(const AsyncValue.loading()) {
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      if (_isDisposed) return;
      state = const AsyncValue.loading();
      final products = await _databaseService.getAllProducts();
      if (_isDisposed) return;
      state = AsyncValue.data(products);
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void _scheduleRefresh(void Function(Ref ref) refresh) {
    final currentRef = _ref;
    if (_isDisposed || currentRef == null) return;
    Future.microtask(() {
      if (!_isDisposed) refresh(currentRef);
    });
  }

  Future<void> addProduct(ProductModel product) async {
    try {
      await _databaseService.insertProduct(product);
      // Fast refresh - update state immediately
      await _loadProducts();

      // Auto-refresh related providers (use Future.microtask to avoid circular dependency)
      _scheduleRefresh(
        (ref) => AutoRefreshService.refreshAfterProductOperation(
          ref,
          productId: product.id,
        ),
      );
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateProduct(ProductModel product) async {
    try {
      await _databaseService.updateProduct(product);
      // Fast refresh - update state immediately
      await _loadProducts();

      // Auto-refresh related providers (use Future.microtask to avoid circular dependency)
      _scheduleRefresh(
        (ref) => AutoRefreshService.refreshAfterProductOperation(
          ref,
          productId: product.id,
        ),
      );
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteProduct(int id, {bool forceDelete = false}) async {
    try {
      await _databaseService.deleteProduct(id, forceDelete: forceDelete);
      // Fast refresh - update state immediately
      await _loadProducts();

      // Auto-refresh related providers (use Future.microtask to avoid circular dependency)
      _scheduleRefresh(
        (ref) =>
            AutoRefreshService.refreshAfterProductOperation(ref, productId: id),
      );
    } catch (error, stackTrace) {
      if (_isDisposed) rethrow;
      state = AsyncValue.error(error, stackTrace);
      rethrow; // Re-throw so UI can handle the error
    }
  }

  Future<void> adjustStock(
    int productId,
    double quantity,
    String reason, {
    String? reference,
    int? employeeId,
  }) async {
    try {
      await _databaseService.adjustStock(
        productId,
        quantity,
        reason,
        reference: reference,
        employeeId: employeeId,
      );
      // Fast refresh - update state immediately
      await _loadProducts();

      // Auto-refresh related providers (use Future.microtask to avoid circular dependency)
      _scheduleRefresh(
        (ref) => AutoRefreshService.refreshAfterStockAdjustment(
          ref,
          productId: productId,
        ),
      );
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void refresh() {
    if (_isDisposed) return;
    _loadProducts();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _ref = null;
    super.dispose();
  }
}

final productNotifierProvider =
    StateNotifierProvider<ProductNotifier, AsyncValue<List<ProductModel>>>((
      ref,
    ) {
      final databaseService = ref.watch(databaseServiceProvider);
      final notifier = ProductNotifier(databaseService);

      // Store ref in notifier for auto-refresh
      notifier._ref = ref;

      return notifier;
    });
