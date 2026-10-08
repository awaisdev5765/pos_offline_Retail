import 'package:drift/drift.dart';

// Products table
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get category => text().withLength(min: 1, max: 100)();
  RealColumn get price => real()(); // Selling price (Retail Cash)
  RealColumn get cost => real()(); // Cost price (Purchase Price)
  RealColumn get stock => real().withDefault(const Constant(0))();
  TextColumn get barcode => text().nullable()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  TextColumn get unit =>
      text().withLength(min: 1, max: 50).withDefault(const Constant('pcs'))();
  TextColumn get description => text().nullable()();
  RealColumn get reorderLevel => real().withDefault(const Constant(10))();
  RealColumn get reorderQuantity => real().withDefault(const Constant(50))();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  TextColumn get expiryDate => text().nullable()();
  TextColumn get batchNumber => text().nullable()();
  TextColumn get company => text().nullable()();
  RealColumn get marketPrice => real().nullable()();
  RealColumn get maxLevel => real().nullable()();
  TextColumn get packingMode => text().nullable()();
  RealColumn get wholesaleCash => real().nullable()();
  RealColumn get wholesaleCredit => real().nullable()();
  RealColumn get retailCredit => real().nullable()();
  // Mobile Shop specific fields
  TextColumn get brand => text().nullable()(); // Samsung, Apple, Xiaomi, etc.
  TextColumn get modelName =>
      text().nullable()(); // iPhone 14 Pro, Galaxy S23, etc.
  TextColumn get storageCapacity =>
      text().nullable()(); // 64GB, 128GB, 256GB, etc.
  TextColumn get ram => text().nullable()(); // 4GB, 6GB, 8GB, etc.
  TextColumn get color => text().nullable()(); // Space Gray, Midnight, etc.
  TextColumn get condition =>
      text().nullable()(); // new, refurbished, used, open_box
  TextColumn get unlockStatus =>
      text().nullable()(); // unlocked, locked, carrier name
  TextColumn get warrantyStatus =>
      text().nullable()(); // under_warranty, out_of_warranty, extended
  TextColumn get warrantyPeriod =>
      text().nullable()(); // 12 months, 24 months, etc.
  TextColumn get warrantyProvider =>
      text().nullable()(); // Manufacturer, Store, Third-party
  TextColumn get displaySize => text().nullable()(); // 6.1", 6.7", etc.
  TextColumn get batteryCapacity => text().nullable()(); // 4000 mAh, etc.
  TextColumn get cameraSpecs => text().nullable()(); // 48MP + 12MP + 12MP
  TextColumn get operatingSystem =>
      text().nullable()(); // iOS 17, Android 14, etc.
  TextColumn get networkType => text().nullable()(); // 4G, 5G, Dual SIM, etc.
  TextColumn get simCardType => text().nullable()(); // Nano SIM, eSIM, etc.
  RealColumn get tradeInValue =>
      real().nullable()(); // Trade-in value for used phones
  TextColumn get boxContents =>
      text().nullable()(); // What's included in the box
  // Restaurant specific fields
  TextColumn get courseType =>
      text().nullable()(); // appetizer, main_course, dessert, beverage, combo
  IntColumn get preparationTime =>
      integer().nullable()(); // Preparation time in minutes
  TextColumn get allergens => text()
      .nullable()(); // Comma-separated allergens (nuts, dairy, gluten, etc.)
  TextColumn get modifiers =>
      text().nullable()(); // Available modifiers/add-ons (JSON string)
  TextColumn get dietaryInfo =>
      text().nullable()(); // vegetarian, vegan, halal, kosher, etc.
  // Salon specific fields
  TextColumn get productType =>
      text().nullable()(); // product, service - for salon business
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Customers table
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()
      .withLength(min: 1, max: 255)
      .withDefault(const Constant('Unknown'))();
  TextColumn get phone => text()
      .withLength(min: 1, max: 20)
      .withDefault(const Constant('0000000'))();
  TextColumn get address => text().nullable()();
  RealColumn get totalDue => real().withDefault(const Constant(0))();
  RealColumn get creditLimit => real().withDefault(const Constant(0))();
  IntColumn get creditDays => integer().withDefault(const Constant(0))();
  RealColumn get unclearCheque => real().withDefault(const Constant(0))();
  BoolColumn get isRetailCustomer =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get isWholesaleCustomer =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Sales table
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()(); // ISO 8601 string
  RealColumn get total => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get paid => real().withDefault(const Constant(0))();
  RealColumn get due => real().withDefault(const Constant(0))();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get cashierId =>
      integer().nullable().references(Employees, #id)(); // Who made the sale
  TextColumn get paymentType =>
      text().withLength(min: 1, max: 20)(); // cash, card, credit
  TextColumn get status =>
      text().withLength(min: 1, max: 20)(); // paid, partial, unpaid
  TextColumn get dueDate => text()
      .nullable()(); // ISO 8601 string - Payment due date for credit sales
  BoolColumn get isWholesale =>
      boolean().withDefault(const Constant(false))(); // Wholesale sale flag
  // Restaurant specific fields
  IntColumn get tableNumber =>
      integer().nullable()(); // Table number for dine-in orders
  TextColumn get orderType => text().nullable()(); // dine_in, takeout, delivery
  RealColumn get serviceCharge => real().nullable()(); // Service charge amount
  RealColumn get tip => real().nullable()(); // Tip amount
  IntColumn get numberOfGuests =>
      integer().nullable()(); // Number of guests at table
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
}

// Sale Items table
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get qty => real()();
  RealColumn get price => real()(); // Price at time of sale
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get orderDiscountAllocation =>
      real().withDefault(const Constant(0))();
  RealColumn get taxRate => real().withDefault(const Constant(0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0))();
  RealColumn get costAtSale => real().withDefault(const Constant(0))();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  TextColumn get imei => text().nullable()(); // IMEI number for mobile phones
  // Restaurant specific fields
  TextColumn get specialInstructions =>
      text().nullable()(); // Special instructions for the item
  TextColumn get modifiers =>
      text().nullable()(); // Selected modifiers/add-ons (JSON string)
  TextColumn get createdAt => text()();
}

// Payments table
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get saleId => integer().nullable().references(Sales, #id)();
  RealColumn get amount => real()();
  TextColumn get date => text()(); // ISO 8601 string
  TextColumn get note => text().nullable()();
  TextColumn get paymentMethod =>
      text().withLength(min: 1, max: 20)(); // cash, card, bank_transfer
  IntColumn get processedByEmployeeId =>
      integer().nullable().references(Employees, #id)();
  TextColumn get createdAt => text()();
}

// Settings table
class Settings extends Table {
  TextColumn get key => text().withLength(min: 1, max: 100)();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// Stock Adjustments table
class StockAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity =>
      real()(); // Positive for stock in, negative for stock out
  TextColumn get reason => text()
      .withLength(min: 1, max: 100)(); // purchase, damage, return, adjustment
  TextColumn get reference => text().nullable()(); // Reference number or note
  TextColumn get date => text()(); // ISO 8601 string
  IntColumn get employeeId => integer()
      .nullable()
      .references(Employees, #id)(); // Employee who created the adjustment
  TextColumn get createdAt => text()();
}

// Categories table
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  TextColumn get color => text().withDefault(const Constant('3B82F6'))();
  TextColumn get icon => text().withDefault(const Constant('category'))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Suppliers table
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get code => text()
      .withLength(min: 1, max: 50)
      .withDefault(const Constant('SUP-0000'))();
  TextColumn get contactPerson => text().withLength(min: 1, max: 255)();
  TextColumn get phone => text().withLength(min: 1, max: 20)();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get state => text().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get zipCode => text().nullable()();
  RealColumn get creditLimit => real().withDefault(const Constant(0))();
  RealColumn get currentBalance => real().withDefault(const Constant(0))();
  IntColumn get creditDays => integer().withDefault(const Constant(0))();
  RealColumn get unclearCheque => real().withDefault(const Constant(0))();
  TextColumn get paymentTerms =>
      text().withDefault(const Constant('30 days'))();
  TextColumn get notes => text().nullable()();
  TextColumn get otherContact1 =>
      text().nullable()(); // Additional contact name 1
  TextColumn get otherContact2 =>
      text().nullable()(); // Additional contact name 2
  TextColumn get otherContact3 =>
      text().nullable()(); // Additional contact name 3
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Purchase Orders table
class PurchaseOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get orderNumber => text().withLength(min: 1, max: 50)();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  TextColumn get orderDate => text()(); // ISO 8601 string
  TextColumn get expectedDate => text().nullable()(); // ISO 8601 string
  TextColumn get receivedDate => text().nullable()(); // ISO 8601 string
  RealColumn get subtotal => real()();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get total => real()();
  TextColumn get status =>
      text().withLength(min: 1, max: 20)(); // pending, received, cancelled
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Purchase Order Items table
class PurchaseOrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseOrderId => integer().references(PurchaseOrders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitCost => real()();
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get total => real()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
}

// Employees table
class Employees extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get username => text().nullable()(); // Can be null for old users
  TextColumn get email => text().nullable()(); // Legacy field for old users
  TextColumn get phone => text().withLength(min: 1, max: 20)();
  TextColumn get address => text().nullable()();
  TextColumn get role =>
      text().withLength(min: 1, max: 50)(); // admin, manager, cashier, staff
  TextColumn get employeeId => text().withLength(min: 1, max: 50)();
  RealColumn get salary => real().nullable()();
  TextColumn get hireDate => text()(); // ISO 8601 string
  TextColumn get terminationDate => text().nullable()(); // ISO 8601 string
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get canLogin => boolean().withDefault(const Constant(true))();
  TextColumn get password => text().nullable()(); // Hashed password
  TextColumn get permissions =>
      text().nullable()(); // JSON string of permissions
  RealColumn get commissionPercentage =>
      real().nullable()(); // Commission percentage for salon employees
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Returns table
class Returns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get returnNumber => text().withLength(min: 1, max: 50)();
  IntColumn get originalSaleId => integer().references(Sales, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  TextColumn get returnDate => text()(); // ISO 8601 string
  RealColumn get totalAmount => real()();
  TextColumn get reason => text().withLength(
      min: 1, max: 100)(); // defective, wrong_item, customer_request, etc.
  TextColumn get status => text()
      .withLength(min: 1, max: 20)(); // pending, approved, rejected, processed
  TextColumn get notes => text().nullable()();
  TextColumn get processedBy =>
      text().nullable()(); // Employee who processed the return
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Return Items table
class ReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get returnId => integer().references(Returns, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get subtotal => real()();
  TextColumn get reason => text().withLength(min: 1, max: 100)();
  TextColumn get condition =>
      text().withLength(min: 1, max: 20)(); // good, damaged, defective
  TextColumn get action =>
      text().withLength(min: 1, max: 20)(); // refund, exchange, credit
  TextColumn get createdAt => text()();
}

// Banks table
class Banks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get code => text().withLength(min: 1, max: 50)();
  TextColumn get accountNumber => text().nullable()();
  TextColumn get branch => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  RealColumn get currentBalance => real().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Bank Payments table (for cheques and bank transactions)
class BankPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bankId => integer().references(Banks, #id)();
  TextColumn get partyName => text().withLength(min: 1, max: 255)();
  TextColumn get otherName => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get paymentType => text()
      .withLength(min: 1, max: 20)(); // cheque, transfer, deposit, withdrawal
  TextColumn get chequeNumber => text().nullable()();
  TextColumn get chequeDate => text().nullable()(); // ISO 8601 string
  TextColumn get issueDate => text()(); // ISO 8601 string
  TextColumn get paidDate => text()(); // ISO 8601 string
  RealColumn get previousBalance => real().withDefault(const Constant(0))();
  RealColumn get newBalance => real().withDefault(const Constant(0))();
  TextColumn get status => text()
      .withLength(min: 1, max: 20)
      .withDefault(const Constant('pending'))(); // pending, cleared, cancelled
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Supplier Payments table
class SupplierPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  RealColumn get amount => real()();
  TextColumn get paymentMethod =>
      text().withLength(min: 1, max: 20)(); // cash, bank_transfer, cheque
  TextColumn get paymentType =>
      text().withLength(min: 1, max: 20)(); // payment, refund, adjustment
  TextColumn get date => text()(); // ISO 8601 string
  TextColumn get reference =>
      text().nullable()(); // Cheque number, transaction reference
  TextColumn get chequeDate =>
      text().nullable()(); // ISO 8601 string for cheque date
  TextColumn get issueDate =>
      text().nullable()(); // ISO 8601 string for issue date
  TextColumn get note => text().nullable()();
  TextColumn get otherName =>
      text().nullable()(); // Name of person making payment
  TextColumn get status => text().withLength(min: 1, max: 20).withDefault(
      const Constant('completed'))(); // completed, pending, cancelled
  TextColumn get createdBy =>
      text().nullable()(); // Employee who created the payment
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Staff Performance table
class StaffPerformances extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId => integer().references(Employees, #id)();
  TextColumn get employeeName => text().withLength(min: 1, max: 100)();
  TextColumn get date => text()(); // ISO 8601 string
  RealColumn get totalSales => real()();
  IntColumn get totalTransactions => integer()();
  RealColumn get averageTransactionValue => real()();
  IntColumn get itemsSold => integer()();
  RealColumn get commission => real()();
  RealColumn get tips => real()();
  IntColumn get hoursWorked => integer()();
  RealColumn get salesPerHour => real()();
  IntColumn get customerInteractions => integer()();
  RealColumn get customerSatisfaction => real()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Expenses table
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get category => text().withLength(min: 1, max: 100)();
  RealColumn get amount => real()();
  TextColumn get date => text()(); // ISO 8601 string
  TextColumn get paymentMethod =>
      text().withLength(min: 1, max: 50)(); // cash, card, bank_transfer, cheque
  TextColumn get reference => text().nullable()(); // Invoice/receipt number
  TextColumn get description => text().nullable()();
  TextColumn get vendor => text().nullable()(); // Supplier/vendor name
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurringPeriod =>
      text().nullable()(); // daily, weekly, monthly, yearly
  TextColumn get attachmentPath =>
      text().nullable()(); // Path to receipt/invoice image
  TextColumn get createdBy => text().nullable()(); // Employee who created
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Expense Heads table
class ExpenseHeads extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  TextColumn get jobType => text().nullable()(); // Job type or category
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Product IMEIs table - For tracking individual IMEI numbers
class ProductIMEIs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get imei =>
      text().withLength(min: 1, max: 50)(); // IMEI number (15 digits typically)
  IntColumn get saleId => integer()
      .nullable()
      .references(Sales, #id)(); // Which sale this IMEI was sold in
  IntColumn get customerId => integer()
      .nullable()
      .references(Customers, #id)(); // Which customer bought this IMEI
  TextColumn get status => text().withLength(min: 1, max: 20).withDefault(
      const Constant('available'))(); // available, sold, returned, damaged
  TextColumn get purchaseDate =>
      text().nullable()(); // When this IMEI was purchased from supplier
  TextColumn get saleDate => text().nullable()(); // When this IMEI was sold
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Product Bundles table - For combo packages
class ProductBundles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  RealColumn get price => real()(); // Bundle price (usually discounted)
  RealColumn get cost => real()(); // Total cost of bundle items
  TextColumn get category => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get imagePath => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Product Bundle Items table - Products included in a bundle
class ProductBundleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bundleId => integer().references(ProductBundles, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity =>
      real().withDefault(const Constant(1))(); // Quantity of product in bundle
  RealColumn get price =>
      real().nullable()(); // Override price for this item in bundle (optional)
  TextColumn get createdAt => text()();
}

// Employee Commissions table - Track commission earnings and withdrawals for salon employees
class EmployeeCommissions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId => integer().references(Employees, #id)();
  TextColumn get transactionType =>
      text().withLength(min: 1, max: 20)(); // earning, withdrawal
  IntColumn get saleId => integer()
      .nullable()
      .references(Sales, #id)(); // Reference to sale for earnings
  RealColumn get amount =>
      real()(); // Positive for earnings, negative for withdrawals
  RealColumn get commissionPercentage =>
      real().nullable()(); // Commission rate at time of transaction
  RealColumn get saleAmount =>
      real().nullable()(); // Sale amount that generated this commission
  RealColumn get balanceAfter =>
      real().nullable()(); // Balance after this transaction
  TextColumn get date => text()(); // ISO 8601 string
  TextColumn get notes => text().nullable()(); // Notes about the transaction
  TextColumn get processedBy =>
      text().nullable()(); // Employee who processed withdrawal
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

// Product Ingredients table - For restaurant menu items with ingredient-level costing
class ProductIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id,
      onDelete: KeyAction.cascade)(); // The menu item (e.g., Burger)
  IntColumn get ingredientProductId => integer().references(Products, #id,
      onDelete: KeyAction
          .restrict)(); // The ingredient from inventory (e.g., Chicken Fillet)
  RealColumn get quantity => real()(); // Quantity needed (e.g., 100 for grams)
  TextColumn get unit => text()
      .withLength(min: 1, max: 50)(); // Unit of measurement (gm, ml, pcs, etc.)
  TextColumn get costType =>
      text().withLength(min: 1, max: 20)(); // 'quantity_based' or 'fixed_cost'
  RealColumn get fixedCost => real()
      .nullable()(); // Fixed cost (e.g., Rs 30 for bun, Rs 10 for packing)
  IntColumn get sortOrder => integer()
      .withDefault(const Constant(0))(); // Order in which ingredients appear
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}
