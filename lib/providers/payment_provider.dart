import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment.dart';
import '../services/database_service.dart';

// Payment providers
final paymentsProvider = FutureProvider<List<PaymentModel>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getPaymentsByDateRange(
    DateTime.now().subtract(const Duration(days: 30)),
    DateTime.now(),
  );
});

final paymentsByCustomerProvider =
    FutureProvider.family<List<PaymentModel>, int>((ref, customerId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getPaymentsByCustomer(customerId);
});

final paymentsByDateRangeProvider =
    FutureProvider.family<List<PaymentModel>, DateRange>(
        (ref, dateRange) async {
  final databaseService = ref.watch(databaseServiceProvider);
  // React to refresh ticks so dependents update in real-time after mutations
  ref.watch(paymentsRefreshTickProvider);
  return await databaseService.getPaymentsByDateRange(
      dateRange.start, dateRange.end);
});

// Payment state notifier for CRUD operations
class PaymentNotifier extends StateNotifier<AsyncValue<List<PaymentModel>>> {
  final DatabaseService _databaseService;

  PaymentNotifier(this._databaseService) : super(const AsyncValue.loading()) {
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      state = const AsyncValue.loading();
      final payments = await _databaseService.getPaymentsByDateRange(
        DateTime.now().subtract(const Duration(days: 30)),
        DateTime.now(),
      );
      state = AsyncValue.data(payments);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<int> addPayment(PaymentModel payment) async {
    try {
      final paymentId = await _databaseService.insertPayment(payment);
      await _loadPayments();

      // CRITICAL: Invalidate customer-related providers to refresh balance display
      // Note: This requires access to ref, which we don't have directly in the notifier
      // The caller (customer_payment_screen.dart) already handles this, but we'll note it here

      return paymentId;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow; // CRITICAL: Re-throw to allow caller to handle errors
    }
  }

  Future<void> updatePayment(PaymentModel payment) async {
    try {
      await _databaseService.updatePayment(payment);
      await _loadPayments();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deletePayment(int paymentId) async {
    try {
      await _databaseService.deletePayment(paymentId);
      await _loadPayments();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void refresh() {
    _loadPayments();
  }
}

final paymentNotifierProvider =
    StateNotifierProvider<PaymentNotifier, AsyncValue<List<PaymentModel>>>(
        (ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return PaymentNotifier(databaseService);
});

// Refresh tick to force recomputation of date-range payments across the app
final paymentsRefreshTickProvider = StateProvider<int>((ref) => 0);

// Helper class
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});

  DateRange copyWith({DateTime? start, DateTime? end}) {
    return DateRange(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DateRange) return false;
    return start.isAtSameMomentAs(other.start) &&
        end.isAtSameMomentAs(other.end);
  }

  @override
  int get hashCode => Object.hash(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      );
}
