import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/currency.dart';
import '../../models/product.dart';
import '../../providers/currency_provider.dart';

/// Reusable product card widget for POS screen
/// Extracted from pos_screen.dart for better code organization
class ProductCardWidget extends ConsumerWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isMobile;
  final bool isEnhanced;

  const ProductCardWidget({
    super.key,
    required this.product,
    required this.onTap,
    this.onLongPress,
    this.isMobile = false,
    this.isEnhanced = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessNature = 'retail';
    final currency = ref.watch(currentCurrencyProvider);
    final isService = businessNature == 'salon' && 
        (product.productType == 'service' || product.productType == null);
    final isLowStock = isService ? false : (product.stock <= 5);
    final isOutOfStock = isService ? false : (product.stock <= 0);

    if (isMobile) {
      return _buildMobileCard(context, ref, isService, isLowStock, isOutOfStock, currency);
    } else {
      return _buildDesktopCard(context, ref, isService, isLowStock, isOutOfStock, currency);
    }
  }

  Widget _buildMobileCard(
    BuildContext context,
    WidgetRef ref,
    bool isService,
    bool isLowStock,
    bool isOutOfStock,
    Currency currency,
  ) {
    return GestureDetector(
      onTap: isService ? onTap : (isOutOfStock ? null : onTap),
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: (!isService && isOutOfStock)
                        ? [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)]
                        : [
                            const Color(0xFF3B82F6).withValues(alpha: 0.1),
                            const Color(0xFF1D4ED8).withValues(alpha: 0.1)
                          ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _getProductIcon(product.category),
                        size: 32,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                    if (!isService && isLowStock && !isOutOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Low Stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (!isService && isOutOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Out of Stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF1E293B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currency.symbol}${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF059669),
                      ),
                    ),
                    if ('retail' != 'salon') ...[
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Stock: ${product.stock.toInt()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isOutOfStock
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6)
                                  .withValues(alpha: isOutOfStock ? 0.05 : 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 16,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopCard(
    BuildContext context,
    WidgetRef ref,
    bool isService,
    bool isLowStock,
    bool isOutOfStock,
    Currency currency,
  ) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              onLongPress?.call();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF3B82F6)
                                    .withValues(alpha: 0.1),
                                const Color(0xFF1D4ED8)
                                    .withValues(alpha: 0.1)
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _getProductIcon(product.category),
                              size: 20,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${currency.symbol}${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669),
                                ),
                              ),
                              if ('retail' != 'salon') ...[
                                const Spacer(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Stock: ${product.stock.toInt()}',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: isLowStock
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (isOutOfStock)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'OUT',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isLowStock && !isOutOfStock)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LOW',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getProductIcon(String category) {
    switch (category.toLowerCase()) {
      case 'electronics':
        return Icons.devices;
      case 'clothing':
        return Icons.checkroom;
      case 'food':
        return Icons.restaurant;
      case 'books':
        return Icons.menu_book;
      case 'beauty':
        return Icons.face;
      default:
        return Icons.inventory;
    }
  }
}






