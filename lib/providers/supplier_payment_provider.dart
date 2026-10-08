import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier_payment.dart';
import '../services/database_service.dart';
import '../providers/payment_provider.dart';

// Supplier Payment Notifier for CRUD operations
class SupplierPaymentNotifier
    extends StateNotifier<AsyncValue<List<SupplierPaymentModel>>> {
  final DatabaseService _databaseService;
  final int _supplierId;

  SupplierPaymentNotifier(this._databaseService, this._supplierId)
      : super(const AsyncValue.loading()) {
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      state = const AsyncValue.loading();
      final payments = await _databaseService.getSupplierPayments(_supplierId);
      state = AsyncValue.data(payments);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<int> addPayment(SupplierPaymentModel payment) async {
    try {
      // CRITICAL: Validate payment amount
      if (payment.amount == 0 ||
          payment.amount.isNaN ||
          payment.amount.isInfinite) {
        throw Exception(
            'Invalid payment amount: ${payment.amount}. Amount must be non-zero and finite.');
      }

      final paymentId = await _databaseService.insertSupplierPayment(payment);
      await _loadPayments();
      return paymentId;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow; // CRITICAL: Re-throw to allow caller to handle errors
    }
  }

  Future<void> updatePayment(SupplierPaymentModel payment) async {
    try {
      await _databaseService.updateSupplierPayment(payment);
      await _loadPayments();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deletePayment(int id) async {
    try {
      await _databaseService.deleteSupplierPayment(id);
      await _loadPayments();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void refresh() {
    _loadPayments();
  }
}

// Provider for supplier payments
final supplierPaymentsProvider = StateNotifierProvider.family<
    SupplierPaymentNotifier,
    AsyncValue<List<SupplierPaymentModel>>,
    int>((ref, supplierId) {
  return SupplierPaymentNotifier(
      ref.watch(databaseServiceProvider), supplierId);
});

// Provider for supplier balance
final supplierBalanceProvider =
    FutureProvider.family<double, int>((ref, supplierId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getSupplierBalance(supplierId);
});

// Provider for supplier payments by date range
final supplierPaymentsByDateRangeProvider = FutureProvider.family<
    List<SupplierPaymentModel>,
    ({int supplierId, DateTime start, DateTime end})>((ref, dateRange) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getSupplierPaymentsByDateRange(
      dateRange.supplierId, dateRange.start, dateRange.end);
});

// Aggregate all supplier payments across all suppliers in a date range
final allSupplierPaymentsByDateRangeProvider = FutureProvider.family<
    List<SupplierPaymentModel>,
    ({DateTime start, DateTime end})>((ref, dateRange) async {
  // React to global payments refresh tick so cash/overview updates in real-time
  ref.watch(paymentsRefreshTickProvider);
  final databaseService = ref.watch(databaseServiceProvider);
  final suppliers = await databaseService.getAllSuppliers();
  final List<SupplierPaymentModel> all = [];
  for (final supplier in suppliers) {
    // This already returns List<SupplierPaymentModel>, no mapping needed
    final payments = await databaseService.getSupplierPaymentsByDateRange(
        supplier.id, dateRange.start, dateRange.end);
    all.addAll(payments);
  }
  return all;
});
