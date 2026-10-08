import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/staff_performance.dart';
import '../services/database_service.dart';
import '../database/database.dart';

// Staff Performance Notifier for CRUD operations
class StaffPerformanceNotifier
    extends StateNotifier<AsyncValue<List<StaffPerformance>>> {
  final DatabaseService _databaseService;

  StaffPerformanceNotifier(this._databaseService)
      : super(const AsyncValue.loading()) {
    _loadStaffPerformance();
  }

  Future<void> _loadStaffPerformance() async {
    try {
      state = const AsyncValue.loading();
      final performances = await _databaseService.getAllStaffPerformance();
      state = AsyncValue.data(performances);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addStaffPerformance(StaffPerformanceModel performance) async {
    try {
      await _databaseService.insertStaffPerformance(performance);
      await _loadStaffPerformance();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateStaffPerformance(StaffPerformanceModel performance) async {
    try {
      await _databaseService.updateStaffPerformance(performance);
      await _loadStaffPerformance();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteStaffPerformance(int id) async {
    try {
      await _databaseService.deleteStaffPerformance(id);
      await _loadStaffPerformance();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void refresh() {
    _loadStaffPerformance();
  }
}

final staffPerformanceNotifierProvider = StateNotifierProvider<
    StaffPerformanceNotifier, AsyncValue<List<StaffPerformance>>>((ref) {
  return StaffPerformanceNotifier(ref.watch(databaseServiceProvider));
});

// Provider for staff performance summary
final staffPerformanceSummaryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final performances = await databaseService.getStaffPerformanceSummary();
  return performances;
});

// Provider for individual staff performance
final staffPerformanceByIdProvider =
    FutureProvider.family<List<StaffPerformance>, int>((ref, employeeId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final performances =
      await databaseService.getStaffPerformanceByEmployee(employeeId);
  return performances;
});

// Provider for staff performance by date range
final staffPerformanceByDateRangeProvider = FutureProvider.family<
    List<StaffPerformance>,
    ({DateTime start, DateTime end})>((ref, dateRange) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final performances = await databaseService.getStaffPerformanceByDateRange(
      dateRange.start, dateRange.end);
  return performances;
});

// Provider for top performers
final topPerformersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final performances = await databaseService.getTopPerformers(10);
  return performances;
});

// Provider for staff performance analytics
final staffPerformanceAnalyticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getStaffPerformanceAnalytics();
});
