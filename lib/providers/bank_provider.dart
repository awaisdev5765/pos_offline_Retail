import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bank.dart';
import '../models/bank_payment.dart';
import '../services/database_service.dart';
import 'payment_provider.dart' as payment_provider;

// Bank Notifier for CRUD operations
class BankNotifier extends StateNotifier<AsyncValue<List<BankModel>>> {
  final DatabaseService _databaseService;

  BankNotifier(this._databaseService) : super(const AsyncValue.loading()) {
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    try {
      if (mounted) {
        state = const AsyncValue.loading();
      }
      final banks = await _databaseService.getAllBanks();
      if (mounted) {
        state = AsyncValue.data(banks);
      }
    } catch (error, stackTrace) {
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> addBank(BankModel bank) async {
    try {
      await _databaseService.insertBank(bank);
      await _loadBanks();
    } catch (error, stackTrace) {
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> updateBank(BankModel bank) async {
    try {
      await _databaseService.updateBank(bank);
      await _loadBanks();
    } catch (error, stackTrace) {
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> deleteBank(int id) async {
    try {
      await _databaseService.deleteBank(id);
      await _loadBanks();
    } catch (error, stackTrace) {
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  void refresh() {
    _loadBanks();
  }
}

// Bank Payment Notifier for CRUD operations
class BankPaymentNotifier
    extends StateNotifier<AsyncValue<List<BankPaymentModel>>> {
  final DatabaseService _databaseService;
  final int _bankId;

  BankPaymentNotifier(this._databaseService, this._bankId)
      : super(const AsyncValue.loading()) {
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      if (mounted) {
        state = const AsyncValue.loading();
      }
      final payments = await _databaseService.getBankPayments(_bankId);
      if (mounted) {
        state = AsyncValue.data(payments);
      }
    } catch (error, stackTrace) {
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> addPayment(BankPaymentModel payment) async {
    try {
      await _databaseService.insertBankPayment(payment);
      await _loadPayments();
    } catch (error, stackTrace) {
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> updatePayment(BankPaymentModel payment) async {
    try {
      await _databaseService.updateBankPayment(payment);
      await _loadPayments();
    } catch (error, stackTrace) {
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> deletePayment(int id) async {
    try {
      await _databaseService.deleteBankPayment(id);
      await _loadPayments();
    } catch (error, stackTrace) {
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> updatePaymentStatus(int id, String status) async {
    try {
      await _databaseService.updateBankPaymentStatus(id, status);
      await _loadPayments();
    } catch (error, stackTrace) {
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  void refresh() {
    _loadPayments();
  }
}

// Providers for banks
final bankNotifierProvider =
    StateNotifierProvider<BankNotifier, AsyncValue<List<BankModel>>>((ref) {
  return BankNotifier(ref.watch(databaseServiceProvider));
});

// Watch notifier but never invalidate this provider directly
// Only invalidate bankNotifierProvider to avoid circular dependency
final banksProvider = Provider.autoDispose<AsyncValue<List<BankModel>>>((ref) {
  return ref.watch(bankNotifierProvider);
});

final activeBanksProvider = FutureProvider<List<BankModel>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getActiveBanks();
});

final bankByIdProvider =
    FutureProvider.family<BankModel?, int>((ref, bankId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getBankById(bankId);
});

// Providers for bank payments
final bankPaymentsProvider = StateNotifierProvider.family<BankPaymentNotifier,
    AsyncValue<List<BankPaymentModel>>, int>((ref, bankId) {
  return BankPaymentNotifier(ref.watch(databaseServiceProvider), bankId);
});

final bankPaymentsByDateRangeProvider = FutureProvider.family<
    List<BankPaymentModel>,
    ({DateTime start, DateTime end})>((ref, dateRange) async {
  // React to refresh ticks so dependents update in real-time after mutations
  ref.watch(payment_provider.paymentsRefreshTickProvider);
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getBankPaymentsByDateRange(
      dateRange.start, dateRange.end);
});

final bankPaymentsByPartyProvider =
    FutureProvider.family<List<BankPaymentModel>, String>(
        (ref, partyName) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getBankPaymentsByParty(partyName);
});

final bankPaymentsByChequeNumberProvider =
    FutureProvider.family<List<BankPaymentModel>, String>(
        (ref, chequeNumber) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getBankPaymentsByChequeNumber(chequeNumber);
});

// Provider for all bank payments across all banks
final allBankPaymentsProvider =
    FutureProvider<List<BankPaymentModel>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final banks = await databaseService.getAllBanks();
  final allPayments = <BankPaymentModel>[];

  for (final bank in banks) {
    if (bank.id != null) {
      final payments = await databaseService.getBankPayments(bank.id!);
      allPayments.addAll(payments);
    }
  }

  // Sort by issue date descending
  allPayments.sort((a, b) => b.issueDate.compareTo(a.issueDate));
  return allPayments;
});
