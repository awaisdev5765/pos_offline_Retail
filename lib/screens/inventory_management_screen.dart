import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/product_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/purchase_order_provider.dart';
import '../providers/supplier_provider.dart';
import '../models/product.dart';
import '../models/currency.dart';
import '../models/purchase_order.dart';
import '../models/supplier.dart';
import '../widgets/app_snack_bar.dart';

class InventoryManagementScreen extends ConsumerStatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  ConsumerState<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState
    extends ConsumerState<InventoryManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  double _lowStockThreshold = 10.0;
  bool _showOnlyLowStock = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final currency = ref.watch(currentCurrencyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('inventory.title'.tr()),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.inventory), text: 'All Products'),
            Tab(icon: Icon(Icons.warning), text: 'Low Stock'),
            Tab(icon: Icon(Icons.analytics), text: 'Reports'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: 'Search Products',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Products',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-product'),
            tooltip: 'Add Product',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllProductsTab(productsAsync, currency),
          _buildLowStockTab(productsAsync, currency),
          _buildReportsTab(productsAsync, currency),
        ],
      ),
    );
  }

  Widget _buildAllProductsTab(
      AsyncValue<List<ProductModel>> productsAsync, Currency currency) {
    return productsAsync.when(
      data: (products) {
        final filteredProducts = _filterProducts(products);
        return Column(
          children: [
            _buildInventoryStats(products, currency),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(productsProvider);
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _buildProductCard(product, currency);
                  },
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(error),
    );
  }

  Widget _buildLowStockTab(
      AsyncValue<List<ProductModel>> productsAsync, Currency currency) {
    return productsAsync.when(
      data: (products) {
        final lowStockProducts =
            products.where((p) => p.stock <= _lowStockThreshold).toList();
        return Column(
          children: [
            _buildLowStockHeader(lowStockProducts.length, currency),
            Expanded(
              child: lowStockProducts.isEmpty
                  ? RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(productsProvider);
                        await Future.delayed(const Duration(milliseconds: 300));
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: _buildEmptyLowStock(),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(productsProvider);
                        await Future.delayed(const Duration(milliseconds: 300));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: lowStockProducts.length,
                        itemBuilder: (context, index) {
                          final product = lowStockProducts[index];
                          return _buildLowStockCard(product, currency);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(error),
    );
  }

  Widget _buildReportsTab(
      AsyncValue<List<ProductModel>> productsAsync, Currency currency) {
    return productsAsync.when(
      data: (products) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Actions Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              const Icon(Icons.swap_horiz, color: Colors.blue),
                        ),
                        title: Text('stock_movements.title'.tr()),
                        subtitle:
                            Text('inventory.movement_history_sub'.tr()),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => context.go('/stock-movements'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildInventorySummary(products, currency),
              const SizedBox(height: 24),
              _buildStockValueAnalysis(products, currency),
              const SizedBox(height: 24),
              _buildCategoryBreakdown(products, currency),
              const SizedBox(height: 24),
              _buildReorderSuggestions(products, currency),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(error),
    );
  }

  Widget _buildInventoryStats(List<ProductModel> products, Currency currency) {
    final totalProducts = products.length;
    final lowStockCount =
        products.where((p) => p.stock <= _lowStockThreshold).length;
    final outOfStockCount = products.where((p) => p.stock <= 0).length;
    final totalStockValue =
        products.fold(0.0, (sum, p) => sum + (p.stock * p.cost));

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Products',
                  totalProducts.toString(),
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatCard(
                  'Low Stock',
                  lowStockCount.toString(),
                  Icons.warning,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Out of Stock',
                  outOfStockCount.toString(),
                  Icons.error,
                  Colors.red,
                ),
              ),
              Expanded(
                child: _buildStatCard(
                  'Stock Value',
                  '${currency.symbol}${totalStockValue.toStringAsFixed(2)}',
                  Icons.monetization_on,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductModel product, Currency currency) {
    final isLowStock = product.stock <= _lowStockThreshold;
    final isOutOfStock = product.stock <= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isOutOfStock
                ? Colors.red.shade100
                : isLowStock
                    ? Colors.orange.shade100
                    : Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isOutOfStock
                ? Icons.error
                : isLowStock
                    ? Icons.warning
                    : Icons.check_circle,
            color: isOutOfStock
                ? Colors.red
                : isLowStock
                    ? Colors.orange
                    : Colors.green,
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${product.category}'),
            Text('Stock: ${product.stock.toStringAsFixed(0)} ${product.unit}'),
            Text('Cost: ${currency.symbol}${product.cost.toStringAsFixed(2)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${currency.symbol}${product.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (isLowStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'LOW STOCK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => context.push('/edit-product?id=${product.id}'),
      ),
    );
  }

  Widget _buildLowStockHeader(int count, Currency currency) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange.shade700, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count products need attention',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consider reordering these items to avoid stockouts',
                  style: TextStyle(
                    color: Colors.orange.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockCard(ProductModel product, Currency currency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.warning, color: Colors.orange),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Current Stock: ${product.stock.toStringAsFixed(0)} ${product.unit}'),
            Text(
                'Threshold: ${_lowStockThreshold.toStringAsFixed(0)} ${product.unit}'),
            Text('Cost: ${currency.symbol}${product.cost.toStringAsFixed(2)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${currency.symbol}${product.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: () => _showReorderDialog(product),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: const Text(
                'Reorder',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ],
        ),
        onTap: () => context.push('/edit-product?id=${product.id}'),
      ),
    );
  }

  Widget _buildEmptyLowStock() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Great! No low stock items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All your products have sufficient stock',
            style: TextStyle(
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySummary(
      List<ProductModel> products, Currency currency) {
    final totalValue = products.fold(0.0, (sum, p) => sum + (p.stock * p.cost));
    final totalProducts = products.length;
    final averageStock =
        products.fold(0.0, (sum, p) => sum + p.stock) / totalProducts;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inventory Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Products',
                    totalProducts.toString(),
                    Icons.inventory,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Value',
                    '${currency.symbol}${totalValue.toStringAsFixed(2)}',
                    Icons.monetization_on,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Average Stock',
                    averageStock.toStringAsFixed(1),
                    Icons.analytics,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Categories',
                    products.map((p) => p.category).toSet().length.toString(),
                    Icons.category,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStockValueAnalysis(
      List<ProductModel> products, Currency currency) {
    final highValueProducts =
        products.where((p) => (p.stock * p.cost) > 1000).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'High Value Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (highValueProducts.isEmpty)
              Text('inventory.no_high_value'.tr())
            else
              ...highValueProducts.take(5).map((product) => ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text(product.name),
                    subtitle: Text('${product.stock.toStringAsFixed(0)} units'),
                    trailing: Text(
                      '${currency.symbol}${(product.stock * product.cost).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(
      List<ProductModel> products, Currency currency) {
    final categoryMap = <String, List<ProductModel>>{};
    for (final product in products) {
      categoryMap.putIfAbsent(product.category, () => []).add(product);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...categoryMap.entries.map((entry) {
              final category = entry.key;
              final products = entry.value;
              final totalValue =
                  products.fold(0.0, (sum, p) => sum + (p.stock * p.cost));

              return ListTile(
                leading: const Icon(Icons.category),
                title: Text(category),
                subtitle: Text('${products.length} products'),
                trailing: Text(
                  '${currency.symbol}${totalValue.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderSuggestions(
      List<ProductModel> products, Currency currency) {
    final lowStockProducts =
        products.where((p) => p.stock <= _lowStockThreshold).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reorder Suggestions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (lowStockProducts.isEmpty)
              Text('inventory.no_reorder'.tr())
            else
              ...lowStockProducts.map((product) => ListTile(
                    leading:
                        const Icon(Icons.shopping_cart, color: Colors.orange),
                    title: Text(product.name),
                    subtitle: Text(
                        'Current: ${product.stock.toStringAsFixed(0)} | Suggested: ${(_lowStockThreshold * 3).toStringAsFixed(0)}'),
                    trailing: Text(
                      '${currency.symbol}${(product.cost * (_lowStockThreshold * 3 - product.stock)).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error loading inventory: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(productsProvider),
            child: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }

  List<ProductModel> _filterProducts(List<ProductModel> products) {
    var filtered = products;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((p) =>
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.category.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_selectedCategory != 'all') {
      filtered =
          filtered.where((p) => p.category == _selectedCategory).toList();
    }

    if (_showOnlyLowStock) {
      filtered = filtered.where((p) => p.stock <= _lowStockThreshold).toList();
    }

    return filtered;
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('inventory.search_products_title'.tr()),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter product name or category...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _searchQuery = '');
              Navigator.pop(context);
            },
            child: Text('common.clear'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.search'.tr()),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('inventory.filter_products_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('inventory.low_stock_only'.tr()),
              value: _showOnlyLowStock,
              onChanged: (value) {
                setState(() => _showOnlyLowStock = value);
              },
            ),
            const Divider(),
            ListTile(
              title: Text('inventory.low_stock_threshold'.tr()),
              subtitle: Text('${_lowStockThreshold.toStringAsFixed(0)} units'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      setState(() {
                        if (_lowStockThreshold > 1) _lowStockThreshold--;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() => _lowStockThreshold++);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.apply'.tr()),
          ),
        ],
      ),
    );
  }

  void _showReorderDialog(ProductModel product) async {
    final currency = ref.read(currentCurrencyProvider);
    final suggestedQuantity =
        (_lowStockThreshold * 3 - product.stock).clamp(0.0, double.infinity);
    final estimatedCost = product.cost * suggestedQuantity;

    // Get supplier info if available
    SupplierModel? supplier;
    if (product.supplierId != null) {
      try {
        final suppliersAsync = ref.read(suppliersProvider);
        final suppliers = await suppliersAsync.when(
          data: (list) => list,
          loading: () => <SupplierModel>[],
          error: (_, __) => <SupplierModel>[],
        );

        if (suppliers.isNotEmpty) {
          supplier = suppliers.firstWhere(
            (s) => s.id == product.supplierId,
            orElse: () => suppliers.first,
          );
        }
      } catch (e) {
        // Supplier not found, will create order without supplier
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reorder ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Current Stock: ${product.stock.toStringAsFixed(0)} ${product.unit}'),
            const SizedBox(height: 8),
            Text(
                'Reorder Level: ${product.reorderLevel.toStringAsFixed(0)} ${product.unit}'),
            const SizedBox(height: 8),
            Text(
                'Suggested Order: ${suggestedQuantity.toStringAsFixed(0)} ${product.unit}'),
            const SizedBox(height: 8),
            Text(
                'Unit Cost: ${currency.symbol}${product.cost.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(
              'Estimated Cost: ${currency.symbol}${estimatedCost.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (supplier != null) ...[
              const SizedBox(height: 16),
              Text('Supplier: ${supplier!.name}'),
            ] else if (product.supplierId == null) ...[
              const SizedBox(height: 16),
              const Text(
                '⚠️ No supplier assigned to this product',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('inventory.create_po'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _createPurchaseOrderFromProduct(
          product, suggestedQuantity, supplier);
    }
  }

  Future<void> _createPurchaseOrderFromProduct(
    ProductModel product,
    double quantity,
    SupplierModel? supplier,
  ) async {
    try {
      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // If no supplier, check if we need to assign one
      if (supplier == null && product.supplierId == null) {
        // Get all suppliers to let user choose
        final suppliersAsync = ref.read(suppliersProvider);
        final suppliers = await suppliersAsync.when(
          data: (list) => list,
          loading: () => <SupplierModel>[],
          error: (_, __) => <SupplierModel>[],
        );

        // Hide loading
        if (mounted) Navigator.pop(context);

        if (suppliers.isEmpty) {
          if (mounted) {
            AppSnackBar.show(
              context,
              const SnackBar(
                content: Text(
                    'No suppliers available. Please add a supplier first.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        // If only one supplier, use it; otherwise show selection dialog
        if (suppliers.length == 1) {
          supplier = suppliers.first;
        } else {
          // Show supplier selection dialog
          final selectedSupplier = await showDialog<SupplierModel>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('inventory.select_supplier'.tr()),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final s = suppliers[index];
                    return ListTile(
                      title: Text(s.name),
                      subtitle: Text(s.phone),
                      onTap: () => Navigator.pop(context, s),
                    );
                  },
                ),
              ),
            ),
          );

          if (selectedSupplier == null) {
            return; // User cancelled
          }
          supplier = selectedSupplier;
        }

        // Show loading again
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );
        }
      }

      // Create purchase order
      final orderNumber = 'PO-${DateTime.now().millisecondsSinceEpoch}';
      final unitCost = product.cost;
      final subtotal = quantity * unitCost;
      final tax = 0.0; // Can be added later
      final discount = 0.0; // Can be added later
      final total = subtotal + tax - discount;

      final purchaseOrder = PurchaseOrderModel(
        orderNumber: orderNumber,
        supplierId: supplier?.id ?? 0,
        orderDate: DateTime.now(),
        expectedDate: DateTime.now().add(const Duration(days: 7)),
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        total: total,
        status: PurchaseOrderStatus.pending,
        notes: 'Auto-generated from low stock alert for ${product.name}',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create purchase order item
      final orderItem = PurchaseOrderItemModel(
        purchaseOrderId: 0, // Will be set after order creation
        productId: product.id!,
        quantity: quantity,
        unitCost: unitCost,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total,
        createdAt: DateTime.now(),
      );

      // Save purchase order first
      final purchaseOrderNotifier =
          ref.read(purchaseOrderNotifierProvider.notifier);
      final orderId = await purchaseOrderNotifier
          .addPurchaseOrder(purchaseOrder, [orderItem]);

      // Hide loading
      if (mounted) Navigator.pop(context);

      // Show success message and offer to navigate
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Purchase order created: $orderNumber'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Create Invoice',
              textColor: Colors.white,
              onPressed: () async {
                // Navigate to purchase invoice screen with pre-filled order data
                final productAsync = ref.read(productNotifierProvider);
                final products = await productAsync.when(
                  data: (list) => list,
                  loading: () => <ProductModel>[],
                  error: (_, __) => <ProductModel>[],
                );

                final productModel = products.firstWhere(
                  (p) => p.id == product.id,
                  orElse: () => product,
                );

                // Navigate to purchase invoice with pre-filled item
                if (mounted) {
                  await context.push(
                    '/purchase-invoice',
                    extra: {
                      'supplierId': supplier?.id,
                      'preFillItems': [
                        {
                          'productId': product.id!,
                          'product': productModel,
                          'quantity': quantity,
                          'unitCost': unitCost,
                          'subtotal': subtotal,
                        }
                      ],
                      'invoiceNumber': orderNumber.replaceAll('PO-', 'PI-'),
                      'notes':
                          'Auto-generated from reorder for ${product.name}',
                    },
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Hide loading if still showing
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error creating purchase order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
