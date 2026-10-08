import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../models/product.dart';
import '../models/product_bundle.dart';
import '../models/product_ingredient.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/payment.dart';
import '../models/category.dart';
import '../models/employee.dart';
import '../models/employee_commission.dart';
import '../models/staff_performance.dart';
import '../models/supplier_payment.dart';
import '../models/supplier.dart';
import '../models/bank.dart';
import '../models/bank_payment.dart';
import '../models/sales_summary.dart' as models;

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

class DatabaseService {
  final AppDatabase _database;

  DatabaseService(this._database);

  AppDatabase get db => _database;

  // Product operations
  Future<List<ProductModel>> getAllProducts(
      {bool includeInactive = false}) async {
    final products = await _database.getAllProducts();
    final productModels =
        products.map((p) => ProductModel.fromProduct(p)).toList();

    // Filter out inactive products by default (unless explicitly requested)
    if (!includeInactive) {
      return productModels.where((p) => p.isActive).toList();
    }

    return productModels;
  }

  Future<ProductModel?> getProductById(int id) async {
    final product = await _database.getProductById(id);
    return product != null ? ProductModel.fromProduct(product) : null;
  }

  Future<ProductModel?> getProductByBarcode(String barcode) async {
    final product = await _database.getProductByBarcode(barcode);
    return product != null ? ProductModel.fromProduct(product) : null;
  }

  Future<List<ProductModel>> getProductsByBarcode(String barcode) async {
    final products = await _database.getProductsByBarcode(barcode);
    return products.map((p) => ProductModel.fromProduct(p)).toList();
  }

  Future<ProductModel?> getProductByName(String name) async {
    final product = await _database.getProductByName(name);
    return product != null ? ProductModel.fromProduct(product) : null;
  }

  Future<List<ProductModel>> getProductsByCategory(String category) async {
    final products = await _database.getProductsByCategory(category);
    return products.map((p) => ProductModel.fromProduct(p)).toList();
  }

  Future<List<ProductModel>> getLowStockProducts(double threshold) async {
    final products = await _database.getLowStockProducts(threshold);
    return products.map((p) => ProductModel.fromProduct(p)).toList();
  }

  Future<int> insertProduct(ProductModel product) async {
    return await _database.insertProduct(product.toCompanion());
  }

  /// Creates a product and its opening-stock audit entry atomically.
  Future<int> insertProductWithOpeningStock(
    ProductModel product, {
    int? employeeId,
  }) async {
    final openingStock = product.stock;
    if (!openingStock.isFinite || openingStock < 0) {
      throw ArgumentError('Opening stock must be a non-negative number.');
    }

    return _database.transaction(() async {
      final productId = await _database.insertProduct(product.toCompanion());
      if (openingStock > 0) {
        final now = DateTime.now();
        await _database.insertStockAdjustment(
          StockAdjustmentsCompanion(
            productId: Value(productId),
            quantity: Value(openingStock),
            reason: const Value('Opening Stock'),
            reference: const Value('Entered during product creation'),
            date: Value(now.toIso8601String()),
            employeeId: Value(employeeId),
            createdAt: Value(now.toIso8601String()),
          ),
        );
      }
      return productId;
    });
  }

  Future<bool> updateProduct(ProductModel product) async {
    return await _database.updateProduct(product.toProduct());
  }

  Future<int> deleteProduct(int id, {bool forceDelete = false}) async {
    try {
      // Check if product has been used in sales
      bool usedInSales = false;
      final allSales = await getAllSales();
      for (final sale in allSales) {
        for (final item in sale.items) {
          if (item.productId == id) {
            usedInSales = true;
            break;
          }
        }
        if (usedInSales) break;
      }

      // If product is used in sales, do soft delete (mark as inactive) instead of hard delete
      // This preserves historical data while allowing the product to be "deleted"
      if (usedInSales) {
        // Get the product first
        final product = await getProductById(id);
        if (product == null) {
          throw Exception('Product not found');
        }

        // Mark as inactive (soft delete) instead of deleting
        final updatedProduct = product.copyWith(
          isActive: false,
          updatedAt: DateTime.now(),
        );
        await updateProduct(updatedProduct);

        // Return success for soft delete
        return 1;
      }

      // Delete related records that don't affect historical data
      // 1. Delete product ingredients (where this product is the menu item)
      await _database.deleteIngredientsByProductId(id);

      // 2. Delete product IMEIs
      final imeis = await (_database.select(_database.productIMEIs)
            ..where((tbl) => tbl.productId.equals(id)))
          .get();
      for (final imei in imeis) {
        await (_database.delete(_database.productIMEIs)
              ..where((tbl) => tbl.id.equals(imei.id)))
            .go();
      }

      // 3. Delete product bundle items (where this product is included in bundles)
      final bundleItems = await (_database.select(_database.productBundleItems)
            ..where((tbl) => tbl.productId.equals(id)))
          .get();
      for (final item in bundleItems) {
        await (_database.delete(_database.productBundleItems)
              ..where((tbl) => tbl.id.equals(item.id)))
            .go();
      }

      // 4. Delete stock adjustments for this product
      final stockAdjustments = await _database.getStockAdjustmentsByProduct(id);
      for (final adjustment in stockAdjustments) {
        await _database.deleteStockAdjustment(adjustment.id);
      }

      // 5. Delete purchase order items that reference this product
      // Get all purchase orders and check their items
      final allPurchaseOrders = await getAllPurchaseOrders();
      for (final order in allPurchaseOrders) {
        if (order.id != null) {
          final items = await getPurchaseOrderItems(order.id!);
          for (final item in items) {
            if (item.productId == id) {
              await _database.deletePurchaseOrderItem(item.id);
            }
          }
        }
      }

      // 6. Now delete the product itself
      // (We've already checked for sales usage above, so if we reach here, deletion is safe)
      return await _database.deleteProduct(id);
    } catch (e) {
      // Re-throw with more context if it's our custom exception
      if (e.toString().contains('Cannot delete product')) {
        rethrow;
      }
      // If it's a foreign key constraint error, provide a better message
      if (e.toString().contains('FOREIGN KEY constraint') ||
          e.toString().contains('787') ||
          e.toString().contains('constraint failed')) {
        if (forceDelete) {
          throw Exception(
              'Cannot force delete product. It is referenced in sale items which are historical records that cannot be modified. '
              'To maintain data integrity, products used in sales cannot be deleted even with admin privileges. '
              'Consider archiving or marking the product as inactive instead.');
        } else {
          throw Exception(
              'Cannot delete product. It is still referenced in sales, purchase orders, or other records. '
              'Products that have been sold cannot be deleted to maintain historical records.');
        }
      }
      rethrow;
    }
  }

  // Product Bundle operations
  Future<List<ProductBundleModel>> getAllBundles() async {
    final bundles = await _database.getAllBundles();
    final result = <ProductBundleModel>[];
    for (final bundle in bundles) {
      final items = await _database.getBundleItemsByBundleId(bundle.id);
      final bundleItems = <ProductBundleItemModel>[];
      for (final item in items) {
        final product = await _database.getProductById(item.productId);
        if (product != null) {
          bundleItems.add(ProductBundleItemModel.fromBundleItem(
            item,
            ProductModel.fromProduct(product),
          ));
        }
      }
      result.add(ProductBundleModel.fromBundle(bundle, items: bundleItems));
    }
    return result;
  }

  Future<ProductBundleModel?> getBundleById(int id) async {
    final bundle = await _database.getBundleById(id);
    if (bundle == null) return null;
    final items = await _database.getBundleItemsByBundleId(bundle.id);
    final bundleItems = <ProductBundleItemModel>[];
    for (final item in items) {
      final product = await _database.getProductById(item.productId);
      if (product != null) {
        bundleItems.add(ProductBundleItemModel.fromBundleItem(
          item,
          ProductModel.fromProduct(product),
        ));
      }
    }
    return ProductBundleModel.fromBundle(bundle, items: bundleItems);
  }

  Future<List<ProductBundleModel>> getBundlesByCategory(String category) async {
    final bundles = await _database.getBundlesByCategory(category);
    final result = <ProductBundleModel>[];
    for (final bundle in bundles) {
      final items = await _database.getBundleItemsByBundleId(bundle.id);
      final bundleItems = <ProductBundleItemModel>[];
      for (final item in items) {
        final product = await _database.getProductById(item.productId);
        if (product != null) {
          bundleItems.add(ProductBundleItemModel.fromBundleItem(
            item,
            ProductModel.fromProduct(product),
          ));
        }
      }
      result.add(ProductBundleModel.fromBundle(bundle, items: bundleItems));
    }
    return result;
  }

  Future<int> insertBundle(ProductBundleModel bundle) async {
    final bundleId = await _database.insertBundle(bundle.toCompanion());
    // Insert bundle items
    for (final item in bundle.items) {
      await _database.insertBundleItem(
        ProductBundleItemsCompanion(
          bundleId: Value(bundleId),
          productId: Value(item.product.id!),
          quantity: Value(item.quantity),
          price: Value(item.price),
          createdAt: Value(DateTime.now().toIso8601String()),
        ),
      );
    }
    return bundleId;
  }

  Future<bool> updateBundle(ProductBundleModel bundle) async {
    if (bundle.id == null) return false;
    // Delete existing items
    await _database.deleteBundleItemsByBundleId(bundle.id!);
    // Update bundle
    final success = await _database.updateBundle(
      ProductBundle(
        id: bundle.id!,
        name: bundle.name,
        description: bundle.description,
        price: bundle.price,
        cost: bundle.cost,
        category: bundle.category,
        isActive: bundle.isActive,
        imagePath: bundle.imagePath,
        createdAt: bundle.createdAt.toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ),
    );
    // Insert new items
    for (final item in bundle.items) {
      await _database.insertBundleItem(
        ProductBundleItemsCompanion(
          bundleId: Value(bundle.id!),
          productId: Value(item.product.id!),
          quantity: Value(item.quantity),
          price: Value(item.price),
          createdAt: Value(DateTime.now().toIso8601String()),
        ),
      );
    }
    return success;
  }

  Future<int> deleteBundle(int id) async {
    // Delete bundle items first
    await _database.deleteBundleItemsByBundleId(id);
    return await _database.deleteBundle(id);
  }

  // Product Ingredient operations
  Future<List<ProductIngredientModel>> getIngredientsByProductId(
      int productId) async {
    final ingredients = await _database.getIngredientsByProductId(productId);
    final result = <ProductIngredientModel>[];
    for (final ingredient in ingredients) {
      final product =
          await _database.getProductById(ingredient.ingredientProductId);
      result.add(ProductIngredientModel.fromIngredient(
        ingredient,
        ingredientProduct:
            product != null ? ProductModel.fromProduct(product) : null,
      ));
    }
    return result;
  }

  Future<ProductIngredientModel?> getIngredientById(int id) async {
    final ingredient = await _database.getIngredientById(id);
    if (ingredient == null) return null;
    final product =
        await _database.getProductById(ingredient.ingredientProductId);
    return ProductIngredientModel.fromIngredient(
      ingredient,
      ingredientProduct:
          product != null ? ProductModel.fromProduct(product) : null,
    );
  }

  Future<int> insertIngredient(ProductIngredientModel ingredient) async {
    return await _database.insertIngredient(ingredient.toCompanion());
  }

  Future<bool> updateIngredient(ProductIngredientModel ingredient) async {
    if (ingredient.id == null) return false;
    final dbIngredient = await _database.getIngredientById(ingredient.id!);
    if (dbIngredient == null) return false;

    final updated = ProductIngredient(
      id: ingredient.id!,
      productId: ingredient.productId,
      ingredientProductId: ingredient.ingredientProductId,
      quantity: ingredient.quantity,
      unit: ingredient.unit,
      costType: ingredient.costType == IngredientCostType.quantityBased
          ? 'quantity_based'
          : 'fixed_cost',
      fixedCost: ingredient.fixedCost,
      sortOrder: ingredient.sortOrder,
      createdAt: dbIngredient.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
    return await _database.updateIngredient(updated);
  }

  Future<int> deleteIngredient(int id) async {
    return await _database.deleteIngredient(id);
  }

  Future<int> deleteIngredientsByProductId(int productId) async {
    return await _database.deleteIngredientsByProductId(productId);
  }

  /// Calculate total cost of a product from its ingredients
  Future<double> calculateProductCostFromIngredients(int productId) async {
    final ingredients = await getIngredientsByProductId(productId);
    double totalCost = 0.0;
    for (final ingredient in ingredients) {
      totalCost += ingredient.calculateCost();
    }
    return totalCost;
  }

  Future<List<ProductLedgerEntry>> getProductLedgerEntries(
      int productId) async {
    double _readDouble(QueryRow row, String column) {
      final double? doubleValue = row.read<double?>(column);
      if (doubleValue != null) return doubleValue;

      final int? intValue = row.read<int?>(column);
      if (intValue != null) return intValue.toDouble();

      final String? textValue = row.read<String?>(column);
      if (textValue != null) return double.tryParse(textValue) ?? 0.0;

      return 0.0;
    }

    String _readString(QueryRow row, String column) {
      final String? value = row.read<String?>(column);
      return value ?? '';
    }

    DateTime _readDate(QueryRow row, String column) {
      final raw = row.read<String?>(column);
      return DateTime.tryParse(raw ?? '') ?? DateTime.now();
    }

    final entries = <ProductLedgerEntry>[];

    final saleRows = await _database.customSelect(
      '''
      SELECT 
        si.id AS entry_id,
        s.id AS reference_id,
        s.date AS entry_date,
        si.qty AS quantity,
        si.price AS rate,
        si.subtotal AS total,
        c.name AS counterparty_name,
        s.notes AS notes
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      LEFT JOIN customers c ON c.id = s.customer_id
      WHERE si.product_id = ?
      ''',
      variables: [Variable<int>(productId)],
      readsFrom: {_database.saleItems, _database.sales, _database.customers},
    ).get();

    for (final row in saleRows) {
      final referenceId = row.read<int?>('reference_id') ?? 0;
      final counterparty = _readString(row, 'counterparty_name');
      entries.add(
        ProductLedgerEntry(
          entryId: row.read<int?>('entry_id') ?? referenceId,
          type: ProductLedgerEntryType.sale,
          referenceId: referenceId,
          invoiceNumber: 'SALE-${referenceId.toString().padLeft(5, '0')}',
          date: _readDate(row, 'entry_date'),
          quantity: _readDouble(row, 'quantity'),
          rate: _readDouble(row, 'rate'),
          total: _readDouble(row, 'total'),
          counterpartyName: counterparty.isEmpty ? null : counterparty,
          notes: row.read<String?>('notes'),
        ),
      );
    }

    final purchaseRows = await _database.customSelect(
      '''
      SELECT 
        poi.id AS entry_id,
        po.id AS reference_id,
        po.order_number AS invoice_no,
        po.order_date AS entry_date,
        poi.quantity AS quantity,
        poi.unit_cost AS rate,
        poi.total AS total,
        sup.name AS counterparty_name,
        po.notes AS notes
      FROM purchase_order_items poi
      INNER JOIN purchase_orders po ON po.id = poi.purchase_order_id
      LEFT JOIN suppliers sup ON sup.id = po.supplier_id
      WHERE poi.product_id = ?
      ''',
      variables: [Variable<int>(productId)],
      readsFrom: {
        _database.purchaseOrderItems,
        _database.purchaseOrders,
        _database.suppliers
      },
    ).get();

    for (final row in purchaseRows) {
      final referenceId = row.read<int?>('reference_id') ?? 0;
      final invoiceNo = row.read<String?>('invoice_no');
      final counterparty = _readString(row, 'counterparty_name');
      entries.add(
        ProductLedgerEntry(
          entryId: row.read<int?>('entry_id') ?? referenceId,
          type: ProductLedgerEntryType.purchase,
          referenceId: referenceId,
          invoiceNumber: invoiceNo?.isNotEmpty == true
              ? invoiceNo!
              : 'PO-${referenceId.toString().padLeft(5, '0')}',
          date: _readDate(row, 'entry_date'),
          quantity: _readDouble(row, 'quantity'),
          rate: _readDouble(row, 'rate'),
          total: _readDouble(row, 'total'),
          counterpartyName: counterparty.isEmpty ? null : counterparty,
          notes: row.read<String?>('notes'),
        ),
      );
    }

    // Add stock adjustments - include all manual adjustments, not from POS sales
    // Include stock movements from:
    //   - Stock Movement page (reason == 'Stock Movement')
    //   - Settings page making stock zero (reason == 'Stock set to zero by Stock Manager')
    //   - Other manual adjustments
    // Exclude stock movements with reason == 'Sale' (from POS sales - these are shown as sale entries)
    final stockAdjustmentRows = await _database.customSelect(
      '''
      SELECT 
        sa.id AS entry_id,
        sa.id AS reference_id,
        sa.date AS entry_date,
        sa.quantity AS quantity,
        p.cost AS rate,
        (sa.quantity * p.cost) AS total,
        sa.reason AS reason,
        sa.reference AS reference
      FROM stock_adjustments sa
      INNER JOIN products p ON p.id = sa.product_id
      WHERE sa.product_id = ? AND sa.reason != 'Sale'
      ''',
      variables: [Variable<int>(productId)],
      readsFrom: {_database.stockAdjustments, _database.products},
    ).get();

    for (final row in stockAdjustmentRows) {
      final referenceId = row.read<int?>('reference_id') ?? 0;
      final reason = _readString(row, 'reason');
      final reference = row.read<String?>('reference');
      final quantity = _readDouble(row, 'quantity');
      final rate = _readDouble(row, 'rate');

      entries.add(
        ProductLedgerEntry(
          entryId: row.read<int?>('entry_id') ?? referenceId,
          type: ProductLedgerEntryType.stockAdjustment,
          referenceId: referenceId,
          invoiceNumber: reference?.isNotEmpty == true
              ? reference!
              : 'ADJ-${referenceId.toString().padLeft(5, '0')}',
          date: _readDate(row, 'entry_date'),
          quantity: quantity,
          rate: rate,
          total: _readDouble(row, 'total'),
          counterpartyName: null,
          notes: reason.isNotEmpty ? reason : null,
        ),
      );
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  // Customer operations
  Future<List<CustomerModel>> getAllCustomers() async {
    final customers = await _database.getAllCustomers();
    return customers.map((c) => CustomerModel.fromCustomer(c)).toList();
  }

  Future<CustomerModel?> getCustomerById(int id) async {
    try {
      final customer = await _database.getCustomerById(id);
      if (customer != null) {
        final customerModel = CustomerModel.fromCustomer(customer);
        return customerModel;
      } else {
        return null;
      }
    } catch (e) {
      print('Database Service: Error getting customer by ID: $e');
      rethrow;
    }
  }

  Future<CustomerModel?> getCustomerByPhone(String phone) async {
    final customer = await _database.getCustomerByPhone(phone);
    return customer != null ? CustomerModel.fromCustomer(customer) : null;
  }

  Future<List<CustomerModel>> getCustomersWithDue() async {
    final customers = await _database.getCustomersWithDue();
    return customers.map((c) => CustomerModel.fromCustomer(c)).toList();
  }

  Future<int> insertCustomer(CustomerModel customer) async {
    return await _database.insertCustomer(customer.toCompanion());
  }

  Future<bool> updateCustomer(CustomerModel customer) async {
    return await _database.updateCustomer(customer.toCustomer());
  }

  Future<int> deleteCustomer(int id) async {
    try {
      // Get all sales for this customer
      final sales = await getSalesByCustomer(id);

      // Delete all sales for this customer (restore stock and update balances)
      for (final sale in sales) {
        if (sale.id != null) {
          // Get sale items before deleting to restore stock
          final saleItems = await _database.getSaleItemsBySaleId(sale.id!);

          // Restore stock for each item (stock was reduced when sale was created)
          for (final item in saleItems) {
            await adjustStock(
              item.productId,
              item.qty, // Positive quantity to restore stock
              'Sale Deletion - Stock Restoration',
              reference: 'Customer Deletion: Sale #${sale.id}',
            );
          }

          // Delete sale items first
          await _database.deleteSaleItemsBySaleId(sale.id!);

          // Delete the sale (this will also recalculate customer balance, but customer will be deleted anyway)
          await _database.deleteSale(sale.id!);
        }
      }

      // Recalculate customer balance one final time after all sales are deleted
      // This ensures balance is zero before we delete payments
      final customer = await getCustomerById(id);
      if (customer != null) {
        final newBalance = await recalculateCustomerBalance(id);
        final updatedCustomer = customer.copyWith(
          totalDue: newBalance,
          updatedAt: DateTime.now(),
        );
        await updateCustomer(updatedCustomer);
      }

      // Delete all payments for this customer
      final payments = await getPaymentsByCustomer(id);
      for (final payment in payments) {
        if (payment.id != null) {
          await deletePayment(payment.id!);
        }
      }

      // Now delete the customer
      final result = await _database.deleteCustomer(id);
      if (result <= 0) {
        throw Exception('Failed to delete customer. Customer may not exist.');
      }

      print(
          'Database Service: Successfully deleted customer $id along with ${sales.length} sale(s) and ${payments.length} payment(s)');
      return result;
    } catch (e) {
      print('Database Service: Error deleting customer $id: $e');
      rethrow;
    }
  }

  // Helper method to build complete sale model with items and customer
  Future<SaleModel> _buildCompleteSaleModel(Sale sale) async {
    // Get sale items for the sale
    final items = await _database.getSaleItemsBySaleId(sale.id);
    final saleItems = <SaleItemModel>[];

    for (final item in items) {
      final product = await getProductById(item.productId);
      saleItems.add(SaleItemModel.fromSaleItem(item, product: product));
    }

    // Get customer if exists
    CustomerModel? customer;
    if (sale.customerId != null) {
      customer = await getCustomerById(sale.customerId!);
    }

    // Get cashier if exists
    EmployeeModel? cashier;
    if (sale.cashierId != null) {
      cashier = await getEmployeeById(sale.cashierId!);
    }

    return SaleModel.fromSale(sale,
        items: saleItems, customer: customer, cashier: cashier);
  }

  // Sale operations
  Future<List<SaleModel>> getAllSales() async {
    final sales = await _database.getAllSales();
    final saleModels = <SaleModel>[];

    for (final sale in sales) {
      saleModels.add(await _buildCompleteSaleModel(sale));
    }

    return saleModels;
  }

  Future<SaleModel?> getSaleById(int id) async {
    final sale = await _database.getSaleById(id);
    if (sale == null) return null;

    return await _buildCompleteSaleModel(sale);
  }

  Future<List<SaleModel>> getSalesByDateRange(
      DateTime start, DateTime end) async {
    final sales = await _database.getSalesByDateRange(start, end);
    final saleModels = <SaleModel>[];

    for (final sale in sales) {
      saleModels.add(await _buildCompleteSaleModel(sale));
    }

    return saleModels;
  }

  // Get item-wise sales report data
  Future<List<models.ItemWiseSalesData>> getItemWiseSalesReport(
      int productId, DateTime startDate, DateTime endDate) async {
    final sales = await _database.getSalesByDateRange(startDate, endDate);
    final reportData = <models.ItemWiseSalesData>[];

    // Add sales data
    for (final sale in sales) {
      final saleModel = await _buildCompleteSaleModel(sale);

      // Find items matching the productId
      for (final item in saleModel.items) {
        if (item.productId == productId) {
          final product = item.product;
          if (product != null) {
            // Calculate profit: (sale price - cost price) * quantity
            final profit = (item.price - product.cost) * item.qty;

            reportData.add(models.ItemWiseSalesData(
              invoiceNo: saleModel.id ?? 0,
              date: saleModel.date,
              itemName: product.name,
              saleQty: item.qty,
              purchasePrice: product.cost,
              salePrice: item.price,
              totalAmount: item.subtotal,
              profit: profit,
              isStockMovement: false,
              stockIncreaseQty: 0,
              stockDecreaseQty: 0,
              movementReason: null,
              reference: 'Sale #${saleModel.id ?? '-'}',
            ));
          }
        }
      }
    }

    // Add stock movements from stock movement page (not from POS sales)
    // Only include movements with reason == 'Stock Movement' (from stock movement page)
    // Exclude movements with reason == 'Sale' (from POS sales)
    final allStockMovements =
        await getStockMovementsByDateRange(startDate, endDate);

    for (final movement in allStockMovements) {
      // Only include stock movements from stock movement page
      // Exclude stock movements created by POS sales (reason == 'Sale')
      if (movement.productId == productId &&
          movement.reason.trim() == 'Stock Movement') {
        final product = await getProductById(movement.productId);
        if (product != null) {
          final movementDate = DateTime.parse(movement.date);
          final quantity = movement.quantity;
          final isStockIn = quantity > 0;

          // Calculate values for stock movements
          // For stock movements, saleQty is the absolute quantity (positive or negative)
          // Stock movements don't have sale price or profit, so we use purchase price
          final purchasePrice = product.cost;

          reportData.add(models.ItemWiseSalesData(
            invoiceNo: movement.id ?? 0,
            date: movementDate,
            itemName: product.name,
            saleQty:
                quantity, // Can be positive (stock in) or negative (stock out)
            purchasePrice: purchasePrice,
            salePrice: purchasePrice, // For stock movements, use purchase price
            totalAmount:
                (purchasePrice * quantity.abs()), // Absolute value for total
            profit: 0, // Stock movements don't have profit
            isStockMovement: true,
            stockIncreaseQty: isStockIn ? quantity.abs() : 0,
            stockDecreaseQty: !isStockIn ? quantity.abs() : 0,
            movementReason: movement.reason,
            reference:
                movement.reference ?? 'Stock Movement #${movement.id ?? '-'}',
          ));
        }
      }
    }

    // Sort by date descending
    reportData.sort((a, b) => b.date.compareTo(a.date));

    return reportData;
  }

  Future<List<SaleModel>> getSalesByCustomer(int customerId) async {
    try {
      final sales = await _database.getSalesByCustomer(customerId);
      final saleModels = <SaleModel>[];

      for (final sale in sales) {
        try {
          final saleModel = await _buildCompleteSaleModel(sale);
          saleModels.add(saleModel);
        } catch (e) {
          print(
              'Database Service: Error building sale model for sale ${sale.id}: $e');
        }
      }

      return saleModels;
    } catch (e) {
      print('Database Service: Error getting sales by customer: $e');
      rethrow;
    }
  }

  Future<List<SaleModel>> getUnpaidSales() async {
    final sales = await _database.getUnpaidSales();
    final saleModels = <SaleModel>[];

    for (final sale in sales) {
      saleModels.add(await _buildCompleteSaleModel(sale));
    }

    return saleModels;
  }

  Future<int> insertSale(SaleModel sale) async {
    final saleId = await _database.insertSale(sale.toCompanion());

    // Insert sale items
    for (final item in sale.items) {
      final itemWithSaleId = item.copyWith(saleId: saleId);
      await _database.insertSaleItem(itemWithSaleId.toCompanion());

      // Save IMEI to ProductIMEIs table for mobile phones
      if (item.imei != null &&
          item.imei!.isNotEmpty &&
          item.productId != null) {
        try {
          final product = await getProductById(item.productId);
          // Only save IMEI if it's a phone product (has mobile shop data or category is smartphones)
          final isPhoneProduct = product != null &&
              (product.category.toLowerCase() == 'smartphones' ||
                  ((product.brand?.trim().isNotEmpty ?? false) &&
                      (product.modelName?.trim().isNotEmpty ?? false)));

          if (isPhoneProduct) {
            await _database.into(_database.productIMEIs).insert(
                  ProductIMEIsCompanion.insert(
                    productId: item.productId!,
                    imei: item.imei!,
                    saleId: Value(saleId),
                    customerId: Value(sale.customerId),
                    status: const Value('sold'),
                    purchaseDate: const Value(null),
                    saleDate: Value(sale.date.toIso8601String()),
                    notes: const Value(null),
                    createdAt: DateTime.now().toIso8601String(),
                    updatedAt: DateTime.now().toIso8601String(),
                  ),
                );
          }
        } catch (e) {
          // Log error but don't fail the sale
          print(
              'Error saving IMEI ${item.imei} for product ${item.productId}: $e');
        }
      }
    }

    // Zero-tolerance: Recalculate customer's total due for accuracy
    if (sale.customerId != null) {
      final customer = await getCustomerById(sale.customerId!);
      if (customer != null) {
        final newBalance = await recalculateCustomerBalance(sale.customerId!);
        final updatedCustomer = customer.copyWith(
          totalDue: newBalance,
          updatedAt: DateTime.now(),
        );
        await updateCustomer(updatedCustomer);
      }
    }

    return saleId;
  }

  /// Persists a checkout and its inventory movements as one atomic operation.
  ///
  /// This is the only method interactive checkout flows should use. If any
  /// sale item or stock update fails, Drift rolls the complete transaction
  /// back so reports and physical stock cannot diverge.
  Future<int> insertSaleAndAdjustStock(SaleModel sale) async {
    if (sale.items.isEmpty) {
      throw ArgumentError('A sale must contain at least one item.');
    }
    if (!sale.total.isFinite ||
        !sale.discount.isFinite ||
        !sale.paid.isFinite ||
        !sale.due.isFinite) {
      throw ArgumentError('Sale amounts must be finite numbers.');
    }
    if (sale.total < 0 || sale.discount < 0 || sale.paid < 0 || sale.due < 0) {
      throw ArgumentError('Sale amounts cannot be negative.');
    }

    final quantitiesByProduct = <int, double>{};
    for (final item in sale.items) {
      if (!item.qty.isFinite || item.qty <= 0) {
        throw ArgumentError(
            'Invalid quantity for product ${item.productId}: ${item.qty}');
      }
      if (!item.price.isFinite || item.price < 0 || !item.subtotal.isFinite) {
        throw ArgumentError('Invalid amount for product ${item.productId}.');
      }
      quantitiesByProduct[item.productId] =
          (quantitiesByProduct[item.productId] ?? 0) + item.qty;
    }

    return _database.transaction(() async {
      // Recheck stock inside the write transaction to prevent two tills from
      // both selling the same final units based on stale UI state.
      for (final entry in quantitiesByProduct.entries) {
        final product = await getProductById(entry.key);
        if (product == null) {
          throw StateError('Product ${entry.key} no longer exists.');
        }
        if (product.stock + 0.000001 < entry.value) {
          throw StateError(
              'Insufficient stock for ${product.name}. Available: ${product.stock}, required: ${entry.value}.');
        }
      }

      final saleId = await insertSale(sale);

      for (final entry in quantitiesByProduct.entries) {
        await adjustStock(
          entry.key,
          -entry.value,
          'Sale - POS Transaction',
          reference: 'Sale ID: $saleId',
          employeeId: sale.cashierId,
        );
      }

      return saleId;
    });
  }

  Future<bool> updateSale(SaleModel sale) async {
    // Capture original item quantities for stock reconciliation
    final existingSaleItems = await _database.getSaleItemsBySaleId(sale.id!);
    final Map<int, double> originalQuantities = {};
    for (final item in existingSaleItems) {
      originalQuantities[item.productId] =
          (originalQuantities[item.productId] ?? 0) + item.qty;
    }

    // Delete existing sale items
    await _database.deleteSaleItemsBySaleId(sale.id!);

    // Update the sale
    await _database.updateSale(sale.toSale());

    // Insert updated sale items
    final Map<int, double> updatedQuantities = {};
    for (final item in sale.items) {
      final itemWithSaleId = item.copyWith(saleId: sale.id!);
      await _database.insertSaleItem(itemWithSaleId.toCompanion());
      updatedQuantities[item.productId] =
          (updatedQuantities[item.productId] ?? 0) + item.qty;
    }

    // Reconcile stock levels based on quantity differences
    final productIds = {
      ...originalQuantities.keys,
      ...updatedQuantities.keys,
    };
    for (final productId in productIds) {
      final oldQty = originalQuantities[productId] ?? 0;
      final newQty = updatedQuantities[productId] ?? 0;
      final delta = oldQty - newQty;

      if (delta.abs() > 0.0001) {
        await adjustStock(
          productId,
          delta,
          'Sale Edit Adjustment',
          reference: 'Sale ID: ${sale.id}',
        );
      }
    }

    // Zero-tolerance: Recalculate customer's total due for accuracy after edit
    if (sale.customerId != null) {
      final customer = await getCustomerById(sale.customerId!);
      if (customer != null) {
        final newBalance = await recalculateCustomerBalance(sale.customerId!);
        final updatedCustomer = customer.copyWith(
          totalDue: newBalance,
          updatedAt: DateTime.now(),
        );
        await updateCustomer(updatedCustomer);
      }
    }

    return true;
  }

  Future<int> deleteSale(int id) async {
    try {
      final sale = await _database.getSaleById(id);
      final customerId = sale?.customerId;

      final saleItems = await _database.getSaleItemsBySaleId(id);
      final Map<int, double> qtyByProduct = {};
      for (final item in saleItems) {
        qtyByProduct[item.productId] =
            (qtyByProduct[item.productId] ?? 0) + item.qty;
      }

      await (_database.delete(_database.productIMEIs)
            ..where((t) => t.saleId.equals(id)))
          .go();

      for (final entry in qtyByProduct.entries) {
        if (entry.value.abs() > 0.0001) {
          try {
            await adjustStock(
              entry.key,
              entry.value,
              'Sale Deletion Reversal',
              reference: 'Sale ID: $id',
            );
          } catch (err) {
            print(
                'Database Service: Error restoring stock for product ${entry.key} after sale delete: $err');
          }
        }
      }

      await _database.deleteSaleItemsBySaleId(id);
      final deleted = await _database.deleteSale(id);

      if (customerId != null) {
        final newBalance = await recalculateCustomerBalance(customerId);
        final customer = await getCustomerById(customerId);
        if (customer != null) {
          await updateCustomer(customer.copyWith(
            totalDue: newBalance,
            updatedAt: DateTime.now(),
          ));
        }
      }

      return deleted;
    } catch (e) {
      print('Database Service: Error deleting sale $id: $e');
      rethrow;
    }
  }

  // Payment operations
  Future<List<PaymentModel>> getPaymentsByCustomer(int customerId) async {
    try {
      final payments = await _database.getPaymentsByCustomer(customerId);
      final paymentModels = <PaymentModel>[];

      for (final payment in payments) {
        try {
          EmployeeModel? processedBy;
          if (payment.processedByEmployeeId != null) {
            processedBy = await getEmployeeById(payment.processedByEmployeeId!);
          }
          CustomerModel? customer;
          try {
            customer = await getCustomerById(payment.customerId);
          } catch (_) {
            customer = null;
          }
          final paymentModel = PaymentModel.fromPayment(
            payment,
            customer: customer,
            processedBy: processedBy,
          );
          paymentModels.add(paymentModel);
        } catch (e) {
          print(
              'Database Service: Error building payment model for payment ${payment.id}: $e');
        }
      }

      return paymentModels;
    } catch (e) {
      print('Database Service: Error getting payments by customer: $e');
      rethrow;
    }
  }

  Future<List<PaymentModel>> getPaymentsByDateRange(
      DateTime start, DateTime end) async {
    final payments = await _database.getPaymentsByDateRange(start, end);
    final models = <PaymentModel>[];
    for (final payment in payments) {
      EmployeeModel? processedBy;
      if (payment.processedByEmployeeId != null) {
        processedBy = await getEmployeeById(payment.processedByEmployeeId!);
      }
      CustomerModel? customer;
      try {
        customer = await getCustomerById(payment.customerId);
      } catch (_) {
        customer = null;
      }
      models.add(
        PaymentModel.fromPayment(
          payment,
          customer: customer,
          processedBy: processedBy,
        ),
      );
    }
    return models;
  }

  Future<int> insertPayment(PaymentModel payment) async {
    // CRITICAL: Validate payment amount before processing
    if (payment.amount == 0 ||
        payment.amount.isNaN ||
        payment.amount.isInfinite) {
      throw Exception(
          'Invalid payment amount: ${payment.amount}. Amount must be non-zero and finite.');
    }

    // CRITICAL: Validate customer exists
    final customer = await getCustomerById(payment.customerId);
    if (customer == null) {
      throw Exception('Customer not found. Cannot process payment.');
    }

    // CRITICAL: Insert payment first
    final paymentId = await _database.insertPayment(payment.toCompanion());

    // CRITICAL: Use recalculation instead of incremental update for safety
    // This ensures balance is always accurate even if there are concurrent operations
    await _updateCustomerBalance(payment.customerId);

    return paymentId;
  }

  Future<bool> updatePayment(PaymentModel payment) async {
    final result = await _database.updatePayment(payment.toPayment());

    // Update customer's total due
    await _updateCustomerBalance(payment.customerId);

    return result;
  }

  Future<int> deletePayment(int paymentId) async {
    try {
      // Get payment details before deletion for balance recalculation
      final payment = await _database.getPaymentById(paymentId);
      final customerId = payment?.customerId;

      if (customerId == null) {
        throw Exception('Payment not found or has no associated customer');
      }

      // CRITICAL: Delete payment first
      final result = await _database.deletePayment(paymentId);

      // CRITICAL: Recalculate the customer's balance based on remaining sales and payments
      await _updateCustomerBalance(customerId);

      return result;
    } catch (e) {
      print('Database Service: Error deleting payment $paymentId: $e');
      rethrow;
    }
  }

  // Settings operations
  Future<String?> getSetting(String key) async {
    return await _database.getSetting(key);
  }

  Future<Map<String, String>> getSettings() async {
    final settings = await _database.getAllSettings();
    final Map<String, String> settingsMap = {};
    for (final setting in settings) {
      settingsMap[setting.key] = setting.value;
    }
    return settingsMap;
  }

  Future<void> setSetting(String key, String value) async {
    await _database.setSetting(key, value);
  }

  // Employee operations
  Future<List<EmployeeModel>> getAllEmployees() async {
    final employees = await _database.getAllEmployees();
    return employees.map((e) => EmployeeModel.fromEmployee(e)).toList();
  }

  Future<EmployeeModel?> getEmployeeById(int id) async {
    final employee = await _database.getEmployeeById(id);
    return employee != null ? EmployeeModel.fromEmployee(employee) : null;
  }

  Future<EmployeeModel?> getEmployeeByUsername(String username) async {
    final employees = await _database.getAllEmployees();
    try {
      final employee = employees.where((e) => e.username == username).first;
      return EmployeeModel.fromEmployee(employee);
    } catch (e) {
      return null;
    }
  }

  Future<int> createEmployee({
    required String name,
    required String username,
    required String phone,
    required String role,
    required String employeeId,
    String? address,
    double? salary,
    double? commissionPercentage,
    String? password,
    String? permissions,
    bool? canLogin,
  }) async {
    final now = DateTime.now().toIso8601String();
    return await _database.insertEmployee(EmployeesCompanion(
      name: Value(name),
      username: Value(username),
      phone: Value(phone),
      address: Value(address),
      role: Value(role),
      employeeId: Value(employeeId),
      salary: Value(salary),
      commissionPercentage: Value(commissionPercentage),
      hireDate: Value(now),
      canLogin: Value(canLogin ?? true),
      password: Value(password),
      permissions: Value(permissions),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  Future<bool> updateEmployee(EmployeeModel employee) async {
    return await _database.updateEmployee(employee.toEmployee());
  }

  Future<int> deleteEmployee(int id) async {
    return await _database.deleteEmployee(id);
  }

  // Analytics operations
  Future<models.SalesSummary> getSalesSummary(
      DateTime start, DateTime end) async {
    try {
      // Get sales in date range
      final sales = await _database.getSalesByDateRange(start, end);

      if (sales.isEmpty) {
        return models.SalesSummary.empty();
      }

      double totalSales = 0;
      double totalPaid = 0;
      double totalDue = 0;
      int salesCount = sales.length;
      int paidSales = 0;
      int unpaidSales = 0;
      int partialSales = 0;

      for (final sale in sales) {
        totalSales += sale.total;

        // Get payments for this sale
        final payments = await _database.getPaymentsBySaleId(sale.id);
        double paidAmount =
            payments.fold(0.0, (sum, payment) => sum + payment.amount);

        totalPaid += paidAmount;
        double saleDue = sale.total - paidAmount;
        totalDue += saleDue;

        // Categorize sales by payment status
        if (paidAmount >= sale.total) {
          paidSales++;
        } else if (paidAmount == 0) {
          unpaidSales++;
        } else {
          partialSales++;
        }
      }

      double averageSale = salesCount > 0 ? totalSales / salesCount : 0.0;

      return models.SalesSummary(
        totalSales: totalSales,
        totalPaid: totalPaid,
        totalDue: totalDue,
        salesCount: salesCount,
        averageSale: averageSale,
        paidSales: paidSales,
        unpaidSales: unpaidSales,
        partialSales: partialSales,
      );
    } catch (e) {
      // Return empty summary on error
      return models.SalesSummary.empty();
    }
  }

  Future<List<models.ProductSales>> getProductSalesReport(
      DateTime start, DateTime end) async {
    final sales = await getSalesByDateRange(start, end);
    final aggregates = <int,
        ({
      String name,
      String category,
      double quantity,
      double sales,
      Set<int> invoices
    })>{};

    for (final sale in sales) {
      for (final item in sale.items) {
        final product = item.product;
        final previous = aggregates[item.productId];
        final invoices = {...?previous?.invoices};
        if (sale.id != null) invoices.add(sale.id!);
        aggregates[item.productId] = (
          name: product?.name ?? 'Product ${item.productId}',
          category: product?.category ?? 'Unknown',
          quantity: (previous?.quantity ?? 0) + item.qty,
          sales: (previous?.sales ?? 0) + item.subtotal,
          invoices: invoices,
        );
      }
    }

    final result = aggregates.entries
        .map((entry) => models.ProductSales(
              productId: entry.key,
              productName: entry.value.name,
              category: entry.value.category,
              totalQuantity: entry.value.quantity,
              totalSales: entry.value.sales,
              salesCount: entry.value.invoices.length,
            ))
        .toList();
    result.sort((a, b) => b.totalSales.compareTo(a.totalSales));
    return result;
  }

  // Stock operations
  Future<List<StockAdjustment>> getAllStockMovements() async {
    return await _database.getAllStockAdjustments();
  }

  Future<List<StockAdjustment>> getStockMovementsByProduct(
      int productId) async {
    return await _database.getStockAdjustmentsByProduct(productId);
  }

  Future<List<StockAdjustment>> getStockMovementsByDateRange(
      DateTime start, DateTime end) async {
    return await _database.getStockAdjustmentsByDateRange(start, end);
  }

  Future<List<StockAdjustment>> getStockMovementsByReason(String reason) async {
    return await _database.getStockAdjustmentsByReason(reason);
  }

  Future<void> adjustStock(int productId, double quantity, String reason,
      {String? reference, int? employeeId}) async {
    if (!quantity.isFinite || quantity == 0) {
      throw ArgumentError(
          'Stock movement quantity must be finite and non-zero.');
    }
    await _database.transaction(() async {
      final product = await getProductById(productId);
      if (product == null) throw StateError('Product $productId not found.');
      final now = DateTime.now();
      final newStock = product.stock + quantity;
      if (!newStock.isFinite) throw StateError('Invalid resulting stock.');

      await _database.insertStockAdjustment(StockAdjustmentsCompanion(
        productId: Value(productId),
        quantity: Value(quantity),
        reason: Value(reason),
        reference: Value(reference),
        date: Value(now.toIso8601String()),
        employeeId: Value(employeeId),
        createdAt: Value(now.toIso8601String()),
      ));
      await updateProduct(product.copyWith(stock: newStock, updatedAt: now));
    });
  }

  Future<bool> deleteStockMovement(int id) async {
    final movement = await _database.getStockAdjustmentById(id);
    if (movement == null) return false;
    // Inventory history is immutable. A requested deletion is recorded as a
    // compensating movement so the audit trail and resulting stock both remain
    // correct.
    await adjustStock(
      movement.productId,
      -movement.quantity,
      'Reversal',
      reference: 'Reversal of stock movement #$id (${movement.reason})',
      employeeId: movement.employeeId,
    );
    return true;
  }

  // Customer ledger operations
  Future<CustomerWithSales> getCustomerWithSales(int customerId) async {
    final customer = await getCustomerById(customerId);
    if (customer == null) {
      throw Exception('Customer not found');
    }

    final customerSales = await getSalesByCustomer(customerId);

    return CustomerWithSales(
      customer: customer,
      sales: customerSales,
    );
  }

  // Category operations
  Future<List<CategoryModel>> getAllCategories() async {
    final categories = await _database.getAllCategories();
    return categories.map((c) => CategoryModel.fromCategory(c)).toList();
  }

  Future<CategoryModel?> getCategoryById(int id) async {
    final category = await _database.getCategoryById(id);
    return category != null ? CategoryModel.fromCategory(category) : null;
  }

  Future<int> insertCategory(CategoryModel category) async {
    return await _database.insertCategory(category.toCompanion());
  }

  Future<bool> updateCategory(CategoryModel category) async {
    return await _database.updateCategory(category.toCategory());
  }

  Future<int> deleteCategory(int id) async {
    return await _database.deleteCategory(id);
  }

  // Expense operations
  Future<List<Expense>> getAllExpenses() async {
    return await _database.getAllExpenses();
  }

  Future<Expense?> getExpenseById(int id) async {
    return await _database.getExpenseById(id);
  }

  Future<List<Expense>> getExpensesByDateRange(
      DateTime start, DateTime end) async {
    return await _database.getExpensesByDateRange(start, end);
  }

  Future<List<Expense>> getExpensesByCategory(String category) async {
    return await _database.getExpensesByCategory(category);
  }

  Future<List<Expense>> getExpensesByPaymentMethod(String method) async {
    return await _database.getExpensesByPaymentMethod(method);
  }

  Future<int> insertExpense(ExpensesCompanion expense) async {
    return await _database.insertExpense(expense);
  }

  Future<bool> updateExpense(Expense expense) async {
    return await _database.updateExpense(expense);
  }

  Future<int> deleteExpense(int id) async {
    return await _database.deleteExpense(id);
  }

  // Expense Head operations
  Future<List<ExpenseHead>> getAllExpenseHeads() async {
    return await _database.getAllExpenseHeads();
  }

  Future<ExpenseHead?> getExpenseHeadById(int id) async {
    return await _database.getExpenseHeadById(id);
  }

  Future<int> insertExpenseHead(ExpenseHeadsCompanion expenseHead) async {
    return await _database.insertExpenseHead(expenseHead);
  }

  Future<bool> updateExpenseHead(ExpenseHead expenseHead) async {
    return await _database.updateExpenseHead(expenseHead);
  }

  Future<int> deleteExpenseHead(int id) async {
    return await _database.deleteExpenseHead(id);
  }

  // Supplier operations
  Future<List<Supplier>> getAllSuppliers() async {
    return await _database.getAllSuppliers();
  }

  Future<Supplier?> getSupplierById(int id) async {
    return await _database.getSupplierById(id);
  }

  Future<List<Supplier>> getActiveSuppliers() async {
    return await _database.getActiveSuppliers();
  }

  Future<int> insertSupplier(SuppliersCompanion supplier) async {
    final codeValue = supplier.code.present ? supplier.code.value.trim() : '';
    if (codeValue.isEmpty) {
      throw Exception('Supplier code is required.');
    }
    if (await supplierCodeExists(codeValue)) {
      throw Exception('Supplier code "$codeValue" already exists.');
    }
    final normalized = supplier.copyWith(
      code: Value(codeValue.toUpperCase()),
      updatedAt: Value(DateTime.now().toIso8601String()),
    );
    return await _database.insertSupplier(normalized);
  }

  Future<bool> updateSupplier(Supplier supplier) async {
    final trimmedCode = supplier.code.trim();
    if (trimmedCode.isEmpty) {
      throw Exception('Supplier code is required.');
    }
    if (await supplierCodeExists(trimmedCode, excludeId: supplier.id)) {
      throw Exception('Supplier code "$trimmedCode" already exists.');
    }
    final normalized = supplier.copyWith(
      code: trimmedCode.toUpperCase(),
      updatedAt: DateTime.now().toIso8601String(),
    );
    return await _database.updateSupplier(normalized);
  }

  Future<int> deleteSupplier(int id) async {
    try {
      // Get all purchase orders for this supplier
      final purchaseOrders = await getPurchaseOrdersBySupplier(id);

      // Delete all purchase orders for this supplier
      for (final order in purchaseOrders) {
        if (order.id != null) {
          // Get purchase order items before deleting to reverse stock changes
          final orderItems = await getPurchaseOrderItems(order.id!);

          // Reverse stock changes for each item (stock was increased when purchase was received)
          for (final item in orderItems) {
            // Only reverse stock if order was received (stock was actually increased)
            if (order.status == 'received') {
              await adjustStock(
                item.productId,
                -item.quantity, // Negative quantity to reverse stock increase
                'Supplier Deletion - Purchase Order Stock Reversal',
                reference:
                    'Supplier Deletion: Purchase Order #${order.orderNumber}',
              );
            }
          }

          // Delete purchase order items first
          await deletePurchaseOrderItems(order.id!);

          // Delete the purchase order
          await deletePurchaseOrder(order.id!);
        }
      }

      // Delete all supplier payments for this supplier
      final supplierPayments = await getSupplierPayments(id);
      for (final payment in supplierPayments) {
        if (payment.id != null) {
          await deleteSupplierPayment(payment.id!);
        }
      }

      // Update products to remove supplier reference (set supplierId to null)
      final allProducts = await getAllProducts();
      for (final product in allProducts) {
        if (product.supplierId == id) {
          final updatedProduct = product.copyWith(
            supplierId: null,
            updatedAt: DateTime.now(),
          );
          await updateProduct(updatedProduct);
        }
      }

      // Now delete the supplier
      final result = await _database.deleteSupplier(id);
      if (result <= 0) {
        throw Exception('Failed to delete supplier. Supplier may not exist.');
      }

      print(
          'Database Service: Successfully deleted supplier $id along with ${purchaseOrders.length} purchase order(s) and ${supplierPayments.length} payment(s)');
      return result;
    } catch (e) {
      print('Database Service: Error deleting supplier $id: $e');
      rethrow;
    }
  }

  // Supplier Payment operations
  Future<List<SupplierPaymentModel>> getSupplierPayments(int supplierId) async {
    final payments = await _database.getSupplierPayments(supplierId);
    return payments
        .map((p) => SupplierPaymentModel.fromSupplierPayment(p))
        .toList();
  }

  Future<List<SupplierPaymentModel>> getSupplierPaymentsByDateRange(
      int supplierId, DateTime start, DateTime end) async {
    final payments =
        await _database.getSupplierPaymentsByDateRange(supplierId, start, end);
    return payments
        .map((p) => SupplierPaymentModel.fromSupplierPayment(p))
        .toList();
  }

  Future<int> insertSupplierPayment(SupplierPaymentModel payment) async {
    // CRITICAL: Validate payment amount before processing
    if (payment.amount == 0 ||
        payment.amount.isNaN ||
        payment.amount.isInfinite) {
      throw Exception(
          'Invalid payment amount: ${payment.amount}. Amount must be non-zero and finite.');
    }

    // CRITICAL: Validate supplier exists
    final supplier = await getSupplierById(payment.supplierId);
    if (supplier == null) {
      throw Exception('Supplier not found. Cannot process payment.');
    }

    // CRITICAL: Insert payment first
    final paymentId =
        await _database.insertSupplierPayment(payment.toCompanion());

    await _updateSupplierBalance(payment.supplierId);

    return paymentId;
  }

  Future<bool> updateSupplierPayment(SupplierPaymentModel payment) async {
    // Get the existing payment to check if status changed
    final existingPayment = await _database.getSupplierPaymentById(payment.id!);
    if (existingPayment == null) {
      return await _database.updateSupplierPayment(payment.toSupplierPayment());
    }

    final result =
        await _database.updateSupplierPayment(payment.toSupplierPayment());

    // CRITICAL: Only recalculate supplier balance if payment STATUS changed (especially for cancelled cheques)
    // Do NOT recalculate if only the note changed (e.g., from "Pending" to "Cleared")
    // This prevents balance from being incorrectly adjusted when cheque is cleared
    final isCheque = payment.paymentMethod == 'cheque';
    final isCancelled = payment.status == 'cancelled';
    final existingStatus = existingPayment.status;
    final existingIsCancelled = existingStatus == 'cancelled';

    // Only recalculate if the cancelled status actually changed (not just note)
    if (isCheque && (isCancelled != existingIsCancelled)) {
      // Status changed for a cheque (cancelled or uncancelled), recalculate balance
      final newBalance = await recalculateSupplierBalance(payment.supplierId);
      final supplier = await getSupplierById(payment.supplierId);
      if (supplier != null) {
        final updatedSupplier = SupplierModel.fromSupplier(supplier).copyWith(
          currentBalance: newBalance,
          updatedAt: DateTime.now(),
        );
        await updateSupplier(updatedSupplier.toSupplier());
      }
    }
    // If only note changed (e.g., "Pending" to "Cleared"), balance stays the same
    // Balance was already correctly set when payment was created

    return result;
  }

  Future<int> deleteSupplierPayment(int id) async {
    // Get payment details before deletion for balance recalculation
    final payment = await _database.getSupplierPaymentById(id);
    final supplierId = payment?.supplierId;

    // Delete the payment
    final result = await _database.deleteSupplierPayment(id);

    // Recalculate supplier balance after deletion
    if (supplierId != null) {
      await _updateSupplierBalance(supplierId);
    }

    return result;
  }

  Future<double> getSupplierBalance(int supplierId) async {
    // This method is not used for balance calculation, but keeping it for compatibility
    // Actual balance is stored in supplier.currentBalance and maintained via insertSupplierPayment
    final supplier = await getSupplierById(supplierId);
    return supplier?.currentBalance ?? 0.0;
  }

  Future<double> recalculateSupplierBalance(int supplierId) async {
    try {
      final supplier = await getSupplierById(supplierId);
      if (supplier == null) return 0.0;

      // Get all purchase orders for this supplier
      final purchaseOrders =
          await _database.getPurchaseOrdersBySupplier(supplierId);
      double totalPurchases = purchaseOrders
          .where((order) => order.status == 'received')
          .fold(0.0, (sum, order) => sum + order.total);

      // Get all payments for this supplier, excluding cancelled cheques
      final payments = await getSupplierPayments(supplierId);
      double totalPayments = payments.fold(0.0, (sum, payment) {
        final isCheque = payment.paymentMethod == 'cheque';
        final isCancelled = payment.status == 'cancelled';
        final isCancelledCheque = isCheque && isCancelled;

        // Exclude cancelled cheques from balance calculation
        if (isCancelledCheque) {
          return sum;
        }

        if (payment.paymentType == 'payment') {
          return sum + payment.amount; // Payment reduces what we owe
        } else if (payment.paymentType == 'refund') {
          return sum - payment.amount; // Refund increases what we owe
        }
        return sum;
      });

      // Balance = what we owe (purchases) - what we've paid
      final balance = totalPurchases - totalPayments;

      return balance;
    } catch (e) {
      print(
          'Database Service: Error recalculating supplier balance for $supplierId: $e');
      rethrow;
    }
  }

  Future<void> _updateCustomerBalance(int customerId) async {
    final newBalance = await recalculateCustomerBalance(customerId);
    final customer = await getCustomerById(customerId);
    if (customer != null) {
      final updatedCustomer = customer.copyWith(
        totalDue: newBalance,
        updatedAt: DateTime.now(),
      );
      await updateCustomer(updatedCustomer);
    }
  }

  Future<void> _updateSupplierBalance(int supplierId) async {
    final newBalance = await recalculateSupplierBalance(supplierId);
    final supplier = await getSupplierById(supplierId);
    if (supplier != null) {
      final updatedSupplier = SupplierModel.fromSupplier(supplier).copyWith(
        currentBalance: newBalance,
        updatedAt: DateTime.now(),
      );
      await updateSupplier(updatedSupplier.toSupplier());
    }
  }

  Future<bool> supplierCodeExists(String code, {int? excludeId}) async {
    final query = StringBuffer(
        'SELECT COUNT(*) AS count FROM suppliers WHERE LOWER(code) = LOWER(?)');
    final vars = <Variable>[
      Variable<String>(code),
    ];
    if (excludeId != null) {
      query.write(' AND id != ?');
      vars.add(Variable<int>(excludeId));
    }
    final row = await _database
        .customSelect(query.toString(), variables: vars)
        .getSingle();
    final total =
        row.read<int>('count') ?? (row.read<BigInt>('count')?.toInt() ?? 0);
    return total > 0;
  }

  Future<String> generateSupplierCode() async {
    final prefix = DateFormat('yyMM').format(DateTime.now());
    var candidate = 'SUP-$prefix';
    var counter = 1;
    while (await supplierCodeExists(candidate)) {
      candidate = 'SUP-$prefix${counter.toString().padLeft(2, '0')}';
      counter++;
      if (counter > 99) {
        final fallback =
            'SUP-${DateFormat('yyMMddHHmmss').format(DateTime.now())}';
        if (!await supplierCodeExists(fallback)) {
          return fallback;
        }
      }
    }
    return candidate;
  }

  // Staff Performance operations
  Future<List<StaffPerformance>> getAllStaffPerformance() async {
    final performances = await _database.getAllStaffPerformance();
    return performances;
  }

  Future<List<StaffPerformance>> getStaffPerformanceByEmployee(
      int employeeId) async {
    final performances =
        await _database.getStaffPerformanceByEmployee(employeeId);
    return performances;
  }

  Future<List<StaffPerformance>> getStaffPerformanceByDateRange(
      DateTime start, DateTime end) async {
    final performances =
        await _database.getStaffPerformanceByDateRange(start, end);
    return performances;
  }

  Future<int> insertStaffPerformance(StaffPerformanceModel performance) async {
    return await _database.insertStaffPerformance(performance.toCompanion());
  }

  Future<bool> updateStaffPerformance(StaffPerformanceModel performance) async {
    return await _database
        .updateStaffPerformance(performance.toStaffPerformance());
  }

  Future<int> deleteStaffPerformance(int id) async {
    return await _database.deleteStaffPerformance(id);
  }

  Future<List<Map<String, dynamic>>> getStaffPerformanceSummary() async {
    return await _database.getStaffPerformanceSummary();
  }

  Future<List<Map<String, dynamic>>> getTopPerformers(int limit) async {
    return await _database.getTopPerformers(limit);
  }

  Future<Map<String, dynamic>> getStaffPerformanceAnalytics() async {
    return await _database.getStaffPerformanceAnalytics();
  }

  // Recalculate customer's total due based on all sales and payments
  // CRITICAL: Recalculate customer balance from all sales and payments
  // This ensures accuracy and prevents balance drift from incremental updates
  Future<double> recalculateCustomerBalance(int customerId) async {
    try {
      final sales = await getSalesByCustomer(customerId);
      final payments = await getPaymentsByCustomer(customerId);
      final returns = await getReturnsByCustomer(customerId);

      // CRITICAL: Calculate total sales amount (only credit sales contribute to balance)
      // Only include sales where paymentType is credit OR where there's a due amount > 0
      // Cash and card sales should NOT affect customer balance
      double totalSales = sales.fold(0.0, (sum, sale) {
        // Only include credit sales in balance calculation
        // Cash and card sales are fully paid at the time of sale, so they don't affect balance
        if (sale.paymentType == PaymentType.credit || sale.due > 0) {
          return sum +
              sale.due; // Use due amount, not total, as it represents what's actually owed
        }
        return sum; // Exclude cash/card sales from balance
      });

      // CRITICAL: Calculate total payments amount, excluding cancelled cheques
      // For customer payments, check if payment method is cheque and note contains "cancelled" or "cancel"
      double totalPayments = payments.fold(0.0, (sum, payment) {
        final isCheque = payment.paymentMethod == PaymentMethod.cheque;
        final note = payment.note?.toLowerCase() ?? '';
        final isCancelledCheque =
            isCheque && (note.contains('cancelled') || note.contains('cancel'));

        // Exclude cancelled cheques from balance calculation
        if (isCancelledCheque) {
          return sum;
        }
        return sum + payment.amount;
      });

      // CRITICAL: Calculate total due (credit sales due - payments)
      // This is the correct calculation: what customer owes from credit sales minus what they've paid
      final approvedReturnCredits = returns.fold(0.0, (sum, item) {
        if (item.status == 'approved' || item.status == 'processed') {
          return sum + item.totalAmount;
        }
        return sum;
      });

      final finalBalance = totalSales - totalPayments - approvedReturnCredits;

      return finalBalance;
    } catch (e) {
      print(
          'Database Service: Error recalculating customer balance for $customerId: $e');
      rethrow;
    }
  }

  // Bank operations
  Future<List<BankModel>> getAllBanks() async {
    final banks = await _database.getAllBanks();
    return banks.map((b) => BankModel.fromBank(b)).toList();
  }

  Future<BankModel?> getBankById(int id) async {
    final bank = await _database.getBankById(id);
    return bank != null ? BankModel.fromBank(bank) : null;
  }

  Future<List<BankModel>> getActiveBanks() async {
    final banks = await _database.getActiveBanks();
    return banks.map((b) => BankModel.fromBank(b)).toList();
  }

  Future<int> insertBank(BankModel bank) async {
    return await _database.insertBank(bank.toCompanion());
  }

  Future<bool> updateBank(BankModel bank) async {
    return await _database.updateBank(bank.toBank());
  }

  Future<int> deleteBank(int id) async {
    return await _database.deleteBank(id);
  }

  // Bank Payment operations
  Future<List<BankPaymentModel>> getBankPayments(int bankId) async {
    final payments = await _database.getBankPayments(bankId);
    return payments.map((p) => BankPaymentModel.fromBankPayment(p)).toList();
  }

  Future<List<BankPaymentModel>> getBankPaymentsByDateRange(
      DateTime start, DateTime end) async {
    final payments = await _database.getBankPaymentsByDateRange(start, end);
    return payments.map((p) => BankPaymentModel.fromBankPayment(p)).toList();
  }

  Future<List<BankPaymentModel>> getBankPaymentsByParty(
      String partyName) async {
    final payments = await _database.getBankPaymentsByParty(partyName);
    return payments.map((p) => BankPaymentModel.fromBankPayment(p)).toList();
  }

  Future<List<BankPaymentModel>> getBankPaymentsByChequeNumber(
      String chequeNumber) async {
    final payments =
        await _database.getBankPaymentsByChequeNumber(chequeNumber);
    return payments.map((p) => BankPaymentModel.fromBankPayment(p)).toList();
  }

  Future<int> insertBankPayment(BankPaymentModel payment) async {
    return await _database.insertBankPayment(payment.toCompanion());
  }

  Future<bool> updateBankPayment(BankPaymentModel payment) async {
    return await _database.updateBankPayment(payment.toBankPayment());
  }

  Future<bool> updateBankPaymentStatus(int id, String status) async {
    return await _database.updateBankPaymentStatus(id, status);
  }

  Future<int> deleteBankPayment(int id) async {
    return await _database.deleteBankPayment(id);
  }

  // Purchase Order operations
  Future<List<PurchaseOrder>> getAllPurchaseOrders() async {
    return await _database.getAllPurchaseOrders();
  }

  Future<PurchaseOrder?> getPurchaseOrderById(int id) async {
    return await _database.getPurchaseOrderById(id);
  }

  Future<List<PurchaseOrder>> getPurchaseOrdersBySupplier(
      int supplierId) async {
    return await _database.getPurchaseOrdersBySupplier(supplierId);
  }

  Future<List<PurchaseOrder>> getPurchaseOrdersByStatus(String status) async {
    return await _database.getPurchaseOrdersByStatus(status);
  }

  Future<List<PurchaseOrder>> getPurchaseOrdersByDateRange(
      DateTime start, DateTime end) async {
    return await _database.getPurchaseOrdersByDateRange(start, end);
  }

  Future<int> insertPurchaseOrder(PurchaseOrdersCompanion order) async {
    return await _database.insertPurchaseOrder(order);
  }

  Future<bool> updatePurchaseOrder(PurchaseOrder order) async {
    return await _database.updatePurchaseOrder(order);
  }

  Future<int> deletePurchaseOrder(int id) async {
    return await _database.deletePurchaseOrder(id);
  }

  // Purchase Order Items operations
  Future<List<PurchaseOrderItem>> getPurchaseOrderItems(int orderId) async {
    return await _database.getPurchaseOrderItems(orderId);
  }

  Future<int> insertPurchaseOrderItem(PurchaseOrderItemsCompanion item) async {
    return await _database.insertPurchaseOrderItem(item);
  }

  Future<bool> updatePurchaseOrderItem(PurchaseOrderItem item) async {
    return await _database.updatePurchaseOrderItem(item);
  }

  Future<int> deletePurchaseOrderItem(int id) async {
    return await _database.deletePurchaseOrderItem(id);
  }

  Future<int> deletePurchaseOrderItems(int orderId) async {
    return await _database.deletePurchaseOrderItems(orderId);
  }

  // Return operations
  Future<List<Return>> getAllReturns() async {
    return await _database.getAllReturns();
  }

  Future<Return?> getReturnById(int id) async {
    return await _database.getReturnById(id);
  }

  Future<List<Return>> getReturnsByCustomer(int customerId) async {
    return await _database.getReturnsByCustomer(customerId);
  }

  Future<List<Return>> getReturnsBySale(int saleId) async {
    return await _database.getReturnsBySale(saleId);
  }

  Future<List<Return>> getReturnsByStatus(String status) async {
    return await _database.getReturnsByStatus(status);
  }

  Future<List<Return>> getReturnsByDateRange(
      DateTime start, DateTime end) async {
    return await _database.getReturnsByDateRange(start, end);
  }

  Future<int> insertReturn(ReturnsCompanion returnData) async {
    return await _database.insertReturn(returnData);
  }

  Future<bool> updateReturn(Return returnData) async {
    return await _database.updateReturn(returnData);
  }

  /// Approves a return, validates it against the original invoice, restores
  /// sellable stock and updates customer credit as one transaction.
  Future<void> approveReturnAtomically(int returnId,
      {String processedBy = 'System'}) async {
    await _database.transaction(() async {
      final returnEntity = await _database.getReturnById(returnId);
      if (returnEntity == null) throw StateError('Return not found.');
      if (returnEntity.status != 'pending') {
        throw StateError('Only pending returns can be approved.');
      }

      final items = await _database.getReturnItems(returnId);
      if (items.isEmpty) throw StateError('Return has no items.');
      final soldItems =
          await _database.getSaleItemsBySaleId(returnEntity.originalSaleId);
      final soldByProduct = <int, double>{};
      for (final item in soldItems) {
        soldByProduct[item.productId] =
            (soldByProduct[item.productId] ?? 0) + item.qty;
      }

      final alreadyReturned = <int, double>{};
      final previousReturns =
          await _database.getReturnsBySale(returnEntity.originalSaleId);
      for (final previous in previousReturns) {
        if (previous.id == returnId ||
            (previous.status != 'approved' && previous.status != 'processed')) {
          continue;
        }
        for (final item in await _database.getReturnItems(previous.id)) {
          alreadyReturned[item.productId] =
              (alreadyReturned[item.productId] ?? 0) + item.quantity;
        }
      }

      final requested = <int, double>{};
      for (final item in items) {
        if (!item.quantity.isFinite || item.quantity <= 0) {
          throw StateError('Return quantities must be positive.');
        }
        requested[item.productId] =
            (requested[item.productId] ?? 0) + item.quantity;
      }
      for (final entry in requested.entries) {
        final available =
            (soldByProduct[entry.key] ?? 0) - (alreadyReturned[entry.key] ?? 0);
        if (entry.value > available + 0.000001) {
          throw StateError(
              'Return quantity exceeds the unreturned invoice quantity for product ${entry.key}.');
        }
      }

      for (final item in items) {
        // Damaged/defective goods remain outside sellable stock. Good items are
        // restored regardless of whether compensation is refund, exchange or credit.
        if (item.condition == 'good') {
          await adjustStock(
            item.productId,
            item.quantity,
            'Return',
            reference: 'Return approved: ${returnEntity.returnNumber}',
          );
        }
      }

      await _database.updateReturn(returnEntity.copyWith(
        status: 'approved',
        processedBy: Value(processedBy),
        updatedAt: DateTime.now().toIso8601String(),
      ));
      await _updateCustomerBalance(returnEntity.customerId);
    });
  }

  Future<int> deleteReturn(int id) async {
    return await _database.deleteReturn(id);
  }

  // Return Item operations
  Future<List<ReturnItem>> getReturnItems(int returnId) async {
    return await _database.getReturnItems(returnId);
  }

  Future<int> insertReturnItem(ReturnItemsCompanion item) async {
    return await _database.insertReturnItem(item);
  }

  Future<bool> updateReturnItem(ReturnItem item) async {
    return await _database.updateReturnItem(item);
  }

  Future<int> deleteReturnItem(int id) async {
    return await _database.deleteReturnItem(id);
  }

  Future<int> deleteReturnItems(int returnId) async {
    return await _database.deleteReturnItems(returnId);
  }

  // Close database
  // IMEI operations for mobile shop
  Future<List<ProductIMEI>> getIMEIsByCustomer(int customerId) async {
    return await (_database.select(_database.productIMEIs)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm.desc(t.saleDate)]))
        .get();
  }

  Future<List<ProductIMEI>> getIMEIsBySale(int saleId) async {
    return await (_database.select(_database.productIMEIs)
          ..where((t) => t.saleId.equals(saleId))
          ..orderBy([(t) => OrderingTerm.desc(t.saleDate)]))
        .get();
  }

  Future<ProductIMEI?> getIMEIByNumber(String imei) async {
    return await (_database.select(_database.productIMEIs)
          ..where((t) => t.imei.equals(imei)))
        .getSingleOrNull();
  }

  Future<List<ProductIMEI>> getAllIMEIs({String? status}) async {
    final query = _database.select(_database.productIMEIs);
    if (status != null) {
      query.where((t) => t.status.equals(status));
    }
    return await (query..orderBy([(t) => OrderingTerm.desc(t.saleDate)])).get();
  }

  Future<List<ProductIMEI>> getIMEIsByProduct(int productId) async {
    return await (_database.select(_database.productIMEIs)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([(t) => OrderingTerm.desc(t.saleDate)]))
        .get();
  }

  /// Insert or register an IMEI record for a product (useful for trade-in intake or stocking phones).
  Future<int> insertIMEIRecord({
    required int productId,
    required String imei,
    String status = 'available',
    int? customerId,
    int? saleId,
    String? notes,
    DateTime? purchaseDate,
    DateTime? saleDate,
  }) async {
    return await _database.into(_database.productIMEIs).insert(
          ProductIMEIsCompanion.insert(
            productId: productId,
            imei: imei,
            status: Value(status),
            customerId: Value(customerId),
            saleId: Value(saleId),
            notes: Value(notes),
            purchaseDate: Value(
                purchaseDate != null ? purchaseDate.toIso8601String() : null),
            saleDate:
                Value(saleDate != null ? saleDate.toIso8601String() : null),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> updateIMEIStatus(int imeiId, String status,
      {String? notes}) async {
    await (_database.update(_database.productIMEIs)
          ..where((t) => t.id.equals(imeiId)))
        .write(ProductIMEIsCompanion(
      status: Value(status),
      notes: notes != null ? Value(notes) : const Value.absent(),
      updatedAt: Value(DateTime.now().toIso8601String()),
    ));
  }

  // Employee Commission operations (for salon business)
  Future<int> insertEmployeeCommission(
      EmployeeCommissionModel commission) async {
    // Note: This will work after database files are regenerated
    // For now, using custom statement as fallback
    try {
      await _database.customStatement('''
        INSERT INTO employee_commissions (
          employee_id, transaction_type, sale_id, amount, commission_percentage,
          sale_amount, balance_after, date, notes, processed_by, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        commission.employeeId,
        commission.transactionType == CommissionTransactionType.earning
            ? 'earning'
            : 'withdrawal',
        commission.saleId,
        commission.amount,
        commission.commissionPercentage,
        commission.saleAmount,
        commission.balanceAfter,
        commission.date.toIso8601String(),
        commission.notes,
        commission.processedBy,
        commission.createdAt.toIso8601String(),
        commission.updatedAt.toIso8601String(),
      ]);
      // Get the last inserted ID
      final result = await _database
          .customSelect('SELECT last_insert_rowid() as id')
          .getSingle();
      return result.read<int>('id') ?? 0;
    } catch (e) {
      print('Error inserting employee commission: $e');
      rethrow;
    }
  }

  Future<List<EmployeeCommissionModel>> getEmployeeCommissions(
    int employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String query = '''
        SELECT * FROM employee_commissions
        WHERE employee_id = ?
      ''';
      List<Variable<Object>> variables = [Variable<int>(employeeId)];

      if (startDate != null) {
        query += ' AND date >= ?';
        variables.add(Variable<String>(startDate.toIso8601String()));
      }

      if (endDate != null) {
        query += ' AND date <= ?';
        variables.add(Variable<String>(endDate.toIso8601String()));
      }

      query += ' ORDER BY date DESC, created_at DESC';

      final rows = await _database
          .customSelect(query, variables: variables, readsFrom: {}).get();

      return rows.map((row) {
        return EmployeeCommissionModel(
          id: row.read<int>('id'),
          employeeId: row.read<int>('employee_id'),
          transactionType: row.read<String>('transaction_type') == 'earning'
              ? CommissionTransactionType.earning
              : CommissionTransactionType.withdrawal,
          saleId: row.read<int?>('sale_id'),
          amount: row.read<double>('amount'),
          commissionPercentage: row.read<double?>('commission_percentage'),
          saleAmount: row.read<double?>('sale_amount'),
          balanceAfter: row.read<double?>('balance_after'),
          date: DateTime.parse(row.read<String>('date')),
          notes: row.read<String?>('notes'),
          processedBy: row.read<String?>('processed_by'),
          createdAt: DateTime.parse(row.read<String>('created_at')),
          updatedAt: DateTime.parse(row.read<String>('updated_at')),
        );
      }).toList();
    } catch (e) {
      print('Error getting employee commissions: $e');
      return [];
    }
  }

  Future<void> close() async {
    await _database.close();
  }
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final database = ref.watch(databaseProvider);
  return DatabaseService(database);
});
