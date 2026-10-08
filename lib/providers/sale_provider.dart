import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../models/product_bundle.dart';
import '../models/sales_summary.dart' as models;
import '../services/database_service.dart';
import '../services/auto_refresh_service.dart';

// Sale providers with keepAlive for better caching and performance
final salesProvider = FutureProvider.autoDispose<List<SaleModel>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final sales = await databaseService.getAllSales();

  // Keep alive to reduce unnecessary rebuilds
  ref.keepAlive();

  return sales;
});

final saleByIdProvider =
    FutureProvider.family<SaleModel?, int>((ref, id) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getSaleById(id);
});

final salesByDateRangeProvider =
    FutureProvider.family<List<SaleModel>, DateRange>((ref, dateRange) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getSalesByDateRange(
      dateRange.start, dateRange.end);
});

final salesByCustomerProvider =
    FutureProvider.family<List<SaleModel>, int>((ref, customerId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getSalesByCustomer(customerId);
});

final unpaidSalesProvider = FutureProvider<List<SaleModel>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getUnpaidSales();
});

// Sales summary provider with keepAlive for fast response
final salesSummaryProvider = FutureProvider.autoDispose
    .family<models.SalesSummary, models.DateRange>((ref, dateRange) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final summary =
      await databaseService.getSalesSummary(dateRange.start, dateRange.end);

  // Keep alive to cache results and reduce rebuilds
  ref.keepAlive();

  return summary;
});

// Product sales report provider with keepAlive for fast response
final productSalesReportProvider = FutureProvider.autoDispose
    .family<List<models.ProductSales>, models.DateRange>(
        (ref, dateRange) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final report = await databaseService.getProductSalesReport(
      dateRange.start, dateRange.end);

  // Keep alive to cache results and reduce rebuilds
  ref.keepAlive();

  return report;
});

// Sale state notifier for CRUD operations
class SaleNotifier extends StateNotifier<AsyncValue<List<SaleModel>>> {
  final DatabaseService _databaseService;
  bool _isDisposed = false;
  Ref? _ref; // Store ref for auto-refresh

  SaleNotifier(this._databaseService) : super(const AsyncValue.loading()) {
    _loadSales();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // Safe state setter that checks if notifier is still valid
  void _safeSetState(AsyncValue<List<SaleModel>> newState) {
    if (_isDisposed) return;
    try {
      state = newState;
    } catch (e) {
      // Ignore errors if notifier is disposed
      if (e.toString().contains('dispose') ||
          e.toString().contains('Bad state')) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _loadSales() async {
    if (_isDisposed) return;
    try {
      _safeSetState(const AsyncValue.loading());
      final sales = await _databaseService.getAllSales();
      if (!_isDisposed) {
        _safeSetState(AsyncValue.data(sales));
      }
    } catch (error, stackTrace) {
      if (!_isDisposed) {
        _safeSetState(AsyncValue.error(error, stackTrace));
      }
    }
  }

  Future<int> addSale(SaleModel sale) async {
    if (_isDisposed) throw StateError('SaleNotifier has been disposed');
    try {
      final saleId = await _databaseService.insertSaleAndAdjustStock(sale);
      // Fast refresh - update state immediately
      await _loadSales();

      // Auto-refresh related providers (use Future.microtask to avoid circular dependency)
      if (_ref != null) {
        final productIds = sale.items.map((item) => item.productId).toList();
        Future.microtask(() {
          AutoRefreshService.refreshAfterSaleOperation(
            _ref!,
            saleId: saleId,
            customerId: sale.customerId,
            productIds: productIds,
          );
        });
      }

      return saleId;
    } catch (error, stackTrace) {
      if (!_isDisposed) {
        _safeSetState(AsyncValue.error(error, stackTrace));
      }
      rethrow;
    }
  }

  Future<void> updateSale(SaleModel sale) async {
    if (_isDisposed) return;
    try {
      await _databaseService.updateSale(sale);
      // Fast refresh - update state immediately
      await _loadSales();

      // Auto-refresh related providers (use Future.microtask to avoid circular dependency)
      if (_ref != null) {
        final productIds = sale.items.map((item) => item.productId).toList();
        Future.microtask(() {
          AutoRefreshService.refreshAfterSaleOperation(
            _ref!,
            saleId: sale.id,
            customerId: sale.customerId,
            productIds: productIds,
          );
        });
      }
    } catch (error, stackTrace) {
      if (!_isDisposed) {
        _safeSetState(AsyncValue.error(error, stackTrace));
      }
    }
  }

  Future<void> deleteSale(int id) async {
    if (_isDisposed) return;
    try {
      await _databaseService.deleteSale(id);
      // Fast refresh - update state immediately
      await _loadSales();

      // Auto-refresh related providers (use Future.microtask to avoid circular dependency)
      if (_ref != null) {
        Future.microtask(() {
          AutoRefreshService.refreshAfterSaleOperation(_ref!);
        });
      }
    } catch (error, stackTrace) {
      if (!_isDisposed) {
        _safeSetState(AsyncValue.error(error, stackTrace));
      }
    }
  }

  void refresh() {
    if (_isDisposed) return;
    _loadSales();
  }
}

final saleNotifierProvider =
    StateNotifierProvider<SaleNotifier, AsyncValue<List<SaleModel>>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final notifier = SaleNotifier(databaseService);

  // Store ref in notifier for auto-refresh
  notifier._ref = ref;

  return notifier;
});

// POS Cart state notifier
class CartItem {
  final ProductModel? product;
  final ProductBundleModel? bundle;
  double quantity;
  double discount;
  String? imei; // IMEI number for mobile phones

  CartItem({
    this.product,
    this.bundle,
    this.quantity = 1,
    this.discount = 0,
    this.imei,
  })  : assert(product != null || bundle != null,
            'Either product or bundle must be provided'),
        assert(product == null || bundle == null,
            'Cannot have both product and bundle');

  bool get isBundle => bundle != null;

  // Safe subtotal calculation with NaN checks
  double get subtotal {
    try {
      final price = isBundle
          ? (bundle!.price.isNaN || bundle!.price.isInfinite
              ? 0.0
              : bundle!.price)
          : (product!.price.isNaN || product!.price.isInfinite
              ? 0.0
              : product!.price);
      final safeQuantity =
          quantity.isNaN || quantity.isInfinite ? 0.0 : quantity;
      final safeDiscount =
          discount.isNaN || discount.isInfinite ? 0.0 : discount;
      final result = (price * safeQuantity) - safeDiscount;
      return result.isNaN || result.isInfinite ? 0.0 : result;
    } catch (e) {
      return 0.0;
    }
  }

  double get netSubtotal => subtotal;

  CartItem copyWith({
    ProductModel? product,
    ProductBundleModel? bundle,
    double? quantity,
    double? discount,
    String? imei,
  }) {
    return CartItem(
      product: product ?? this.product,
      bundle: bundle ?? this.bundle,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      imei: imei ?? this.imei,
    );
  }
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addProduct(ProductModel product, {double quantity = 1, String? imei}) {
    try {
      // Validate product before adding
      if (product.id == null) {
        debugPrint('Error: Cannot add product to cart - product ID is null');
        return;
      }

      // Validate quantity
      final safeQuantity =
          quantity.isNaN || quantity.isInfinite || quantity <= 0
              ? 1.0
              : quantity;

      // Find existing product in cart
      final existingIndex = state.indexWhere((item) =>
          !item.isBundle &&
          item.product?.id != null &&
          item.product!.id == product.id);

      if (existingIndex != -1 && existingIndex < state.length) {
        // Update existing item
        final existingItem = state[existingIndex];
        final updatedQuantity = (existingItem.quantity + safeQuantity).isNaN ||
                (existingItem.quantity + safeQuantity).isInfinite
            ? existingItem.quantity
            : existingItem.quantity + safeQuantity;

        final updatedItem = existingItem.copyWith(
          quantity: updatedQuantity,
          imei: imei ?? existingItem.imei,
        );

        // Safe list update
        final newState = List<CartItem>.from(state);
        newState[existingIndex] = updatedItem;
        state = newState;
      } else {
        // Add new item
        state = [
          ...state,
          CartItem(product: product, quantity: safeQuantity, imei: imei)
        ];
      }
    } catch (e, stackTrace) {
      debugPrint('Error adding product to cart: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't crash - just log the error
    }
  }

  void addBundle(ProductBundleModel bundle, {double quantity = 1}) {
    try {
      // Validate bundle before adding
      if (bundle.id == null) {
        debugPrint('Error: Cannot add bundle to cart - bundle ID is null');
        return;
      }

      // Validate quantity
      final safeQuantity =
          quantity.isNaN || quantity.isInfinite || quantity <= 0
              ? 1.0
              : quantity;

      // Find existing bundle in cart
      final existingIndex = state.indexWhere((item) =>
          item.isBundle &&
          item.bundle?.id != null &&
          item.bundle!.id == bundle.id);

      if (existingIndex != -1 && existingIndex < state.length) {
        // Update existing bundle
        final existingItem = state[existingIndex];
        final updatedQuantity = (existingItem.quantity + safeQuantity).isNaN ||
                (existingItem.quantity + safeQuantity).isInfinite
            ? existingItem.quantity
            : existingItem.quantity + safeQuantity;

        final updatedItem = existingItem.copyWith(
          quantity: updatedQuantity,
        );

        // Safe list update
        final newState = List<CartItem>.from(state);
        newState[existingIndex] = updatedItem;
        state = newState;
      } else {
        // Add new bundle
        state = [...state, CartItem(bundle: bundle, quantity: safeQuantity)];
      }
    } catch (e, stackTrace) {
      debugPrint('Error adding bundle to cart: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't crash - just log the error
    }
  }

  void removeProduct(int productId) {
    try {
      state = state
          .where((item) =>
              item.isBundle ||
              (item.product?.id != null && item.product!.id != productId))
          .toList();
    } catch (e) {
      debugPrint('Error removing product from cart: $e');
    }
  }

  void removeBundle(int bundleId) {
    try {
      state = state
          .where((item) =>
              !item.isBundle ||
              (item.bundle?.id != null && item.bundle!.id != bundleId))
          .toList();
    } catch (e) {
      debugPrint('Error removing bundle from cart: $e');
    }
  }

  void updateQuantity(int productId, double quantity) {
    try {
      // Allow negative quantities for returns/adjustments
      // Only remove if quantity is exactly 0, NaN, or Infinite
      if (quantity == 0 || quantity.isNaN || quantity.isInfinite) {
        removeProduct(productId);
        return;
      }

      final index = state.indexWhere((item) =>
          !item.isBundle &&
          item.product?.id != null &&
          item.product!.id == productId);

      if (index != -1 && index < state.length) {
        final item = state[index];
        final updatedItem = item.copyWith(quantity: quantity);

        // Safe list update
        final newState = List<CartItem>.from(state);
        newState[index] = updatedItem;
        state = newState;
      }
    } catch (e) {
      debugPrint('Error updating quantity: $e');
    }
  }

  void updateBundleQuantity(int bundleId, double quantity) {
    try {
      // Allow negative quantities for returns/adjustments
      // Only remove if quantity is exactly 0, NaN, or Infinite
      if (quantity == 0 || quantity.isNaN || quantity.isInfinite) {
        removeBundle(bundleId);
        return;
      }

      final index = state.indexWhere((item) =>
          item.isBundle &&
          item.bundle?.id != null &&
          item.bundle!.id == bundleId);

      if (index != -1 && index < state.length) {
        final item = state[index];
        final updatedItem = item.copyWith(quantity: quantity);

        // Safe list update
        final newState = List<CartItem>.from(state);
        newState[index] = updatedItem;
        state = newState;
      }
    } catch (e) {
      debugPrint('Error updating bundle quantity: $e');
    }
  }

  void updateDiscount(int productId, double discount) {
    try {
      final safeDiscount =
          discount.isNaN || discount.isInfinite ? 0.0 : discount;

      final index = state.indexWhere((item) =>
          !item.isBundle &&
          item.product?.id != null &&
          item.product!.id == productId);

      if (index != -1 && index < state.length) {
        final item = state[index];
        final updatedItem = item.copyWith(discount: safeDiscount);

        // Safe list update
        final newState = List<CartItem>.from(state);
        newState[index] = updatedItem;
        state = newState;
      }
    } catch (e) {
      debugPrint('Error updating discount: $e');
    }
  }

  void clear() {
    state = [];
  }

  // Safe total calculation
  double get total {
    try {
      return state.fold(0.0, (sum, item) {
        try {
          final subtotal = item.subtotal;
          if (subtotal.isNaN || subtotal.isInfinite) {
            return sum;
          }
          final result = sum + subtotal;
          return result.isNaN || result.isInfinite ? sum : result;
        } catch (e) {
          return sum;
        }
      });
    } catch (e) {
      debugPrint('Error calculating total: $e');
      return 0.0;
    }
  }

  int get itemCount => state.length;

  double get totalQuantity {
    try {
      return state.fold(0.0, (sum, item) {
        try {
          final qty = item.quantity;
          if (qty.isNaN || qty.isInfinite) {
            return sum;
          }
          final result = sum + qty;
          return result.isNaN || result.isInfinite ? sum : result;
        } catch (e) {
          return sum;
        }
      });
    } catch (e) {
      debugPrint('Error calculating total quantity: $e');
      return 0.0;
    }
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

// Helper classes
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}
