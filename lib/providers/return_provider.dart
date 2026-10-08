import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../models/return.dart';
import '../services/database_service.dart';
import '../database/database.dart' as db;

// Return Notifier
class ReturnNotifier extends StateNotifier<AsyncValue<List<ReturnModel>>> {
  final DatabaseService _databaseService;

  ReturnNotifier(this._databaseService) : super(const AsyncValue.loading()) {
    _loadReturns();
  }

  Future<void> _loadReturns() async {
    state = const AsyncValue.loading();
    try {
      final returns = await _databaseService.getAllReturns();
      final returnModels = <ReturnModel>[];

      for (final returnEntity in returns) {
        // Get sale (already returns SaleModel)
        final sale =
            await _databaseService.getSaleById(returnEntity.originalSaleId);

        // Get customer (already returns CustomerModel)
        final customer =
            await _databaseService.getCustomerById(returnEntity.customerId);

        // Get return items
        final itemsEntities =
            await _databaseService.getReturnItems(returnEntity.id);
        final items = <ReturnItemModel>[];

        for (final itemEntity in itemsEntities) {
          final productModel =
              await _databaseService.getProductById(itemEntity.productId);

          items.add(ReturnItemModel.fromReturnItem(
            itemEntity,
            product: productModel,
          ));
        }

        returnModels.add(ReturnModel.fromReturn(
          returnEntity,
          originalSale: sale,
          customer: customer,
          items: items,
        ));
      }

      state = AsyncValue.data(returnModels);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadReturns();
  }

  Future<void> addReturn(ReturnModel returnModel) async {
    try {
      // Generate return number
      final now = DateTime.now();
      final returnNumber =
          'RET${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.millisecondsSinceEpoch % 10000}';

      // Insert return
      final returnId = await _databaseService.insertReturn(
        db.ReturnsCompanion(
          returnNumber: Value(returnNumber),
          originalSaleId: Value(returnModel.originalSaleId),
          customerId: Value(returnModel.customerId),
          returnDate: Value(returnModel.returnDate.toIso8601String()),
          totalAmount: Value(returnModel.totalAmount),
          reason: Value(returnModel.reason.toString().split('.').last),
          status: Value(returnModel.status.toString().split('.').last),
          notes: Value(returnModel.notes),
          processedBy: Value(returnModel.processedBy),
          createdAt: Value(now.toIso8601String()),
          updatedAt: Value(now.toIso8601String()),
        ),
      );

      // Insert return items
      for (final item in returnModel.items) {
        await _databaseService.insertReturnItem(
          db.ReturnItemsCompanion(
            returnId: Value(returnId),
            productId: Value(item.productId),
            quantity: Value(item.quantity),
            unitPrice: Value(item.unitPrice),
            subtotal: Value(item.subtotal),
            reason: Value(item.reason.toString().split('.').last),
            condition: Value(item.condition.toString().split('.').last),
            action: Value(item.action.toString().split('.').last),
            createdAt: Value(now.toIso8601String()),
          ),
        );
      }

      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateReturn(ReturnModel returnModel) async {
    try {
      if (returnModel.id == null) throw Exception('Return ID is required');

      final now = DateTime.now();
      final returnEntity = db.Return(
        id: returnModel.id!,
        returnNumber: returnModel.returnNumber,
        originalSaleId: returnModel.originalSaleId,
        customerId: returnModel.customerId,
        returnDate: returnModel.returnDate.toIso8601String(),
        totalAmount: returnModel.totalAmount,
        reason: returnModel.reason.toString().split('.').last,
        status: returnModel.status.toString().split('.').last,
        notes: returnModel.notes,
        processedBy: returnModel.processedBy,
        createdAt: returnModel.createdAt.toIso8601String(),
        updatedAt: now.toIso8601String(),
      );

      await _databaseService.updateReturn(returnEntity);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteReturn(int id) async {
    try {
      await _databaseService.deleteReturnItems(id);
      await _databaseService.deleteReturn(id);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> approveReturn(int returnId) async {
    try {
      await _databaseService.approveReturnAtomically(returnId);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> rejectReturn(int returnId, String? rejectionNotes) async {
    try {
      final returnEntity = await _databaseService.getReturnById(returnId);
      if (returnEntity == null) throw Exception('Return not found');

      // Update return status to rejected
      final updatedReturn = db.Return(
        id: returnEntity.id,
        returnNumber: returnEntity.returnNumber,
        originalSaleId: returnEntity.originalSaleId,
        customerId: returnEntity.customerId,
        returnDate: returnEntity.returnDate,
        totalAmount: returnEntity.totalAmount,
        reason: returnEntity.reason,
        status: ReturnStatus.rejected.toString().split('.').last,
        notes: rejectionNotes ?? returnEntity.notes,
        processedBy: 'System', // You can pass the actual user here
        createdAt: returnEntity.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await _databaseService.updateReturn(updatedReturn);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> processReturn(int returnId) async {
    try {
      final returnEntity = await _databaseService.getReturnById(returnId);
      if (returnEntity == null) throw Exception('Return not found');

      // Update return status to processed
      final updatedReturn = db.Return(
        id: returnEntity.id,
        returnNumber: returnEntity.returnNumber,
        originalSaleId: returnEntity.originalSaleId,
        customerId: returnEntity.customerId,
        returnDate: returnEntity.returnDate,
        totalAmount: returnEntity.totalAmount,
        reason: returnEntity.reason,
        status: ReturnStatus.processed.toString().split('.').last,
        notes: returnEntity.notes,
        processedBy: 'System', // You can pass the actual user here
        createdAt: returnEntity.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await _databaseService.updateReturn(updatedReturn);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// Providers
final returnNotifierProvider =
    StateNotifierProvider<ReturnNotifier, AsyncValue<List<ReturnModel>>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return ReturnNotifier(databaseService);
});

// Watch notifier but never invalidate this provider directly
// Only invalidate returnNotifierProvider to avoid circular dependency
final returnsProvider =
    Provider.autoDispose<AsyncValue<List<ReturnModel>>>((ref) {
  return ref.watch(returnNotifierProvider);
});

// Filter by status
final returnsByStatusProvider =
    Provider.family<AsyncValue<List<ReturnModel>>, String>((ref, status) {
  final returnsAsync = ref.watch(returnsProvider);
  return returnsAsync.whenData((returns) {
    if (status == 'all') return returns;
    return returns
        .where((r) => r.status.toString().split('.').last == status)
        .toList();
  });
});

// Filter by customer
final returnsByCustomerProvider =
    Provider.family<AsyncValue<List<ReturnModel>>, int>((ref, customerId) {
  final returnsAsync = ref.watch(returnsProvider);
  return returnsAsync.whenData((returns) {
    return returns.where((r) => r.customerId == customerId).toList();
  });
});

// Get single return by ID
final returnByIdProvider =
    Provider.family<AsyncValue<ReturnModel?>, int>((ref, id) {
  final returnsAsync = ref.watch(returnsProvider);
  return returnsAsync.whenData((returns) {
    try {
      return returns.firstWhere(
        (r) => r.id == id,
        orElse: () => throw StateError('Return not found'),
      );
    } catch (e) {
      return null;
    }
  });
});

// Return Statistics
class ReturnStats {
  final int totalReturns;
  final int pendingReturns;
  final int approvedReturns;
  final int rejectedReturns;
  final int processedReturns;
  final double totalRefundAmount;

  ReturnStats({
    required this.totalReturns,
    required this.pendingReturns,
    required this.approvedReturns,
    required this.rejectedReturns,
    required this.processedReturns,
    required this.totalRefundAmount,
  });
}

final returnStatsProvider = Provider<AsyncValue<ReturnStats>>((ref) {
  final returnsAsync = ref.watch(returnsProvider);
  return returnsAsync.whenData((returns) {
    final pendingReturns =
        returns.where((r) => r.status == ReturnStatus.pending).length;
    final approvedReturns =
        returns.where((r) => r.status == ReturnStatus.approved).length;
    final rejectedReturns =
        returns.where((r) => r.status == ReturnStatus.rejected).length;
    final processedReturns =
        returns.where((r) => r.status == ReturnStatus.processed).length;
    final totalRefundAmount = returns
        .where((r) =>
            r.status == ReturnStatus.approved ||
            r.status == ReturnStatus.processed)
        .fold(0.0, (sum, r) => sum + r.totalAmount);

    return ReturnStats(
      totalReturns: returns.length,
      pendingReturns: pendingReturns,
      approvedReturns: approvedReturns,
      rejectedReturns: rejectedReturns,
      processedReturns: processedReturns,
      totalRefundAmount: totalRefundAmount,
    );
  });
});
