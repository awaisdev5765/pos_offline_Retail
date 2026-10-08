import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../models/product_bundle.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../providers/product_provider.dart';
import '../providers/sale_provider.dart';
import '../services/database_service.dart';
import '../providers/auth_provider.dart';
import '../providers/tax_provider.dart';
import '../models/product_ingredient.dart';

/// Controller for POS business logic
/// Separates business logic from UI
class PosController {
  final Ref ref;
  
  PosController(this.ref);

  /// Check if a product is a phone (requires IMEI) - Retail only, always false
  bool isPhoneProduct(ProductModel product, bool isMobileShop) {
    return false;
  }

  /// Get safe product ID
  String safeGetProductId(ProductModel product) {
    try {
      return product.id?.toString() ?? 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Get safe product name
  String safeGetProductName(ProductModel product) {
    try {
      return product.name.isEmpty ? 'Unknown Product' : product.name;
    } catch (e) {
      return 'Unknown Product';
    }
  }

  /// Calculate item price based on mode and payment type
  double calculateItemPrice({
    required CartItem item,
    required bool isWholesaleMode,
    required String paymentType,
    required Map<String, double> itemPrices,
  }) {
    try {
      if (item.isBundle || item.product == null) {
        return item.subtotal / (item.quantity > 0 ? item.quantity : 1);
      }

      final productId = safeGetProductId(item.product!);
      
      // Check for custom price first
      if (itemPrices.containsKey(productId)) {
        final customPrice = itemPrices[productId]!;
        return customPrice.isNaN || customPrice.isInfinite ? 0.0 : customPrice;
      }

      double basePrice;
      if (isWholesaleMode) {
        // Wholesale mode: use wholesale cash or credit price based on payment type
        if (paymentType == 'credit') {
          basePrice = item.product!.wholesaleCredit ?? item.product!.price;
        } else {
          basePrice = item.product!.wholesaleCash ?? item.product!.price;
        }
      } else {
        // Retail mode: use retail cash or credit price based on payment type
        if (paymentType == 'credit') {
          basePrice = item.product!.retailCredit ?? item.product!.price;
        } else {
          basePrice = item.product!.price;
        }
      }

      return basePrice.isNaN || basePrice.isInfinite ? 0.0 : basePrice;
    } catch (e) {
      debugPrint('Error getting item price: $e');
      return 0.0;
    }
  }

  /// Calculate item discount
  double calculateItemDiscount({
    required CartItem item,
    required Map<String, double> itemDiscounts,
  }) {
    try {
      // Bundles don't have item-level discounts
      if (item.isBundle) return 0.0;
      
      if (item.product == null) return 0.0;
      
      final productId = safeGetProductId(item.product!);
      final discount = itemDiscounts[productId] ?? 0.0;
      return discount.isNaN || discount.isInfinite ? 0.0 : discount;
    } catch (e) {
      debugPrint('Error getting item discount: $e');
      return 0.0;
    }
  }

  /// Calculate item subtotal
  double calculateItemSubtotal({
    required CartItem item,
    required bool isWholesaleMode,
    required String paymentType,
    required Map<String, double> itemPrices,
    required Map<String, double> itemDiscounts,
  }) {
    try {
      final price = calculateItemPrice(
        item: item,
        isWholesaleMode: isWholesaleMode,
        paymentType: paymentType,
        itemPrices: itemPrices,
      );
      final discount = calculateItemDiscount(
        item: item,
        itemDiscounts: itemDiscounts,
      );
      final quantity =
          item.quantity.isNaN || item.quantity.isInfinite ? 0.0 : item.quantity;

      final discountedPrice = price - discount;
      final safeDiscountedPrice =
          discountedPrice.isNaN || discountedPrice.isInfinite
              ? 0.0
              : discountedPrice;
      final subtotal = safeDiscountedPrice * quantity;

      return subtotal.isNaN || subtotal.isInfinite ? 0.0 : subtotal;
    } catch (e) {
      debugPrint('Error calculating subtotal: $e');
      return 0.0;
    }
  }

  /// Check stock availability before payment
  Future<String?> validateStockAvailability(List<CartItem> cart) async {
    final databaseService = ref.read(databaseServiceProvider);
    final businessNature = 'retail';
    
    for (final item in cart) {
      if (item.isBundle && item.bundle != null) {
        // Check stock for all items in bundle
        for (final bundleItem in item.bundle!.items) {
          if (bundleItem.product.id != null) {
            final product = await databaseService.getProductById(bundleItem.product.id!);
            if (product != null) {
              final requiredQty = bundleItem.quantity * item.quantity;
              if (requiredQty > 0 && product.stock < requiredQty) {
                return 'Insufficient stock for ${safeGetProductName(product)} in bundle "${item.bundle!.name}". Required: ${requiredQty.toStringAsFixed(2)}, Available: ${product.stock.toStringAsFixed(2)}';
              }
            }
          }
        }
      } else if (item.product != null && item.product!.id != null) {
        // Get latest product data from database to ensure accurate stock
        final product = await databaseService.getProductById(item.product!.id!);
        if (product != null) {
          // Check if this is a service in salon business - skip stock validation for services
          final isService = businessNature == 'salon' && (product.productType == 'service' || product.productType == null);
          
          // Skip stock validation for services in salon business
          if (!isService) {
            // Check if product is out of stock (only for positive quantities)
            if (item.quantity > 0 && product.stock <= 0) {
              return 'Product ${safeGetProductName(product)} is out of stock.';
            }

            // Check if requested quantity exceeds available stock
            if (item.quantity > 0 && item.quantity > product.stock) {
              return 'Product ${safeGetProductName(product)} is out of stock.';
            }
          }
        }
      }
    }
    
    return null; // No stock issues
  }

  /// Validate ingredient stock for restaurant products
  Future<List<String>> validateIngredientStock(List<CartItem> cart) async {
    final businessNature = 'retail';
    if (businessNature != 'restaurant') return [];
    
    final databaseService = ref.read(databaseServiceProvider);
    final insufficientIngredients = <String>[];
    
    for (final item in cart) {
      if (item.product?.id != null) {
        final ingredients = await databaseService.getIngredientsByProductId(item.product!.id!);
        for (final ingredient in ingredients) {
          if (ingredient.costType == IngredientCostType.quantityBased && ingredient.ingredientProduct != null) {
            // Calculate required quantity
            double qtyRequired = ingredient.quantity * item.quantity;
            
            // Convert units if needed
            final ingredientProduct = ingredient.ingredientProduct!;
            if (ingredientProduct.unit.toLowerCase() == 'kg' && ingredient.unit.toLowerCase() == 'gm') {
              qtyRequired = qtyRequired / 1000;
            } else if (ingredientProduct.unit.toLowerCase() == 'liter' && ingredient.unit.toLowerCase() == 'ml') {
              qtyRequired = qtyRequired / 1000;
            }
            
            // Check if stock is sufficient
            if (ingredientProduct.stock < qtyRequired) {
              insufficientIngredients.add(
                '${ingredientProduct.name}: Need ${qtyRequired.toStringAsFixed(2)} ${ingredientProduct.unit}, Available: ${ingredientProduct.stock.toStringAsFixed(2)} ${ingredientProduct.unit} (for ${item.product!.name})'
              );
            }
          }
        }
      }
    }
    
    return insufficientIngredients;
  }

  /// Check credit limit for customer
  bool checkCreditLimit(CustomerModel customer, double dueAmount) {
    // Only check if customer has a credit limit set
    if (customer.creditLimit > 0) {
      // Calculate new total due after this order
      final newTotalDue = customer.totalDue + dueAmount;

      // Check if new total due exceeds credit limit
      return newTotalDue <= customer.creditLimit;
    }
    return true; // No limit set, allow
  }

  /// Calculate cart totals
  CartTotals calculateCartTotals({
    required List<CartItem> cart,
    required bool isWholesaleMode,
    required String paymentType,
    required Map<String, double> itemPrices,
    required Map<String, double> itemDiscounts,
    required double discount,
    required String discountType,
  }) {
    // Calculate subtotal
    final subtotal = cart.fold(0.0, (sum, item) {
      try {
        final basePrice = calculateItemPrice(
          item: item,
          isWholesaleMode: isWholesaleMode,
          paymentType: paymentType,
          itemPrices: itemPrices,
        );
        final safePrice =
            basePrice.isNaN || basePrice.isInfinite ? 0.0 : basePrice;
        final safeQuantity = item.quantity.isNaN || item.quantity.isInfinite
            ? 0.0
            : item.quantity;
        return sum + (safePrice * safeQuantity);
      } catch (e) {
        return sum;
      }
    });
    
    // Calculate discount amount
    final discountAmount = discountType == 'percentage'
        ? (subtotal * discount / 100)
        : discount;
    
    final subtotalAfterDiscount = subtotal - discountAmount;

    // Get tax rate and calculate tax
    final taxRate = ref.read(currentTaxRateProvider);
    final taxAmount = TaxCalculator.calculateTax(subtotalAfterDiscount, taxRate);
    final total = subtotalAfterDiscount + taxAmount;

    return CartTotals(
      subtotal: subtotal,
      discount: discountAmount,
      subtotalAfterDiscount: subtotalAfterDiscount,
      tax: taxAmount,
      total: total,
    );
  }

  /// Clamp payment amount to total
  double clampPaymentToTotal(double amount, double total) {
    if (amount.isNaN || amount.isInfinite) {
      return total >= 0 ? 0.0 : total;
    }
    final lowerLimit = total >= 0 ? 0.0 : total;
    final upperLimit = total >= 0 ? total : 0.0;
    return amount.clamp(lowerLimit, upperLimit);
  }
}

/// Cart totals data class
class CartTotals {
  final double subtotal;
  final double discount;
  final double subtotalAfterDiscount;
  final double tax;
  final double total;

  CartTotals({
    required this.subtotal,
    required this.discount,
    required this.subtotalAfterDiscount,
    required this.tax,
    required this.total,
  });
}

/// Provider for POS controller
final posControllerProvider = Provider<PosController>((ref) {
  return PosController(ref);
});

