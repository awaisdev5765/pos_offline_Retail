import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../providers/sale_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/product_provider.dart';
import '../services/database_service.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../models/currency.dart';
import '../theme/app_theme.dart';
import '../services/csv_export_service.dart';
import '../services/unified_print_service.dart';
import '../widgets/app_snack_bar.dart';
import '../utils/quantity_formatter.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  int? _printingSaleId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sales = ref.watch(salesProvider);
    final currency = ref.watch(currentCurrencyProvider);

    // Auto-refresh when date range changes
    ref.listen(salesProvider, (previous, next) {
      if (next.hasError) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error loading sales: ${next.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    final isDarkMode = ref.watch(isDarkModeProvider);

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('reports_screen.sales_reports'.tr()),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'excel':
                  _exportToExcel(ref.read(salesProvider).value ?? []);
                  break;
                case 'csv':
                  _exportToCsv(ref.read(salesProvider).value ?? []);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Export to Excel'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.text_snippet, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Export to CSV'),
                  ],
                ),
              ),
            ],
            child: const Icon(Icons.download),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Sales',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          _buildSearchAndFilterBar(),
          // Sales Data
          Expanded(
            child: sales.when(
              data: (salesList) {
                final filteredSales = _filterSales(salesList);
                return filteredSales.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No sales found',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start making sales to see them here',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildSalesCustomTable(context, filteredSales);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading sales',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by customer, sale ID, or amount...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _selectedStatus == 'all'
                  ? const Color(0xFF1E293B)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                isDense: true,
                style: TextStyle(
                  color:
                      _selectedStatus == 'all' ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Sales')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value ?? 'all';
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reorderSale(SaleModel sale) async {
    try {
      // Clear the current cart first
      ref.read(cartProvider.notifier).clear();

      final databaseService = ref.read(databaseServiceProvider);
      int addedCount = 0;
      int failedCount = 0;

      // Add each item from the sale to the cart
      for (final item in sale.items) {
        try {
          // Get the product - first check if product is already loaded in the item
          ProductModel? product;
          if (item.product != null) {
            product = item.product;
          } else {
            // Fetch product by ID
            product = await databaseService.getProductById(item.productId);
          }

          if (product != null && product.id != null) {
            // Add product to cart with the same quantity and price from the sale
            ref
                .read(cartProvider.notifier)
                .addProduct(product, quantity: item.qty);
            addedCount++;
          } else {
            failedCount++;
          }
        } catch (e) {
          failedCount++;
          debugPrint('Error adding product ${item.productId} to cart: $e');
        }
      }

      if (mounted) {
        // Show success message
        String message =
            'Added $addedCount item${addedCount != 1 ? 's' : ''} to cart';
        if (failedCount > 0) {
          message +=
              '. $failedCount item${failedCount != 1 ? 's' : ''} could not be added';
        }

        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(message),
            backgroundColor: failedCount > 0
                ? AppColors.warningColor
                : AppColors.successColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        // Navigate to POS screen
        context.go('/pos');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error reordering sale: ${e.toString()}'),
            backgroundColor: AppColors.errorColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  // ==================== CUSTOM SALES TABLE WIDGET ====================
  Widget _buildSalesCustomTable(BuildContext context, List<SaleModel> sales) {
    final currency = ref.read(currentCurrencyProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildHeaderCell('Sale ID'),
                ),
                Expanded(
                  child: _buildHeaderCell('Customer'),
                ),
                Expanded(
                  child: _buildHeaderCell('Items'),
                ),
                Expanded(
                  child: _buildHeaderCell('Total'),
                ),
                Expanded(
                  child: _buildHeaderCell('Profit'),
                ),
                Expanded(
                  child: _buildHeaderCell('Status'),
                ),
                Expanded(
                  child: _buildHeaderCell('Cashier'),
                ),
                Expanded(
                  child: _buildHeaderCell('Date'),
                ),
                Expanded(
                  child: _buildHeaderCell('Actions'),
                ),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: sales.length,
              itemBuilder: (context, index) {
                final sale = sales[index];
                final isEven = index % 2 == 0;

                return Container(
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : const Color(0xFFF9FAFB),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFE5E7EB),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Sale ID Column
                        Expanded(
                          child: Text(
                            '#${sale.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        // Customer Column
                        Expanded(
                          child: Text(
                            sale.customer?.name ?? 'Walk-in',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Items Column
                        Expanded(
                          child: Text(
                            '${sale.items.length}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        // Total Column
                        Expanded(
                          child: Text(
                            '${currency.symbol}${sale.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        // Profit Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${currency.symbol}${sale.profit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: sale.profit >= 0
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626),
                                  fontSize: 12,
                                ),
                              ),
                              if (!sale.profit.isNaN && sale.total > 0)
                                Text(
                                  '${sale.profitMargin.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: sale.profit >= 0
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFDC2626),
                                    fontSize: 10,
                                  ),
                                )
                              else
                                const Text(
                                  'N/A',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Status Column
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Completed',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        // Cashier Column
                        Expanded(
                          child: Text(
                            sale.cashier?.name ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Date Column
                        Expanded(
                          child: Text(
                            _formatDate(sale.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        // Actions Column
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.visibility,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () =>
                                    _showSaleDetails(context, sale),
                                tooltip: 'View Details',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.repeat,
                                  size: 16,
                                  color: AppColors.primaryColor,
                                ),
                                onPressed: () => _reorderSale(sale),
                                tooltip: 'Reorder',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              IconButton(
                                icon: Icon(
                                  _printingSaleId == sale.id
                                      ? Icons.hourglass_top
                                      : Icons.print,
                                  size: 16,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed: _printingSaleId == sale.id
                                    ? null
                                    : () => _printSaleReceipt(sale),
                                tooltip: 'Print Receipt',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFF374151),
        fontSize: 12,
      ),
    );
  }

  List<SaleModel> _filterSales(List<SaleModel> sales) {
    return sales.where((sale) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final matchesSearch = sale.id.toString().contains(searchLower) ||
            (sale.customer?.name.toLowerCase().contains(searchLower) ??
                false) ||
            sale.total.toString().contains(searchLower);
        if (!matchesSearch) return false;
      }

      // Status filter
      if (_selectedStatus != 'all') {
        if (_selectedStatus == 'paid' && sale.status != SaleStatus.paid)
          return false;
        if (_selectedStatus == 'unpaid' && sale.status != SaleStatus.unpaid)
          return false;
      }

      // Date filter
      if (_startDate != null && sale.createdAt.isBefore(_startDate!))
        return false;
      if (_endDate != null &&
          sale.createdAt.isAfter(_endDate!.add(const Duration(days: 1))))
        return false;

      return true;
    }).toList();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('reports.filter_sales'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('ledger.start_date'.tr()),
              subtitle: Text(_startDate == null
                  ? 'reports.no_start_date'.tr()
                  : _formatDate(_startDate!)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _startDate = date;
                    });
                  }
                },
              ),
            ),
            ListTile(
              title: Text('ledger.end_date'.tr()),
              subtitle: Text(_endDate == null
                  ? 'reports.no_end_date'.tr()
                  : _formatDate(_endDate!)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: _startDate ?? DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                    });
                  }
                },
              ),
            ),
            if (_startDate != null || _endDate != null)
              ListTile(
                title: Text('reports.clear_date_filters'.tr()),
                trailing: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final hour12 =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final amPm = date.hour < 12 ? 'AM' : 'PM';
    return '${date.day}/${date.month}/${date.year} ${hour12}:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  void _showSaleDetails(BuildContext context, SaleModel sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sale #${sale.id} Details'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Customer', sale.customer?.name ?? 'Walk-in'),
              _buildDetailRow('Cashier', sale.cashier?.name ?? 'Unknown'),
              _buildDetailRow('Date', _formatDate(sale.createdAt)),
              _buildDetailRow('Status', sale.status.name.toUpperCase()),
              _buildDetailRow(
                  'Payment Type', sale.paymentType.name.toUpperCase()),
              _buildDetailRow('Profit',
                  '${ref.read(currentCurrencyProvider).symbol}${sale.profit.toStringAsFixed(2)}'),
              _buildDetailRow(
                  'Profit Margin', '${sale.profitMargin.toStringAsFixed(1)}%'),
              if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDetailRow('Remarks', sale.notes!,
                    valueColor: const Color(0xFF64748B)),
              ],
              const Divider(),
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...sale.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                              '${item.product?.name ?? 'Unknown Product'} x${item.qty}'),
                        ),
                        Text(
                            '${ref.read(currentCurrencyProvider).symbol}${((item.price * item.qty) - item.discount).toStringAsFixed(2)}'),
                      ],
                    ),
                  )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('reports.subtotal'.tr(),
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      '${ref.read(currentCurrencyProvider).symbol}${(sale.total + sale.discount).toStringAsFixed(2)}'),
                ],
              ),
              if (sale.discount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('reports.discount'.tr(),
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        '-${ref.read(currentCurrencyProvider).symbol}${sale.discount.toStringAsFixed(2)}'),
                  ],
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('reports.total'.tr(),
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '${ref.read(currentCurrencyProvider).symbol}${sale.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueColor != null ? TextStyle(color: valueColor) : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel(List<SaleModel> sales) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final filteredSales = _filterSales(sales);
      final currency = ref.read(currentCurrencyProvider);

      if (filteredSales.isEmpty) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(content: Text('No data to export')),
          );
        }
        return;
      }

      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['Sales Report'];

      // Headers
      final headers = [
        'Order ID',
        'Date',
        'Customer',
        'Items Count',
        'Total Amount',
        'Profit',
        'Profit Margin (%)',
        'Payment Type',
        'Status',
        'Item Details',
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = excel.TextCellValue(headers[i]);
      }

      // Data
      for (int i = 0; i < filteredSales.length; i++) {
        final sale = filteredSales[i];
        final row = i + 1;

        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = excel.IntCellValue(sale.id ?? 0);
        sheet
                .cell(excel.CellIndex.indexByColumnRow(
                    columnIndex: 1, rowIndex: row))
                .value =
            excel.TextCellValue(
                DateFormat('dd/MM/yyyy hh:mm a').format(sale.date));
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = excel.TextCellValue(sale.customer?.name ?? 'Walk-in');
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = excel.IntCellValue(sale.items.length);
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .value = excel.DoubleCellValue(sale.total);
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = excel.DoubleCellValue(sale.profit);
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = excel.DoubleCellValue(sale.profitMargin);
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
            .value = excel.TextCellValue(sale.paymentType.name.toUpperCase());
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
            .value = excel.TextCellValue(sale.status.name.toUpperCase());

        // Item Details
        final itemDetails = sale.items.map((item) {
          final productName = item.product?.name ?? 'Unknown Product';
          final qty = QuantityFormatter.withUnit(item.qty, item.product?.unit);
          final price = '${currency.symbol}${item.price.toStringAsFixed(2)}';
          // Calculate subtotal using current price: (price * qty) - discount
          final itemSubtotal = (item.price * item.qty) - item.discount;
          final subtotal =
              '${currency.symbol}${itemSubtotal.toStringAsFixed(2)}';
          return '$productName (Qty: $qty, Price: $price, Total: $subtotal)';
        }).join('; ');

        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
            .value = excel.TextCellValue(itemDetails);
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'Sales_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';

      final fileBytes = excelFile.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        // Share the file
        await Share.shareXFiles([XFile(filePath)], text: 'Sales Report');

        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(content: Text('Report exported successfully: $fileName')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error exporting report: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _printSaleReceipt(SaleModel sale) async {
    setState(() => _printingSaleId = sale.id);
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final success = await UnifiedPrintService.printReceipt(
        sale,
        databaseService: databaseService,
      );

      if (!mounted) return;
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text(
            success
                ? 'Receipt printed successfully'
                : 'Print failed. Check printer connection.',
          ),
          backgroundColor:
              success ? AppColors.successColor : AppColors.warningColor,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text('Error printing receipt: $e'),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _printingSaleId = null);
      }
    }
  }

  Future<void> _exportToCsv(List<SaleModel> sales) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final filteredSales = _filterSales(sales);

      if (filteredSales.isEmpty) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(content: Text('No data to export')),
          );
        }
        return;
      }

      final fileName =
          'Sales_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final filePath =
          await CsvExportService.exportSalesToCsv(filteredSales, fileName);

      // Share the file
      await CsvExportService.shareCsvFile(filePath);

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
              content: Text('CSV report exported successfully: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error exporting CSV report: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
