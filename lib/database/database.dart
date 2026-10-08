import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Products,
  Customers,
  Sales,
  SaleItems,
  Payments,
  Settings,
  StockAdjustments,
  Categories,
  Suppliers,
  PurchaseOrders,
  PurchaseOrderItems,
  Employees,
  Returns,
  ReturnItems,
  Expenses,
  ExpenseHeads,
  SupplierPayments,
  Banks,
  BankPayments,
  StaffPerformances,
  ProductIMEIs,
  ProductBundles,
  ProductBundleItems,
  EmployeeCommissions,
  ProductIngredients,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection()) {
    _initializeDatabase();
  }

  /// Initialize database with cleanup check
  void _initializeDatabase() async {
    try {
      final isFresh = await isFreshInstall();
      if (isFresh) {
        // Delete any existing database files
        await deleteDatabaseFile();
        // Mark as installed
        await markAsInstalled();
        print('Fresh install detected - database will be created fresh');
      }
    } catch (e) {
      print('Error during database initialization: $e');
    }
  }

  @override
  int get schemaVersion => 26;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 26) {
            await m.addColumn(saleItems, saleItems.orderDiscountAllocation);
            await m.addColumn(saleItems, saleItems.taxRate);
            await m.addColumn(saleItems, saleItems.taxAmount);
            await m.addColumn(saleItems, saleItems.costAtSale);
            await m.addColumn(saleItems, saleItems.unit);
            await customStatement('''
              UPDATE sale_items
              SET cost_at_sale = COALESCE(
                    (SELECT cost FROM products WHERE products.id = sale_items.product_id),
                    0
                  ),
                  tax_rate = COALESCE(
                    (SELECT tax FROM products WHERE products.id = sale_items.product_id),
                    0
                  ),
                  unit = COALESCE(
                    (SELECT unit FROM products WHERE products.id = sale_items.product_id),
                    'pcs'
                  )
            ''');
          }
          if (from < 2) {
            // Add new tables for version 2
            await m.createTable(suppliers);
            await m.createTable(purchaseOrders);
            await m.createTable(purchaseOrderItems);
            await m.createTable(employees);
            await m.createTable(returns);
            await m.createTable(returnItems);
          }
          if (from < 3) {
            // Add new fields to products table for version 3
            await m.addColumn(products, products.reorderLevel);
            await m.addColumn(products, products.reorderQuantity);
            await m.addColumn(products, products.supplierId);
            await m.addColumn(products, products.expiryDate);
            await m.addColumn(products, products.batchNumber);
          }
          if (from < 4) {
            // Ensure categories table exists for version 4
            await m.createTable(categories);
          }
          if (from < 5) {
            // Add expenses table for version 5
            await m.createTable(expenses);
          }
          if (from < 6) {
            // Add cashierId column to sales table for version 6
            await m.addColumn(sales, sales.cashierId);
          }
          if (from < 7) {
            // Add supplier payments table for version 7
            await m.createTable(supplierPayments);
          }
          if (from < 8) {
            // Add banks and bank payments tables for version 8
            await m.createTable(banks);
            await m.createTable(bankPayments);
          }
          if (from < 9) {
            // Add staff performance table for version 9
            await m.createTable(staffPerformances);
          }
          if (from < 10) {
            // Add dueDate column to sales table for version 10
            try {
              await m.addColumn(sales, sales.dueDate);
            } catch (e) {
              // If the column already exists, ignore the error
              print('Column due_date might already exist: $e');
            }
          }
          if (from < 11) {
            // Add creditLimit column to customers table for version 11
            try {
              await m.addColumn(customers, customers.creditLimit);
              // Set default value for existing customers
              await customStatement(
                  'UPDATE customers SET credit_limit = 0 WHERE credit_limit IS NULL');
            } catch (e) {
              // If the column already exists, ignore the error
              print('Column credit_limit might already exist: $e');
            }
            // Add new product fields for version 11
            try {
              await m.addColumn(products, products.company);
              await m.addColumn(products, products.marketPrice);
              await m.addColumn(products, products.maxLevel);
              await m.addColumn(products, products.packingMode);
              await m.addColumn(products, products.wholesaleCash);
              await m.addColumn(products, products.wholesaleCredit);
              await m.addColumn(products, products.retailCredit);
              print('Added new product columns for version 11');
            } catch (e) {
              print('Product columns might already exist: $e');
            }
            // Add canLogin to employees for version 11
            try {
              await m.addColumn(employees, employees.canLogin);
              await customStatement(
                  'UPDATE employees SET can_login = 1 WHERE can_login IS NULL');
              print('Added can_login column to employees table');
            } catch (e) {
              print('can_login column might already exist: $e');
            }
            // Add username and email to employees for version 11 (supporting both old and new)
            try {
              await m.addColumn(employees, employees.username);
              await m.addColumn(employees, employees.email);
              print('Added username and email columns to employees table');
            } catch (e) {
              print('username/email columns might already exist: $e');
            }
          }
          if (from < 12) {
            // Add creditDays and unclearCheque columns to suppliers table for version 12
            try {
              await m.addColumn(suppliers, suppliers.creditDays);
              await m.addColumn(suppliers, suppliers.unclearCheque);
              // Set default values for existing suppliers
              await customStatement(
                  'UPDATE suppliers SET credit_days = 0 WHERE credit_days IS NULL');
              await customStatement(
                  'UPDATE suppliers SET unclear_cheque = 0 WHERE unclear_cheque IS NULL');
              print(
                  'Added credit_days and unclear_cheque columns to suppliers table');
            } catch (e) {
              print(
                  'Columns credit_days or unclear_cheque might already exist: $e');
            }
          }
          if (from < 13) {
            // Add creditDays column to customers table for version 13
            try {
              await m.addColumn(customers, customers.creditDays);
              // Set default value for existing customers
              await customStatement(
                  'UPDATE customers SET credit_days = 0 WHERE credit_days IS NULL');
            } catch (e) {
              // If the column already exists, ignore the error
              print('Column credit_days might already exist: $e');
            }
          }
          if (from < 14) {
            // Add unclearCheque column to customers table for version 14
            try {
              await m.addColumn(customers, customers.unclearCheque);
              // Set default value for existing customers
              await customStatement(
                  'UPDATE customers SET unclear_cheque = 0 WHERE unclear_cheque IS NULL');
              print('Added unclear_cheque column to customers table');
            } catch (e) {
              // If the column already exists, ignore the error
              print('Column unclear_cheque might already exist: $e');
            }
          }
          if (from < 15) {
            try {
              await m.addColumn(customers, customers.isRetailCustomer);
              await customStatement(
                  'UPDATE customers SET is_retail_customer = 1 WHERE is_retail_customer IS NULL');
            } catch (e) {
              print('Column is_retail_customer might already exist: $e');
            }
            try {
              await m.addColumn(customers, customers.isWholesaleCustomer);
              await customStatement(
                  'UPDATE customers SET is_wholesale_customer = 0 WHERE is_wholesale_customer IS NULL');
            } catch (e) {
              print('Column is_wholesale_customer might already exist: $e');
            }
            print('Upgraded customers table with retail/wholesale flags');
          }
          if (from < 16) {
            try {
              await m.addColumn(customers, customers.isActive);
              await customStatement(
                  'UPDATE customers SET is_active = 1 WHERE is_active IS NULL');
              print('Added is_active column to customers table');
            } catch (e) {
              print('Column is_active might already exist: $e');
            }
          }
          if (from < 17) {
            try {
              await m.addColumn(payments, payments.processedByEmployeeId);
              print('Added processed_by_employee_id column to payments table');
            } catch (e) {
              print('Column processed_by_employee_id might already exist: $e');
            }
          }
          if (from < 18) {
            try {
              await m.addColumn(suppliers, suppliers.code);
              await customStatement(
                  "UPDATE suppliers SET code = 'SUP-' || printf('%04d', id) WHERE code IS NULL OR code = ''");
              print('Added code column to suppliers table');
            } catch (e) {
              print('Column code on suppliers might already exist: $e');
            }
          }
          if (from < 19) {
            // Add ExpenseHeads table for version 19
            try {
              await m.createTable(expenseHeads);
              print('Added ExpenseHeads table');
            } catch (e) {
              print('ExpenseHeads table might already exist: $e');
            }
          }
          if (from < 20) {
            // Add mobile shop specific fields to products table for version 20
            try {
              await m.addColumn(products, products.brand);
              await m.addColumn(products, products.modelName);
              await m.addColumn(products, products.storageCapacity);
              await m.addColumn(products, products.ram);
              await m.addColumn(products, products.color);
              await m.addColumn(products, products.condition);
              await m.addColumn(products, products.unlockStatus);
              await m.addColumn(products, products.warrantyStatus);
              await m.addColumn(products, products.warrantyPeriod);
              await m.addColumn(products, products.warrantyProvider);
              await m.addColumn(products, products.displaySize);
              await m.addColumn(products, products.batteryCapacity);
              await m.addColumn(products, products.cameraSpecs);
              await m.addColumn(products, products.operatingSystem);
              await m.addColumn(products, products.networkType);
              await m.addColumn(products, products.simCardType);
              await m.addColumn(products, products.tradeInValue);
              await m.addColumn(products, products.boxContents);
              print('Added mobile shop columns to products table');
            } catch (e) {
              print('Mobile shop columns might already exist: $e');
            }
            // Add IMEI column to sale_items table
            try {
              await m.addColumn(saleItems, saleItems.imei);
              print('Added imei column to sale_items table');
            } catch (e) {
              print('imei column might already exist: $e');
            }
            // Create ProductIMEIs table
            try {
              await m.createTable(productIMEIs);
              print('Added ProductIMEIs table');
            } catch (e) {
              print('ProductIMEIs table might already exist: $e');
            }
          }
          if (from < 21) {
            // Add restaurant specific fields to products table for version 21
            try {
              await m.addColumn(products, products.courseType);
              await m.addColumn(products, products.preparationTime);
              await m.addColumn(products, products.allergens);
              await m.addColumn(products, products.modifiers);
              await m.addColumn(products, products.dietaryInfo);
              print('Added restaurant columns to products table');
            } catch (e) {
              print('Restaurant product columns might already exist: $e');
            }
            // Add restaurant specific fields to sales table
            try {
              await m.addColumn(sales, sales.tableNumber);
              await m.addColumn(sales, sales.orderType);
              await m.addColumn(sales, sales.serviceCharge);
              await m.addColumn(sales, sales.tip);
              await m.addColumn(sales, sales.numberOfGuests);
              print('Added restaurant columns to sales table');
            } catch (e) {
              print('Restaurant sales columns might already exist: $e');
            }
            // Add restaurant specific fields to sale_items table
            try {
              await m.addColumn(saleItems, saleItems.specialInstructions);
              await m.addColumn(saleItems, saleItems.modifiers);
              print('Added restaurant columns to sale_items table');
            } catch (e) {
              print('Restaurant sale_items columns might already exist: $e');
            }
          }
          if (from < 22) {
            // Add product bundles tables for version 22
            try {
              await m.createTable(productBundles);
              await m.createTable(productBundleItems);
              print('Added ProductBundles and ProductBundleItems tables');
            } catch (e) {
              print('Product bundles tables might already exist: $e');
            }
          }
          if (from < 23) {
            // Add employeeId column to stock_adjustments table for version 23
            try {
              await m.addColumn(stockAdjustments, stockAdjustments.employeeId);
              print('Added employeeId column to stock_adjustments table');
            } catch (e) {
              print('employeeId column might already exist: $e');
            }
          }
          if (from < 24) {
            // Add salon-specific fields for version 24
            try {
              // Add commissionPercentage to employees table
              await m.addColumn(employees, employees.commissionPercentage);
              print('Added commissionPercentage column to employees table');
            } catch (e) {
              print('commissionPercentage column might already exist: $e');
            }
            try {
              // Add productType to products table
              await m.addColumn(products, products.productType);
              print('Added productType column to products table');
            } catch (e) {
              print('productType column might already exist: $e');
            }
            try {
              // Create employee commissions table
              await m.createTable(employeeCommissions);
              print('Added EmployeeCommissions table');
            } catch (e) {
              print('EmployeeCommissions table might already exist: $e');
            }
          }
          if (from < 25) {
            // Add product ingredients table for restaurant ingredient-level costing (version 25)
            try {
              await m.createTable(productIngredients);
              print('Added ProductIngredients table');
            } catch (e) {
              print('ProductIngredients table might already exist: $e');
            }
          }
        },
        beforeOpen: (OpeningDetails details) async {
          // Custom migration to ensure due_date column exists
          if (details.wasCreated == false) {
            try {
              await customStatement(
                  'ALTER TABLE sales ADD COLUMN due_date TEXT');
              print('Added due_date column to sales table');
            } catch (e) {
              // Column might already exist, ignore error
              print('due_date column might already exist: $e');
            }
            // Ensure creditLimit exists
            try {
              await customStatement(
                  'ALTER TABLE customers ADD COLUMN credit_limit REAL DEFAULT 0');
              print('Added credit_limit column to customers table');
            } catch (e) {
              print('credit_limit column might already exist: $e');
            }
            // Ensure username and email columns exist in employees
            try {
              await customStatement(
                  'ALTER TABLE employees ADD COLUMN username TEXT');
              await customStatement(
                  'ALTER TABLE employees ADD COLUMN email TEXT');
              print('Added username/email columns to employees table');
            } catch (e) {
              print('username/email columns might already exist: $e');
            }
            // Ensure canLogin exists in employees
            try {
              await customStatement(
                  'ALTER TABLE employees ADD COLUMN can_login INTEGER DEFAULT 1');
              print('Added can_login column to employees table');
            } catch (e) {
              print('can_login column might already exist: $e');
            }
            // Ensure isWholesale exists in sales
            try {
              await customStatement(
                  'ALTER TABLE sales ADD COLUMN is_wholesale INTEGER DEFAULT 0');
              print('Added is_wholesale column to sales table');
            } catch (e) {
              print('is_wholesale column might already exist: $e');
            }
            // Ensure creditDays exists in customers
            try {
              await customStatement(
                  'ALTER TABLE customers ADD COLUMN credit_days INTEGER DEFAULT 0');
              print('Added credit_days column to customers table');
            } catch (e) {
              print('credit_days column might already exist: $e');
            }
            // Ensure unclearCheque exists in customers
            try {
              await customStatement(
                  'ALTER TABLE customers ADD COLUMN unclear_cheque REAL DEFAULT 0');
              print('Added unclear_cheque column to customers table');
            } catch (e) {
              print('unclear_cheque column might already exist: $e');
            }
            // Ensure ExpenseHeads table exists
            try {
              await customStatement('''
            CREATE TABLE IF NOT EXISTS expense_heads (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL CHECK(length(name) >= 1 AND length(name) <= 255),
              description TEXT,
              job_type TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
              print('Created ExpenseHeads table in beforeOpen');
            } catch (e) {
              print('ExpenseHeads table might already exist: $e');
            }
            // Ensure isActive exists in customers
            try {
              await customStatement(
                  'ALTER TABLE customers ADD COLUMN is_active INTEGER DEFAULT 1');
              print('Added is_active column to customers table');
            } catch (e) {
              print('is_active column might already exist: $e');
            }
            // Ensure processedByEmployeeId exists in payments
            try {
              await customStatement(
                  'ALTER TABLE payments ADD COLUMN processed_by_employee_id INTEGER REFERENCES employees(id)');
              print('Added processed_by_employee_id column to payments table');
            } catch (e) {
              print('processed_by_employee_id column might already exist: $e');
            }
            // Ensure createdBy exists in supplier_payments
            try {
              await customStatement(
                  'ALTER TABLE supplier_payments ADD COLUMN created_by TEXT');
              print('Added created_by column to supplier_payments table');
            } catch (e) {
              print('created_by column might already exist: $e');
            }
            // Ensure commissionPercentage exists in employees (for salon)
            try {
              await customStatement(
                  'ALTER TABLE employees ADD COLUMN commission_percentage REAL');
              print('Added commission_percentage column to employees table');
            } catch (e) {
              print('commission_percentage column might already exist: $e');
            }
            // Ensure productType exists in products (for salon)
            try {
              await customStatement(
                  'ALTER TABLE products ADD COLUMN product_type TEXT');
              print('Added product_type column to products table');
            } catch (e) {
              print('product_type column might already exist: $e');
            }
            // Ensure EmployeeCommissions table exists (for salon)
            try {
              await customStatement('''
            CREATE TABLE IF NOT EXISTS employee_commissions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              employee_id INTEGER NOT NULL REFERENCES employees(id),
              transaction_type TEXT NOT NULL CHECK(length(transaction_type) >= 1 AND length(transaction_type) <= 20),
              sale_id INTEGER REFERENCES sales(id),
              amount REAL NOT NULL,
              commission_percentage REAL,
              sale_amount REAL,
              balance_after REAL,
              date TEXT NOT NULL,
              notes TEXT,
              processed_by TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
              print('Created EmployeeCommissions table in beforeOpen');
            } catch (e) {
              print('EmployeeCommissions table might already exist: $e');
            }
            // Ensure ProductIngredients table exists (for restaurant ingredient-level costing)
            try {
              await customStatement('''
            CREATE TABLE IF NOT EXISTS product_ingredients (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              product_id INTEGER NOT NULL REFERENCES products(id),
              ingredient_product_id INTEGER NOT NULL REFERENCES products(id),
              quantity REAL NOT NULL,
              unit TEXT NOT NULL CHECK(length(unit) >= 1 AND length(unit) <= 50),
              cost_type TEXT NOT NULL CHECK(length(cost_type) >= 1 AND length(cost_type) <= 20),
              fixed_cost REAL,
              sort_order INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
              print('Created ProductIngredients table in beforeOpen');
            } catch (e) {
              print('ProductIngredients table might already exist: $e');
            }
          }
        },
      );

  // Products CRUD
  Future<List<Product>> getAllProducts() => select(products).get();

  Future<Product?> getProductById(int id) =>
      (select(products)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<Product?> getProductByBarcode(String barcode) async {
    // Use getFirst instead of getSingleOrNull: barcode has no unique
    // constraint at the DB level, so a duplicate must not crash lookups
    // (e.g. scanning at checkout) — just resolve to the first match.
    final matches = await (select(products)
          ..where((tbl) => tbl.barcode.equals(barcode))
          ..limit(1))
        .get();
    return matches.isEmpty ? null : matches.first;
  }

  /// Returns all products sharing [barcode], used to detect duplicates before save.
  Future<List<Product>> getProductsByBarcode(String barcode) =>
      (select(products)..where((tbl) => tbl.barcode.equals(barcode))).get();

  Future<List<Product>> getProductsByCategory(String category) =>
      (select(products)..where((tbl) => tbl.category.equals(category))).get();

  Future<Product?> getProductByName(String name) {
    final normalized = name.trim().toLowerCase();
    return (select(products)
          ..where((tbl) =>
              tbl.name.lower().equals(normalized) & tbl.isActive.equals(true)))
        .getSingleOrNull();
  }

  Future<List<Product>> getLowStockProducts(double threshold) =>
      (select(products)
            ..where((tbl) => tbl.stock.isSmallerThanValue(threshold)))
          .get();

  Future<int> insertProduct(ProductsCompanion product) =>
      into(products).insert(product);

  Future<bool> updateProduct(Product product) =>
      update(products).replace(product);

  Future<int> deleteProduct(int id) =>
      (delete(products)..where((tbl) => tbl.id.equals(id))).go();

  // Product Bundles CRUD
  Future<List<ProductBundle>> getAllBundles() =>
      (select(productBundles)..where((tbl) => tbl.isActive.equals(true))).get();

  Future<ProductBundle?> getBundleById(int id) =>
      (select(productBundles)..where((tbl) => tbl.id.equals(id)))
          .getSingleOrNull();

  Future<List<ProductBundle>> getBundlesByCategory(String category) =>
      (select(productBundles)
            ..where((tbl) =>
                tbl.category.equals(category) & tbl.isActive.equals(true)))
          .get();

  Future<int> insertBundle(ProductBundlesCompanion bundle) =>
      into(productBundles).insert(bundle);

  Future<bool> updateBundle(ProductBundle bundle) =>
      update(productBundles).replace(bundle);

  Future<int> deleteBundle(int id) =>
      (delete(productBundles)..where((tbl) => tbl.id.equals(id))).go();

  // Product Bundle Items CRUD
  Future<List<ProductBundleItem>> getBundleItemsByBundleId(int bundleId) =>
      (select(productBundleItems)
            ..where((tbl) => tbl.bundleId.equals(bundleId)))
          .get();

  Future<int> insertBundleItem(ProductBundleItemsCompanion item) =>
      into(productBundleItems).insert(item);

  Future<int> deleteBundleItemsByBundleId(int bundleId) =>
      (delete(productBundleItems)
            ..where((tbl) => tbl.bundleId.equals(bundleId)))
          .go();

  // Product Ingredients CRUD
  Future<List<ProductIngredient>> getIngredientsByProductId(int productId) =>
      (select(productIngredients)
            ..where((tbl) => tbl.productId.equals(productId))
            ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortOrder)]))
          .get();

  Future<ProductIngredient?> getIngredientById(int id) =>
      (select(productIngredients)..where((tbl) => tbl.id.equals(id)))
          .getSingleOrNull();

  Future<int> insertIngredient(ProductIngredientsCompanion ingredient) =>
      into(productIngredients).insert(ingredient);

  Future<bool> updateIngredient(ProductIngredient ingredient) =>
      update(productIngredients).replace(ingredient);

  Future<int> deleteIngredient(int id) =>
      (delete(productIngredients)..where((tbl) => tbl.id.equals(id))).go();

  Future<int> deleteIngredientsByProductId(int productId) =>
      (delete(productIngredients)
            ..where((tbl) => tbl.productId.equals(productId)))
          .go();

  // Customers CRUD
  // Return ALL customers (both active and inactive) - filtering should be done in UI
  Future<List<Customer>> getAllCustomers() => select(customers).get();

  Future<Customer?> getCustomerById(int id) =>
      (select(customers)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<Customer?> getCustomerByPhone(String phone) =>
      (select(customers)..where((tbl) => tbl.phone.equals(phone)))
          .getSingleOrNull();

  Future<List<Customer>> getCustomersWithDue() => (select(customers)
        ..where(
          (tbl) =>
              tbl.totalDue.isBiggerThanValue(0) & tbl.isActive.equals(true),
        ))
      .get();

  Future<int> insertCustomer(CustomersCompanion customer) =>
      into(customers).insert(customer);

  Future<bool> updateCustomer(Customer customer) =>
      update(customers).replace(customer);

  Future<int> deleteCustomer(int id) =>
      (delete(customers)..where((tbl) => tbl.id.equals(id))).go();

  // Sales CRUD
  Future<List<Sale>> getAllSales() => select(sales).get();

  Future<Sale?> getSaleById(int id) =>
      (select(sales)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) =>
      (select(sales)
            ..where((tbl) => tbl.date.isBetweenValues(
                start.toIso8601String(), end.toIso8601String())))
          .get();

  Future<List<Sale>> getSalesByCustomer(int customerId) =>
      (select(sales)..where((tbl) => tbl.customerId.equals(customerId))).get();

  Future<List<Sale>> getUnpaidSales() =>
      (select(sales)..where((tbl) => tbl.status.equals('unpaid'))).get();

  Future<int> insertSale(SalesCompanion sale) => into(sales).insert(sale);

  Future<bool> updateSale(Sale sale) => update(sales).replace(sale);

  Future<int> deleteSale(int id) =>
      (delete(sales)..where((tbl) => tbl.id.equals(id))).go();

  // Sale Items CRUD
  Future<List<SaleItem>> getSaleItemsBySaleId(int saleId) =>
      (select(saleItems)..where((tbl) => tbl.saleId.equals(saleId))).get();

  Future<int> insertSaleItem(SaleItemsCompanion item) =>
      into(saleItems).insert(item);

  Future<int> deleteSaleItemsBySaleId(int saleId) =>
      (delete(saleItems)..where((tbl) => tbl.saleId.equals(saleId))).go();

  // Payments CRUD
  Future<List<Payment>> getPaymentsByCustomer(int customerId) =>
      (select(payments)..where((tbl) => tbl.customerId.equals(customerId)))
          .get();

  Future<List<Payment>> getPaymentsByDateRange(DateTime start, DateTime end) =>
      (select(payments)
            ..where((tbl) => tbl.date.isBetweenValues(
                start.toIso8601String(), end.toIso8601String())))
          .get();

  Future<List<Payment>> getPaymentsBySaleId(int saleId) =>
      (select(payments)..where((tbl) => tbl.saleId.equals(saleId))).get();

  Future<int> insertPayment(PaymentsCompanion payment) =>
      into(payments).insert(payment);

  Future<bool> updatePayment(Payment payment) =>
      update(payments).replace(payment);

  Future<Payment?> getPaymentById(int id) =>
      (select(payments)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<int> deletePayment(int id) =>
      (delete(payments)..where((tbl) => tbl.id.equals(id))).go();

  // Settings CRUD
  Future<String?> getSetting(String key) async {
    final setting = await (select(settings)
          ..where((tbl) => tbl.key.equals(key)))
        .getSingleOrNull();
    return setting?.value;
  }

  Future<List<Setting>> getAllSettings() async {
    return await select(settings).get();
  }

  Future<void> setSetting(String key, String value) async {
    // Use update-then-insert strategy for broad SQLite compatibility
    final updated = await (update(settings)
          ..where((tbl) => tbl.key.equals(key)))
        .write(SettingsCompanion(value: Value(value)));
    if (updated == 0) {
      await into(settings).insert(SettingsCompanion(
        key: Value(key),
        value: Value(value),
      ));
    }
  }

  // Employees CRUD
  Future<List<Employee>> getAllEmployees() => select(employees).get();

  Future<Employee?> getEmployeeById(int id) =>
      (select(employees)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<Employee?> getEmployeeByUsername(String username) =>
      (select(employees)..where((tbl) => tbl.username.equals(username)))
          .getSingleOrNull();

  Future<List<Employee>> getActiveEmployees() =>
      (select(employees)..where((tbl) => tbl.isActive.equals(true))).get();

  Future<int> insertEmployee(EmployeesCompanion employee) =>
      into(employees).insert(employee);

  Future<bool> updateEmployee(Employee employee) =>
      update(employees).replace(employee);

  Future<int> deleteEmployee(int id) =>
      (delete(employees)..where((tbl) => tbl.id.equals(id))).go();

  // Stock Adjustments CRUD
  Future<List<StockAdjustment>> getAllStockAdjustments() =>
      (select(stockAdjustments)..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<StockAdjustment?> getStockAdjustmentById(int id) =>
      (select(stockAdjustments)..where((tbl) => tbl.id.equals(id)))
          .getSingleOrNull();

  Future<List<StockAdjustment>> getStockAdjustmentsByProduct(int productId) =>
      (select(stockAdjustments)
            ..where((tbl) => tbl.productId.equals(productId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<List<StockAdjustment>> getStockAdjustmentsByDateRange(
          DateTime start, DateTime end) =>
      (select(stockAdjustments)
            ..where((tbl) =>
                tbl.date.isBiggerOrEqualValue(start.toIso8601String()) &
                tbl.date.isSmallerOrEqualValue(end.toIso8601String()))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<List<StockAdjustment>> getStockAdjustmentsByReason(String reason) =>
      (select(stockAdjustments)
            ..where((tbl) => tbl.reason.equals(reason))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<int> insertStockAdjustment(StockAdjustmentsCompanion adjustment) =>
      into(stockAdjustments).insert(adjustment);

  Future<bool> deleteStockAdjustment(int id) =>
      (delete(stockAdjustments)..where((tbl) => tbl.id.equals(id)))
          .go()
          .then((value) => value > 0);

  // Expenses CRUD
  Future<List<Expense>> getAllExpenses() =>
      (select(expenses)..orderBy([(t) => OrderingTerm.desc(t.date)])).get();

  Future<Expense?> getExpenseById(int id) =>
      (select(expenses)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end) =>
      (select(expenses)
            ..where((tbl) =>
                tbl.date.isBiggerOrEqualValue(start.toIso8601String()) &
                tbl.date.isSmallerOrEqualValue(end.toIso8601String()))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<List<Expense>> getExpensesByCategory(String category) =>
      (select(expenses)
            ..where((tbl) => tbl.category.equals(category))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<List<Expense>> getExpensesByPaymentMethod(String method) =>
      (select(expenses)
            ..where((tbl) => tbl.paymentMethod.equals(method))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<int> insertExpense(ExpensesCompanion expense) =>
      into(expenses).insert(expense);

  Future<bool> updateExpense(Expense expense) =>
      update(expenses).replace(expense);

  Future<int> deleteExpense(int id) =>
      (delete(expenses)..where((tbl) => tbl.id.equals(id))).go();

  // Expense Heads CRUD
  Future<List<ExpenseHead>> getAllExpenseHeads() =>
      (select(expenseHeads)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<ExpenseHead?> getExpenseHeadById(int id) =>
      (select(expenseHeads)..where((tbl) => tbl.id.equals(id)))
          .getSingleOrNull();

  Future<int> insertExpenseHead(ExpenseHeadsCompanion expenseHead) =>
      into(expenseHeads).insert(expenseHead);

  Future<bool> updateExpenseHead(ExpenseHead expenseHead) =>
      update(expenseHeads).replace(expenseHead);

  Future<int> deleteExpenseHead(int id) =>
      (delete(expenseHeads)..where((tbl) => tbl.id.equals(id))).go();

  // Categories CRUD
  Future<List<Category>> getAllCategories() => select(categories).get();

  Future<Category?> getCategoryById(int id) =>
      (select(categories)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<int> insertCategory(CategoriesCompanion category) =>
      into(categories).insert(category);

  Future<bool> updateCategory(Category category) =>
      update(categories).replace(category);

  Future<int> deleteCategory(int id) =>
      (delete(categories)..where((tbl) => tbl.id.equals(id))).go();

  // Suppliers CRUD
  Future<List<Supplier>> getAllSuppliers() =>
      (select(suppliers)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<Supplier?> getSupplierById(int id) =>
      (select(suppliers)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<List<Supplier>> getActiveSuppliers() => (select(suppliers)
        ..where((tbl) => tbl.isActive.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .get();

  Future<int> insertSupplier(SuppliersCompanion supplier) =>
      into(suppliers).insert(supplier);

  Future<bool> updateSupplier(Supplier supplier) =>
      update(suppliers).replace(supplier);

  Future<int> deleteSupplier(int id) =>
      (delete(suppliers)..where((tbl) => tbl.id.equals(id))).go();

  // Supplier Payments CRUD
  Future<List<SupplierPayment>> getSupplierPayments(int supplierId) =>
      (select(supplierPayments)
            ..where((tbl) => tbl.supplierId.equals(supplierId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<SupplierPayment?> getSupplierPaymentById(int id) =>
      (select(supplierPayments)..where((tbl) => tbl.id.equals(id)))
          .getSingleOrNull();

  Future<List<SupplierPayment>> getSupplierPaymentsByDateRange(
          int supplierId, DateTime start, DateTime end) =>
      (select(supplierPayments)
            ..where((tbl) => tbl.supplierId.equals(supplierId))
            ..where(
                (tbl) => tbl.date.isBiggerOrEqualValue(start.toIso8601String()))
            ..where(
                (tbl) => tbl.date.isSmallerOrEqualValue(end.toIso8601String()))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<int> insertSupplierPayment(SupplierPaymentsCompanion payment) =>
      into(supplierPayments).insert(payment);

  Future<bool> updateSupplierPayment(SupplierPayment payment) =>
      update(supplierPayments).replace(payment);

  Future<int> deleteSupplierPayment(int id) =>
      (delete(supplierPayments)..where((tbl) => tbl.id.equals(id))).go();

  // Banks CRUD
  Future<List<Bank>> getAllBanks() =>
      (select(banks)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<Bank?> getBankById(int id) =>
      (select(banks)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<List<Bank>> getActiveBanks() => (select(banks)
        ..where((tbl) => tbl.isActive.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .get();

  Future<int> insertBank(BanksCompanion bank) => into(banks).insert(bank);

  Future<bool> updateBank(Bank bank) => update(banks).replace(bank);

  Future<int> deleteBank(int id) =>
      (delete(banks)..where((tbl) => tbl.id.equals(id))).go();

  // Bank Payments CRUD
  Future<List<BankPayment>> getBankPayments(int bankId) => (select(bankPayments)
        ..where((tbl) => tbl.bankId.equals(bankId))
        ..orderBy([(t) => OrderingTerm.desc(t.issueDate)]))
      .get();

  Future<List<BankPayment>> getBankPaymentsByDateRange(
          DateTime start, DateTime end) =>
      (select(bankPayments)
            ..where((tbl) =>
                tbl.issueDate.isBiggerOrEqualValue(start.toIso8601String()) &
                tbl.issueDate.isSmallerOrEqualValue(end.toIso8601String()))
            ..orderBy([(t) => OrderingTerm.desc(t.issueDate)]))
          .get();

  Future<List<BankPayment>> getBankPaymentsByParty(String partyName) =>
      (select(bankPayments)
            ..where((tbl) => tbl.partyName.like('%$partyName%'))
            ..orderBy([(t) => OrderingTerm.desc(t.issueDate)]))
          .get();

  Future<List<BankPayment>> getBankPaymentsByChequeNumber(
          String chequeNumber) =>
      (select(bankPayments)
            ..where((tbl) => tbl.chequeNumber.like('%$chequeNumber%'))
            ..orderBy([(t) => OrderingTerm.desc(t.issueDate)]))
          .get();

  Future<int> insertBankPayment(BankPaymentsCompanion payment) =>
      into(bankPayments).insert(payment);

  Future<bool> updateBankPayment(BankPayment payment) =>
      update(bankPayments).replace(payment);

  Future<bool> updateBankPaymentStatus(int id, String status) async {
    final result = await (update(bankPayments)
          ..where((tbl) => tbl.id.equals(id)))
        .write(BankPaymentsCompanion(
      status: Value(status),
      updatedAt: Value(DateTime.now().toIso8601String()),
    ));
    return result > 0;
  }

  Future<int> deleteBankPayment(int id) =>
      (delete(bankPayments)..where((tbl) => tbl.id.equals(id))).go();

  // Staff Performance operations
  Future<List<StaffPerformance>> getAllStaffPerformance() =>
      select(staffPerformances).get();

  Future<StaffPerformance?> getStaffPerformanceById(int id) =>
      (select(staffPerformances)..where((tbl) => tbl.id.equals(id)))
          .getSingleOrNull();

  Future<List<StaffPerformance>> getStaffPerformanceByEmployee(
          int employeeId) =>
      (select(staffPerformances)
            ..where((tbl) => tbl.employeeId.equals(employeeId)))
          .get();

  Future<List<StaffPerformance>> getStaffPerformanceByDateRange(
          DateTime start, DateTime end) =>
      (select(staffPerformances)
            ..where((tbl) => tbl.date.isBetweenValues(
                start.toIso8601String(), end.toIso8601String())))
          .get();

  Future<int> insertStaffPerformance(StaffPerformancesCompanion performance) =>
      into(staffPerformances).insert(performance);

  Future<bool> updateStaffPerformance(StaffPerformance performance) =>
      update(staffPerformances).replace(performance);

  Future<int> deleteStaffPerformance(int id) =>
      (delete(staffPerformances)..where((tbl) => tbl.id.equals(id))).go();

  Future<List<Map<String, dynamic>>> getStaffPerformanceSummary() async {
    // This would need to be implemented with a custom query
    // For now, return empty list
    return [];
  }

  Future<List<Map<String, dynamic>>> getTopPerformers(int limit) async {
    // This would need to be implemented with a custom query
    // For now, return empty list
    return [];
  }

  Future<Map<String, dynamic>> getStaffPerformanceAnalytics() async {
    // This would need to be implemented with custom queries
    // For now, return empty map
    return {};
  }

  // Database cleanup and reset methods
  static const String _installKey = 'app_install_timestamp';
  static const String _databaseVersionKey = 'database_version';

  /// Check if this is a fresh install or if database needs to be reset
  static Future<bool> isFreshInstall() async {
    final prefs = await SharedPreferences.getInstance();
    final installTimestamp = prefs.getInt(_installKey);
    final currentVersion = prefs.getInt(_databaseVersionKey);

    // If no install timestamp or version mismatch, consider it fresh
    // Schema version is 13, so we check for that
    if (installTimestamp == null || currentVersion != 13) {
      return true;
    }

    // Check if database file exists
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'pos_database.db'));
    return !dbFile.existsSync();
  }

  /// Mark the app as installed and set database version
  static Future<void> markAsInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_installKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_databaseVersionKey, 13);
  }

  /// Reset the entire database (delete all data)
  Future<void> resetDatabase() async {
    try {
      // Delete all data from all tables
      await delete(products).go();
      await delete(customers).go();
      await delete(sales).go();
      await delete(saleItems).go();
      await delete(payments).go();
      await delete(settings).go();
      await delete(stockAdjustments).go();
      await delete(categories).go();
      await delete(suppliers).go();
      await delete(purchaseOrders).go();
      await delete(purchaseOrderItems).go();
      await delete(employees).go();
      await delete(returns).go();
      await delete(returnItems).go();
      await delete(expenses).go();
      await delete(supplierPayments).go();
      await delete(banks).go();
      await delete(bankPayments).go();
      await delete(staffPerformances).go();

      print('Database reset completed successfully');
    } catch (e) {
      print('Error resetting database: $e');
      rethrow;
    }
  }

  /// Delete the entire database file
  static Future<void> deleteDatabaseFile() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'pos_database.db'));

      if (dbFile.existsSync()) {
        await dbFile.delete();
        print('Database file deleted successfully');
      }

      // Also delete any backup files
      final backupFile = File(p.join(dbFolder.path, 'pos_database.db-wal'));
      if (backupFile.existsSync()) {
        await backupFile.delete();
      }

      final shmFile = File(p.join(dbFolder.path, 'pos_database.db-shm'));
      if (shmFile.existsSync()) {
        await shmFile.delete();
      }
    } catch (e) {
      print('Error deleting database file: $e');
      rethrow;
    }
  }

  // Purchase Orders CRUD
  Future<List<PurchaseOrder>> getAllPurchaseOrders() =>
      (select(purchaseOrders)..orderBy([(t) => OrderingTerm.desc(t.orderDate)]))
          .get();

  Future<PurchaseOrder?> getPurchaseOrderById(int id) =>
      (select(purchaseOrders)..where((tbl) => tbl.id.equals(id)))
          .getSingleOrNull();

  Future<List<PurchaseOrder>> getPurchaseOrdersBySupplier(int supplierId) =>
      (select(purchaseOrders)
            ..where((tbl) => tbl.supplierId.equals(supplierId))
            ..orderBy([(t) => OrderingTerm.desc(t.orderDate)]))
          .get();

  Future<List<PurchaseOrder>> getPurchaseOrdersByStatus(String status) =>
      (select(purchaseOrders)
            ..where((tbl) => tbl.status.equals(status))
            ..orderBy([(t) => OrderingTerm.desc(t.orderDate)]))
          .get();

  Future<List<PurchaseOrder>> getPurchaseOrdersByDateRange(
          DateTime start, DateTime end) =>
      (select(purchaseOrders)
            ..where((tbl) =>
                tbl.orderDate.isBiggerOrEqualValue(start.toIso8601String()) &
                tbl.orderDate.isSmallerOrEqualValue(end.toIso8601String()))
            ..orderBy([(t) => OrderingTerm.desc(t.orderDate)]))
          .get();

  Future<int> insertPurchaseOrder(PurchaseOrdersCompanion order) =>
      into(purchaseOrders).insert(order);

  Future<bool> updatePurchaseOrder(PurchaseOrder order) =>
      update(purchaseOrders).replace(order);

  Future<int> deletePurchaseOrder(int id) =>
      (delete(purchaseOrders)..where((tbl) => tbl.id.equals(id))).go();

  // Purchase Order Items CRUD
  Future<List<PurchaseOrderItem>> getPurchaseOrderItems(int orderId) =>
      (select(purchaseOrderItems)
            ..where((tbl) => tbl.purchaseOrderId.equals(orderId)))
          .get();

  Future<int> insertPurchaseOrderItem(PurchaseOrderItemsCompanion item) =>
      into(purchaseOrderItems).insert(item);

  Future<bool> updatePurchaseOrderItem(PurchaseOrderItem item) =>
      update(purchaseOrderItems).replace(item);

  Future<int> deletePurchaseOrderItem(int id) =>
      (delete(purchaseOrderItems)..where((tbl) => tbl.id.equals(id))).go();

  Future<int> deletePurchaseOrderItems(int orderId) =>
      (delete(purchaseOrderItems)
            ..where((tbl) => tbl.purchaseOrderId.equals(orderId)))
          .go();

  // Returns CRUD
  Future<List<Return>> getAllReturns() =>
      (select(returns)..orderBy([(t) => OrderingTerm.desc(t.returnDate)]))
          .get();

  Future<Return?> getReturnById(int id) =>
      (select(returns)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<List<Return>> getReturnsByCustomer(int customerId) => (select(returns)
        ..where((tbl) => tbl.customerId.equals(customerId))
        ..orderBy([(t) => OrderingTerm.desc(t.returnDate)]))
      .get();

  Future<List<Return>> getReturnsBySale(int saleId) => (select(returns)
        ..where((tbl) => tbl.originalSaleId.equals(saleId))
        ..orderBy([(t) => OrderingTerm.desc(t.returnDate)]))
      .get();

  Future<List<Return>> getReturnsByStatus(String status) => (select(returns)
        ..where((tbl) => tbl.status.equals(status))
        ..orderBy([(t) => OrderingTerm.desc(t.returnDate)]))
      .get();

  Future<List<Return>> getReturnsByDateRange(DateTime start, DateTime end) =>
      (select(returns)
            ..where((tbl) =>
                tbl.returnDate.isBiggerOrEqualValue(start.toIso8601String()) &
                tbl.returnDate.isSmallerOrEqualValue(end.toIso8601String()))
            ..orderBy([(t) => OrderingTerm.desc(t.returnDate)]))
          .get();

  Future<int> insertReturn(ReturnsCompanion returnData) =>
      into(returns).insert(returnData);

  Future<bool> updateReturn(Return returnData) =>
      update(returns).replace(returnData);

  Future<int> deleteReturn(int id) =>
      (delete(returns)..where((tbl) => tbl.id.equals(id))).go();

  // Return Items CRUD
  Future<List<ReturnItem>> getReturnItems(int returnId) =>
      (select(returnItems)..where((tbl) => tbl.returnId.equals(returnId)))
          .get();

  Future<int> insertReturnItem(ReturnItemsCompanion item) =>
      into(returnItems).insert(item);

  Future<bool> updateReturnItem(ReturnItem item) =>
      update(returnItems).replace(item);

  Future<int> deleteReturnItem(int id) =>
      (delete(returnItems)..where((tbl) => tbl.id.equals(id))).go();

  Future<int> deleteReturnItems(int returnId) =>
      (delete(returnItems)..where((tbl) => tbl.returnId.equals(returnId))).go();

  // Complex queries
  Future<List<SaleWithItems>> getSalesWithItems() async {
    final query = select(sales).join([
      leftOuterJoin(saleItems, saleItems.saleId.equalsExp(sales.id)),
      leftOuterJoin(products, products.id.equalsExp(saleItems.productId)),
    ]);

    final results = await query.get();
    final Map<int, SaleWithItems> salesMap = {};

    for (final row in results) {
      final sale = row.readTable(sales);
      final saleItem = row.readTableOrNull(saleItems);
      final product = row.readTableOrNull(products);

      if (!salesMap.containsKey(sale.id)) {
        salesMap[sale.id] = SaleWithItems(
          sale: sale,
          items: [],
        );
      }

      if (saleItem != null && product != null) {
        salesMap[sale.id]!.items.add(SaleItemWithProduct(
              saleItem: saleItem,
              product: product,
            ));
      }
    }

    return salesMap.values.toList();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pos_database.db'));

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file, setup: (rawDb) {
      // Enable foreign keys
      rawDb.execute('PRAGMA foreign_keys = ON;');

      // Performance optimizations
      rawDb.execute(
          'PRAGMA journal_mode = WAL;'); // Write-Ahead Logging for better concurrency
      rawDb.execute(
          'PRAGMA synchronous = NORMAL;'); // Balance between safety and performance
      rawDb.execute('PRAGMA cache_size = -64000;'); // 64MB cache
      rawDb.execute(
          'PRAGMA temp_store = MEMORY;'); // Store temp tables in memory

      // Create indexes for commonly queried fields
      try {
        // Products indexes
        rawDb.execute(
            'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);');
        rawDb.execute(
            'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);');
        rawDb.execute(
            'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);');
        rawDb.execute(
            'CREATE INDEX IF NOT EXISTS idx_products_stock ON products(stock);');

        // Sales indexes
        rawDb.execute(
            'CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at);');
        rawDb.execute(
            'CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales(customer_id);');
        rawDb.execute(
            'CREATE INDEX IF NOT EXISTS idx_sales_payment_type ON sales(payment_type);');

        // Sale items indexes
        rawDb.execute(
            'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);');
        rawDb.execute(
            'CREATE INDEX IF NOT EXISTS idx_sale_items_product_id ON sale_items(product_id);');

        // Customers indexes
        rawDb.execute(
            'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name);');
        rawDb.execute(
            'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);');

        // Payments indexes
        rawDb.execute(
            'CREATE INDEX IF NOT EXISTS idx_payments_sale_id ON payments(sale_id);');
        rawDb.execute(
            'CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at);');

        print('Database indexes created successfully');
      } catch (e) {
        print('Error creating indexes (may already exist): $e');
      }

      // Set up encryption (you can implement your own key management)
      // rawDb.execute('PRAGMA key = "your_encryption_key";');
    });
  });
}

// Data classes for complex queries
class SaleWithItems {
  final Sale sale;
  final List<SaleItemWithProduct> items;

  SaleWithItems({required this.sale, required this.items});
}

class SaleItemWithProduct {
  final SaleItem saleItem;
  final Product product;

  SaleItemWithProduct({required this.saleItem, required this.product});
}
