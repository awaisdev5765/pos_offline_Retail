import 'package:drift/drift.dart';
import '../database/database.dart';

class StockMovementModel {
  final int? id;
  final int productId;
  final double quantity;
  final String reason;
  final String? reference;
  final DateTime date;
  final DateTime createdAt;

  // Additional computed properties
  String? productName;
  String? productBarcode;
  String? productUnit;

  StockMovementModel({
    this.id,
    required this.productId,
    required this.quantity,
    required this.reason,
    this.reference,
    required this.date,
    required this.createdAt,
    this.productName,
    this.productBarcode,
    this.productUnit,
  });

  factory StockMovementModel.fromStockAdjustment(StockAdjustment adjustment) {
    return StockMovementModel(
      id: adjustment.id,
      productId: adjustment.productId,
      quantity: adjustment.quantity,
      reason: adjustment.reason,
      reference: adjustment.reference,
      date: DateTime.parse(adjustment.date),
      createdAt: DateTime.parse(adjustment.createdAt),
    );
  }

  StockAdjustmentsCompanion toCompanion() {
    return StockAdjustmentsCompanion.insert(
      productId: productId,
      quantity: quantity,
      reason: reason,
      reference: reference != null ? Value(reference) : const Value(null),
      date: date.toIso8601String(),
      createdAt: createdAt.toIso8601String(),
    );
  }

  StockMovementModel copyWith({
    int? id,
    int? productId,
    double? quantity,
    String? reason,
    String? reference,
    DateTime? date,
    DateTime? createdAt,
    String? productName,
    String? productBarcode,
    String? productUnit,
  }) {
    return StockMovementModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      reason: reason ?? this.reason,
      reference: reference ?? this.reference,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      productBarcode: productBarcode ?? this.productBarcode,
      productUnit: productUnit ?? this.productUnit,
    );
  }

  bool get isStockIn => quantity > 0;
  bool get isStockOut => quantity < 0;

  String get movementType {
    if (isStockIn) return 'Stock In';
    if (isStockOut) return 'Stock Out';
    return 'No Change';
  }

  String get formattedQuantity {
    if (isStockIn) return '+${quantity.abs().toStringAsFixed(2)}';
    if (isStockOut) return '-${quantity.abs().toStringAsFixed(2)}';
    return quantity.toStringAsFixed(2);
  }

  @override
  String toString() {
    return 'StockMovementModel(id: $id, productId: $productId, quantity: $quantity, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StockMovementModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Stock movement reasons enum
class StockMovementReason {
  static const String purchase = 'Purchase';
  static const String sale = 'Sale';
  static const String returnFromCustomer = 'Return from Customer';
  static const String returnToSupplier = 'Return to Supplier';
  static const String damage = 'Damage';
  static const String loss = 'Loss/Theft';
  static const String adjustment = 'Manual Adjustment';
  static const String initialStock = 'Initial Stock';
  static const String transfer = 'Transfer';
  static const String production = 'Production';
  static const String consumption = 'Consumption';
  static const String expired = 'Expired';
  static const String other = 'Other';

  static List<String> get all => [
        purchase,
        sale,
        returnFromCustomer,
        returnToSupplier,
        damage,
        loss,
        adjustment,
        initialStock,
        transfer,
        production,
        consumption,
        expired,
        other,
      ];

  static List<String> get stockInReasons => [
        purchase,
        returnFromCustomer,
        adjustment,
        initialStock,
        transfer,
        production,
      ];

  static List<String> get stockOutReasons => [
        sale,
        returnToSupplier,
        damage,
        loss,
        consumption,
        expired,
        transfer,
      ];
}
