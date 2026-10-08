import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../services/database_service.dart';
import 'package:drift/drift.dart';

final expenseHeadNotifierProvider =
    StateNotifierProvider<ExpenseHeadNotifier, AsyncValue<List<ExpenseHead>>>(
        (ref) {
  return ExpenseHeadNotifier(ref.read(databaseServiceProvider));
});

class ExpenseHeadNotifier extends StateNotifier<AsyncValue<List<ExpenseHead>>> {
  final DatabaseService _databaseService;

  ExpenseHeadNotifier(this._databaseService)
      : super(const AsyncValue.loading()) {
    loadExpenseHeads();
  }

  Future<void> loadExpenseHeads() async {
    try {
      state = const AsyncValue.loading();
      final expenseHeads = await _databaseService.getAllExpenseHeads();
      state = AsyncValue.data(expenseHeads);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addExpenseHead(
      String name, String? description, String? jobType) async {
    try {
      final now = DateTime.now().toIso8601String();
      final companion = ExpenseHeadsCompanion.insert(
        name: name,
        description: Value(description),
        jobType: Value(jobType),
        createdAt: now,
        updatedAt: now,
      );
      await _databaseService.insertExpenseHead(companion);
      await loadExpenseHeads(); // Refresh the list
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateExpenseHead(ExpenseHead expenseHead) async {
    try {
      final updated =
          expenseHead.copyWith(updatedAt: DateTime.now().toIso8601String());
      await _databaseService.updateExpenseHead(updated);
      await loadExpenseHeads(); // Refresh the list
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteExpenseHead(int id) async {
    try {
      await _databaseService.deleteExpenseHead(id);
      await loadExpenseHeads(); // Refresh the list
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void refresh() {
    loadExpenseHeads();
  }
}
