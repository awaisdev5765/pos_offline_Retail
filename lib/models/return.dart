import 'package:drift/drift.dart';
import '../database/database.dart';
import 'sale.dart';
import 'customer.dart';
import 'product.dart';

enum ReturnStatus { pending, approved, rejected, processed }

enum ReturnReason { defective, wrongItem, customerRequest, qualityIssue, other }

enum ReturnCondition { good, damaged, defective }

enum ReturnAction { refund, exchange, credit }

class ReturnModel {
  final int? id;
  final String returnNumber;
  final int originalSaleId;
  final int customerId;
  final DateTime returnDate;
  final double totalAmount;
  final ReturnReason reason;
  final ReturnStatus status;
  final String? notes;
  final String? processedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SaleModel? originalSale;
  final CustomerModel? customer;
  final List<ReturnItemModel> items;

  ReturnModel({
    this.id,
    required this.returnNumber,
    required this.originalSaleId,
    required this.customerId,
    required this.returnDate,
    required this.totalAmount,
    this.reason = ReturnReason.customerRequest,
    this.status = ReturnStatus.pending,
    this.notes,
    this.processedBy,
    required this.createdAt,
    required this.updatedAt,
    this.originalSale,
    this.customer,
    this.items = const [],
  });

  factory ReturnModel.fromReturn(
    Return returnData, {
    SaleModel? originalSale,
    CustomerModel? customer,
    List<ReturnItemModel>? items,
  }) {
    return ReturnModel(
      id: returnData.id,
      returnNumber: returnData.returnNumber,
      originalSaleId: returnData.originalSaleId,
      customerId: returnData.customerId,
      returnDate: DateTime.parse(returnData.returnDate),
      totalAmount: returnData.totalAmount,
      reason: ReturnReason.values.firstWhere(
        (e) => e.name == returnData.reason,
        orElse: () => ReturnReason.customerRequest,
      ),
      status: ReturnStatus.values.firstWhere(
        (e) => e.name == returnData.status,
        orElse: () => ReturnStatus.pending,
      ),
      notes: returnData.notes,
      processedBy: returnData.processedBy,
      createdAt: DateTime.parse(returnData.createdAt),
      updatedAt: DateTime.parse(returnData.updatedAt),
      originalSale: originalSale,
      customer: customer,
      items: items ?? [],
    );
  }

  Return toReturn() {
    return Return(
      id: id ?? 0,
      returnNumber: returnNumber,
      originalSaleId: originalSaleId,
      customerId: customerId,
      returnDate: returnDate.toIso8601String(),
      totalAmount: totalAmount,
      reason: reason.name,
      status: status.name,
      notes: notes,
      processedBy: processedBy,
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  ReturnsCompanion toCompanion() {
    return ReturnsCompanion(
      returnNumber: Value(returnNumber),
      originalSaleId: Value(originalSaleId),
      customerId: Value(customerId),
      returnDate: Value(returnDate.toIso8601String()),
      totalAmount: Value(totalAmount),
      reason: Value(reason.name),
      status: Value(status.name),
      notes: Value(notes),
      processedBy: Value(processedBy),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }

  ReturnModel copyWith({
    int? id,
    String? returnNumber,
    int? originalSaleId,
    int? customerId,
    DateTime? returnDate,
    double? totalAmount,
    ReturnReason? reason,
    ReturnStatus? status,
    String? notes,
    String? processedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    SaleModel? originalSale,
    CustomerModel? customer,
    List<ReturnItemModel>? items,
  }) {
    return ReturnModel(
      id: id ?? this.id,
      returnNumber: returnNumber ?? this.returnNumber,
      originalSaleId: originalSaleId ?? this.originalSaleId,
      customerId: customerId ?? this.customerId,
      returnDate: returnDate ?? this.returnDate,
      totalAmount: totalAmount ?? this.totalAmount,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      processedBy: processedBy ?? this.processedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      originalSale: originalSale ?? this.originalSale,
      customer: customer ?? this.customer,
      items: items ?? this.items,
    );
  }

  bool get isPending => status == ReturnStatus.pending;
  bool get isApproved => status == ReturnStatus.approved;
  bool get isRejected => status == ReturnStatus.rejected;
  bool get isProcessed => status == ReturnStatus.processed;
  bool get canBeProcessed => status == ReturnStatus.approved;
  bool get canBeApproved => status == ReturnStatus.pending;
  bool get canBeRejected => status == ReturnStatus.pending;

  String get reasonDisplayName {
    switch (reason) {
      case ReturnReason.defective:
        return 'Defective Product';
      case ReturnReason.wrongItem:
        return 'Wrong Item';
      case ReturnReason.customerRequest:
        return 'Customer Request';
      case ReturnReason.qualityIssue:
        return 'Quality Issue';
      case ReturnReason.other:
        return 'Other';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case ReturnStatus.pending:
        return 'Pending';
      case ReturnStatus.approved:
        return 'Approved';
      case ReturnStatus.rejected:
        return 'Rejected';
      case ReturnStatus.processed:
        return 'Processed';
    }
  }

  @override
  String toString() {
    return 'ReturnModel(id: $id, returnNumber: $returnNumber, status: $status, totalAmount: $totalAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReturnModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class ReturnItemModel {
  final int? id;
  final int returnId;
  final int productId;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final ReturnReason reason;
  final ReturnCondition condition;
  final ReturnAction action;
  final DateTime createdAt;
  final ProductModel? product;

  ReturnItemModel({
    this.id,
    required this.returnId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.reason = ReturnReason.customerRequest,
    this.condition = ReturnCondition.good,
    this.action = ReturnAction.refund,
    required this.createdAt,
    this.product,
  });

  factory ReturnItemModel.fromReturnItem(
    ReturnItem item, {
    ProductModel? product,
  }) {
    return ReturnItemModel(
      id: item.id,
      returnId: item.returnId,
      productId: item.productId,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      subtotal: item.subtotal,
      reason: ReturnReason.values.firstWhere(
        (e) => e.name == item.reason,
        orElse: () => ReturnReason.customerRequest,
      ),
      condition: ReturnCondition.values.firstWhere(
        (e) => e.name == item.condition,
        orElse: () => ReturnCondition.good,
      ),
      action: ReturnAction.values.firstWhere(
        (e) => e.name == item.action,
        orElse: () => ReturnAction.refund,
      ),
      createdAt: DateTime.parse(item.createdAt),
      product: product,
    );
  }

  ReturnItem toReturnItem() {
    return ReturnItem(
      id: id ?? 0,
      returnId: returnId,
      productId: productId,
      quantity: quantity,
      unitPrice: unitPrice,
      subtotal: subtotal,
      reason: reason.name,
      condition: condition.name,
      action: action.name,
      createdAt: createdAt.toIso8601String(),
    );
  }

  ReturnItemsCompanion toCompanion() {
    return ReturnItemsCompanion(
      returnId: Value(returnId),
      productId: Value(productId),
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
      subtotal: Value(subtotal),
      reason: Value(reason.name),
      condition: Value(condition.name),
      action: Value(action.name),
      createdAt: Value(createdAt.toIso8601String()),
    );
  }

  ReturnItemModel copyWith({
    int? id,
    int? returnId,
    int? productId,
    double? quantity,
    double? unitPrice,
    double? subtotal,
    ReturnReason? reason,
    ReturnCondition? condition,
    ReturnAction? action,
    DateTime? createdAt,
    ProductModel? product,
  }) {
    return ReturnItemModel(
      id: id ?? this.id,
      returnId: returnId ?? this.returnId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
      reason: reason ?? this.reason,
      condition: condition ?? this.condition,
      action: action ?? this.action,
      createdAt: createdAt ?? this.createdAt,
      product: product ?? this.product,
    );
  }

  String get conditionDisplayName {
    switch (condition) {
      case ReturnCondition.good:
        return 'Good Condition';
      case ReturnCondition.damaged:
        return 'Damaged';
      case ReturnCondition.defective:
        return 'Defective';
    }
  }

  String get actionDisplayName {
    switch (action) {
      case ReturnAction.refund:
        return 'Refund';
      case ReturnAction.exchange:
        return 'Exchange';
      case ReturnAction.credit:
        return 'Store Credit';
    }
  }

  @override
  String toString() {
    return 'ReturnItemModel(id: $id, productId: $productId, quantity: $quantity, action: $action)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReturnItemModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
