import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../services/database_service.dart';

// Expenses providers
final expensesProvider = FutureProvider<List<ExpenseModel>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final expenses = await databaseService.getAllExpenses();
  return expenses.map((e) => ExpenseModel.fromExpense(e)).toList();
});

final expenseByIdProvider =
    FutureProvider.family<ExpenseModel?, int>((ref, id) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final expense = await databaseService.getExpenseById(id);
  return expense != null ? ExpenseModel.fromExpense(expense) : null;
});

final expensesByDateRangeProvider =
    FutureProvider.family<List<ExpenseModel>, DateRangeFilter>(
        (ref, dateRange) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final expenses = await databaseService.getExpensesByDateRange(
      dateRange.start, dateRange.end);
  return expenses.map((e) => ExpenseModel.fromExpense(e)).toList();
});

final expensesByCategoryProvider =
    FutureProvider.family<List<ExpenseModel>, String>((ref, category) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final expenses = await databaseService.getExpensesByCategory(category);
  return expenses.map((e) => ExpenseModel.fromExpense(e)).toList();
});

final expensesByCreatedByProvider =
    FutureProvider.family<List<ExpenseModel>, String>((ref, createdBy) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final expenses = await databaseService.getAllExpenses();
  final filtered = expenses.where((e) => e.createdBy == createdBy).toList();
  return filtered.map((e) => ExpenseModel.fromExpense(e)).toList();
});

// Expense notifier for CRUD operations
class ExpenseNotifier extends StateNotifier<AsyncValue<List<ExpenseModel>>> {
  final DatabaseService _databaseService;

  ExpenseNotifier(this._databaseService) : super(const AsyncValue.loading()) {
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    try {
      state = const AsyncValue.loading();
      final expenses = await _databaseService.getAllExpenses();
      final expenseModels =
          expenses.map((e) => ExpenseModel.fromExpense(e)).toList();
      state = AsyncValue.data(expenseModels);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addExpense(ExpenseModel expense) async {
    try {
      await _databaseService.insertExpense(expense.toCompanion());
      await _loadExpenses();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    try {
      await _databaseService.updateExpense(expense.toExpense());
      await _loadExpenses();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteExpense(int id) async {
    try {
      await _databaseService.deleteExpense(id);
      await _loadExpenses();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void refresh() {
    _loadExpenses();
  }
}

final expenseNotifierProvider =
    StateNotifierProvider<ExpenseNotifier, AsyncValue<List<ExpenseModel>>>(
        (ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return ExpenseNotifier(databaseService);
});

// Expense summary providers
// Expense summary provider with keepAlive for fast response
final expenseSummaryProvider =
    FutureProvider.autoDispose.family<ExpenseSummary, DateRangeFilter>(
        (ref, dateRange) async {
  final expenses =
      await ref.watch(expensesByDateRangeProvider(dateRange).future);

  final totalExpense =
      expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  final categorySummary = <String, double>{};
  final paymentMethodSummary = <String, double>{};

  for (final expense in expenses) {
    categorySummary[expense.category] =
        (categorySummary[expense.category] ?? 0) + expense.amount;
    paymentMethodSummary[expense.paymentMethod] =
        (paymentMethodSummary[expense.paymentMethod] ?? 0) + expense.amount;
  }
  
  // Keep alive to cache results and reduce rebuilds
  ref.keepAlive();

  return ExpenseSummary(
    totalExpense: totalExpense,
    expenseCount: expenses.length,
    categorySummary: categorySummary,
    paymentMethodSummary: paymentMethodSummary,
    topCategory: categorySummary.isNotEmpty
        ? categorySummary.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key
        : null,
    topPaymentMethod: paymentMethodSummary.isNotEmpty
        ? paymentMethodSummary.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key
        : null,
  );
});

// Helper classes
class DateRangeFilter {
  final DateTime start;
  final DateTime end;

  DateRangeFilter({required this.start, required this.end});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateRangeFilter && other.start == start && other.end == end;
  }

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}

class ExpenseSummary {
  final double totalExpense;
  final int expenseCount;
  final Map<String, double> categorySummary;
  final Map<String, double> paymentMethodSummary;
  final String? topCategory;
  final String? topPaymentMethod;

  ExpenseSummary({
    required this.totalExpense,
    required this.expenseCount,
    required this.categorySummary,
    required this.paymentMethodSummary,
    this.topCategory,
    this.topPaymentMethod,
  });
}
