import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/payment.dart';
import '../services/database_service.dart';
import '../services/auto_refresh_service.dart';

// Customer providers with keepAlive for better caching
final customersProvider = FutureProvider.autoDispose<List<CustomerModel>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final customers = await databaseService.getAllCustomers();
  
  // Keep alive to reduce unnecessary rebuilds
  ref.keepAlive();
  
  return customers;
});

final customerByIdProvider =
    FutureProvider.family<CustomerModel?, int>((ref, id) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getCustomerById(id);
});

final customerByPhoneProvider =
    FutureProvider.family<CustomerModel?, String>((ref, phone) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getCustomerByPhone(phone);
});

final customersWithDueProvider =
    FutureProvider<List<CustomerModel>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getCustomersWithDue();
});

// Customer state notifier for CRUD operations
class CustomerNotifier extends StateNotifier<AsyncValue<List<CustomerModel>>> {
  final DatabaseService _databaseService;
  Ref? _ref; // Store ref for auto-refresh
  bool _disposed = false;

  CustomerNotifier(this._databaseService) : super(const AsyncValue.loading()) {
    _loadCustomers();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      state = const AsyncValue.loading();
      final customers = await _databaseService.getAllCustomers();
      if (!_disposed) {
        state = AsyncValue.data(customers);
      }
    } catch (error, stackTrace) {
      if (!_disposed) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> addCustomer(CustomerModel customer) async {
    try {
      await _databaseService.insertCustomer(customer);
      await _loadCustomers();
      
      // Auto-refresh related providers (use Future.microtask to avoid circular dependency)
      if (_ref != null) {
        Future.microtask(() {
          AutoRefreshService.refreshAfterCustomerOperation(_ref!, customerId: customer.id);
        });
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    try {
      await _databaseService.updateCustomer(customer);
      await _loadCustomers();
      
      // Auto-refresh related providers (use Future.microtask to avoid circular dependency)
      if (_ref != null) {
        Future.microtask(() {
          AutoRefreshService.refreshAfterCustomerOperation(_ref!, customerId: customer.id);
        });
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteCustomer(int id) async {
    // Don't wrap in try-catch - let errors propagate to UI
    // The UI will handle the error via snackbar without affecting the customer list state
    await _databaseService.deleteCustomer(id);
    
    // Immediately reload customers to update the list
    // This sets state to loading, then updates with new data
    // The screen watching customerNotifierProvider will automatically rebuild
    await _loadCustomers();
    
    // Auto-refresh related providers (use Future.microtask to avoid circular dependency)
    if (_ref != null) {
      Future.microtask(() {
        AutoRefreshService.refreshAfterCustomerOperation(_ref!, customerId: id);
      });
    }
  }

  void refresh() {
    _loadCustomers();
  }
}

final customerNotifierProvider =
    StateNotifierProvider<CustomerNotifier, AsyncValue<List<CustomerModel>>>(
        (ref) {
  final databaseService = ref.read(databaseServiceProvider);
  final notifier = CustomerNotifier(databaseService);
  
  // Store ref in notifier for auto-refresh
  notifier._ref = ref;
  
  return notifier;
});

// Customer ledger provider
final customerLedgerProvider =
    FutureProvider.family<CustomerWithSales, int>((ref, customerId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getCustomerWithSales(customerId);
});

// Customer payments provider
final customerPaymentsProvider =
    FutureProvider.family<List<PaymentModel>, int>((ref, customerId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getPaymentsByCustomer(customerId);
});

// Customer sales provider
final customerSalesProvider =
    FutureProvider.family<List<SaleModel>, int>((ref, customerId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getSalesByCustomer(customerId);
});
