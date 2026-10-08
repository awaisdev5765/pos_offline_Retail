import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../models/currency.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EnhancedProductCard extends ConsumerStatefulWidget {
  final ProductModel product;
  final Currency currency;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showStockWarning;

  const EnhancedProductCard({
    super.key,
    required this.product,
    required this.currency,
    this.onTap,
    this.isSelected = false,
    this.showStockWarning = true,
  });

  @override
  ConsumerState<EnhancedProductCard> createState() =>
      _EnhancedProductCardState();
}

class _EnhancedProductCardState extends ConsumerState<EnhancedProductCard> {
  bool get _isMobileShop {
    final businessNature = 'retail';
    return businessNature == 'mobile_shop';
  }

  bool get _hasMobileData {
    return widget.product.brand != null ||
        widget.product.modelName != null ||
        widget.product.storageCapacity != null ||
        widget.product.color != null;
  }

  @override
  Widget build(BuildContext context) {
    // Null safety checks
    final stock = widget.product.stock.isNaN ? 0.0 : widget.product.stock;
    final price = widget.product.price.isNaN ? 0.0 : widget.product.price;
    final reorderLevel =
        widget.product.reorderLevel.isNaN ? 0.0 : widget.product.reorderLevel;
    final productName =
        widget.product.name.isEmpty ? 'Unknown Product' : widget.product.name;
    final productUnit =
        widget.product.unit.isEmpty ? 'pcs' : widget.product.unit;

    final businessNature = 'retail';
    final isService = businessNature == 'salon' &&
        (widget.product.productType == 'service' ||
            widget.product.productType == null);
    // Services don't have stock management, so no stock warnings
    final isLowStock = isService ? false : (stock <= reorderLevel);
    final isOutOfStock = isService ? false : (stock <= 0);

    // Check if this is a mobile product
    final isMobileProduct = _isMobileShop && _hasMobileData;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isSelected
              ? AppColors.primaryColor
              : const Color(0xFFE2E8F0),
          width: widget.isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isOutOfStock ? null : widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Product Icon
                Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _getProductColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getProductIcon(),
                    size: 26,
                    color: _getProductColor(),
                  ),
                ),
                const SizedBox(height: 6),
                // Product Name or Brand + Model for mobile
                if (isMobileProduct && widget.product.brand != null)
                  Column(
                    children: [
                      Text(
                        widget.product.brand!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      if (widget.product.modelName != null)
                        Text(
                          widget.product.modelName!,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                    ],
                  )
                else
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                // Mobile specs (Storage + RAM + Color)
                if (isMobileProduct &&
                    (widget.product.storageCapacity != null ||
                        widget.product.ram != null ||
                        widget.product.color != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        if (widget.product.storageCapacity != null)
                          widget.product.storageCapacity!,
                        if (widget.product.ram != null) widget.product.ram!,
                        if (widget.product.color != null) widget.product.color!,
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 7.5,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 4),
                // Price
                Text(
                  '${widget.currency.symbol.trim()} ${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _getProductColor(),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                // Stock Info - Hidden for salon business
                if (businessNature != 'salon')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory,
                        size: 12,
                        color: isLowStock ? Colors.orange : Colors.grey[600],
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          '${stock.toStringAsFixed(0)} $productUnit',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isLowStock ? Colors.orange : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                // Condition badge for mobile products
                if (isMobileProduct && widget.product.condition != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _getConditionColor(widget.product.condition!),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        widget.product.condition!.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 6.5,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                // Stock Status Badge - Hidden for services in salon
                if (!isService &&
                    widget.showStockWarning &&
                    (isLowStock || isOutOfStock))
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    decoration: BoxDecoration(
                      color: isOutOfStock ? Colors.red : Colors.orange,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      isOutOfStock ? 'OUT' : 'LOW',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getProductColor() {
    // Return different colors based on category
    switch (widget.product.category.toLowerCase()) {
      case 'electronics':
        return Colors.blue;
      case 'clothing':
        return Colors.purple;
      case 'food':
        return Colors.green;
      case 'books':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getProductIcon() {
    // Return different icons based on category
    switch (widget.product.category.toLowerCase()) {
      case 'electronics':
      case 'smartphones':
        return Icons.phone_android;
      case 'clothing':
        return Icons.checkroom;
      case 'food':
        return Icons.restaurant;
      case 'books':
        return Icons.menu_book;
      default:
        return Icons.inventory;
    }
  }

  Color _getConditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'new':
        return Colors.green;
      case 'refurbished':
        return Colors.blue;
      case 'used':
        return Colors.orange;
      case 'open_box':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// Compact version for smaller grids
class CompactProductCard extends ConsumerWidget {
  final ProductModel product;
  final Currency currency;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const CompactProductCard({
    super.key,
    required this.product,
    required this.currency,
    this.onTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOutOfStock = product.stock <= 0;
    final businessNature = 'retail';
    final isMobileShop = businessNature == 'mobile_shop';
    final hasMobileData = product.brand != null ||
        product.modelName != null ||
        product.storageCapacity != null ||
        product.color != null;
    final isMobileProduct = isMobileShop && hasMobileData;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Icon
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isMobileProduct ? Icons.phone_android : Icons.inventory,
                  color: AppColors.primaryColor,
                  size: 20,
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Product Name or Brand + Model for mobile
              if (isMobileProduct && product.brand != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.brand!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.modelName != null)
                      Text(
                        product.modelName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (product.storageCapacity != null ||
                        product.color != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                            if (product.storageCapacity != null)
                              product.storageCapacity!,
                            if (product.color != null) product.color!,
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                )
              else
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: AppSpacing.xs),

              // Price
              Text(
                '${currency.symbol}${product.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              // Condition badge for mobile products
              if (isMobileProduct && product.condition != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getConditionColor(product.condition!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.condition!.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Stock
              Text(
                '${product.stock.toStringAsFixed(0)} ${product.unit}',
                style: TextStyle(
                  fontSize: 12,
                  color: isOutOfStock ? Colors.red : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getConditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'new':
        return Colors.green;
      case 'refurbished':
        return Colors.blue;
      case 'used':
        return Colors.orange;
      case 'open_box':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
