import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sale_provider.dart';
import '../../providers/currency_provider.dart';
import '../../models/currency.dart';
import '../../utils/pos_helpers.dart';
import '../../controllers/pos_controller.dart';

/// Cart summary widget showing totals
/// Extracted from pos_screen.dart for better code organization
class CartSummaryWidget extends ConsumerWidget {
  final List<CartItem> cart;
  final double discount;
  final String discountType;
  final bool isWholesaleMode;
  final String paymentType;
  final Map<String, double> itemPrices;
  final Map<String, double> itemDiscounts;
  final bool isCompact;

  const CartSummaryWidget({
    super.key,
    required this.cart,
    required this.discount,
    required this.discountType,
    required this.isWholesaleMode,
    required this.paymentType,
    required this.itemPrices,
    required this.itemDiscounts,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(posControllerProvider);
    final currency = ref.watch(currentCurrencyProvider);
    
    final totals = controller.calculateCartTotals(
      cart: cart,
      isWholesaleMode: isWholesaleMode,
      paymentType: paymentType,
      itemPrices: itemPrices,
      itemDiscounts: itemDiscounts,
      discount: discount,
      discountType: discountType,
    );

    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            'Subtotal',
            totals.subtotal,
            currency,
            isCompact,
          ),
          if (totals.discount > 0) ...[
            SizedBox(height: isCompact ? 4 : 6),
            _buildSummaryRow(
              'Discount',
              -totals.discount,
              currency,
              isCompact,
              isDiscount: true,
            ),
          ],
          SizedBox(height: isCompact ? 4 : 6),
          _buildSummaryRow(
            'Tax',
            totals.tax,
            currency,
            isCompact,
          ),
          const Divider(height: 16),
          _buildSummaryRow(
            'Total',
            totals.total,
            currency,
            isCompact,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount,
    Currency currency,
    bool isCompact, {
    bool isDiscount = false,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 12 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isDiscount
                ? const Color(0xFFF59E0B)
                : isTotal
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF64748B),
          ),
        ),
        Text(
          formatCurrency(amount, currency),
          style: TextStyle(
            fontSize: isCompact ? 13 : 15,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isDiscount
                ? const Color(0xFFF59E0B)
                : isTotal
                    ? const Color(0xFF10B981)
                    : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

