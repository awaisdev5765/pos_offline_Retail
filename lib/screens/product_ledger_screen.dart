import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/currency.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/purchase_order.dart';
import '../models/supplier.dart';
import '../providers/product_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/stock_movement_provider.dart';
import '../providers/purchase_order_provider.dart';
import '../services/database_service.dart';
import '../widgets/app_snack_bar.dart';

class ProductLedgerScreen extends ConsumerStatefulWidget {
  final int productId;

  const ProductLedgerScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductLedgerScreen> createState() =>
      _ProductLedgerScreenState();
}

class _ProductLedgerScreenState extends ConsumerState<ProductLedgerScreen> {
  ProductLedgerEntry? _selectedEntry;

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productByIdProvider(widget.productId));
    final ledgerAsync = ref.watch(productLedgerProvider(widget.productId));
    final currency = ref.watch(currentCurrencyProvider);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    // Watch sales provider to detect new sales
    ref.watch(salesProvider);
    
    // Watch stock movements provider to detect stock adjustments
    ref.watch(stockMovementsProvider);
    
    // Watch product notifier to detect product updates
    ref.watch(productNotifierProvider);
    
    // Watch purchase orders to detect new purchases
    ref.watch(purchaseOrderNotifierProvider);

    // Refresh ledger when product stock changes (from stock movements)
    ref.listen(productByIdProvider(widget.productId), (previous, next) {
      if (previous?.value?.stock != next.value?.stock) {
        // Stock changed, refresh ledger
        ref.invalidate(productLedgerProvider(widget.productId));
      }
    });

    // Refresh ledger when sales change (any sale might affect this product)
    ref.listen(salesProvider, (previous, next) {
      if (previous != next) {
        // Invalidate ledger to refresh - the provider will filter by product ID
        ref.invalidate(productLedgerProvider(widget.productId));
      }
    });

    // Refresh ledger when stock movements change (any movement might affect this product)
    ref.listen(stockMovementsProvider, (previous, next) {
      if (previous != next) {
        // Invalidate ledger to refresh - the provider will filter by product ID
        ref.invalidate(productLedgerProvider(widget.productId));
      }
    });

    // Refresh ledger when products list changes (purchases might update products)
    ref.listen(productNotifierProvider, (previous, next) {
      if (previous != next) {
        // Invalidate ledger to refresh when products are updated
        ref.invalidate(productLedgerProvider(widget.productId));
      }
    });

    // Refresh ledger when purchase orders change (any purchase might affect this product)
    ref.listen(purchaseOrderNotifierProvider, (previous, next) {
      if (previous != next) {
        // Invalidate ledger to refresh - the provider will filter by product ID
        ref.invalidate(productLedgerProvider(widget.productId));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: productAsync.maybeWhen(
          data: (product) => Text(product?.name != null
              ? 'ledger.product_with_name'
                  .tr(namedArgs: {'name': product!.name})
              : 'ledger.product'.tr()),
          orElse: () => Text('ledger.product'.tr()),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'ledger.refresh_ledger_tooltip'.tr(),
            onPressed: () {
              ref.invalidate(productByIdProvider(widget.productId));
              ref.invalidate(productLedgerProvider(widget.productId));
            },
          ),
        ],
      ),
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return Center(child: Text('ledger.product_not_found'.tr()));
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductSummary(product, currency.symbol),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ledgerAsync.when(
                        data: (entries) {
                          // Include all entries including stock adjustments
                          final visibleEntries = entries;

                          if (visibleEntries.isEmpty) {
                            return const Center(
                              child: Text(
                                'No ledger entries for this product yet.',
                                style: TextStyle(color: Color(0xFF94A3B8)),
                              ),
                            );
                          }

                          final sorted = [...visibleEntries]
                            ..sort((a, b) => b.date.compareTo(a.date));
                          ProductLedgerEntry detailEntry = _selectedEntry ?? sorted.first;
                          if (!sorted
                              .any((entry) => entry.entryId == detailEntry.entryId)) {
                            detailEntry = sorted.first;
                          }
                          final selectedId = detailEntry.entryId;

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final isCompact = constraints.maxWidth < 850;
                              final list = _buildLedgerList(sorted, selectedId,
                                  dateFormat, currency.symbol, currency);
                              final detail = _buildLedgerDetails(detailEntry,
                                  dateFormat, currency.symbol, currency);

                              if (isCompact) {
                                return Column(
                                  children: [
                                    list,
                                    const SizedBox(height: 16),
                                    detail,
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: list),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 2, child: detail),
                                ],
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load ledger: $error',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading product: $error'),
        ),
      ),
    );
  }

  Widget _buildProductSummary(ProductModel product, String currencySymbol) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _buildSummaryChip(
              'Category', product.category, Icons.category_outlined),
          _buildSummaryChip(
              'Current Stock',
              '${product.stock.toStringAsFixed(2)} ${product.unit}',
              Icons.inventory_2_outlined),
          _buildSummaryChip(
              'Retail Price',
              '$currencySymbol${product.price.toStringAsFixed(2)}',
              Icons.price_check_outlined),
          _buildSummaryChip(
              'Cost Price',
              '$currencySymbol${product.cost.toStringAsFixed(2)}',
              Icons.receipt_outlined),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF6366F1)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerList(
    List<ProductLedgerEntry> entries,
    int selectedEntryId,
    DateFormat dateFormat,
    String currencySymbol,
    Currency currency,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final isSelected = entry.entryId == selectedEntryId;

          return Material(
            color: isSelected ? const Color(0xFFFFF9C4) : Colors.white,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedEntry = entry;
                });
                // Show details based on entry type
                if (entry.isSale) {
                  _showSaleDetails(context, entry.referenceId, currency);
                } else if (entry.isPurchase) {
                  _showPurchaseOrderDetails(
                      context, entry.referenceId, currency);
                }
                // Stock adjustments don't have a detail dialog - info is in the right panel
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: entry.isSale
                                ? const Color(0xFFFEE2E2)
                                : entry.isStockAdjustment
                                    ? (entry.quantity > 0
                                        ? const Color(0xFFD1FAE5) // Green background for stock in
                                        : const Color(0xFFFEE2E2)) // Red background for stock out
                                    : const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            entry.typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: entry.isSale
                                  ? const Color(0xFFB91C1C)
                                  : entry.isStockAdjustment
                                      ? (entry.quantity > 0
                                          ? const Color(0xFF0F766E) // Green for stock in
                                          : const Color(0xFFB91C1C)) // Red for stock out
                                      : const Color(0xFF0F766E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.isStockAdjustment && 
                          entry.invoiceNumber.contains('Stock Manager')
                              ? 'Stock Manager Set to Zero'
                              : entry.invoiceNumber,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(entry.date),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                        // Show stock manager info if available
                        if (entry.isStockAdjustment && 
                            entry.invoiceNumber.contains('Stock Manager')) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.invoiceNumber.replaceAll('Stock Manager: ', ''),
                            style: TextStyle(
                              fontSize: 11, 
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          entry.isSale
                              ? '-${entry.quantity.toStringAsFixed(2)}'
                              : entry.isStockAdjustment
                                  ? (entry.quantity > 0
                                      ? '+${entry.quantity.toStringAsFixed(2)}'
                                      : entry.quantity.toStringAsFixed(2))
                                  : entry.quantity.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: entry.isSale
                                ? const Color(0xFFDC2626)
                                : entry.isStockAdjustment
                                    ? (entry.quantity > 0
                                        ? const Color(0xFF059669) // Green for stock in
                                        : const Color(0xFFDC2626)) // Red for stock out
                                    : const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$currencySymbol${entry.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLedgerDetails(
    ProductLedgerEntry entry,
    DateFormat dateFormat,
    String currencySymbol,
    Currency currency,
  ) {
    Widget buildDetail(String label, String value, {Color? color}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ],
      );
    }

    return FutureBuilder(
      future: entry.isSale
          ? _getSaleDetails(entry.referenceId)
          : entry.isPurchase
              ? _getPurchaseOrderDetails(entry.referenceId)
              : Future.value(null), // Stock adjustments don't need async data
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              color: Colors.white,
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            color: Colors.white,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      entry.isSale
                          ? Icons.sell_outlined
                          : entry.isStockAdjustment
                              ? (entry.quantity > 0
                                  ? Icons.add_circle_outline // Stock in icon
                                  : Icons.remove_circle_outline) // Stock out icon
                              : Icons.local_shipping_outlined,
                      color: entry.isSale
                          ? const Color(0xFFDC2626)
                          : entry.isStockAdjustment
                              ? (entry.quantity > 0
                                  ? const Color(0xFF059669) // Green for stock in
                                  : const Color(0xFFDC2626)) // Red for stock out
                              : const Color(0xFF059669),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.isStockAdjustment
                            ? entry.typeLabel // Just "Stock In" or "Stock Out"
                            : '${entry.typeLabel} Invoice',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (entry.isSale && snapshot.hasData) ...[
                  // Sale Details
                  _buildSaleDetailsPanel(snapshot.data as SaleModel, currency),
                ] else if (entry.isPurchase && snapshot.hasData) ...[
                  // Purchase Order Details
                  _buildPurchaseOrderDetailsPanel(
                      snapshot.data as PurchaseOrderModel, currency),
                ] else if (entry.isStockAdjustment) ...[
                  // Stock Adjustment Details
                  _buildStockAdjustmentDetailsPanel(entry, currency),
                ] else ...[
                  // Fallback to basic info if details not available
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      buildDetail('Invoice No.', entry.invoiceNumber),
                      buildDetail('Date', dateFormat.format(entry.date)),
                      buildDetail(
                        'Quantity',
                        entry.isSale
                            ? '-${entry.quantity.toStringAsFixed(2)}'
                            : entry.isStockAdjustment
                                ? (entry.quantity > 0
                                    ? '+${entry.quantity.toStringAsFixed(2)}'
                                    : entry.quantity.toStringAsFixed(2))
                                : entry.quantity.toStringAsFixed(2),
                        color: entry.isSale
                            ? const Color(0xFFDC2626)
                            : entry.isStockAdjustment
                                ? (entry.quantity > 0
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626))
                                : const Color(0xFF059669),
                      ),
                      buildDetail('Rate',
                          '$currencySymbol${entry.rate.toStringAsFixed(2)}'),
                      buildDetail('Total',
                          '$currencySymbol${entry.total.toStringAsFixed(2)}'),
                    ],
                  ),
                  if (entry.counterpartyName != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    buildDetail(entry.isSale ? 'Customer' : 'Supplier',
                        entry.counterpartyName!),
                  ],
                  if (entry.notes != null &&
                      entry.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    buildDetail('Notes', entry.notes!),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<dynamic> _getSaleDetails(int saleId) async {
    final databaseService = ref.read(databaseServiceProvider);
    return await databaseService.getSaleById(saleId);
  }

  Future<dynamic> _getPurchaseOrderDetails(int orderId) async {
    final databaseService = ref.read(databaseServiceProvider);
    final orderRaw = await databaseService.getPurchaseOrderById(orderId);
    if (orderRaw == null) return null;

    final supplier = await databaseService.getSupplierById(orderRaw.supplierId);
    final itemsRaw = await databaseService.getPurchaseOrderItems(orderId);

    final List<PurchaseOrderItemModel> items = [];
    for (final item in itemsRaw) {
      final product = await databaseService.getProductById(item.productId);
      items.add(
          PurchaseOrderItemModel.fromPurchaseOrderItem(item, product: product));
    }

    final supplierModel =
        supplier != null ? SupplierModel.fromSupplier(supplier) : null;
    return PurchaseOrderModel.fromPurchaseOrder(orderRaw,
        supplier: supplierModel, items: items);
  }

  Widget _buildSaleDetailsPanel(SaleModel sale, Currency currency) {
    Widget buildDetail(String label, String value, {Color? color}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ],
      );
    }

    final subtotal = sale.items.fold<double>(
        0.0, (sum, item) => sum + ((item.price * item.qty) - item.discount));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            buildDetail(
                'Invoice No.', 'SALE-${sale.id.toString().padLeft(5, '0')}'),
            buildDetail(
                'Date', DateFormat('dd/MM/yyyy hh:mm a').format(sale.date)),
            buildDetail('Customer', sale.customer?.name ?? 'Walk-in'),
            buildDetail('Cashier', sale.cashier?.name ?? 'Unknown'),
            buildDetail('Payment Type',
                sale.paymentType.toString().split('.').last.toUpperCase()),
            buildDetail(
                'Status', sale.status.toString().split('.').last.toUpperCase()),
            buildDetail('Type', sale.isWholesale ? 'Wholesale' : 'Retail'),
          ],
        ),
        if (sale.paymentType == PaymentType.credit) ...[
          const SizedBox(height: 16),
          const Divider(),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              buildDetail('Total',
                  '${currency.symbol}${sale.total.toStringAsFixed(2)}'),
              buildDetail(
                  'Paid', '${currency.symbol}${sale.paid.toStringAsFixed(2)}',
                  color: const Color(0xFF059669)),
              buildDetail(
                  'Due', '${currency.symbol}${sale.due.toStringAsFixed(2)}',
                  color: const Color(0xFFDC2626)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const Divider(),
        const Text(
          'Items:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...sale.items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${item.product?.name ?? 'Unknown Product'}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: (item.product?.isActive == false)
                                ? Colors.grey
                                : null,
                          ),
                        ),
                      ),
                      if (item.product?.isActive == false) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.red,
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'Deleted Item',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Qty: ${item.qty.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      Text(
                          'Price: ${currency.symbol}${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      if (item.discount > 0)
                        Text(
                            'Discount: ${currency.symbol}${item.discount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total: ${currency.symbol}${((item.price * item.qty) - item.discount).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 16),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('reports.subtotal'.tr(),
                style: TextStyle(fontWeight: FontWeight.w600)),
            Text('${currency.symbol}${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        if (sale.discount > 0) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('reports.discount'.tr(),
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text('${currency.symbol}${sale.discount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.red)),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('reports.total'.tr(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('${currency.symbol}${sale.total.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        if (sale.profit != null) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('reports.profit'.tr(),
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF059669))),
              Text('${currency.symbol}${sale.profit!.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF059669))),
            ],
          ),
        ],
        if (sale.notes != null && sale.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          buildDetail('Notes', sale.notes!),
        ],
      ],
    );
  }

  Widget _buildStockAdjustmentDetailsPanel(
      ProductLedgerEntry entry, Currency currency) {
    Widget buildDetail(String label, String value, {Color? color}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ],
      );
    }

    final isIncrease = entry.quantity > 0;
    final stockType = isIncrease ? 'Stock In' : 'Stock Out';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stock Type Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isIncrease
                ? const Color(0xFFD1FAE5)
                : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isIncrease
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isIncrease ? Icons.add_circle : Icons.remove_circle,
                size: 16,
                color: isIncrease
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 6),
              Text(
                stockType,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isIncrease
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            buildDetail('Adjustment No.', entry.invoiceNumber),
            buildDetail(
                'Date', DateFormat('dd/MM/yyyy hh:mm a').format(entry.date)),
            buildDetail(
              'Quantity',
              isIncrease
                  ? '+${entry.quantity.toStringAsFixed(2)}'
                  : entry.quantity.toStringAsFixed(2),
              color: isIncrease
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626),
            ),
            buildDetail('Unit Cost',
                '${currency.symbol}${entry.rate.toStringAsFixed(2)}'),
            buildDetail('Total Value',
                '${currency.symbol}${entry.total.toStringAsFixed(2)}'),
          ],
        ),
        if (entry.notes != null && entry.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          buildDetail('Reason', entry.notes!),
        ],
        // Show reference if it contains stock manager information
        if (entry.invoiceNumber.contains('Stock Manager') || 
            entry.invoiceNumber.contains('set stock to zero')) ...[
          const SizedBox(height: 16),
          const Divider(),
          buildDetail('Reference', entry.invoiceNumber),
        ],
      ],
    );
  }

  Widget _buildPurchaseOrderDetailsPanel(
      PurchaseOrderModel order, Currency currency) {
    Widget buildDetail(String label, String value, {Color? color}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ],
      );
    }

    final subtotal =
        order.items.fold<double>(0.0, (sum, item) => sum + item.subtotal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            buildDetail('Order Number', order.orderNumber),
            buildDetail(
                'Date', DateFormat('dd/MM/yyyy hh:mm a').format(order.orderDate)),
            buildDetail('Supplier', order.supplier?.name ?? 'Unknown'),
            buildDetail('Status',
                order.status.toString().split('.').last.toUpperCase()),
            if (order.expectedDate != null)
              buildDetail('Expected Date',
                  DateFormat('dd/MM/yyyy').format(order.expectedDate!)),
            if (order.receivedDate != null)
              buildDetail('Received Date',
                  DateFormat('dd/MM/yyyy').format(order.receivedDate!)),
          ],
        ),
        if (order.supplier != null) ...[
          const SizedBox(height: 16),
          const Divider(),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              if (order.supplier!.phone.isNotEmpty)
                buildDetail('Supplier Phone', order.supplier!.phone),
              if (order.supplier!.email != null &&
                  order.supplier!.email!.isNotEmpty)
                buildDetail('Supplier Email', order.supplier!.email!),
              if (order.supplier!.address != null &&
                  order.supplier!.address!.isNotEmpty)
                buildDetail('Supplier Address', order.supplier!.address!),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const Divider(),
        const Text(
          'Items:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...order.items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${item.product?.name ?? 'Unknown Product'}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: (item.product?.isActive == false)
                                                ? Colors.grey
                                                : null,
                                          ),
                                        ),
                                      ),
                                      if (item.product?.isActive == false) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: Colors.red,
                                              width: 1,
                                            ),
                                          ),
                                          child: const Text(
                                            'Deleted Item',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Qty: ${item.quantity.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      Text(
                          'Unit Cost: ${currency.symbol}${item.unitCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total: ${currency.symbol}${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 16),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('reports.subtotal'.tr(),
                style: TextStyle(fontWeight: FontWeight.w600)),
            Text('${currency.symbol}${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        if (order.tax > 0) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('reports.tax'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${currency.symbol}${order.tax.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
        if (order.discount > 0) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('reports.discount'.tr(),
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text('${currency.symbol}${order.discount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.green)),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('reports.total'.tr(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('${currency.symbol}${order.total.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          buildDetail('Notes', order.notes!),
        ],
      ],
    );
  }

  Future<void> _showSaleDetails(
      BuildContext context, int saleId, Currency currency) async {
    final databaseService = ref.read(databaseServiceProvider);
    final sale = await databaseService.getSaleById(saleId);

    if (sale == null) {
      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Sale not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Calculate subtotal from items
    final subtotal = sale.items.fold<double>(
      0.0,
      (sum, item) => sum + ((item.price * item.qty) - item.discount),
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long,
                      color: Color(0xFF3B82F6), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sale #${sale.id} Details',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                          'Customer', sale.customer?.name ?? 'Walk-in'),
                      _buildDetailRow(
                          'Cashier', sale.cashier?.name ?? 'Unknown'),
                      _buildDetailRow('Date',
                          DateFormat('dd/MM/yyyy hh:mm a').format(sale.date)),
                      _buildDetailRow('Status',
                          sale.status.toString().split('.').last.toUpperCase()),
                      _buildDetailRow(
                          'Payment Type',
                          sale.paymentType
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase()),
                      _buildDetailRow(
                          'Type', sale.isWholesale ? 'Wholesale' : 'Retail'),
                      if (sale.profit != null) ...[
                        _buildDetailRow('Profit',
                            '${currency.symbol}${sale.profit!.toStringAsFixed(2)}'),
                        if (sale.profitMargin != null)
                          _buildDetailRow('Profit Margin',
                              '${sale.profitMargin!.toStringAsFixed(1)}%'),
                      ],
                      if (sale.paymentType == PaymentType.credit) ...[
                        _buildDetailRow('Total',
                            '${currency.symbol}${sale.total.toStringAsFixed(2)}'),
                        _buildDetailRow('Paid',
                            '${currency.symbol}${sale.paid.toStringAsFixed(2)}'),
                        _buildDetailRow('Due',
                            '${currency.symbol}${sale.due.toStringAsFixed(2)}'),
                      ],
                      const Divider(),
                      const Text(
                        'Items:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ...sale.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${item.product?.name ?? 'Unknown Product'}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: (item.product?.isActive == false)
                                                ? Colors.grey
                                                : null,
                                          ),
                                        ),
                                      ),
                                      if (item.product?.isActive == false) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: Colors.red,
                                              width: 1,
                                            ),
                                          ),
                                          child: const Text(
                                            'Deleted Item',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Qty: ${item.qty.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        'Price: ${currency.symbol}${item.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                      if (item.discount > 0)
                                        Text(
                                          'Discount: ${currency.symbol}${item.discount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.red),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Total: ${currency.symbol}${((item.price * item.qty) - item.discount).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${currency.symbol}${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (sale.discount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Discount:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${currency.symbol}${sale.discount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${currency.symbol}${sale.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('common.close'.tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPurchaseOrderDetails(
      BuildContext context, int orderId, Currency currency) async {
    final databaseService = ref.read(databaseServiceProvider);
    final orderRaw = await databaseService.getPurchaseOrderById(orderId);

    if (orderRaw == null) {
      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Purchase order not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Get supplier and items separately
    final supplier = await databaseService.getSupplierById(orderRaw.supplierId);
    final itemsRaw = await databaseService.getPurchaseOrderItems(orderId);

    // Convert items to models with products
    final List<PurchaseOrderItemModel> items = [];
    for (final item in itemsRaw) {
      final product = await databaseService.getProductById(item.productId);
      items.add(PurchaseOrderItemModel.fromPurchaseOrderItem(
        item,
        product: product,
      ));
    }

    // Convert supplier to model
    final supplierModel =
        supplier != null ? SupplierModel.fromSupplier(supplier) : null;

    // Convert to PurchaseOrderModel
    final order = PurchaseOrderModel.fromPurchaseOrder(
      orderRaw,
      supplier: supplierModel,
      items: items,
    );

    // Calculate subtotal from items
    final subtotal = order.items.fold<double>(
      0.0,
      (sum, item) => sum + item.subtotal,
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping,
                      color: Color(0xFF059669), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Purchase Order ${order.orderNumber}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                          'Supplier', order.supplier?.name ?? 'Unknown'),
                      _buildDetailRow('Order Number', order.orderNumber),
                      _buildDetailRow(
                          'Order Date',
                          DateFormat('dd/MM/yyyy hh:mm a')
                              .format(order.orderDate)),
                      if (order.expectedDate != null)
                        _buildDetailRow(
                            'Expected Date',
                            DateFormat('dd/MM/yyyy')
                                .format(order.expectedDate!)),
                      if (order.receivedDate != null)
                        _buildDetailRow(
                            'Received Date',
                            DateFormat('dd/MM/yyyy')
                                .format(order.receivedDate!)),
                      _buildDetailRow(
                          'Status',
                          order.status
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase()),
                      if (order.supplier?.phone != null &&
                          order.supplier!.phone.isNotEmpty)
                        _buildDetailRow(
                            'Supplier Phone', order.supplier!.phone),
                      if (order.supplier?.email != null &&
                          order.supplier!.email!.isNotEmpty)
                        _buildDetailRow(
                            'Supplier Email', order.supplier!.email!),
                      if (order.supplier?.address != null &&
                          order.supplier!.address!.isNotEmpty)
                        _buildDetailRow(
                            'Supplier Address', order.supplier!.address!),
                      const Divider(),
                      const Text(
                        'Items:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${item.product?.name ?? 'Unknown Product'}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: (item.product?.isActive == false)
                                                ? Colors.grey
                                                : null,
                                          ),
                                        ),
                                      ),
                                      if (item.product?.isActive == false) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: Colors.red,
                                              width: 1,
                                            ),
                                          ),
                                          child: const Text(
                                            'Deleted Item',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Qty: ${item.quantity.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        'Unit Cost: ${currency.symbol}${item.unitCost.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Total: ${currency.symbol}${item.subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${currency.symbol}${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (order.tax > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tax:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${currency.symbol}${order.tax.toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                      if (order.discount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Discount:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${currency.symbol}${order.discount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${currency.symbol}${order.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (order.notes != null &&
                          order.notes!.trim().isNotEmpty) ...[
                        const Divider(),
                        _buildDetailRow('Notes', order.notes!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('common.close'.tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
