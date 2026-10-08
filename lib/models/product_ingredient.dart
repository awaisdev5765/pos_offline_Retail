import '../database/database.dart' as db;
import 'package:drift/drift.dart' as drift;
import 'product.dart';

enum IngredientCostType {
  quantityBased,
  fixedCost;

  static IngredientCostType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'quantity_based':
      case 'quantitybased':
        return IngredientCostType.quantityBased;
      case 'fixed_cost':
      case 'fixedcost':
        return IngredientCostType.fixedCost;
      default:
        return IngredientCostType.quantityBased;
    }
  }

  String toStringValue() {
    switch (this) {
      case IngredientCostType.quantityBased:
        return 'quantity_based';
      case IngredientCostType.fixedCost:
        return 'fixed_cost';
    }
  }
}

class ProductIngredientModel {
  final int? id;
  final int productId; // The menu item (e.g., Burger)
  final int ingredientProductId; // The ingredient from inventory (e.g., Chicken Fillet)
  final double quantity; // Quantity needed (e.g., 100 for grams)
  final String unit; // Unit of measurement (gm, ml, pcs, etc.)
  final IngredientCostType costType; // 'quantity_based' or 'fixed_cost'
  final double? fixedCost; // Fixed cost (e.g., Rs 30 for bun, Rs 10 for packing)
  final int sortOrder; // Order in which ingredients appear
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProductModel? ingredientProduct; // The actual product model for the ingredient

  ProductIngredientModel({
    this.id,
    required this.productId,
    required this.ingredientProductId,
    required this.quantity,
    required this.unit,
    required this.costType,
    this.fixedCost,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.ingredientProduct,
  });

  factory ProductIngredientModel.fromIngredient(
    db.ProductIngredient ingredient, {
    ProductModel? ingredientProduct,
  }) {
    return ProductIngredientModel(
      id: ingredient.id,
      productId: ingredient.productId,
      ingredientProductId: ingredient.ingredientProductId,
      quantity: ingredient.quantity,
      unit: ingredient.unit,
      costType: IngredientCostType.fromString(ingredient.costType),
      fixedCost: ingredient.fixedCost,
      sortOrder: ingredient.sortOrder,
      createdAt: DateTime.parse(ingredient.createdAt),
      updatedAt: DateTime.parse(ingredient.updatedAt),
      ingredientProduct: ingredientProduct,
    );
  }

  /// Calculate the cost of this ingredient
  /// For quantity-based: quantity * (ingredient product cost per unit)
  /// For fixed-cost: uses the fixedCost value
  double calculateCost() {
    if (costType == IngredientCostType.fixedCost) {
      return fixedCost ?? 0.0;
    } else {
      // Quantity-based costing
      if (ingredientProduct == null) return 0.0;
      
      // Get the cost per unit from the ingredient product
      double costPerUnit = ingredientProduct!.cost;
      
      // Calculate total cost
      // Note: This assumes the unit matches. For more complex conversions,
      // additional logic would be needed (e.g., gm to kg conversion)
      return quantity * costPerUnit;
    }
  }

  db.ProductIngredientsCompanion toCompanion() {
    return db.ProductIngredientsCompanion.insert(
      productId: productId,
      ingredientProductId: ingredientProductId,
      quantity: quantity,
      unit: unit,
      costType: costType.toStringValue(),
      fixedCost: fixedCost != null ? drift.Value(fixedCost!) : const drift.Value.absent(),
      sortOrder: drift.Value(sortOrder),
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  db.ProductIngredient toIngredient() {
    if (id == null) {
      throw Exception('Cannot convert to ProductIngredient without id');
    }
    return db.ProductIngredient(
      id: id!,
      productId: productId,
      ingredientProductId: ingredientProductId,
      quantity: quantity,
      unit: unit,
      costType: costType.toStringValue(),
      fixedCost: fixedCost,
      sortOrder: sortOrder,
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  ProductIngredientModel copyWith({
    int? id,
    int? productId,
    int? ingredientProductId,
    double? quantity,
    String? unit,
    IngredientCostType? costType,
    double? fixedCost,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProductModel? ingredientProduct,
  }) {
    return ProductIngredientModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      ingredientProductId: ingredientProductId ?? this.ingredientProductId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      costType: costType ?? this.costType,
      fixedCost: fixedCost ?? this.fixedCost,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ingredientProduct: ingredientProduct ?? this.ingredientProduct,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'ingredientProductId': ingredientProductId,
      'quantity': quantity,
      'unit': unit,
      'costType': costType.toStringValue(),
      'fixedCost': fixedCost,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProductIngredientModel.fromJson(Map<String, dynamic> json) {
    return ProductIngredientModel(
      id: json['id'] as int?,
      productId: json['productId'] as int,
      ingredientProductId: json['ingredientProductId'] as int,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      costType: IngredientCostType.fromString(json['costType'] as String),
      fixedCost: json['fixedCost'] != null ? (json['fixedCost'] as num).toDouble() : null,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
