import 'package:drift/drift.dart';
import '../database/database.dart' as db;
import 'supplier.dart';
import 'product.dart';

enum PurchaseOrderStatus { pending, received, cancelled }

class PurchaseOrderModel {
  final int? id;
  final String orderNumber;
  final int supplierId;
  final DateTime orderDate;
  final DateTime? expectedDate;
  final DateTime? receivedDate;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final PurchaseOrderStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SupplierModel? supplier;
  final List<PurchaseOrderItemModel> items;

  PurchaseOrderModel({
    this.id,
    required this.orderNumber,
    required this.supplierId,
    required this.orderDate,
    this.expectedDate,
    this.receivedDate,
    required this.subtotal,
    this.tax = 0,
    this.discount = 0,
    required this.total,
    this.status = PurchaseOrderStatus.pending,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.supplier,
    this.items = const [],
  });

  factory PurchaseOrderModel.fromPurchaseOrder(
    db.PurchaseOrder purchaseOrder, {
    SupplierModel? supplier,
    List<PurchaseOrderItemModel>? items,
  }) {
    return PurchaseOrderModel(
      id: purchaseOrder.id,
      orderNumber: purchaseOrder.orderNumber,
      supplierId: purchaseOrder.supplierId,
      orderDate: DateTime.parse(purchaseOrder.orderDate),
      expectedDate: purchaseOrder.expectedDate != null
          ? DateTime.parse(purchaseOrder.expectedDate!)
          : null,
      receivedDate: purchaseOrder.receivedDate != null
          ? DateTime.parse(purchaseOrder.receivedDate!)
          : null,
      subtotal: purchaseOrder.subtotal,
      tax: purchaseOrder.tax,
      discount: purchaseOrder.discount,
      total: purchaseOrder.total,
      status: PurchaseOrderStatus.values.firstWhere(
        (e) => e.name == purchaseOrder.status,
        orElse: () => PurchaseOrderStatus.pending,
      ),
      notes: purchaseOrder.notes,
      createdAt: DateTime.parse(purchaseOrder.createdAt),
      updatedAt: DateTime.parse(purchaseOrder.updatedAt),
      supplier: supplier,
      items: items ?? [],
    );
  }

  db.PurchaseOrder toPurchaseOrder() {
    return db.PurchaseOrder(
      id: id ?? 0,
      orderNumber: orderNumber,
      supplierId: supplierId,
      orderDate: orderDate.toIso8601String(),
      expectedDate: expectedDate?.toIso8601String(),
      receivedDate: receivedDate?.toIso8601String(),
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      total: total,
      status: status.name,
      notes: notes,
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  db.PurchaseOrdersCompanion toCompanion() {
    return db.PurchaseOrdersCompanion(
      orderNumber: Value(orderNumber),
      supplierId: Value(supplierId),
      orderDate: Value(orderDate.toIso8601String()),
      expectedDate: Value(expectedDate?.toIso8601String()),
      receivedDate: Value(receivedDate?.toIso8601String()),
      subtotal: Value(subtotal),
      tax: Value(tax),
      discount: Value(discount),
      total: Value(total),
      status: Value(status.name),
      notes: Value(notes),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }

  PurchaseOrderModel copyWith({
    int? id,
    String? orderNumber,
    int? supplierId,
    DateTime? orderDate,
    DateTime? expectedDate,
    DateTime? receivedDate,
    double? subtotal,
    double? tax,
    double? discount,
    double? total,
    PurchaseOrderStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    SupplierModel? supplier,
    List<PurchaseOrderItemModel>? items,
  }) {
    return PurchaseOrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      supplierId: supplierId ?? this.supplierId,
      orderDate: orderDate ?? this.orderDate,
      expectedDate: expectedDate ?? this.expectedDate,
      receivedDate: receivedDate ?? this.receivedDate,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplier: supplier ?? this.supplier,
      items: items ?? this.items,
    );
  }

  bool get isPending => status == PurchaseOrderStatus.pending;
  bool get isReceived => status == PurchaseOrderStatus.received;
  bool get isCancelled => status == PurchaseOrderStatus.cancelled;
  bool get isOverdue =>
      expectedDate != null &&
      DateTime.now().isAfter(expectedDate!) &&
      status == PurchaseOrderStatus.pending;

  @override
  String toString() {
    return 'PurchaseOrderModel(id: $id, orderNumber: $orderNumber, status: $status, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PurchaseOrderModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class PurchaseOrderItemModel {
  final int? id;
  final int purchaseOrderId;
  final int productId;
  final double quantity;
  final double unitCost;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String? notes;
  final DateTime createdAt;
  final ProductModel? product;

  PurchaseOrderItemModel({
    this.id,
    required this.purchaseOrderId,
    required this.productId,
    required this.quantity,
    required this.unitCost,
    required this.subtotal,
    this.discount = 0,
    this.tax = 0,
    required this.total,
    this.notes,
    required this.createdAt,
    this.product,
  });

  factory PurchaseOrderItemModel.fromPurchaseOrderItem(
    db.PurchaseOrderItem item, {
    ProductModel? product,
  }) {
    return PurchaseOrderItemModel(
      id: item.id,
      purchaseOrderId: item.purchaseOrderId,
      productId: item.productId,
      quantity: item.quantity,
      unitCost: item.unitCost,
      subtotal: item.subtotal,
      discount: item.discount,
      tax: item.tax,
      total: item.total,
      notes: item.notes,
      createdAt: DateTime.parse(item.createdAt),
      product: product,
    );
  }

  db.PurchaseOrderItem toPurchaseOrderItem() {
    return db.PurchaseOrderItem(
      id: id ?? 0,
      purchaseOrderId: purchaseOrderId,
      productId: productId,
      quantity: quantity,
      unitCost: unitCost,
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: total,
      notes: notes,
      createdAt: createdAt.toIso8601String(),
    );
  }

  db.PurchaseOrderItemsCompanion toCompanion() {
    return db.PurchaseOrderItemsCompanion(
      purchaseOrderId: Value(purchaseOrderId),
      productId: Value(productId),
      quantity: Value(quantity),
      unitCost: Value(unitCost),
      subtotal: Value(subtotal),
      discount: Value(discount),
      tax: Value(tax),
      total: Value(total),
      notes: Value(notes),
      createdAt: Value(createdAt.toIso8601String()),
    );
  }

  PurchaseOrderItemModel copyWith({
    int? id,
    int? purchaseOrderId,
    int? productId,
    double? quantity,
    double? unitCost,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    String? notes,
    DateTime? createdAt,
    ProductModel? product,
  }) {
    return PurchaseOrderItemModel(
      id: id ?? this.id,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      product: product ?? this.product,
    );
  }

  double get netSubtotal => subtotal - discount;

  @override
  String toString() {
    return 'PurchaseOrderItemModel(id: $id, productId: $productId, quantity: $quantity, unitCost: $unitCost)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PurchaseOrderItemModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
