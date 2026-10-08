import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/product.dart';
import '../providers/currency_provider.dart';
import '../providers/product_provider.dart';
import '../providers/stock_movement_provider.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../utils/input_formatters.dart';
import '../widgets/app_snack_bar.dart';

// Widget for displaying a stock movement bill card
class _StockMovementBillCard extends StatelessWidget {
  final DateTime billDate;
  final int itemCount;
  final double totalQty;
  final List<StockMovementWithProduct> movements;
  final VoidCallback onTap;

  const _StockMovementBillCard({
    required this.billDate,
    required this.itemCount,
    required this.totalQty,
    required this.movements,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Color(0xFF2563EB),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(billDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'} • Total Qty: ${totalQty.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (movements.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Type: ${movements.first.movement.reason}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (movements.first.employee != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'By: ${movements.first.employee!.name}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StockMovementsScreen extends ConsumerStatefulWidget {
  const StockMovementsScreen({super.key});

  @override
  ConsumerState<StockMovementsScreen> createState() =>
      _StockMovementsScreenState();
}

class _StockMovementsScreenState extends ConsumerState<StockMovementsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _entryTimeController = TextEditingController();

  // Store selected products for the table
  final List<ProductModel> _selectedProducts = [];
  final Map<int, TextEditingController> _saleQtyControllers = {};
  final Map<int, TextEditingController> _stockQtyControllers = {};

  DateTime _movementDate = DateTime.now();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _entryTimeController.text = DateFormat('hh:mm a').format(DateTime.now());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _entryTimeController.dispose();
    for (final controller in _saleQtyControllers.values) {
      controller.dispose();
    }
    for (final controller in _stockQtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productNotifierProvider);
    final currency = ref.watch(currentCurrencyProvider);
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;
    
    // Watch stock movements provider to refresh when data changes
    ref.watch(stockMovementsProvider);
    ref.watch(stockMovementNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: isMobile
                // Mobile: vertical layout with search panel above table
                ? Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: _buildMobileSearchPanel(productsAsync),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _buildDocumentHeader(),
                            Expanded(
                              child: _buildProductTable(currency.symbol),
                            ),
                            _buildSummarySection(currency.symbol),
                            _buildActionButtons(),
                          ],
                        ),
                      ),
                    ],
                  )
                // Desktop/tablet: existing side-by-side layout
                : Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildDocumentHeader(),
                            Expanded(
                              child: _buildProductTable(currency.symbol),
                            ),
                            _buildSummarySection(currency.symbol),
                            _buildActionButtons(),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _buildMobileSearchPanel(productsAsync),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Shared product search & picker panel, used in both mobile and desktop layouts
  Widget _buildMobileSearchPanel(
      AsyncValue<List<ProductModel>> productsAsync) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: productsAsync.when(
              data: (allProducts) {
                final filtered = _searchQuery.isEmpty
                    ? <ProductModel>[]
                    : allProducts.where((p) {
                        final name = p.name.toLowerCase();
                        final barcode = (p.barcode ?? '').toLowerCase();
                        final code = _formatItemCode(p).toLowerCase();
                        return name.contains(_searchQuery) ||
                            barcode.contains(_searchQuery) ||
                            code.contains(_searchQuery);
                      }).toList();

                if (_searchQuery.isEmpty) {
                  return const Center(
                    child: Text(
                      'Search for products to add',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No products found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final isSelected =
                        _selectedProducts.any((p) => p.id == product.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(product.name),
                        subtitle:
                            Text('Code: ${_formatItemCode(product)}'),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : IconButton(
                                icon: const Icon(Icons.add_circle),
                                onPressed: () => _addProduct(product),
                              ),
                      ),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          Text(
            'stock_movements.header'.tr(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(stockMovementsProvider);
              ref.invalidate(stockMovementNotifierProvider);
              ref.invalidate(productsProvider);
              ref.read(productNotifierProvider.notifier).refresh();
              _showSnack('Refreshed');
            },
            tooltip: 'Refresh Data',
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _showStockMovementFinder,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
              ),
            ),
            icon: const Icon(Icons.search),
            label: Text('common.find'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Text(
            'stock_movements.document_title'.tr(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildHeaderField(
                  'Date',
                  DateFormat('dd-MM-yyyy').format(_movementDate),
                  Icons.calendar_today,
                  onTap: _pickMovementDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderField(
                  'Entry Time',
                  _entryTimeController.text,
                  Icons.access_time,
                  isEditable: true,
                  controller: _entryTimeController,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderField(
    String label,
    String value,
    IconData icon, {
    bool isEditable = false,
    TextEditingController? controller,
    VoidCallback? onTap,
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
          onTap: onTap ?? (isEditable ? null : () {}),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: isEditable && controller != null
                ? TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      prefixIcon: Icon(icon, size: 18, color: Colors.grey),
                    ),
                    style: const TextStyle(fontSize: 14),
                  )
                : Row(
                    children: [
                      Icon(icon, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          value.isEmpty ? '---' : value,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductTable(String currencySymbol) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: _selectedProducts.isEmpty
                ? const Center(
                    child: Text(
                      'No products added. Search and add products from the right panel.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _selectedProducts.length,
                    itemBuilder: (context, index) {
                      final product = _selectedProducts[index];
                      return _buildTableRow(index, product, currencySymbol);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFE5EEF8),
        border: Border(bottom: BorderSide(color: Color(0xFFD0D7E2))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text('Barcode', style: _headerTextStyle()),
          ),
          SizedBox(
            width: 80,
            child: Text('ID', style: _headerTextStyle()),
          ),
          Expanded(
            flex: 3,
            child: Text('Name', style: _headerTextStyle()),
          ),
          SizedBox(
            width: 100,
            child: Text('Sale Qty',
                textAlign: TextAlign.center, style: _headerTextStyle()),
          ),
          SizedBox(
            width: 100,
            child: Text('Stock',
                textAlign: TextAlign.center, style: _headerTextStyle()),
          ),
          SizedBox(
            width: 120,
            child: Text('Sale Price',
                textAlign: TextAlign.right, style: _headerTextStyle()),
          ),
          SizedBox(
            width: 120,
            child: Text('Total',
                textAlign: TextAlign.right, style: _headerTextStyle()),
          ),
          SizedBox(
            width: 60,
            child: Text('Action',
                textAlign: TextAlign.center, style: _headerTextStyle()),
          ),
        ],
      ),
    );
  }

  TextStyle _headerTextStyle() {
    return const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1F2937),
    );
  }

  Widget _buildTableRow(
      int index, ProductModel product, String currencySymbol) {
    final key = product.id ?? product.hashCode;
    final saleController = _saleQtyControllers.putIfAbsent(key, () {
      final controller = TextEditingController(text: '0');
      controller.addListener(() => setState(() {}));
      return controller;
    });

    final stockController = _stockQtyControllers.putIfAbsent(key, () {
      final controller =
          TextEditingController(text: product.stock.toStringAsFixed(0));
      controller.addListener(() => setState(() {}));
      return controller;
    });

    final saleQty = double.tryParse(saleController.text) ?? 0;
    final salePrice = product.price;
    final total = saleQty * salePrice;
    final isEven = index % 2 == 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFFFF9C4),
        border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              product.barcode ?? '---',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              product.id?.toString() ?? '---',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              product.name,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: saleController,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,4}')),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: stockController,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,4}')),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              '$currencySymbol${salePrice.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              '$currencySymbol${total.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 60,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _removeProduct(product),
              tooltip: 'Remove product',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(String currencySymbol) {
    final totalQty = _calculateTotalQty();
    final grandTotal = _calculateGrandTotal();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: TextField(
              controller:
                  TextEditingController(text: totalQty.toStringAsFixed(0)),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              readOnly: true,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Total Qty',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          const Text(
            'Grand Total:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: TextField(
              controller: TextEditingController(
                  text: '$currencySymbol${grandTotal.toStringAsFixed(2)}'),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              readOnly: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton('SAVE', 'F10-SAVE', Colors.blue, _handleSave),
          _buildActionButton('PRINT', 'F8-PRINT', Colors.blue, _handlePrint),
          _buildActionButton('EXIT', '', Colors.grey, _handleExit),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String label, String shortcut, Color color, VoidCallback onPressed) {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 40,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (shortcut.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              shortcut,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  void _addProduct(ProductModel product) {
    if (_selectedProducts.any((p) => p.id == product.id)) {
      _showSnack('Product already added');
      return;
    }
    setState(() {
      _selectedProducts.add(product);
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _removeProduct(ProductModel product) {
    setState(() {
      _selectedProducts.remove(product);
      // Clean up controllers for the removed product
      final key = product.id ?? product.hashCode;
      _saleQtyControllers[key]?.dispose();
      _stockQtyControllers[key]?.dispose();
      _saleQtyControllers.remove(key);
      _stockQtyControllers.remove(key);
    });
    _showSnack('Product removed');
  }

  double _calculateTotalQty() {
    double total = 0;
    for (final controller in _saleQtyControllers.values) {
      total += double.tryParse(controller.text) ?? 0;
    }
    return total;
  }

  double _calculateGrandTotal() {
    double total = 0;
    for (final product in _selectedProducts) {
      final key = product.id ?? product.hashCode;
      final controller = _saleQtyControllers[key];
      final qty = double.tryParse(controller?.text ?? '0') ?? 0;
      total += qty * product.price;
    }
    return total;
  }

  Future<void> _pickMovementDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _movementDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      setState(() {
        _movementDate = selected;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_selectedProducts.isEmpty) {
      _showSnack('No products to save');
      return;
    }

    final notifier = ref.read(productNotifierProvider.notifier);
    bool updated = false;

    for (final product in _selectedProducts) {
      if (product.id == null) continue;
      final key = product.id ?? product.hashCode;

      // Get sale qty (this is the adjustment value)
      final saleController = _saleQtyControllers[key];
      final adjustmentValue = double.tryParse(saleController?.text ?? '0') ?? 0;

      // Inverted logic: negative = increase, positive = decrease
      final delta = -adjustmentValue; // Invert the sign

      if (delta.abs() < 0.001) continue;

      updated = true;
      // Get current user's employee ID
      final currentUser = ref.read(authProvider).currentUser;
      final employeeId = currentUser?.id;
      
      await notifier.adjustStock(
        product.id!,
        delta,
        'Stock Movement',
        reference: null,
        employeeId: employeeId,
      );
    }

    if (updated) {
      _showSnack('Stock updated successfully');
      
      // Invalidate providers to refresh data across the app
      ref.invalidate(stockMovementsProvider);
      ref.invalidate(stockMovementNotifierProvider);
      ref.invalidate(productsProvider);
      ref.read(productNotifierProvider.notifier).refresh();
      
      // Clear the table after save
      setState(() {
        _selectedProducts.clear();
        _saleQtyControllers.clear();
        _stockQtyControllers.clear();
        _entryTimeController.text = DateFormat('hh:mm a').format(DateTime.now());
        _movementDate = DateTime.now();
      });
    } else {
      _showSnack('No changes to save');
    }
  }

  void _handlePrint() {
    _showSnack('Print functionality coming soon');
  }

  void _handleExit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppSnackBar.show(
      context,
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showStockMovementFinder() async {
    try {
      // Invalidate and refresh stock movements to get latest data
      ref.invalidate(stockMovementsProvider);
      ref.invalidate(stockMovementNotifierProvider);
      
      // Wait a bit for the provider to refresh
      await Future.delayed(const Duration(milliseconds: 200));
      
      final movements = await ref.read(stockMovementsProvider.future);
      if (!mounted) return;

      // Show all stock movements (purchase invoices, sales, manual adjustments, etc.)
      // Filter out zero quantity movements
      final allMovements = movements
          .where((movement) => movement.movement.quantity != 0)
          .toList();
      
      if (allMovements.isEmpty) {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('No stock movements found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Group movements by createdAt, reason, and reference (bills created at the same time belong together)
      // This ensures purchase invoices, sales, and manual movements are properly grouped
      final Map<String, List<StockMovementWithProduct>> billsByTime = {};
      
      for (final movement in allMovements) {
        // Parse createdAt string to DateTime, then use rounded to nearest second as the key to group bills
        DateTime createdAt;
        try {
          createdAt = DateTime.parse(movement.movement.createdAt);
        } catch (_) {
          createdAt = DateTime.now();
        }
        // Round to nearest second for grouping
        final roundedDate = DateTime(
          createdAt.year,
          createdAt.month,
          createdAt.day,
          createdAt.hour,
          createdAt.minute,
          createdAt.second,
        );
        
        // Create a key that includes time, reason, and reference to properly group related movements
        final reason = movement.movement.reason.trim();
        final reference = movement.movement.reference?.trim() ?? '';
        
        // For purchase invoices, use reference if available to group by invoice
        // For sales, use reference if available
        // For manual stock movements, group by time and reason
        String groupKey;
        if (reference.isNotEmpty && (reason.toLowerCase().contains('purchase') || 
                                     reason.toLowerCase().contains('sale') ||
                                     reference.toLowerCase().contains('invoice'))) {
          // Use reference to group invoices together
          groupKey = '${roundedDate.year}-${roundedDate.month}-${roundedDate.day}-${roundedDate.hour}-${roundedDate.minute}-${roundedDate.second}-$reason-$reference';
        } else {
          // Group by time and reason for manual movements
          groupKey = '${roundedDate.year}-${roundedDate.month}-${roundedDate.day}-${roundedDate.hour}-${roundedDate.minute}-${roundedDate.second}-$reason';
        }
        
        if (!billsByTime.containsKey(groupKey)) {
          billsByTime[groupKey] = [];
        }
        billsByTime[groupKey]!.add(movement);
      }

      // Convert to list of bills and sort by date (newest first)
      final bills = billsByTime.entries.toList()
        ..sort((a, b) {
          if (a.value.isEmpty || b.value.isEmpty) return 0;
          DateTime dateA, dateB;
          try {
            dateA = DateTime.parse(a.value.first.movement.createdAt);
          } catch (_) {
            dateA = DateTime.fromMillisecondsSinceEpoch(0);
          }
          try {
            dateB = DateTime.parse(b.value.first.movement.createdAt);
          } catch (_) {
            dateB = DateTime.fromMillisecondsSinceEpoch(0);
          }
          return dateB.compareTo(dateA);
        });

      await showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: SizedBox(
            width: 900,
            height: 700,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'All Stock Movements & Invoices',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (bills.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No stock movement bills found.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bills.length,
                      itemBuilder: (_, index) {
                        final bill = bills[index];
                        final billMovements = bill.value;
                        if (billMovements.isEmpty) return const SizedBox.shrink();
                        
                        DateTime billDate;
                        try {
                          billDate = DateTime.parse(billMovements.first.movement.createdAt);
                        } catch (_) {
                          billDate = DateTime.now();
                        }
                        final itemCount = billMovements.length;
                        double totalQty = 0;
                        for (final m in billMovements) {
                          totalQty += m.movement.quantity.abs();
                        }

                        return _StockMovementBillCard(
                          billDate: billDate,
                          itemCount: itemCount,
                          totalQty: totalQty,
                          movements: billMovements,
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _showBillDetailsDialog(billMovements, billDate);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text('Unable to load stock movements: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMovementDetailDialog(StockMovementWithProduct movement) {
    if (!mounted) return;

    DateTime movementDate;
    try {
      movementDate = DateTime.parse(movement.movement.date);
    } catch (_) {
      movementDate = DateTime.now();
    }

    final isIncrease = movement.movement.quantity > 0;
    final quantityText =
        '${isIncrease ? '+' : '-'}${movement.movement.quantity.abs().toStringAsFixed(2)} ${movement.product.unit}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isIncrease ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncrease ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(isIncrease ? 'Stock Increased' : 'Stock Decreased'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Product', movement.product.name ?? 'Unknown'),
            if (movement.employee != null)
              _buildDetailRow('Created By', movement.employee!.name),
            if (movement.product.barcode != null &&
                movement.product.barcode!.isNotEmpty)
              _buildDetailRow('Barcode', movement.product.barcode!),
            _buildDetailRow('Quantity Change', quantityText),
            _buildDetailRow('Reason', movement.movement.reason),
            if (movement.movement.reference != null &&
                movement.movement.reference!.isNotEmpty)
              _buildDetailRow('Reference', movement.movement.reference!),
            _buildDetailRow(
              'Date',
              DateFormat('dd MMM yyyy, hh:mm a').format(movementDate),
            ),
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
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
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

  void _showBillDetailsDialog(
      List<StockMovementWithProduct> movements, DateTime billDate) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 800,
          height: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stock Movement Bill Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(billDate),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: movements.length,
                  itemBuilder: (context, index) {
                    final movement = movements[index];
                    final quantity = movement.movement.quantity;
                    final isIncrease = quantity > 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isIncrease ? Colors.green : Colors.red)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isIncrease
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: isIncrease ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  movement.product.name ?? 'Unknown Product',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (movement.product.barcode != null &&
                                    movement.product.barcode!.isNotEmpty)
                                  Text(
                                    'Barcode: ${movement.product.barcode}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                if (movement.employee != null)
                                  Text(
                                    'By: ${movement.employee!.name}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${isIncrease ? '+' : '-'}${quantity.abs().toStringAsFixed(2)} ${movement.product.unit}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isIncrease ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
