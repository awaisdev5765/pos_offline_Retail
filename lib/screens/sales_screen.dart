import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/sale_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/product_provider.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../services/print_settings_service.dart';
import '../services/unified_print_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack_bar.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesProvider);

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('sales.history_title'.tr()),
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
            child: salesAsync.when(
              data: (sales) {
                final filteredSales = _filterSales(sales);
                final screenSize = MediaQuery.of(context).size;
                final isMobile = screenSize.width < 768;

                return filteredSales.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No sales found',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Start making sales to see them here',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : isMobile
                        ? _buildSalesCardView(context, filteredSales)
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
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        // Slightly tighter vertically on mobile devices to free space
        vertical: isMobile ? 8 : 16,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05),
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
              textInputAction: TextInputAction.search,
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
                  borderSide: BorderSide(
                      color: isDarkMode
                          ? const Color(0xFF374151)
                          : Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isMobile ? 10 : 14,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              onSubmitted: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          if (!isMobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedStatus == 'all'
                    ? const Color(0xFF1E293B)
                    : (isDarkMode
                        ? const Color(0xFF374151)
                        : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  isDense: true,
                  style: TextStyle(
                    color: _selectedStatus == 'all'
                        ? Colors.white
                        : (isDarkMode ? Colors.white : Colors.black87),
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
          if (isMobile)
            IconButton(
              tooltip: 'Filters',
              icon: const Icon(Icons.filter_alt_outlined),
              onPressed: _showFilterDialog,
            ),
        ],
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
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${item.product?.name ?? 'Unknown Product'} x${item.qty}',
                                  style: TextStyle(
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // ==================== CUSTOM SALES TABLE WIDGET ====================
  Widget _buildSalesCustomTable(BuildContext context, List<SaleModel> sales) {
    final currency = ref.read(currentCurrencyProvider);
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color:
                isDarkMode ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05),
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
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF2A2F36)
                  : const Color(0xFFF3F4F6),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
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
                    color: isEven
                        ? (isDarkMode ? AppColors.surfaceDark : Colors.white)
                        : (isDarkMode
                            ? const Color(0xFF2A2F36)
                            : const Color(0xFFF9FAFB)),
                    border: Border(
                      bottom: BorderSide(
                        color: isDarkMode
                            ? const Color(0xFF374151)
                            : const Color(0xFFE5E7EB),
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
                                icon: const Icon(
                                  Icons.print,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () => _printReceipt(sale),
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

  Widget _buildSalesCardView(BuildContext context, List<SaleModel> sales) {
    final currency = ref.read(currentCurrencyProvider);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: sale.status == SaleStatus.paid
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : const Color(0xFFE5E7EB),
              width: sale.status == SaleStatus.paid ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => _showSaleDetails(context, sale),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Color(0xFF3B82F6),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sale #${sale.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sale.customer?.name ?? 'Walk-in Customer',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Items',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${sale.items.length} item${sale.items.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cashier',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sale.cashier?.name ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(sale.createdAt),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${currency.symbol}${sale.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 20),
                            onPressed: () => _showSaleDetails(context, sale),
                            tooltip: 'View Details',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.repeat, size: 20),
                            onPressed: () => _reorderSale(sale),
                            tooltip: 'Reorder',
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  AppColors.primaryColor.withValues(alpha: 0.1),
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.print, size: 20),
                            onPressed: () => _printReceipt(sale),
                            tooltip: 'Print Receipt',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

  Future<void> _printReceipt(SaleModel sale) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final savedSettings = await PrintSettingsService.getDefaultSettings();
      final dbPrinterIp =
          (await databaseService.getSetting('printer_ip'))?.trim();
      final dbPrinterPortRaw =
          (await databaseService.getSetting('printer_port'))?.trim();
      final dbPrinterPort = int.tryParse(dbPrinterPortRaw ?? '');

      final savedIp = (savedSettings.printerIp ?? '').trim();
      final effectiveIp = savedIp.isNotEmpty ? savedIp : (dbPrinterIp ?? '');
      final hasPrinterIp = effectiveIp.isNotEmpty;
      final hasBluetoothPrinter =
          await BluetoothPrinterService.verifyConnection();

      // Sales reprint is thermal-only by requirement.
      if (!hasBluetoothPrinter && !hasPrinterIp) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('No thermal or Bluetooth printer is connected.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final thermalSettings = savedSettings.copyWith(
        printerType: hasBluetoothPrinter
            ? PrinterType.bluetooth
            : PrinterType.networkThermal,
        printerIp: hasBluetoothPrinter ? savedSettings.printerIp : effectiveIp,
        printerPort: dbPrinterPort ?? savedSettings.printerPort,
        paperSize: savedSettings.paperSize == PaperSize.thermal58mm
            ? PaperSize.thermal58mm
            : PaperSize.thermal80mm,
        orientation: PrintOrientation.portrait,
      );

      final success = await UnifiedPrintService.printReceipt(
        sale,
        settings: thermalSettings,
        databaseService: databaseService,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('Sales print timeout');
          return false;
        },
      );

      if (mounted) {
        if (success) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Receipt printed successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text(
                  'Failed to print receipt. Please check printer connection.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error printing receipt: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
