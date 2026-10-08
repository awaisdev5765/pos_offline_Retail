import 'package:drift/drift.dart';
import '../database/database.dart';
import 'product.dart';
import 'customer.dart';
import 'employee.dart';

enum PaymentType { cash, card, credit }

enum SaleStatus { paid, partial, unpaid }

class SaleModel {
  final int? id;
  final DateTime date;
  final double total;
  final double discount;
  final double paid;
  final double due;
  final int? customerId;
  final int? cashierId; // Who made the sale
  final PaymentType paymentType;
  final SaleStatus status;
  final DateTime? dueDate; // Payment due date for credit sales
  final bool isWholesale; // Wholesale sale flag
  // Restaurant specific fields
  final int? tableNumber; // Table number for dine-in orders
  final String? orderType; // dine_in, takeout, delivery
  final double? serviceCharge; // Service charge amount
  final double? tip; // Tip amount
  final int? numberOfGuests; // Number of guests at table
  final String? notes;
  final DateTime createdAt;
  final List<SaleItemModel> items;
  final CustomerModel? customer;
  final EmployeeModel? cashier; // Cashier/employee who made the sale

  SaleModel({
    this.id,
    required this.date,
    required this.total,
    this.discount = 0,
    this.paid = 0,
    this.due = 0,
    this.customerId,
    this.cashierId,
    this.paymentType = PaymentType.cash,
    this.status = SaleStatus.paid,
    this.dueDate,
    this.isWholesale = false,
    this.tableNumber,
    this.orderType,
    this.serviceCharge,
    this.tip,
    this.numberOfGuests,
    this.notes,
    required this.createdAt,
    this.items = const [],
    this.customer,
    this.cashier,
  });

  factory SaleModel.fromSale(Sale sale,
      {List<SaleItemModel>? items,
      CustomerModel? customer,
      EmployeeModel? cashier}) {
    DateTime parseDate(String dateString) {
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        print('Error parsing date: $dateString - $e');
        return DateTime.now();
      }
    }

    return SaleModel(
      id: sale.id,
      date: parseDate(sale.date),
      total: sale.total.isNaN ? 0 : sale.total,
      discount: sale.discount.isNaN ? 0 : sale.discount,
      paid: sale.paid.isNaN ? 0 : sale.paid,
      due: sale.due.isNaN ? 0 : sale.due,
      customerId: sale.customerId,
      cashierId: sale.cashierId,
      paymentType: PaymentType.values.firstWhere(
        (e) => e.name == sale.paymentType,
        orElse: () => PaymentType.cash,
      ),
      status: SaleStatus.values.firstWhere(
        (e) => e.name == sale.status,
        orElse: () => SaleStatus.paid,
      ),
      dueDate: sale.dueDate != null ? parseDate(sale.dueDate!) : null,
      isWholesale: sale.isWholesale,
      tableNumber: sale.tableNumber,
      orderType: sale.orderType,
      serviceCharge: sale.serviceCharge,
      tip: sale.tip,
      numberOfGuests: sale.numberOfGuests,
      notes: sale.notes,
      createdAt: parseDate(sale.createdAt),
      items: items ?? [],
      customer: customer,
      cashier: cashier,
    );
  }

  Sale toSale() {
    return Sale(
      id: id ?? 0,
      date: date.toIso8601String(),
      total: total,
      discount: discount,
      paid: paid,
      due: due,
      customerId: customerId,
      cashierId: cashierId,
      paymentType: paymentType.name,
      status: status.name,
      dueDate: dueDate?.toIso8601String(),
      isWholesale: isWholesale,
      tableNumber: tableNumber,
      orderType: orderType,
      serviceCharge: serviceCharge,
      tip: tip,
      numberOfGuests: numberOfGuests,
      notes: notes,
      createdAt: createdAt.toIso8601String(),
    );
  }

  SalesCompanion toCompanion() {
    return SalesCompanion(
      date: Value(date.toIso8601String()),
      total: Value(total),
      discount: Value(discount),
      paid: Value(paid),
      due: Value(due),
      customerId: Value(customerId),
      cashierId: Value(cashierId),
      paymentType: Value(paymentType.name),
      status: Value(status.name),
      dueDate: Value(dueDate?.toIso8601String()),
      isWholesale: Value(isWholesale),
      tableNumber: Value(tableNumber),
      orderType: Value(orderType),
      serviceCharge: Value(serviceCharge),
      tip: Value(tip),
      numberOfGuests: Value(numberOfGuests),
      notes: Value(notes),
      createdAt: Value(createdAt.toIso8601String()),
    );
  }

  SaleModel copyWith({
    int? id,
    DateTime? date,
    double? total,
    double? discount,
    double? paid,
    double? due,
    int? customerId,
    int? cashierId,
    PaymentType? paymentType,
    SaleStatus? status,
    DateTime? dueDate,
    bool? isWholesale,
    int? tableNumber,
    String? orderType,
    double? serviceCharge,
    double? tip,
    int? numberOfGuests,
    String? notes,
    DateTime? createdAt,
    List<SaleItemModel>? items,
    CustomerModel? customer,
    EmployeeModel? cashier,
  }) {
    return SaleModel(
      id: id ?? this.id,
      date: date ?? this.date,
      total: total ?? this.total,
      discount: discount ?? this.discount,
      paid: paid ?? this.paid,
      due: due ?? this.due,
      customerId: customerId ?? this.customerId,
      cashierId: cashierId ?? this.cashierId,
      paymentType: paymentType ?? this.paymentType,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      isWholesale: isWholesale ?? this.isWholesale,
      tableNumber: tableNumber ?? this.tableNumber,
      orderType: orderType ?? this.orderType,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      tip: tip ?? this.tip,
      numberOfGuests: numberOfGuests ?? this.numberOfGuests,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      customer: customer ?? this.customer,
      cashier: cashier ?? this.cashier,
    );
  }

  double get netTotal => total - discount;
  bool get isFullyPaid => status == SaleStatus.paid;
  bool get isPartiallyPaid => status == SaleStatus.partial;
  bool get isUnpaid => status == SaleStatus.unpaid;

  /// Calculate total profit for this sale
  double get profit {
    double totalProfit = 0.0;
    for (final item in items) {
      final netRevenue =
          item.subtotal - item.discount - item.orderDiscountAllocation;
      totalProfit += netRevenue - (item.costAtSale * item.qty);
    }
    return totalProfit;
  }

  /// Calculate profit margin percentage
  double get profitMargin {
    if (total <= 0) return 0.0;
    return (profit / total) * 100;
  }

  @override
  String toString() {
    return 'SaleModel(id: $id, total: $total, status: $status, items: ${items.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SaleModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class SaleItemModel {
  final int? id;
  final int saleId;
  final int productId;
  final double qty;
  final double price;
  final double subtotal;
  final double discount;
  final double orderDiscountAllocation;
  final double taxRate;
  final double taxAmount;
  final double costAtSale;
  final String unit;
  final String? imei; // IMEI number for mobile phones
  // Restaurant specific fields
  final String? specialInstructions; // Special instructions for the item
  final String? modifiers; // Selected modifiers/add-ons (JSON string)
  final DateTime createdAt;
  final ProductModel? product;

  SaleItemModel({
    this.id,
    required this.saleId,
    required this.productId,
    required this.qty,
    required this.price,
    required this.subtotal,
    this.discount = 0,
    this.orderDiscountAllocation = 0,
    this.taxRate = 0,
    this.taxAmount = 0,
    this.costAtSale = 0,
    this.unit = 'pcs',
    this.imei,
    this.specialInstructions,
    this.modifiers,
    required this.createdAt,
    this.product,
  });

  factory SaleItemModel.fromSaleItem(SaleItem saleItem,
      {ProductModel? product}) {
    return SaleItemModel(
      id: saleItem.id,
      saleId: saleItem.saleId,
      productId: saleItem.productId,
      qty: saleItem.qty,
      price: saleItem.price,
      subtotal: saleItem.subtotal,
      discount: saleItem.discount,
      orderDiscountAllocation: saleItem.orderDiscountAllocation,
      taxRate: saleItem.taxRate,
      taxAmount: saleItem.taxAmount,
      costAtSale: saleItem.costAtSale,
      unit: saleItem.unit,
      imei: saleItem.imei,
      specialInstructions: saleItem.specialInstructions,
      modifiers: saleItem.modifiers,
      createdAt: DateTime.parse(saleItem.createdAt),
      product: product,
    );
  }

  SaleItem toSaleItem() {
    return SaleItem(
      id: id ?? 0,
      saleId: saleId,
      productId: productId,
      qty: qty,
      price: price,
      subtotal: subtotal,
      discount: discount,
      orderDiscountAllocation: orderDiscountAllocation,
      taxRate: taxRate,
      taxAmount: taxAmount,
      costAtSale: costAtSale,
      unit: unit,
      imei: imei,
      specialInstructions: specialInstructions,
      modifiers: modifiers,
      createdAt: createdAt.toIso8601String(),
    );
  }

  SaleItemsCompanion toCompanion() {
    return SaleItemsCompanion(
      saleId: Value(saleId),
      productId: Value(productId),
      qty: Value(qty),
      imei: Value(imei),
      price: Value(price),
      subtotal: Value(subtotal),
      discount: Value(discount),
      orderDiscountAllocation: Value(orderDiscountAllocation),
      taxRate: Value(taxRate),
      taxAmount: Value(taxAmount),
      costAtSale: Value(costAtSale),
      unit: Value(unit),
      specialInstructions: Value(specialInstructions),
      modifiers: Value(modifiers),
      createdAt: Value(createdAt.toIso8601String()),
    );
  }

  SaleItemModel copyWith({
    int? id,
    int? saleId,
    int? productId,
    double? qty,
    double? price,
    double? subtotal,
    double? discount,
    double? orderDiscountAllocation,
    double? taxRate,
    double? taxAmount,
    double? costAtSale,
    String? unit,
    String? imei,
    String? specialInstructions,
    String? modifiers,
    DateTime? createdAt,
    ProductModel? product,
  }) {
    return SaleItemModel(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      orderDiscountAllocation:
          orderDiscountAllocation ?? this.orderDiscountAllocation,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      costAtSale: costAtSale ?? this.costAtSale,
      unit: unit ?? this.unit,
      imei: imei ?? this.imei,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      modifiers: modifiers ?? this.modifiers,
      createdAt: createdAt ?? this.createdAt,
      product: product ?? this.product,
    );
  }

  double get netSubtotal => subtotal - discount;

  @override
  String toString() {
    return 'SaleItemModel(id: $id, productId: $productId, qty: $qty, price: $price, subtotal: $subtotal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SaleItemModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
