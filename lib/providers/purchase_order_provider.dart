import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../models/purchase_order.dart';
import '../models/supplier.dart';
import '../services/database_service.dart';
import '../database/database.dart' as db;
import '../providers/product_provider.dart';
import '../providers/supplier_provider.dart';
import '../services/auto_refresh_service.dart';

// Purchase Order Notifier for CRUD operations
class PurchaseOrderNotifier
    extends StateNotifier<AsyncValue<List<PurchaseOrderModel>>> {
  final DatabaseService _databaseService;
  final Ref _ref;

  PurchaseOrderNotifier(this._databaseService, this._ref)
      : super(const AsyncValue.loading()) {
    _loadPurchaseOrders();
  }

  Future<void> _loadPurchaseOrders() async {
    try {
      state = const AsyncValue.loading();
      final orders = await _databaseService.getAllPurchaseOrders();

      // Enrich with supplier and items data
      final List<PurchaseOrderModel> enrichedOrders = [];
      for (final order in orders) {
        final supplier =
            await _databaseService.getSupplierById(order.supplierId);
        final items = await _databaseService.getPurchaseOrderItems(order.id);

        // Enrich items with product data
        final List<PurchaseOrderItemModel> enrichedItems = [];
        for (final item in items) {
          final productModel =
              await _databaseService.getProductById(item.productId);
          enrichedItems.add(PurchaseOrderItemModel.fromPurchaseOrderItem(
            item,
            product: productModel,
          ));
        }

        enrichedOrders.add(PurchaseOrderModel.fromPurchaseOrder(
          order,
          supplier:
              supplier != null ? SupplierModel.fromSupplier(supplier) : null,
          items: enrichedItems,
        ));
      }

      state = AsyncValue.data(enrichedOrders);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<int> addPurchaseOrder(
      PurchaseOrderModel order, List<PurchaseOrderItemModel> items) async {
    try {
      // Insert the purchase order
      final orderId =
          await _databaseService.insertPurchaseOrder(order.toCompanion());

      // Insert all items
      for (final item in items) {
        await _databaseService.insertPurchaseOrderItem(
          db.PurchaseOrderItemsCompanion(
            purchaseOrderId: Value(orderId),
            productId: Value(item.productId),
            quantity: Value(item.quantity),
            unitCost: Value(item.unitCost),
            subtotal: Value(item.subtotal),
            discount: Value(item.discount),
            tax: Value(item.tax),
            total: Value(item.total),
            notes: Value(item.notes),
            createdAt: Value(DateTime.now().toIso8601String()),
          ),
        );
      }

      await _loadPurchaseOrders();
      return orderId;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updatePurchaseOrder(
      PurchaseOrderModel order, List<PurchaseOrderItemModel> items) async {
    try {
      // Get existing order to check if it was received and get old total
      final existingOrder =
          await _databaseService.getPurchaseOrderById(order.id ?? 0);
      final wasReceived = existingOrder?.status == 'received';
      final oldTotal = existingOrder?.total ?? 0.0;

      // If order was received, reverse the balance change
      if (wasReceived && existingOrder != null) {
        final supplier =
            await _databaseService.getSupplierById(order.supplierId);
        if (supplier != null) {
          final supplierModel = SupplierModel.fromSupplier(supplier);
          final updatedSupplier = supplierModel.copyWith(
            currentBalance: supplierModel.currentBalance - oldTotal,
            updatedAt: DateTime.now(),
          );
          await _databaseService.updateSupplier(updatedSupplier.toSupplier());
        }
      }

      // Update the purchase order
      await _databaseService.updatePurchaseOrder(order.toPurchaseOrder());

      // Delete existing items and insert new ones
      if (order.id != null) {
        await _databaseService.deletePurchaseOrderItems(order.id!);

        for (final item in items) {
          await _databaseService.insertPurchaseOrderItem(
            db.PurchaseOrderItemsCompanion(
              purchaseOrderId: Value(order.id!),
              productId: Value(item.productId),
              quantity: Value(item.quantity),
              unitCost: Value(item.unitCost),
              subtotal: Value(item.subtotal),
              discount: Value(item.discount),
              tax: Value(item.tax),
              total: Value(item.total),
              notes: Value(item.notes),
              createdAt: Value(DateTime.now().toIso8601String()),
            ),
          );
        }
      }

      // If order is received (or was already received), add the new total to balance
      if (order.status == PurchaseOrderStatus.received) {
        final supplier =
            await _databaseService.getSupplierById(order.supplierId);
        if (supplier != null) {
          final supplierModel = SupplierModel.fromSupplier(supplier);
          final updatedSupplier = supplierModel.copyWith(
            currentBalance: supplierModel.currentBalance + order.total,
            updatedAt: DateTime.now(),
          );
          await _databaseService.updateSupplier(updatedSupplier.toSupplier());
          // Refresh supplier providers
          _ref.invalidate(supplierNotifierProvider);
          _ref.invalidate(activeSuppliersProvider);
          _ref.invalidate(supplierByIdProvider(order.supplierId));
        }
      }

      await _loadPurchaseOrders();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> receivePurchaseOrder(int orderId) async {
    try {
      final order = await _databaseService.getPurchaseOrderById(orderId);
      if (order == null) return;

      // Update order status to received
      final updatedOrder = db.PurchaseOrder(
        id: order.id,
        orderNumber: order.orderNumber,
        supplierId: order.supplierId,
        orderDate: order.orderDate,
        expectedDate: order.expectedDate,
        receivedDate: DateTime.now().toIso8601String(),
        subtotal: order.subtotal,
        tax: order.tax,
        discount: order.discount,
        total: order.total,
        status: 'received',
        notes: order.notes,
        createdAt: order.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await _databaseService.updatePurchaseOrder(updatedOrder);

      // Get all items and update product stock
      final items = await _databaseService.getPurchaseOrderItems(orderId);
      for (final item in items) {
        final productModel =
            await _databaseService.getProductById(item.productId);
        if (productModel != null) {
          final updatedProduct = productModel.copyWith(
            stock: productModel.stock + item.quantity,
            updatedAt: DateTime.now(),
          );
          await _databaseService.updateProduct(updatedProduct);

          // Add stock movement record
          await _databaseService.adjustStock(
            productModel.id!,
            item.quantity,
            'purchase',
            reference: 'Purchase Order: ${order.orderNumber}',
          );
        }
      }

      // Increase supplier current balance (accounts payable) by the order total
      final supplier = await _databaseService.getSupplierById(order.supplierId);
      if (supplier != null) {
        final supplierModel = SupplierModel.fromSupplier(supplier);
        final updatedSupplier = supplierModel.copyWith(
          currentBalance: supplierModel.currentBalance + order.total,
          updatedAt: DateTime.now(),
        );
        await _databaseService.updateSupplier(updatedSupplier.toSupplier());
        // Refresh supplier lists in UI
        _ref.invalidate(supplierNotifierProvider);
        _ref.invalidate(activeSuppliersProvider);
        _ref.invalidate(supplierByIdProvider(order.supplierId));
      }

      // Invalidate product provider to refresh stock levels
      _ref.invalidate(productsProvider);

      await _loadPurchaseOrders();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> cancelPurchaseOrder(int orderId) async {
    try {
      final order = await _databaseService.getPurchaseOrderById(orderId);
      if (order == null) return;

      final updatedOrder = db.PurchaseOrder(
        id: order.id,
        orderNumber: order.orderNumber,
        supplierId: order.supplierId,
        orderDate: order.orderDate,
        expectedDate: order.expectedDate,
        receivedDate: order.receivedDate,
        subtotal: order.subtotal,
        tax: order.tax,
        discount: order.discount,
        total: order.total,
        status: 'cancelled',
        notes: order.notes,
        createdAt: order.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await _databaseService.updatePurchaseOrder(updatedOrder);
      await _loadPurchaseOrders();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Create a direct Purchase Invoice (CRN/Stock In)
  // This inserts the order, items, immediately marks it as received,
  // updates stock quantities, and increases supplier currentBalance.
  Future<int> createPurchaseInvoice(
    PurchaseOrderModel order,
    List<PurchaseOrderItemModel> items,
  ) async {
    try {
      // 1) Insert order
      final orderId = await _databaseService.insertPurchaseOrder(order
          .copyWith(
            status: PurchaseOrderStatus.received,
            receivedDate: DateTime.now(),
            updatedAt: DateTime.now(),
          )
          .toCompanion());

      // 2) Insert items
      for (final item in items) {
        await _databaseService.insertPurchaseOrderItem(
          db.PurchaseOrderItemsCompanion(
            purchaseOrderId: Value(orderId),
            productId: Value(item.productId),
            quantity: Value(item.quantity),
            unitCost: Value(item.unitCost),
            subtotal: Value(item.subtotal),
            discount: Value(item.discount),
            tax: Value(item.tax),
            total: Value(item.total),
            notes: Value(item.notes),
            createdAt: Value(DateTime.now().toIso8601String()),
          ),
        );
      }

      // 3) Update product pricing/details and add stock movement records
      for (final item in items) {
        final productModel =
            await _databaseService.getProductById(item.productId);
        if (productModel != null) {
          // Update product with new pricing from item if available, do not touch stock here
          final productToUpdate = item.product != null
              ? productModel.copyWith(
                  cost: item.product!.cost,
                  price: item.product!.price,
                  retailCredit: item.product!.retailCredit,
                  wholesaleCash: item.product!.wholesaleCash,
                  wholesaleCredit: item.product!.wholesaleCredit,
                  marketPrice: item.product!.marketPrice,
                  updatedAt: DateTime.now(),
                )
              : productModel.copyWith(
                  cost: item.unitCost, // Update cost with purchase rate
                  updatedAt: DateTime.now(),
                );

          await _databaseService.updateProduct(productToUpdate);

          await _databaseService.adjustStock(
            productModel.id!,
            item.quantity,
            'purchase',
            reference: 'Purchase Invoice: ${order.orderNumber}',
          );
        }
      }

      // 4) Mark order as received in DB with receivedDate
      final inserted = await _databaseService.getPurchaseOrderById(orderId);
      if (inserted != null) {
        final updatedOrder = db.PurchaseOrder(
          id: inserted.id,
          orderNumber: inserted.orderNumber,
          supplierId: inserted.supplierId,
          orderDate: inserted.orderDate,
          expectedDate: inserted.expectedDate,
          receivedDate: DateTime.now().toIso8601String(),
          subtotal: inserted.subtotal,
          tax: inserted.tax,
          discount: inserted.discount,
          total: inserted.total,
          status: 'received',
          notes: inserted.notes,
          createdAt: inserted.createdAt,
          updatedAt: DateTime.now().toIso8601String(),
        );
        await _databaseService.updatePurchaseOrder(updatedOrder);
      }

      // 5) Increase supplier current balance (payable)
      final supplier = await _databaseService.getSupplierById(order.supplierId);
      if (supplier != null) {
        final supplierModel = SupplierModel.fromSupplier(supplier);
        final updatedSupplier = supplierModel.copyWith(
          currentBalance: supplierModel.currentBalance + order.total,
          updatedAt: DateTime.now(),
        );
        await _databaseService.updateSupplier(updatedSupplier.toSupplier());
      }

      // Invalidate products to refresh stock levels
      _ref.invalidate(productsProvider);

      // Get product IDs for refresh
      final productIds = items.map((item) => item.productId).toList();

      // Refresh all related providers (supplier balance, reports, etc.)
      AutoRefreshService.refreshAfterPurchaseOperation(
        _ref,
        supplierId: order.supplierId,
        productIds: productIds,
      );

      await _loadPurchaseOrders();
      return orderId;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updatePurchaseInvoice(
    PurchaseOrderModel order,
    List<PurchaseOrderItemModel> items,
  ) async {
    if (order.id == null) {
      throw Exception('Cannot update invoice without order ID');
    }

    try {
      // 1) Get existing order items to reverse stock changes
      final existingItems =
          await _databaseService.getPurchaseOrderItems(order.id!);
      final existingOrder =
          await _databaseService.getPurchaseOrderById(order.id!);

      if (existingOrder == null) {
        throw Exception('Order not found');
      }

      // 2) Calculate old total for supplier balance adjustment
      final oldTotal = existingOrder.total;

      // 3) Reverse previous stock changes
      for (final oldItem in existingItems) {
        await _databaseService.adjustStock(
          oldItem.productId,
          -oldItem.quantity,
          'purchase_edit_reversal',
          reference: 'Purchase Invoice Update: ${order.orderNumber}',
        );
      }

      // 4) Supplier balance will be adjusted once at the end using net delta

      // 5) Update the purchase order
      await _databaseService.updatePurchaseOrder(order.toPurchaseOrder());

      // 6) Delete existing items
      await _databaseService.deletePurchaseOrderItems(order.id!);

      // 7) Insert new items
      for (final item in items) {
        await _databaseService.insertPurchaseOrderItem(
          db.PurchaseOrderItemsCompanion(
            purchaseOrderId: Value(order.id!),
            productId: Value(item.productId),
            quantity: Value(item.quantity),
            unitCost: Value(item.unitCost),
            subtotal: Value(item.subtotal),
            discount: Value(item.discount),
            tax: Value(item.tax),
            total: Value(item.total),
            notes: Value(item.notes),
            createdAt: Value(DateTime.now().toIso8601String()),
          ),
        );
      }

      // 8) Apply new stock changes and product updates (only if items exist)
      if (items.isNotEmpty) {
        for (final item in items) {
          final productModel =
              await _databaseService.getProductById(item.productId);
          if (productModel != null) {
            // Update product with new pricing from item if available (stock handled via adjustStock)
            final productToUpdate = item.product != null
                ? productModel.copyWith(
                    cost: item.product!.cost,
                    price: item.product!.price,
                    retailCredit: item.product!.retailCredit,
                    wholesaleCash: item.product!.wholesaleCash,
                    wholesaleCredit: item.product!.wholesaleCredit,
                    marketPrice: item.product!.marketPrice,
                    updatedAt: DateTime.now(),
                  )
                : productModel.copyWith(
                    cost: item.unitCost,
                    updatedAt: DateTime.now(),
                  );

            await _databaseService.updateProduct(productToUpdate);

            await _databaseService.adjustStock(
              productModel.id!,
              item.quantity,
              'purchase_update',
              reference: 'Purchase Invoice Update: ${order.orderNumber}',
            );
          }
        }
      }

      // 9) Update supplier balance with net change (new total - old total)
      final latestSupplier =
          await _databaseService.getSupplierById(order.supplierId);
      if (latestSupplier != null) {
        final supplierModel = SupplierModel.fromSupplier(latestSupplier);
        final double delta = order.total - oldTotal;
        if (delta != 0) {
          final updatedSupplier = supplierModel.copyWith(
            currentBalance: supplierModel.currentBalance + delta,
            updatedAt: DateTime.now(),
          );
          await _databaseService.updateSupplier(updatedSupplier.toSupplier());
        }
      }

      // Invalidate product provider to refresh stock levels
      _ref.invalidate(productsProvider);

      // Get product IDs for refresh
      final productIds = items.map((item) => item.productId).toList();

      // Refresh all related providers (supplier balance, reports, etc.)
      AutoRefreshService.refreshAfterPurchaseOperation(
        _ref,
        supplierId: order.supplierId,
        productIds: productIds,
      );

      await _loadPurchaseOrders();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deletePurchaseOrder(int id) async {
    try {
      // Get order details before deletion to know supplier and products
      final existingOrder = await _databaseService.getPurchaseOrderById(id);
      final existingItems = existingOrder != null
          ? await _databaseService.getPurchaseOrderItems(id)
          : <db.PurchaseOrderItem>[];

      // Delete the order
      await _databaseService.deletePurchaseOrder(id);

      // Reverse stock changes for deleted items
      for (final item in existingItems) {
        await _databaseService.adjustStock(
          item.productId,
          -item.quantity,
          'purchase_delete_reversal',
          reference: 'Purchase Invoice Deletion: ${existingOrder?.orderNumber ?? 'N/A'}',
        );
      }

      // Update supplier balance (subtract the order total)
      if (existingOrder != null) {
        final supplier = await _databaseService.getSupplierById(existingOrder.supplierId);
        if (supplier != null) {
          final supplierModel = SupplierModel.fromSupplier(supplier);
          final updatedSupplier = supplierModel.copyWith(
            currentBalance: supplierModel.currentBalance - existingOrder.total,
            updatedAt: DateTime.now(),
          );
          await _databaseService.updateSupplier(updatedSupplier.toSupplier());
        }

        // Get product IDs for refresh
        final productIds = existingItems.map((item) => item.productId).toList();

        // Refresh all related providers
        AutoRefreshService.refreshAfterPurchaseOperation(
          _ref,
          supplierId: existingOrder.supplierId,
          productIds: productIds,
        );
      }

      await _loadPurchaseOrders();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  void refresh() {
    _loadPurchaseOrders();
  }
}

final purchaseOrderNotifierProvider = StateNotifierProvider<
    PurchaseOrderNotifier, AsyncValue<List<PurchaseOrderModel>>>((ref) {
  return PurchaseOrderNotifier(ref.watch(databaseServiceProvider), ref);
});

// Providers for filtered views
// Watch notifier but never invalidate this provider directly
// Only invalidate purchaseOrderNotifierProvider to avoid circular dependency
final purchaseOrdersProvider =
    Provider.autoDispose<AsyncValue<List<PurchaseOrderModel>>>((ref) {
  return ref.watch(purchaseOrderNotifierProvider);
});

final purchaseOrdersByStatusProvider =
    FutureProvider.family<List<PurchaseOrderModel>, String>(
        (ref, status) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final orders = await databaseService.getPurchaseOrdersByStatus(status);

  // Enrich with supplier data
  final List<PurchaseOrderModel> enrichedOrders = [];
  for (final order in orders) {
    final supplier = await databaseService.getSupplierById(order.supplierId);
    final items = await databaseService.getPurchaseOrderItems(order.id);

    // Enrich items with product data
    final List<PurchaseOrderItemModel> enrichedItems = [];
    for (final item in items) {
      final productModel = await databaseService.getProductById(item.productId);
      enrichedItems.add(PurchaseOrderItemModel.fromPurchaseOrderItem(
        item,
        product: productModel,
      ));
    }

    enrichedOrders.add(PurchaseOrderModel.fromPurchaseOrder(
      order,
      supplier: supplier != null ? SupplierModel.fromSupplier(supplier) : null,
      items: enrichedItems,
    ));
  }

  return enrichedOrders;
});

final purchaseOrderByIdProvider =
    FutureProvider.family<PurchaseOrderModel?, int>((ref, id) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final order = await databaseService.getPurchaseOrderById(id);
  if (order == null) return null;

  final supplier = await databaseService.getSupplierById(order.supplierId);
  final items = await databaseService.getPurchaseOrderItems(order.id);

  // Enrich items with product data
  final List<PurchaseOrderItemModel> enrichedItems = [];
  for (final item in items) {
    final productModel = await databaseService.getProductById(item.productId);
    enrichedItems.add(PurchaseOrderItemModel.fromPurchaseOrderItem(
      item,
      product: productModel,
    ));
  }

  return PurchaseOrderModel.fromPurchaseOrder(
    order,
    supplier: supplier != null ? SupplierModel.fromSupplier(supplier) : null,
    items: enrichedItems,
  );
});

final purchaseOrdersBySupplierProvider =
    FutureProvider.family<List<PurchaseOrderModel>, int>(
        (ref, supplierId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final orders = await databaseService.getPurchaseOrdersBySupplier(supplierId);

  // Enrich with supplier and items data
  final List<PurchaseOrderModel> enrichedOrders = [];
  for (final order in orders) {
    final supplier = await databaseService.getSupplierById(order.supplierId);
    final items = await databaseService.getPurchaseOrderItems(order.id);

    // Enrich items with product data
    final List<PurchaseOrderItemModel> enrichedItems = [];
    for (final item in items) {
      final productModel = await databaseService.getProductById(item.productId);
      enrichedItems.add(PurchaseOrderItemModel.fromPurchaseOrderItem(
        item,
        product: productModel,
      ));
    }

    enrichedOrders.add(PurchaseOrderModel.fromPurchaseOrder(
      order,
      supplier: supplier != null ? SupplierModel.fromSupplier(supplier) : null,
      items: enrichedItems,
    ));
  }

  return enrichedOrders;
});
