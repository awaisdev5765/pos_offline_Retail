import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/currency.dart';
import '../providers/product_provider.dart';
import '../providers/currency_provider.dart';
import '../services/database_service.dart';
import '../models/product.dart';
import '../models/sales_summary.dart' as models;
import '../models/sale.dart';
import '../database/database.dart';
import '../widgets/app_snack_bar.dart';
import '../utils/quantity_formatter.dart';

// Provider for item-wise sales report with keepAlive for fast response
final itemWiseSalesReportProvider = FutureProvider.autoDispose
    .family<List<models.ItemWiseSalesData>, ItemWiseSalesReportParams>(
  (ref, params) async {
    final databaseService = ref.read(databaseServiceProvider);
    final report = await databaseService.getItemWiseSalesReport(
      params.productId,
      params.startDate,
      params.endDate,
    );

    // Keep alive to cache results and reduce rebuilds
    ref.keepAlive();

    return report;
  },
);

class ItemWiseSalesReportParams {
  final int productId;
  final DateTime startDate;
  final DateTime endDate;

  ItemWiseSalesReportParams({
    required this.productId,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemWiseSalesReportParams &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode =>
      productId.hashCode ^ startDate.hashCode ^ endDate.hashCode;
}

class ItemWiseSalesReportScreen extends ConsumerStatefulWidget {
  const ItemWiseSalesReportScreen({super.key});

  @override
  ConsumerState<ItemWiseSalesReportScreen> createState() =>
      _ItemWiseSalesReportScreenState();
}

class _ItemWiseSalesReportScreenState
    extends ConsumerState<ItemWiseSalesReportScreen> {
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  ProductModel? _selectedProduct;
  bool _isLoading = false;
  double _tableScale = 1.0;
  final ScrollController _horizontalTableController = ScrollController();
  final TextEditingController _productSearchController =
      TextEditingController();

  static const double _minTableScale = 0.85;
  static const double _maxTableScale = 1.6;

  @override
  void dispose() {
    _horizontalTableController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currentCurrencyProvider);
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'misc.item_wise_sales'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Header Section with Filters
          _buildHeaderSection(currency, productsAsync),

          // Report Table
          Expanded(
            child: _selectedProduct == null
                ? _buildEmptyState(
                    'Please select an item and date range to view the report')
                : _buildReportTable(currency),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(
      Currency currency, AsyncValue<List<ProductModel>> productsAsync) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Title
          const Row(
            children: [
              Icon(Icons.assessment, color: Color(0xFF3B82F6), size: 24),
              SizedBox(width: 8),
              Text(
                'Item-wise Sales Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters Row
          Row(
            children: [
              // From Date
              Expanded(
                child: _buildDatePicker(
                  label: 'From Date',
                  date: _fromDate,
                  onDateSelected: (date) {
                    setState(() {
                      _fromDate = date;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),

              // To Date
              Expanded(
                child: _buildDatePicker(
                  label: 'To Date',
                  date: _toDate,
                  minDate: _fromDate,
                  onDateSelected: (date) {
                    setState(() {
                      _toDate = date;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Item Dropdown
              Expanded(
                flex: 2,
                child: _buildItemDropdown(productsAsync),
              ),
              const SizedBox(width: 12),

              // Show Report Button
              ElevatedButton.icon(
                onPressed: _selectedProduct == null ? null : _loadReport,
                icon: const Icon(Icons.search, size: 18),
                label: Text('misc.item_wise_show_report'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    DateTime? minDate,
    required Function(DateTime) onDateSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: minDate ?? DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              helpText: label,
            );
            if (picked != null) {
              onDateSelected(picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd-MMM-yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemDropdown(AsyncValue<List<ProductModel>> productsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        productsAsync.when(
          data: (products) {
            // Initialize controller text if product is selected
            if (_selectedProduct != null &&
                _productSearchController.text.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _productSearchController.text = _selectedProduct!.name;
                }
              });
            }

            return StatefulBuilder(
              builder: (context, setLocalState) {
                return Autocomplete<ProductModel>(
                  displayStringForOption: (product) => product.name,
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.toLowerCase();
                    if (query.isEmpty) {
                      return products;
                    }
                    return products.where((product) {
                      final name = product.name.toLowerCase();
                      final barcode = (product.barcode ?? '').toLowerCase();
                      final code = _formatItemCode(product).toLowerCase();
                      return name.contains(query) ||
                          barcode.contains(query) ||
                          code.contains(query);
                    }).toList();
                  },
                  fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController textEditingController,
                    FocusNode focusNode,
                    VoidCallback onFieldSubmitted,
                  ) {
                    // Sync controller with our state controller
                    if (textEditingController.text !=
                        _productSearchController.text) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          textEditingController.text =
                              _productSearchController.text;
                        }
                      });
                    }

                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Item',
                        hintText: 'Search or select item...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: textEditingController.text.isNotEmpty &&
                                _selectedProduct != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  textEditingController.clear();
                                  _productSearchController.clear();
                                  setState(() {
                                    _selectedProduct = null;
                                  });
                                  setLocalState(() {});
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      onChanged: (value) {
                        _productSearchController.text = value;
                        setLocalState(() {});
                      },
                      onSubmitted: (String value) {
                        onFieldSubmitted();
                      },
                    );
                  },
                  onSelected: (ProductModel selection) {
                    setState(() {
                      _selectedProduct = selection;
                      _productSearchController.text = selection.name;
                    });
                    // Auto-load report when item is selected
                    Future.microtask(() => _loadReport());
                  },
                  optionsViewBuilder: (
                    BuildContext context,
                    AutocompleteOnSelected<ProductModel> onSelected,
                    Iterable<ProductModel> options,
                  ) {
                    if (options.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final product = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(product),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      if (product.barcode != null &&
                                          product.barcode!.isNotEmpty)
                                        Text(
                                          'Barcode: ${product.barcode}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
          loading: () => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Loading items...',
                    style: TextStyle(color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          error: (error, stack) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEF4444)),
            ),
            child: const Text(
              'Error loading items',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }

  String _formatItemCode(ProductModel product) {
    if (product.barcode != null && product.barcode!.isNotEmpty) {
      return product.barcode!;
    }
    if (product.id != null) {
      return 'SKU-${product.id!.toString().padLeft(4, '0')}';
    }
    return 'SKU-NA';
  }

  Widget _buildReportTable(Currency currency) {
    if (_selectedProduct == null) {
      return _buildEmptyState('Please select an item');
    }

    // Set time to start of day for fromDate and end of day for toDate
    final startDate = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final endDate =
        DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59, 999);

    final params = ItemWiseSalesReportParams(
      productId: _selectedProduct!.id!,
      startDate: startDate,
      endDate: endDate,
    );

    final reportAsync = ref.watch(itemWiseSalesReportProvider(params));

    return reportAsync.when(
      data: (reportData) {
        if (reportData.isEmpty) {
          return _buildEmptyState(
              'No sales data found for the selected item and date range');
        }

        // Calculate totals
        final totalSaleQty =
            reportData.fold(0.0, (sum, item) => sum + item.saleQty);
        final totalSaleAmount =
            reportData.fold(0.0, (sum, item) => sum + item.totalAmount);
        final totalNetProfit =
            reportData.fold(0.0, (sum, item) => sum + item.profit);
        final totalStockIncrease =
            reportData.fold(0.0, (sum, item) => sum + item.stockIncreaseQty);
        final totalStockDecrease =
            reportData.fold(0.0, (sum, item) => sum + item.stockDecreaseQty);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Zoom ${(_tableScale * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildZoomButton(
                    icon: Icons.zoom_out,
                    label: 'Zoom Out',
                    onPressed: _tableScale > _minTableScale
                        ? () => _adjustTableScale(-0.1)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _buildZoomButton(
                    icon: Icons.refresh,
                    label: 'Reset',
                    onPressed:
                        _tableScale == 1.0 ? null : () => _setTableScale(1.0),
                  ),
                  const SizedBox(width: 8),
                  _buildZoomButton(
                    icon: Icons.zoom_in,
                    label: 'Zoom In',
                    onPressed: _tableScale < _maxTableScale
                        ? () => _adjustTableScale(0.1)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Scrollable Table
            Expanded(
              child: SingleChildScrollView(
                child: _buildDataTable(reportData, currency),
              ),
            ),

            // Summary Section
            _buildSummarySection(
              totalSaleQty,
              totalSaleAmount,
              totalNetProfit,
              currency,
              totalStockIncrease,
              totalStockDecrease,
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading report: $error',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReport,
              child: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(
      List<models.ItemWiseSalesData> reportData, Currency currency) {
    return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Scrollbar(
          controller: _horizontalTableController,
          thumbVisibility: true,
          trackVisibility: true,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontalTableController,
            scrollDirection: Axis.horizontal,
            child: Transform.scale(
              scale: _tableScale,
              alignment: Alignment.topLeft,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                    const Color(0xFFFFF9C4)), // Light yellow header
                headingRowHeight: 48,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 64,
                columnSpacing: 24,
                horizontalMargin: 16,
                columns: const [
                  DataColumn(
                    label: Text(
                      'Invoice No',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Date',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Item Name',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Type',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Stock In Qty',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Stock Out Qty',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Sale Qty',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Pur Price',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Sale Price',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Total Amount',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Profit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    numeric: true,
                  ),
                ],
                rows: reportData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final isNegativeProfit = data.profit < 0;
                  final isEven = index % 2 == 0;
                  final isStockMovement = data.isStockMovement;

                  return DataRow(
                    color: MaterialStateProperty.all(
                      isEven ? Colors.white : const Color(0xFFF8FAFC),
                    ),
                    cells: [
                      DataCell(
                          Text(
                            '${data.invoiceNo}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () => _openInvoiceDetails(data.invoiceNo)),
                      DataCell(Text(
                        DateFormat('dd-MMM-yyyy').format(data.date),
                        style: const TextStyle(fontSize: 13),
                      )),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.itemName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isStockMovement &&
                                (data.movementReason?.isNotEmpty ?? false))
                              Text(
                                'Reason: ${data.movementReason}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            if (isStockMovement &&
                                (data.reference?.isNotEmpty ?? false))
                              Text(
                                'Ref: ${data.reference}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                          ],
                        ),
                      ),
                      DataCell(Text(
                        isStockMovement ? 'Stock Movement' : 'Sale',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isStockMovement
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isStockMovement
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF475569),
                        ),
                      )),
                      DataCell(
                        Text(
                          data.stockIncreaseQty > 0
                              ? data.stockIncreaseQty.toStringAsFixed(2)
                              : '-',
                          style: TextStyle(
                            fontSize: 13,
                            color: data.stockIncreaseQty > 0
                                ? Colors.green
                                : const Color(0xFF94A3B8),
                            fontWeight: data.stockIncreaseQty > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      DataCell(
                        Text(
                          data.stockDecreaseQty > 0
                              ? data.stockDecreaseQty.toStringAsFixed(2)
                              : '-',
                          style: TextStyle(
                            fontSize: 13,
                            color: data.stockDecreaseQty > 0
                                ? Colors.red
                                : const Color(0xFF94A3B8),
                            fontWeight: data.stockDecreaseQty > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      DataCell(Text(
                        data.saleQty >= 0
                            ? data.saleQty.toStringAsFixed(2)
                            : data.saleQty.toStringAsFixed(
                                2), // Negative values for stock adjustments
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              data.saleQty < 0 ? const Color(0xFFDC2626) : null,
                        ),
                        textAlign: TextAlign.right,
                      )),
                      DataCell(Text(
                        '${currency.symbol}${data.purchasePrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.right,
                      )),
                      DataCell(Text(
                        '${currency.symbol}${data.salePrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.right,
                      )),
                      DataCell(Text(
                        '${currency.symbol}${data.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.right,
                      )),
                      DataCell(Text(
                        '${currency.symbol}${data.profit.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isNegativeProfit ? Colors.red : Colors.green,
                        ),
                        textAlign: TextAlign.right,
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ));
  }

  Widget _buildZoomButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: label,
      child: SizedBox(
        height: 36,
        width: 36,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: BorderSide(
              color: onPressed == null
                  ? const Color(0xFFCBD5F5)
                  : const Color(0xFF3B82F6),
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onPressed == null
                ? const Color(0xFF94A3B8)
                : const Color(0xFF1E40AF),
          ),
        ),
      ),
    );
  }

  void _adjustTableScale(double delta) {
    setState(() {
      _tableScale = (_tableScale + delta).clamp(_minTableScale, _maxTableScale);
    });
  }

  void _setTableScale(double value) {
    setState(() {
      _tableScale = value.clamp(_minTableScale, _maxTableScale);
    });
  }

  Future<void> _openInvoiceDetails(int invoiceNo) async {
    final databaseService = ref.read(databaseServiceProvider);

    // Try to get as sale first
    final sale = await databaseService.getSaleById(invoiceNo);

    if (sale != null) {
      if (!mounted) return;
      _showSaleDetails(context, sale);
      return;
    }

    // If not a sale, check if it's a stock adjustment
    try {
      final stockAdjustments = await databaseService.getAllStockMovements();
      final adjustment = stockAdjustments.firstWhere(
        (adj) => adj.id == invoiceNo,
      );

      if (mounted) {
        _showStockAdjustmentDetails(context, adjustment);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Invoice not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStockAdjustmentDetails(
      BuildContext context, StockAdjustment adjustment) {
    final currency = ref.read(currentCurrencyProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stock Adjustment #${adjustment.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
                'Date',
                DateFormat('dd/MM/yyyy hh:mm a')
                    .format(DateTime.parse(adjustment.date))),
            _buildDetailRow(
              'Quantity',
              adjustment.quantity > 0
                  ? '+${adjustment.quantity.toStringAsFixed(2)}'
                  : adjustment.quantity.toStringAsFixed(2),
            ),
            _buildDetailRow('Reason', adjustment.reason),
            if (adjustment.reference != null &&
                adjustment.reference!.isNotEmpty)
              _buildDetailRow('Reference', adjustment.reference!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
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
            width: 100,
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

  void _showSaleDetails(BuildContext context, SaleModel sale) {
    final currency = ref.read(currentCurrencyProvider);

    // Calculate subtotal from items (sum of all item totals after item discounts)
    final subtotal = sale.items.fold<double>(
      0.0,
      (sum, item) => sum + ((item.price * item.qty) - item.discount),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sale #${sale.id} Details'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Customer', sale.customer?.name ?? 'Walk-in'),
                _buildDetailRow('Cashier', sale.cashier?.name ?? 'Unknown'),
                _buildDetailRow(
                    'Date', DateFormat('dd/MM/yyyy hh:mm a').format(sale.date)),
                _buildDetailRow('Status',
                    sale.status.toString().split('.').last.toUpperCase()),
                _buildDetailRow('Payment Type',
                    sale.paymentType.toString().split('.').last.toUpperCase()),
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                            Text(
                              '${item.product?.name ?? 'Unknown Product'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Qty: ${QuantityFormatter.withUnit(item.qty, item.product?.unit)}',
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    double totalSaleQty,
    double totalSaleAmount,
    double totalNetProfit,
    Currency currency,
    double totalStockIncrease,
    double totalStockDecrease,
  ) {
    final isNegativeProfit = totalNetProfit < 0;

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3B82F6), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildSummaryItem(
            'Total Sale Qty',
            totalSaleQty.toStringAsFixed(2),
            currency,
            showCurrency: false,
          ),
          _buildSummaryItem(
            'Stock Increased',
            totalStockIncrease.toStringAsFixed(2),
            currency,
            showCurrency: false,
            customColor: Colors.green,
          ),
          _buildSummaryItem(
            'Stock Decreased',
            totalStockDecrease.toStringAsFixed(2),
            currency,
            showCurrency: false,
            isDecrease: true,
          ),
          _buildSummaryItem(
            'Total Sale Amount',
            totalSaleAmount.toStringAsFixed(2),
            currency,
            showCurrency: true,
          ),
          _buildSummaryItem(
            'Total Net Profit',
            totalNetProfit.toStringAsFixed(2),
            currency,
            showCurrency: true,
            isProfit: true,
            isNegative: isNegativeProfit,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    Currency currency, {
    bool showCurrency = true,
    bool isProfit = false,
    bool isNegative = false,
    bool isDecrease = false,
    Color? customColor,
  }) {
    final baseColor = customColor ??
        (isProfit
            ? (isNegative ? Colors.red : const Color(0xFF3B82F6))
            : (isDecrease ? Colors.red : const Color(0xFF3B82F6)));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isProfit && isNegative
                ? const Color(0xFFFEF2F2)
                : isDecrease
                    ? const Color(0xFFFFE4E6)
                    : baseColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: baseColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            showCurrency
                ? '${currency.symbol}${_formatNumber(value)}'
                : _formatNumber(value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: baseColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assessment_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatNumber(String value) {
    // Format number with commas (e.g., 106450.00 -> 106,450.00)
    final parts = value.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '';

    // Add commas to integer part
    final formattedInteger = integerPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return decimalPart.isNotEmpty
        ? '$formattedInteger.$decimalPart'
        : formattedInteger;
  }

  void _loadReport() {
    if (_selectedProduct == null) {
      AppSnackBar.show(
        context,
        const SnackBar(
          content: Text('Please select an item'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Set time to start of day for fromDate and end of day for toDate
    final startDate = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final endDate =
        DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59, 999);

    // Invalidate the provider to reload data
    final params = ItemWiseSalesReportParams(
      productId: _selectedProduct!.id!,
      startDate: startDate,
      endDate: endDate,
    );
    ref.invalidate(itemWiseSalesReportProvider(params));
  }
}
