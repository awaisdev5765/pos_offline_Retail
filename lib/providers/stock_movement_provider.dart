import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock_movement.dart';
import '../models/product.dart';
import '../models/employee.dart';
import '../services/database_service.dart';
import '../database/database.dart';

// Stock movements provider with keepAlive for better performance
final stockMovementsProvider =
    FutureProvider.autoDispose<List<StockMovementWithProduct>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final movements = await databaseService.getAllStockMovements();
  final products = await databaseService.getAllProducts();
  final employees = await databaseService.getAllEmployees();

  final result = movements.map((m) {
    final product = products.firstWhere(
      (p) => p.id == m.productId,
      orElse: () => ProductModel(
        id: m.productId,
        name: 'Unknown Product',
        category: '',
        price: 0,
        cost: 0,
        stock: 0,
        unit: 'pcs',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    
    // Get employee information if available
    EmployeeModel? employee;
    if (m.employeeId != null) {
      try {
        final matchingEmployees = employees.where((e) => e.id == m.employeeId);
        if (matchingEmployees.isNotEmpty) {
          employee = matchingEmployees.first;
        }
      } catch (_) {
        employee = null;
      }
    }
    
    return StockMovementWithProduct(movement: m, product: product, employee: employee);
  }).toList();
  
  // Keep alive to cache results and reduce rebuilds
  ref.keepAlive();
  
  return result;
});

// Stock movements by product provider
final stockMovementsByProductProvider =
    FutureProvider.family<List<StockMovementModel>, int>(
        (ref, productId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final movements = await databaseService.getStockMovementsByProduct(productId);
  final product = await databaseService.getProductById(productId);

  return movements.map((m) {
    final model = StockMovementModel.fromStockAdjustment(m);
    if (product != null) {
      return model.copyWith(
        productName: product.name,
        productBarcode: product.barcode,
        productUnit: product.unit,
      );
    }
    return model;
  }).toList();
});

// Stock movements by date range provider
final stockMovementsByDateRangeProvider =
    FutureProvider.family<List<StockMovementWithProduct>, DateRange>(
        (ref, dateRange) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final movements = await databaseService.getStockMovementsByDateRange(
      dateRange.start, dateRange.end);
  final products = await databaseService.getAllProducts();

  return movements.map((m) {
    final product = products.firstWhere(
      (p) => p.id == m.productId,
      orElse: () => ProductModel(
        id: m.productId,
        name: 'Unknown Product',
        category: '',
        price: 0,
        cost: 0,
        stock: 0,
        unit: 'pcs',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return StockMovementWithProduct(movement: m, product: product);
  }).toList();
});

// Stock movement notifier for CRUD operations
class StockMovementNotifier
    extends StateNotifier<AsyncValue<List<StockMovementWithProduct>>> {
  final DatabaseService _databaseService;
  bool _isDisposed = false;

  StockMovementNotifier(this._databaseService)
      : super(const AsyncValue.loading()) {
    _loadMovements();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadMovements() async {
    if (_isDisposed) return;
    
    try {
      if (!_isDisposed) {
        state = const AsyncValue.loading();
      }
      final movements = await _databaseService.getAllStockMovements();
      if (_isDisposed) return;
      
      final products = await _databaseService.getAllProducts();
      if (_isDisposed) return;
      
      final employees = await _databaseService.getAllEmployees();
      if (_isDisposed) return;

      final movementsWithProducts = movements.map((m) {
        final product = products.firstWhere(
          (p) => p.id == m.productId,
          orElse: () => ProductModel(
            id: m.productId,
            name: 'Unknown Product',
            category: '',
            price: 0,
            cost: 0,
            stock: 0,
            unit: 'pcs',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        
        // Get employee information if available
        EmployeeModel? employee;
        if (m.employeeId != null) {
          try {
            final matchingEmployees = employees.where((e) => e.id == m.employeeId);
            if (matchingEmployees.isNotEmpty) {
              employee = matchingEmployees.first;
            }
          } catch (_) {
            employee = null;
          }
        }
        
        return StockMovementWithProduct(movement: m, product: product, employee: employee);
      }).toList();

      if (!_isDisposed) {
        state = AsyncValue.data(movementsWithProducts);
      }
    } catch (error, stackTrace) {
      if (!_isDisposed) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> addStockMovement(int productId, double quantity, String reason,
      {String? reference, int? employeeId}) async {
    if (_isDisposed) return;
    
    try {
      await _databaseService.adjustStock(productId, quantity, reason,
          reference: reference, employeeId: employeeId);
      if (!_isDisposed) {
        await _loadMovements();
      }
    } catch (error, stackTrace) {
      if (!_isDisposed) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> deleteStockMovement(int id) async {
    if (_isDisposed) return;
    
    try {
      await _databaseService.deleteStockMovement(id);
      if (!_isDisposed) {
        await _loadMovements();
      }
    } catch (error, stackTrace) {
      if (!_isDisposed) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  void refresh() {
    if (!_isDisposed) {
      _loadMovements();
    }
  }
}

final stockMovementNotifierProvider = StateNotifierProvider<
    StockMovementNotifier, AsyncValue<List<StockMovementWithProduct>>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return StockMovementNotifier(databaseService);
});

// Helper classes
class StockMovementWithProduct {
  final StockAdjustment movement;
  final ProductModel product;
  final EmployeeModel? employee;

  StockMovementWithProduct({
    required this.movement,
    required this.product,
    this.employee,
  });

  StockMovementModel toModel() {
    return StockMovementModel.fromStockAdjustment(movement).copyWith(
      productName: product.name,
      productBarcode: product.barcode,
      productUnit: product.unit,
    );
  }
}

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateRange && other.start == start && other.end == end;
  }

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}
