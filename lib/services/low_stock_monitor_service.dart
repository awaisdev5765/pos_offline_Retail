import 'dart:async';
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/local_notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LowStockMonitorService {
  static final LowStockMonitorService _instance = LowStockMonitorService._internal();
  factory LowStockMonitorService() => _instance;
  LowStockMonitorService._internal();

  Timer? _monitoringTimer;
  final Set<int> _notifiedProducts = {}; // Track which products we've already notified
  final LocalNotificationService _notificationService = LocalNotificationService();
  bool _isMonitoring = false;

  /// Start monitoring for low stock products
  /// Uses [WidgetRef] from the UI layer to access providers.
  Future<void> startMonitoring(WidgetRef ref,
      {Duration interval = const Duration(minutes: 5)}) async {
    if (_isMonitoring) {
      print('⚠️ Low stock monitoring is already running');
      return;
    }

    // Initialize notification service
    await _notificationService.initialize();

    _isMonitoring = true;
    print('✅ Started low stock monitoring (checking every ${interval.inMinutes} minutes)');

    // Check immediately
    await _checkLowStock(ref);

    // Then check periodically
    _monitoringTimer = Timer.periodic(interval, (_) async {
      await _checkLowStock(ref);
    });
  }

  /// Stop monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    print('⏹️ Stopped low stock monitoring');
  }

  /// Check for low stock products and send notifications
  Future<void> _checkLowStock(WidgetRef ref) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final products = await databaseService.getAllProducts();

      final List<ProductModel> lowStockProducts = products
          .where((product) => product.stock <= product.reorderLevel && product.stock > 0)
          .toList();

      final List<ProductModel> outOfStockProducts = products
          .where((product) => product.stock <= 0)
          .toList();

      if (lowStockProducts.isEmpty && outOfStockProducts.isEmpty) {
        // Clear notified products if stock is back to normal
        _notifiedProducts.clear();
        return;
      }

      // Send notifications for low stock products
      for (final product in lowStockProducts) {
        if (product.id != null && !_notifiedProducts.contains(product.id)) {
          await _notificationService.showLowStockNotification(
            productId: product.id!,
            productName: product.name,
            currentStock: product.stock,
            reorderLevel: product.reorderLevel,
          );
          _notifiedProducts.add(product.id!);
        }
      }

      // Send notifications for out of stock products
      for (final product in outOfStockProducts) {
        if (product.id != null && !_notifiedProducts.contains(product.id)) {
          await _notificationService.showLowStockNotification(
            productId: product.id!,
            productName: product.name,
            currentStock: 0,
            reorderLevel: product.reorderLevel,
          );
          _notifiedProducts.add(product.id!);
        }
      }

      // Send summary notification if there are multiple products
      final totalLowStock = lowStockProducts.length + outOfStockProducts.length;
      if (totalLowStock > 1) {
        await _notificationService.showMultipleLowStockNotification(totalLowStock);
      }

      print('📊 Low stock check: ${lowStockProducts.length} low stock, ${outOfStockProducts.length} out of stock');
    } catch (e) {
      print('❌ Error checking low stock: $e');
    }
  }

  /// Manually trigger a low stock check
  Future<void> checkNow(WidgetRef ref) async {
    await _checkLowStock(ref);
  }

  /// Clear notification history for a product (when stock is replenished)
  void clearNotificationForProduct(int productId) {
    _notifiedProducts.remove(productId);
    _notificationService.cancelNotification(productId);
  }

  /// Clear all notification history
  void clearAllNotifications() {
    _notifiedProducts.clear();
    _notificationService.cancelAllNotifications();
  }

  bool get isMonitoring => _isMonitoring;
}

// Provider for low stock monitor service
final lowStockMonitorServiceProvider = Provider<LowStockMonitorService>((ref) {
  return LowStockMonitorService();
});

