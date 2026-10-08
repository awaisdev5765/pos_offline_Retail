import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/product_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../providers/bank_provider.dart';
import '../providers/staff_performance_provider.dart';
import '../providers/stock_movement_provider.dart';

class GlobalRefreshService {
  static final GlobalRefreshService _instance =
      GlobalRefreshService._internal();
  factory GlobalRefreshService() => _instance;
  GlobalRefreshService._internal();

  // Global refresh method that refreshes all providers
  static void refreshAllData(WidgetRef ref) {
    try {
      // Refresh all main data providers
      ref.invalidate(productNotifierProvider);
      ref.invalidate(productsProvider);
      ref.invalidate(customerNotifierProvider);
      ref.invalidate(saleNotifierProvider);
      ref.invalidate(supplierNotifierProvider);
      ref.invalidate(expenseNotifierProvider);
      ref.invalidate(categoryNotifierProvider);
      ref.invalidate(bankNotifierProvider);
      ref.invalidate(staffPerformanceNotifierProvider);
      ref.invalidate(stockMovementNotifierProvider);

      // Refresh summary providers
      ref.invalidate(expenseSummaryProvider);
      ref.invalidate(staffPerformanceSummaryProvider);
      ref.invalidate(topPerformersProvider);
      ref.invalidate(staffPerformanceAnalyticsProvider);

      print('🔄 Global data refresh completed');
    } catch (e) {
      print('❌ Error during global refresh: $e');
    }
  }

  // Refresh specific data types
  static void refreshProducts(WidgetRef ref) {
    ref.invalidate(productNotifierProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(categoryNotifierProvider);
  }

  static void refreshSales(WidgetRef ref) {
    ref.invalidate(saleNotifierProvider);
  }

  static void refreshCustomers(WidgetRef ref) {
    ref.invalidate(customerNotifierProvider);
  }

  static void refreshSuppliers(WidgetRef ref) {
    ref.invalidate(supplierNotifierProvider);
  }

  static void refreshExpenses(WidgetRef ref) {
    ref.invalidate(expenseNotifierProvider);
    ref.invalidate(expenseSummaryProvider);
  }

  static void refreshBanking(WidgetRef ref) {
    ref.invalidate(bankNotifierProvider);
  }

  static void refreshStaffPerformance(WidgetRef ref) {
    ref.invalidate(staffPerformanceNotifierProvider);
    ref.invalidate(staffPerformanceSummaryProvider);
    ref.invalidate(topPerformersProvider);
    ref.invalidate(staffPerformanceAnalyticsProvider);
  }

  static void refreshInventory(WidgetRef ref) {
    ref.invalidate(productNotifierProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(stockMovementNotifierProvider);
  }
}

// Provider for global refresh service
final globalRefreshServiceProvider = Provider<GlobalRefreshService>((ref) {
  return GlobalRefreshService();
});

// Provider to trigger global refresh
final globalRefreshTriggerProvider = StateProvider<int>((ref) => 0);

// Method to trigger global refresh
void triggerGlobalRefresh(WidgetRef ref) {
  ref.read(globalRefreshTriggerProvider.notifier).state++;
  GlobalRefreshService.refreshAllData(ref);
}
