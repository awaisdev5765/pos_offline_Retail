import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/product_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/supplier_payment_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../providers/bank_provider.dart';
import '../providers/staff_performance_provider.dart';
import '../providers/stock_movement_provider.dart';
import '../providers/purchase_order_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/customer_provider.dart';

/// Optimized auto-refresh service for fast database operations
/// Automatically refreshes only affected providers after CRUD operations
class AutoRefreshService {
  /// Refresh providers after product operations
  static void refreshAfterProductOperation(Ref ref, {int? productId}) {
    // NOTE: Do NOT invalidate productNotifierProvider here to avoid circular dependency.
    // The ProductNotifier already refreshes itself via _loadProducts() after operations.
    // Invalidating it from within the notifier would cause a circular dependency error.
    
    // Invalidate categories provider (it fetches directly from DB, no circular dependency)
    ref.invalidate(productCategoriesProvider);
    
    // Invalidate productsProvider (FutureProvider that fetches directly from DB)
    // This ensures screens using productsProvider (not the notifier) get updated data
    ref.invalidate(productsProvider);
    
    // If specific product ID, invalidate that provider too
    if (productId != null) {
      ref.invalidate(productByIdProvider(productId));
      ref.invalidate(productLedgerProvider(productId));
    }
    
    // Refresh stock movements if stock was affected
    ref.invalidate(stockMovementNotifierProvider);
  }

  /// Refresh providers after customer operations
  static void refreshAfterCustomerOperation(Ref ref, {int? customerId}) {
    // Do NOT invalidate customerNotifierProvider here; the notifier already
    // refreshed itself after the mutation. Invalidating it from within its own
    // execution context creates a self-dependency loop in Riverpod.
    // Instead, only invalidate scoped, read-only providers.
    if (customerId != null) {
      ref.invalidate(customerByIdProvider(customerId));
      ref.invalidate(customerSalesProvider(customerId));
      ref.invalidate(customerPaymentsProvider(customerId));
      ref.invalidate(customerLedgerProvider(customerId));
    }
  }

  /// Refresh providers after supplier operations
  static void refreshAfterSupplierOperation(Ref ref, {int? supplierId}) {
    // NOTE: Do NOT invalidate supplierNotifierProvider here to avoid circular dependency.
    // The SupplierNotifier already refreshes itself via _loadSuppliers() after operations.
    // Invalidating it from within the notifier would cause a circular dependency error.
    
    // Invalidate activeSuppliersProvider used by purchase invoice screen
    ref.invalidate(activeSuppliersProvider);
    
    if (supplierId != null) {
      ref.invalidate(supplierByIdProvider(supplierId));
      ref.invalidate(supplierBalanceProvider(supplierId));
    }
  }

  /// Refresh providers after sale operations
  static void refreshAfterSaleOperation(Ref ref, {int? saleId, int? customerId, List<int>? productIds}) {
    // Note: saleNotifierProvider is NOT invalidated here to avoid circular dependency
    // The SaleNotifier already refreshes its own state via _loadSales() after operations
    // Invalidating it from within the notifier would cause a circular dependency error
    
    // Refresh report providers (they depend on sales data)
    // Note: We can't invalidate all date ranges, but the providers will refresh when accessed
    // The keepAlive will ensure fast response when data is already cached
    
    // Refresh products (stock changes) - only invalidate notifier
    ref.invalidate(productNotifierProvider);
    
    // Refresh specific products if provided
    if (productIds != null) {
      for (final productId in productIds) {
        ref.invalidate(productByIdProvider(productId));
        ref.invalidate(productLedgerProvider(productId));
      }
    }
    
    // Refresh customer if provided
    if (customerId != null) {
      ref.invalidate(customerByIdProvider(customerId));
      ref.invalidate(customerSalesProvider(customerId));
      ref.invalidate(customerPaymentsProvider(customerId));
      ref.invalidate(customerLedgerProvider(customerId));
    }
    
    // Refresh stock movements
    ref.invalidate(stockMovementNotifierProvider);
  }

  /// Refresh providers after payment operations
  static void refreshAfterPaymentOperation(Ref ref, {int? customerId}) {
    ref.invalidate(paymentNotifierProvider);
    
    if (customerId != null) {
      ref.invalidate(customerByIdProvider(customerId));
      ref.invalidate(customerPaymentsProvider(customerId));
      ref.invalidate(customerSalesProvider(customerId));
      ref.invalidate(customerLedgerProvider(customerId));
    }
  }

  /// Refresh providers after purchase order operations
  /// Accepts both Ref (from providers) and WidgetRef (from widgets)
  static void refreshAfterPurchaseOperation(dynamic ref, {int? supplierId, List<int>? productIds}) {
    // NOTE: Do NOT invalidate purchaseOrderNotifierProvider here to avoid circular dependency.
    // The PurchaseOrderNotifier already refreshes itself via _loadPurchaseOrders() after operations.
    // Invalidating it from within the notifier would cause a circular dependency error.
    
    // NOTE: Do NOT invalidate productNotifierProvider or supplierNotifierProvider here either.
    // They refresh themselves and invalidating from another notifier's context can cause issues.
    // Instead, invalidate the FutureProviders that fetch directly from DB.
    ref.invalidate(productsProvider);
    
    // Refresh specific products if provided
    if (productIds != null) {
      for (final productId in productIds) {
        ref.invalidate(productByIdProvider(productId));
      }
    }
    
    // Refresh supplier if provided
    if (supplierId != null) {
      ref.invalidate(supplierByIdProvider(supplierId));
      ref.invalidate(supplierBalanceProvider(supplierId));
      ref.invalidate(purchaseOrdersBySupplierProvider(supplierId));
      // Also invalidate activeSuppliersProvider used by purchase invoice screen
      ref.invalidate(activeSuppliersProvider);
    }
    
    // Refresh stock movements
    ref.invalidate(stockMovementNotifierProvider);
  }

  /// Refresh providers after stock adjustment
  static void refreshAfterStockAdjustment(Ref ref, {int? productId}) {
    ref.invalidate(stockMovementNotifierProvider);
    // NOTE: Do NOT invalidate productNotifierProvider here to avoid circular dependency.
    // The ProductNotifier already refreshes itself via _loadProducts() after operations.
    // Invalidating it from within the notifier would cause a circular dependency error.
    
    // Invalidate productsProvider to ensure screens using it get updated data
    ref.invalidate(productsProvider);
    
    if (productId != null) {
      ref.invalidate(productByIdProvider(productId));
      ref.invalidate(productLedgerProvider(productId));
    }
  }

  /// Refresh providers after expense operations
  static void refreshAfterExpenseOperation(Ref ref) {
    ref.invalidate(expenseNotifierProvider);
    ref.invalidate(expenseSummaryProvider);
  }

  /// Refresh providers after bank operations
  static void refreshAfterBankOperation(Ref ref, {int? bankId}) {
    // Only invalidate notifier to avoid circular dependency
    ref.invalidate(bankNotifierProvider);
    
    if (bankId != null) {
      ref.invalidate(bankByIdProvider(bankId));
    }
  }

  /// Batch refresh - refreshes multiple data types efficiently
  static void batchRefresh(Ref ref, {
    bool products = false,
    bool customers = false,
    bool suppliers = false,
    bool sales = false,
    bool payments = false,
    bool purchases = false,
    bool stock = false,
    bool expenses = false,
    bool banks = false,
  }) {
    if (products) {
      // Only invalidate productNotifierProvider to avoid circular dependency
      ref.invalidate(productNotifierProvider);
      ref.invalidate(productCategoriesProvider);
    }
    if (customers) {
      // Only invalidate notifier to avoid circular dependency
      ref.invalidate(customerNotifierProvider);
    }
    if (suppliers) {
      // Only invalidate notifier to avoid circular dependency
      ref.invalidate(supplierNotifierProvider);
    }
    if (sales) {
      // Only invalidate notifier to avoid circular dependency
      ref.invalidate(saleNotifierProvider);
    }
    if (payments) {
      ref.invalidate(paymentNotifierProvider);
    }
    if (purchases) {
      // Only invalidate notifier to avoid circular dependency
      ref.invalidate(purchaseOrderNotifierProvider);
    }
    if (stock) {
      ref.invalidate(stockMovementNotifierProvider);
    }
    if (expenses) {
      ref.invalidate(expenseNotifierProvider);
      ref.invalidate(expenseSummaryProvider);
    }
    if (banks) {
      // Only invalidate notifier to avoid circular dependency
      ref.invalidate(bankNotifierProvider);
    }
  }
}

/// Provider for auto-refresh service
final autoRefreshServiceProvider = Provider<AutoRefreshService>((ref) {
  return AutoRefreshService();
});

