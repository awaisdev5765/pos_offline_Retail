import 'package:drift/drift.dart';
import '../database/database.dart' as db;
import 'product.dart';

class ProductBundleModel {
  final int? id;
  final String name;
  final String? description;
  final double price;
  final double cost;
  final String? category;
  final bool isActive;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductBundleItemModel> items;

  ProductBundleModel({
    this.id,
    required this.name,
    this.description,
    required this.price,
    required this.cost,
    this.category,
    this.isActive = true,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory ProductBundleModel.fromBundle(
      db.ProductBundle bundle, {
        List<ProductBundleItemModel>? items,
      }) {
    return ProductBundleModel(
      id: bundle.id,
      name: bundle.name,
      description: bundle.description,
      price: bundle.price,
      cost: bundle.cost,
      category: bundle.category,
      isActive: bundle.isActive,
      imagePath: bundle.imagePath,
      createdAt: DateTime.parse(bundle.createdAt),
      updatedAt: DateTime.parse(bundle.updatedAt),
      items: items ?? [],
    );
  }

  db.ProductBundlesCompanion toCompanion() {
    return db.ProductBundlesCompanion(
      name: Value(name),
      description: Value(description),
      price: Value(price),
      cost: Value(cost),
      category: Value(category),
      isActive: Value(isActive),
      imagePath: Value(imagePath),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }

  double get discountAmount {
    double totalItemPrice = items.fold(0.0, (sum, item) {
      final itemPrice = item.price ?? item.product.price;
      return sum + (itemPrice * item.quantity);
    });
    return totalItemPrice - price;
  }

  double get discountPercentage {
    double totalItemPrice = items.fold(0.0, (sum, item) {
      final itemPrice = item.price ?? item.product.price;
      return sum + (itemPrice * item.quantity);
    });
    if (totalItemPrice == 0) return 0;
    return ((discountAmount / totalItemPrice) * 100);
  }

  double get profit => price - cost;
  double get profitMargin => cost > 0 ? ((price - cost) / cost) * 100 : 0;

  ProductBundleModel copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    double? cost,
    String? category,
    bool? isActive,
    String? imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ProductBundleItemModel>? items,
  }) {
    return ProductBundleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }
}

class ProductBundleItemModel {
  final int? id;
  final int bundleId;
  final ProductModel product;
  final double quantity;
  final double? price;

  ProductBundleItemModel({
    this.id,
    required this.bundleId,
    required this.product,
    this.quantity = 1,
    this.price,
  });

  factory ProductBundleItemModel.fromBundleItem(
      db.ProductBundleItem bundleItem,
      ProductModel product,
      ) {
    return ProductBundleItemModel(
      id: bundleItem.id,
      bundleId: bundleItem.bundleId,
      product: product,
      quantity: bundleItem.quantity,
      price: bundleItem.price,
    );
  }

  db.ProductBundleItemsCompanion toCompanion() {
    return db.ProductBundleItemsCompanion(
      bundleId: Value(bundleId),
      productId: Value(product.id!),
      quantity: Value(quantity),
      price: Value(price),
      createdAt: Value(DateTime.now().toIso8601String()),
    );
  }

  double get effectivePrice => price ?? product.price;
  double get subtotal => effectivePrice * quantity;
}