import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/customer.dart';
import '../../providers/currency_provider.dart';
import '../../utils/pos_helpers.dart';

/// Customer credit info widget
/// Extracted from pos_screen.dart for better code organization
class CustomerInfoWidget extends ConsumerStatefulWidget {
  final CustomerModel? customer;
  final bool isCompact;
  final VoidCallback? onExpandToggle;

  const CustomerInfoWidget({
    super.key,
    required this.customer,
    this.isCompact = false,
    this.onExpandToggle,
  });

  @override
  ConsumerState<CustomerInfoWidget> createState() => _CustomerInfoWidgetState();
}

class _CustomerInfoWidgetState extends ConsumerState<CustomerInfoWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    if (customer == null) {
      return const SizedBox.shrink();
    }

    final currency = ref.watch(currentCurrencyProvider);
    final creditLimit = customer.creditLimit;
    final outstanding = customer.totalDue > 0 ? customer.totalDue : 0.0;
    final advance = customer.totalDue < 0 ? -customer.totalDue : 0.0;
    final hasLimit = creditLimit > 0;
    final hasBalance = outstanding > 0 || advance > 0;

    if (!hasLimit && !hasBalance) {
      return const SizedBox.shrink();
    }

    final isCollapsed = widget.isCompact || !_isExpanded;

    if (isCollapsed) {
      return Container(
        width: double.infinity,
        margin: EdgeInsets.only(top: widget.isCompact ? 4 : 6),
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: widget.isCompact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: outstanding > 0
              ? const Color(0xFFFEF2F2)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: outstanding > 0
                ? const Color(0xFFFECACA)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: widget.isCompact
              ? null
              : () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                  widget.onExpandToggle?.call();
                },
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: widget.isCompact ? 14 : 16,
                      color: const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        customer.name,
                        style: TextStyle(
                          fontSize: widget.isCompact ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasLimit) ...[
                Container(
                  width: 1,
                  height: 20,
                  color: const Color(0xFFE2E8F0),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.credit_card,
                          size: widget.isCompact ? 12 : 14,
                          color: const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Credit: ${formatCurrency(creditLimit, currency)}',
                            style: TextStyle(
                              fontSize: widget.isCompact ? 10 : 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2563EB),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (outstanding > 0) ...[
                Container(
                  width: 1,
                  height: 20,
                  color: const Color(0xFFE2E8F0),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: widget.isCompact ? 12 : 14,
                          color: const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Outstanding: ${formatCurrency(outstanding, currency)}',
                            style: TextStyle(
                              fontSize: widget.isCompact ? 10 : 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDC2626),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (!widget.isCompact) ...[
                const SizedBox(width: 8),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: const Color(0xFF6B7280),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Expanded state
    double available = 0.0;
    if (hasLimit) {
      available = creditLimit - outstanding;
      if (available < 0) available = 0;
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: widget.isCompact ? 4 : 6),
      padding: EdgeInsets.all(widget.isCompact ? 8 : 12),
      decoration: BoxDecoration(
        color: outstanding > 0
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: outstanding > 0
              ? const Color(0xFFFECACA)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                customer.name,
                style: TextStyle(
                  fontSize: widget.isCompact ? 12 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              if (!widget.isCompact)
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                    widget.onExpandToggle?.call();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (hasLimit) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              'Credit Limit',
              formatCurrency(creditLimit, currency),
              const Color(0xFF2563EB),
            ),
            _buildInfoRow(
              'Available',
              formatCurrency(available, currency),
              const Color(0xFF10B981),
            ),
          ],
          if (outstanding > 0) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              'Outstanding',
              formatCurrency(outstanding, currency),
              const Color(0xFFDC2626),
            ),
          ],
          if (advance > 0) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              'Advance',
              formatCurrency(advance, currency),
              const Color(0xFF10B981),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: widget.isCompact ? 10 : 12,
              color: color.withOpacity(0.75),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: widget.isCompact ? 11 : 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}






