import 'package:drift/drift.dart';
import '../database/database.dart' as db;

class ProductModel {
  final int? id;
  final String name;
  final String category;
  final double price; // Retail Cash
  final double cost; // Purchase Price
  final double stock;
  final String? barcode;
  final double discount;
  final double tax;
  final String unit;
  final String? description;
  final double reorderLevel;
  final double reorderQuantity;
  final int? supplierId;
  final DateTime? expiryDate;
  final String? batchNumber;
  final String? company;
  final double? marketPrice;
  final double? maxLevel;
  final String? packingMode;
  final double? wholesaleCash;
  final double? wholesaleCredit;
  final double? retailCredit;
  // Mobile Shop specific fields
  final String? brand;
  final String? modelName;
  final String? storageCapacity;
  final String? ram;
  final String? color;
  final String? condition;
  final String? unlockStatus;
  final String? warrantyStatus;
  final String? warrantyPeriod;
  final String? warrantyProvider;
  final String? displaySize;
  final String? batteryCapacity;
  final String? cameraSpecs;
  final String? operatingSystem;
  final String? networkType;
  final String? simCardType;
  final double? tradeInValue;
  final String? boxContents;
  // Restaurant specific fields
  final String? courseType; // appetizer, main_course, dessert, beverage, combo
  final int? preparationTime; // Preparation time in minutes
  final String? allergens; // Comma-separated allergens
  final String? modifiers; // Available modifiers/add-ons (JSON string)
  final String? dietaryInfo; // vegetarian, vegan, halal, kosher, etc.
  // Salon specific fields
  final String? productType; // product, service - for salon business
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.cost,
    this.stock = 0,
    this.barcode,
    this.discount = 0,
    this.tax = 0,
    this.unit = 'pcs',
    this.description,
    this.reorderLevel = 10,
    this.reorderQuantity = 50,
    this.supplierId,
    this.expiryDate,
    this.batchNumber,
    this.company,
    this.marketPrice,
    this.maxLevel,
    this.packingMode,
    this.wholesaleCash,
    this.wholesaleCredit,
    this.retailCredit,
    this.brand,
    this.modelName,
    this.storageCapacity,
    this.ram,
    this.color,
    this.condition,
    this.unlockStatus,
    this.warrantyStatus,
    this.warrantyPeriod,
    this.warrantyProvider,
    this.displaySize,
    this.batteryCapacity,
    this.cameraSpecs,
    this.operatingSystem,
    this.networkType,
    this.simCardType,
    this.tradeInValue,
    this.boxContents,
    this.courseType,
    this.preparationTime,
    this.allergens,
    this.modifiers,
    this.dietaryInfo,
    this.productType,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductModel.fromProduct(db.Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      category: product.category,
      price: product.price,
      cost: product.cost,
      stock: product.stock,
      barcode: product.barcode,
      discount: product.discount,
      tax: product.tax,
      unit: product.unit,
      description: product.description,
      reorderLevel: product.reorderLevel,
      reorderQuantity: product.reorderQuantity,
      supplierId: product.supplierId,
      expiryDate: product.expiryDate != null
          ? DateTime.tryParse(product.expiryDate!)
          : null,
      batchNumber: product.batchNumber,
      company: product.company,
      marketPrice: product.marketPrice,
      maxLevel: product.maxLevel,
      packingMode: product.packingMode,
      wholesaleCash: product.wholesaleCash,
      wholesaleCredit: product.wholesaleCredit,
      retailCredit: product.retailCredit,
      brand: product.brand,
      modelName: product.modelName,
      storageCapacity: product.storageCapacity,
      ram: product.ram,
      color: product.color,
      condition: product.condition,
      unlockStatus: product.unlockStatus,
      warrantyStatus: product.warrantyStatus,
      warrantyPeriod: product.warrantyPeriod,
      warrantyProvider: product.warrantyProvider,
      displaySize: product.displaySize,
      batteryCapacity: product.batteryCapacity,
      cameraSpecs: product.cameraSpecs,
      operatingSystem: product.operatingSystem,
      networkType: product.networkType,
      simCardType: product.simCardType,
      tradeInValue: product.tradeInValue,
      boxContents: product.boxContents,
      courseType: product.courseType,
      preparationTime: product.preparationTime,
      allergens: product.allergens,
      modifiers: product.modifiers,
      dietaryInfo: product.dietaryInfo,
      productType: product.productType,
      isActive: product.isActive,
      createdAt: DateTime.parse(product.createdAt),
      updatedAt: DateTime.parse(product.updatedAt),
    );
  }

  db.Product toProduct() {
    return db.Product(
      id: id ?? 0,
      name: name,
      category: category,
      price: price,
      cost: cost,
      stock: stock,
      barcode: barcode,
      discount: discount,
      tax: tax,
      unit: unit,
      description: description,
      reorderLevel: reorderLevel,
      reorderQuantity: reorderQuantity,
      supplierId: supplierId,
      expiryDate: expiryDate?.toIso8601String(),
      batchNumber: batchNumber,
      company: company,
      marketPrice: marketPrice,
      maxLevel: maxLevel,
      packingMode: packingMode,
      wholesaleCash: wholesaleCash,
      wholesaleCredit: wholesaleCredit,
      retailCredit: retailCredit,
      brand: brand,
      modelName: modelName,
      storageCapacity: storageCapacity,
      ram: ram,
      color: color,
      condition: condition,
      unlockStatus: unlockStatus,
      warrantyStatus: warrantyStatus,
      warrantyPeriod: warrantyPeriod,
      warrantyProvider: warrantyProvider,
      displaySize: displaySize,
      batteryCapacity: batteryCapacity,
      cameraSpecs: cameraSpecs,
      operatingSystem: operatingSystem,
      networkType: networkType,
      simCardType: simCardType,
      tradeInValue: tradeInValue,
      boxContents: boxContents,
      courseType: courseType,
      preparationTime: preparationTime,
      allergens: allergens,
      modifiers: modifiers,
      dietaryInfo: dietaryInfo,
      productType: productType,
      isActive: isActive,
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  db.ProductsCompanion toCompanion() {
    return db.ProductsCompanion(
      name: Value(name),
      category: Value(category),
      price: Value(price),
      cost: Value(cost),
      stock: Value(stock),
      barcode: Value(barcode),
      discount: Value(discount),
      tax: Value(tax),
      unit: Value(unit),
      description: Value(description),
      reorderLevel: Value(reorderLevel),
      reorderQuantity: Value(reorderQuantity),
      supplierId: Value(supplierId),
      expiryDate: Value(expiryDate?.toIso8601String()),
      batchNumber: Value(batchNumber),
      company: Value(company),
      marketPrice: Value(marketPrice),
      maxLevel: Value(maxLevel),
      packingMode: Value(packingMode),
      wholesaleCash: Value(wholesaleCash),
      wholesaleCredit: Value(wholesaleCredit),
      retailCredit: Value(retailCredit),
      brand: Value(brand),
      modelName: Value(modelName),
      storageCapacity: Value(storageCapacity),
      ram: Value(ram),
      color: Value(color),
      condition: Value(condition),
      unlockStatus: Value(unlockStatus),
      warrantyStatus: Value(warrantyStatus),
      warrantyPeriod: Value(warrantyPeriod),
      warrantyProvider: Value(warrantyProvider),
      displaySize: Value(displaySize),
      batteryCapacity: Value(batteryCapacity),
      cameraSpecs: Value(cameraSpecs),
      operatingSystem: Value(operatingSystem),
      networkType: Value(networkType),
      simCardType: Value(simCardType),
      tradeInValue: Value(tradeInValue),
      boxContents: Value(boxContents),
      courseType: Value(courseType),
      preparationTime: Value(preparationTime),
      allergens: Value(allergens),
      modifiers: Value(modifiers),
      dietaryInfo: Value(dietaryInfo),
      productType: Value(productType),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }

  ProductModel copyWith({
    int? id,
    String? name,
    String? category,
    double? price,
    double? cost,
    double? stock,
    String? barcode,
    double? discount,
    double? tax,
    String? unit,
    String? description,
    double? reorderLevel,
    double? reorderQuantity,
    int? supplierId,
    DateTime? expiryDate,
    String? batchNumber,
    String? company,
    double? marketPrice,
    double? maxLevel,
    String? packingMode,
    double? wholesaleCash,
    double? wholesaleCredit,
    double? retailCredit,
    String? brand,
    String? modelName,
    String? storageCapacity,
    String? ram,
    String? color,
    String? condition,
    String? unlockStatus,
    String? warrantyStatus,
    String? warrantyPeriod,
    String? warrantyProvider,
    String? displaySize,
    String? batteryCapacity,
    String? cameraSpecs,
    String? operatingSystem,
    String? networkType,
    String? simCardType,
    double? tradeInValue,
    String? boxContents,
    String? courseType,
    int? preparationTime,
    String? allergens,
    String? modifiers,
    String? dietaryInfo,
    String? productType,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      barcode: barcode ?? this.barcode,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      reorderQuantity: reorderQuantity ?? this.reorderQuantity,
      supplierId: supplierId ?? this.supplierId,
      expiryDate: expiryDate ?? this.expiryDate,
      batchNumber: batchNumber ?? this.batchNumber,
      company: company ?? this.company,
      marketPrice: marketPrice ?? this.marketPrice,
      maxLevel: maxLevel ?? this.maxLevel,
      packingMode: packingMode ?? this.packingMode,
      wholesaleCash: wholesaleCash ?? this.wholesaleCash,
      wholesaleCredit: wholesaleCredit ?? this.wholesaleCredit,
      retailCredit: retailCredit ?? this.retailCredit,
      brand: brand ?? this.brand,
      modelName: modelName ?? this.modelName,
      storageCapacity: storageCapacity ?? this.storageCapacity,
      ram: ram ?? this.ram,
      color: color ?? this.color,
      condition: condition ?? this.condition,
      unlockStatus: unlockStatus ?? this.unlockStatus,
      warrantyStatus: warrantyStatus ?? this.warrantyStatus,
      warrantyPeriod: warrantyPeriod ?? this.warrantyPeriod,
      warrantyProvider: warrantyProvider ?? this.warrantyProvider,
      displaySize: displaySize ?? this.displaySize,
      batteryCapacity: batteryCapacity ?? this.batteryCapacity,
      cameraSpecs: cameraSpecs ?? this.cameraSpecs,
      operatingSystem: operatingSystem ?? this.operatingSystem,
      networkType: networkType ?? this.networkType,
      simCardType: simCardType ?? this.simCardType,
      tradeInValue: tradeInValue ?? this.tradeInValue,
      boxContents: boxContents ?? this.boxContents,
      courseType: courseType ?? this.courseType,
      preparationTime: preparationTime ?? this.preparationTime,
      allergens: allergens ?? this.allergens,
      modifiers: modifiers ?? this.modifiers,
      dietaryInfo: dietaryInfo ?? this.dietaryInfo,
      productType: productType ?? this.productType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double get profit => price - cost;
  double get profitMargin => cost > 0 ? ((price - cost) / cost) * 100 : 0;
  bool get isLowStock => stock <= reorderLevel;

  @override
  String toString() {
    return 'ProductModel(id: $id, name: $name, category: $category, price: $price, stock: $stock)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'cost': cost,
      'stock': stock,
      'barcode': barcode,
      'discount': discount,
      'tax': tax,
      'unit': unit,
      'description': description,
      'reorderLevel': reorderLevel,
      'reorderQuantity': reorderQuantity,
      'supplierId': supplierId,
      'expiryDate': expiryDate?.toIso8601String(),
      'batchNumber': batchNumber,
      'company': company,
      'marketPrice': marketPrice,
      'maxLevel': maxLevel,
      'packingMode': packingMode,
      'wholesaleCash': wholesaleCash,
      'wholesaleCredit': wholesaleCredit,
      'retailCredit': retailCredit,
      'brand': brand,
      'modelName': modelName,
      'storageCapacity': storageCapacity,
      'ram': ram,
      'color': color,
      'condition': condition,
      'unlockStatus': unlockStatus,
      'warrantyStatus': warrantyStatus,
      'warrantyPeriod': warrantyPeriod,
      'warrantyProvider': warrantyProvider,
      'displaySize': displaySize,
      'batteryCapacity': batteryCapacity,
      'cameraSpecs': cameraSpecs,
      'operatingSystem': operatingSystem,
      'networkType': networkType,
      'simCardType': simCardType,
      'tradeInValue': tradeInValue,
      'boxContents': boxContents,
      'courseType': courseType,
      'preparationTime': preparationTime,
      'allergens': allergens,
      'modifiers': modifiers,
      'dietaryInfo': dietaryInfo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
      barcode: json['barcode'],
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] ?? 'pcs',
      description: json['description'],
      reorderLevel: (json['reorderLevel'] as num?)?.toDouble() ?? 10.0,
      reorderQuantity: (json['reorderQuantity'] as num?)?.toDouble() ?? 50.0,
      supplierId: json['supplierId'],
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'])
          : null,
      batchNumber: json['batchNumber'],
      company: json['company'],
      marketPrice: (json['marketPrice'] as num?)?.toDouble(),
      maxLevel: (json['maxLevel'] as num?)?.toDouble(),
      packingMode: json['packingMode'],
      wholesaleCash: (json['wholesaleCash'] as num?)?.toDouble(),
      wholesaleCredit: (json['wholesaleCredit'] as num?)?.toDouble(),
      retailCredit: (json['retailCredit'] as num?)?.toDouble(),
      brand: json['brand'],
      modelName: json['modelName'],
      storageCapacity: json['storageCapacity'],
      ram: json['ram'],
      color: json['color'],
      condition: json['condition'],
      unlockStatus: json['unlockStatus'],
      warrantyStatus: json['warrantyStatus'],
      warrantyPeriod: json['warrantyPeriod'],
      warrantyProvider: json['warrantyProvider'],
      displaySize: json['displaySize'],
      batteryCapacity: json['batteryCapacity'],
      cameraSpecs: json['cameraSpecs'],
      operatingSystem: json['operatingSystem'],
      networkType: json['networkType'],
      simCardType: json['simCardType'],
      tradeInValue: (json['tradeInValue'] as num?)?.toDouble(),
      boxContents: json['boxContents'],
      courseType: json['courseType'],
      preparationTime: json['preparationTime'] as int?,
      allergens: json['allergens'],
      modifiers: json['modifiers'],
      dietaryInfo: json['dietaryInfo'],
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

enum ProductLedgerEntryType { sale, purchase, stockAdjustment }

class ProductLedgerEntry {
  final int entryId;
  final ProductLedgerEntryType type;
  final int referenceId;
  final String invoiceNumber;
  final DateTime date;
  final double quantity;
  final double rate;
  final double total;
  final String? counterpartyName;
  final String? notes;

  const ProductLedgerEntry({
    required this.entryId,
    required this.type,
    required this.referenceId,
    required this.invoiceNumber,
    required this.date,
    required this.quantity,
    required this.rate,
    required this.total,
    this.counterpartyName,
    this.notes,
  });

  bool get isSale => type == ProductLedgerEntryType.sale;
  bool get isPurchase => type == ProductLedgerEntryType.purchase;
  bool get isStockAdjustment => type == ProductLedgerEntryType.stockAdjustment;
  String get typeLabel {
    switch (type) {
      case ProductLedgerEntryType.sale:
        return 'Sale';
      case ProductLedgerEntryType.purchase:
        return 'Purchase';
      case ProductLedgerEntryType.stockAdjustment:
        // Show "Stock In" for positive quantities, "Stock Out" for negative
        return quantity > 0 ? 'Stock In' : 'Stock Out';
    }
  }
}
