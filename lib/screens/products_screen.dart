import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/product_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../services/bulk_import_service.dart';
import '../models/product.dart';
import '../models/currency.dart';
import '../theme/app_theme.dart';
import '../utils/modern_dialog_builder.dart';
import '../utils/input_formatters.dart';
import '../utils/mobile_optimization.dart';
import '../utils/navigation_helper.dart';
import '../widgets/app_snack_bar.dart';
import '../utils/password_hasher.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Stock filter: 'all', 'low_stock', 'out_of_stock'
  String _stockFilter = 'all';

  // Track expanded state for stock alert sections
  bool _lowStockExpanded = false;
  bool _outOfStockExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatStockQuantity(ProductModel product) {
    final stock = product.stock;
    if (stock.isNaN || stock.isInfinite) {
      return '0';
    }
    final isWholeNumber = stock == stock.truncateToDouble();
    final formatted = stock.toStringAsFixed(isWholeNumber ? 0 : 2);
    return isWholeNumber
        ? formatted
        : formatted.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productNotifierProvider);
    final productNotifier = ref.watch(productNotifierProvider.notifier);
    final currency = ref.watch(currentCurrencyProvider);
    final isDarkMode = ref.watch(isDarkModeProvider);
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;
    final canEditProducts = currentUser?.canManageProducts() ?? false;

    final allProducts = productsAsync.valueOrNull ?? [];
    final totalProductsCount = allProducts.length;
    final lowStockOverviewCount =
        allProducts.where((p) => p.isLowStock && p.stock > 0).length;
    final outOfStockOverviewCount =
        allProducts.where((p) => p.stock <= 0).length;

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: _searchQuery.isEmpty
            ? Text('products.title'.tr())
            : Text('Search: $_searchQuery'),
        automaticallyImplyLeading: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Bulk actions',
            onSelected: (value) {
              if (value == 'bulk_import') {
                _handleImportProducts();
              } else if (value == 'bulk_guide') {
                _showBulkImportGuide();
              } else if (value == 'bulk_export') {
                _handleExportProducts();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'bulk_import',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('Bulk Add Products'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'bulk_export',
                child: ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text('Export Products'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'bulk_guide',
                child: ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text('Bulk Import Guide'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            icon: const Icon(Icons.playlist_add_check),
          ),
          MobileOptimization.mobileIconButton(
            icon: _searchQuery.isEmpty ? Icons.search : Icons.close,
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
            },
            tooltip: _searchQuery.isEmpty ? 'Search' : 'Clear',
          ),
          MobileOptimization.mobileIconButton(
            icon: Icons.filter_list,
            onPressed: () => _showFilterDialog(),
            tooltip: 'Filter',
          ),
          PopupMenuButton<String>(
            tooltip: 'Overview',
            onSelected: (value) {
              setState(() => _stockFilter = value);
            },
            itemBuilder: (context) => [
              _overviewMenuItem(
                value: 'all',
                icon: Icons.inventory,
                color: AppColors.primaryColor,
                label: 'Total Products',
                count: totalProductsCount,
              ),
              _overviewMenuItem(
                value: 'low_stock',
                icon: Icons.warning,
                color: AppColors.warningColor,
                label: 'Low Stock',
                count: lowStockOverviewCount,
              ),
              _overviewMenuItem(
                value: 'out_of_stock',
                icon: Icons.error,
                color: AppColors.errorColor,
                label: 'Out of Stock',
                count: outOfStockOverviewCount,
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(
                MediaQuery.of(context).size.width < 600 ? 12 : 16),
            decoration: BoxDecoration(
              color:
                  isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode
                      ? AppColors.borderColor.withValues(alpha: 0.3)
                      : AppColors.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'products.search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primaryColor, width: 2),
                ),
                filled: true,
                fillColor:
                    isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Products List
          Expanded(
            child: productsAsync.when(
              data: (products) {
                // Pass unfiltered products to _buildProductsList
                // It will handle all filtering internally
                return _buildProductsList(
                    context, products, productNotifier, canEditProducts);
              },
              loading: () => _buildLoadingState(),
              error: (error, stack) =>
                  _buildErrorState(context, error, productNotifier),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/add-product'),
        heroTag: "products_fab",
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  PopupMenuItem<String> _overviewMenuItem({
    required String value,
    required IconData icon,
    required Color color,
    required String label,
    required int count,
  }) {
    final isSelected = _stockFilter == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          if (isSelected) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle, size: 14, color: Colors.green),
          ],
        ],
      ),
    );
  }

  bool _productMatchesSearch(ProductModel product) {
    if (_searchQuery.isEmpty) return true;
    bool fieldContains(String? value) =>
        value != null && value.toLowerCase().contains(_searchQuery);
    return product.name.toLowerCase().contains(_searchQuery) ||
        product.category.toLowerCase().contains(_searchQuery) ||
        fieldContains(product.barcode) ||
        fieldContains(product.brand) ||
        fieldContains(product.modelName) ||
        fieldContains(product.company) ||
        fieldContains(product.description);
  }

  /// Text search for the retail products list (applied after stock grouping).
  List<ProductModel> _applyAdditionalFilters(List<ProductModel> products) {
    return products.where(_productMatchesSearch).toList();
  }

  void _showFilterDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.filter_list, color: AppColors.primaryColor),
              const SizedBox(width: 8),
              Expanded(child: Text('products.filter_stock_title'.tr())),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('products.filter_all'.tr()),
                value: 'all',
                groupValue: _stockFilter,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _stockFilter = v);
                  Navigator.pop(dialogContext);
                },
              ),
              RadioListTile<String>(
                title: Text('products.filter_low_stock'.tr()),
                value: 'low_stock',
                groupValue: _stockFilter,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _stockFilter = v);
                  Navigator.pop(dialogContext);
                },
              ),
              RadioListTile<String>(
                title: Text('products.filter_out_of_stock'.tr()),
                value: 'out_of_stock',
                groupValue: _stockFilter,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _stockFilter = v);
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('common.close'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleImportProducts() async {
    try {
      final file = await BulkImportService.pickExcelFile();
      if (file == null) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(content: Text('No file selected')),
          );
        }
        return;
      }

      if (mounted) {
        ModernDialogBuilder.showLoadingDialog(
          context: context,
          message: 'Importing products...',
        );
      }

      final databaseService = ref.read(databaseServiceProvider);
      final result = await BulkImportService.importProductsFromExcel(
          databaseService, file);

      if (mounted) {
        NavigationHelper.safeCloseDialog(context);
        if (result.errors.isNotEmpty) {
          await _showImportErrorsDialog(result);
        } else {
          await ModernDialogBuilder.showInfoDialog(
            context: context,
            title: 'Import Completed',
            message:
                'Inserted: ${result.inserted}\nUpdated: ${result.updated}\nSkipped: ${result.skipped}',
            icon: Icons.cloud_done_outlined,
            iconColor: const Color(0xFF10B981),
            buttonText: 'OK',
          );
        }
      }

      ref.read(productNotifierProvider.notifier).refresh();
      ref.invalidate(productsProvider);
    } catch (e) {
      if (mounted) {
        NavigationHelper.safeCloseDialog(context);
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showImportErrorsDialog(BulkImportResult result) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Completed'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Inserted: ${result.inserted}   Updated: ${result.updated}   Skipped: ${result.skipped}'),
              const SizedBox(height: 12),
              const Text('Rows that need attention:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: result.errors.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(result.errors[index],
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExportProducts() async {
    try {
      if (mounted) {
        ModernDialogBuilder.showLoadingDialog(
          context: context,
          message: 'Exporting products...',
        );
      }

      final products = ref.read(productNotifierProvider).valueOrNull ?? [];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = await BulkImportService.exportProductsToExcel(
          products, 'products_export_$timestamp');

      if (mounted) {
        NavigationHelper.safeCloseDialog(context);
      }

      await Share.shareXFiles([XFile(filePath)],
          text: 'Product catalog export');
    } catch (e) {
      if (mounted) {
        NavigationHelper.safeCloseDialog(context);
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showBulkImportGuide() async {
    const headers = 'Name, Category, Retail Cash, Cost Price, Stock, Barcode, '
        'Unit, Reorder Level, Reorder Quantity, Discount, Tax, Description';
    const sampleRows = [
      'iPhone 13, Phones, 95000, 87000, 8, IP13-BLK-128, pcs, 3, 10, 0, 0, 128GB Black',
      'Type-C Charger 20W, Accessories, 1200, 850, 40, CHG-TYPEC-20W, pcs, 10, 25, 0, 0, Fast charger',
      'Hair Serum 100ml, Salon Products, 850, 600, 25, HS-100ML-01, pcs, 5, 15, 5, 0, Anti-frizz serum'
    ];

    await ModernDialogBuilder.showInfoDialog(
      context: context,
      title: 'Bulk Product Import Guide',
      message:
          'Use an Excel file (.xlsx/.xls) with the exact header row below:\n\n$headers\n\n'
          'Sample rows:\n${sampleRows.join('\n')}\n\n'
          'Rules:\n'
          '1) Header names and order must match exactly.\n'
          '2) Name and Category are required.\n'
          '3) If Barcode matches an existing product, it updates that row.\n'
          '4) Without Barcode, Name + Category are used for update matching.\n'
          '5) Numbers can be plain (e.g. 1200) or decimal (e.g. 1200.50).',
      icon: Icons.info_outline,
      iconColor: AppColors.primaryColor,
      buttonText: 'Close',
    );
  }

  Widget _buildProductsList(BuildContext context, List<ProductModel> products,
      ProductNotifier productNotifier, bool canEditProducts) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first product to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/add-product'),
              icon: const Icon(Icons.add),
              label: Text('pos.add_product'.tr()),
            ),
          ],
        ),
      );
    }

    // Group products by stock status
    final lowStockProducts =
        products.where((p) => p.isLowStock && p.stock > 0).toList();
    final outOfStockProducts = products.where((p) => p.stock <= 0).toList();
    final normalStockProducts =
        products.where((p) => !p.isLowStock && p.stock > 0).toList();

    // Filter products based on selected filter
    List<ProductModel> filteredProducts;
    String sectionTitle;
    if (_stockFilter == 'low_stock') {
      filteredProducts = lowStockProducts;
      sectionTitle = 'Low Stock Products';
    } else if (_stockFilter == 'out_of_stock') {
      filteredProducts = outOfStockProducts;
      sectionTitle = 'Out of Stock Products';
    } else {
      filteredProducts = products;
      sectionTitle = 'All Products';
    }

    // Apply text search to the already stock-filtered products
    final finalFilteredProducts = _applyAdditionalFilters(filteredProducts);

    final isMobile = MediaQuery.of(context).size.width < 600;

    return RefreshIndicator(
      onRefresh: () async => productNotifier.refresh(),
      child: ListView(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        children: [
          // Show filter indicator if a filter is active
          if (_stockFilter != 'all') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _stockFilter == 'low_stock'
                    ? AppColors.warningColor.withValues(alpha: 0.1)
                    : AppColors.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _stockFilter == 'low_stock'
                      ? AppColors.warningColor
                      : AppColors.errorColor,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _stockFilter == 'low_stock' ? Icons.warning : Icons.error,
                    color: _stockFilter == 'low_stock'
                        ? AppColors.warningColor
                        : AppColors.errorColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing: $sectionTitle',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _stockFilter == 'low_stock'
                            ? AppColors.warningColor
                            : AppColors.errorColor,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _stockFilter = 'all';
                      });
                    },
                    child: Text('products_ui.clear_filter'.tr()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Low Stock Alert (only show if not filtered or if showing all)
          if (_stockFilter == 'all' && lowStockProducts.isNotEmpty) ...[
            _buildStockAlertSection('Low Stock Alert', lowStockProducts,
                AppColors.warningColor, Icons.warning),
            const SizedBox(height: 16),
          ],

          // Out of Stock Alert (only show if not filtered or if showing all)
          if (_stockFilter == 'all' && outOfStockProducts.isNotEmpty) ...[
            _buildStockAlertSection('Out of Stock', outOfStockProducts,
                AppColors.errorColor, Icons.error),
            const SizedBox(height: 16),
          ],

          // Filtered Products List
          _buildProductsSection(sectionTitle, finalFilteredProducts,
              productNotifier, canEditProducts),
        ],
      ),
    );
  }

  Widget _buildStockAlertSection(
      String title, List<ProductModel> products, Color color, IconData icon) {
    final isLowStock = title.toLowerCase().contains('low');
    final isExpanded = isLowStock ? _lowStockExpanded : _outOfStockExpanded;
    final displayCount = isExpanded ? products.length : 3;
    final hasMore = products.length > 3;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '${products.length} items',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...products.take(displayCount).map((product) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      '${_formatStockQuantity(product)} ${product.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              )),
          if (hasMore)
            InkWell(
              onTap: () {
                setState(() {
                  if (isLowStock) {
                    _lowStockExpanded = !_lowStockExpanded;
                  } else {
                    _outOfStockExpanded = !_outOfStockExpanded;
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isExpanded ? 'Show Less' : '${products.length - 3} more',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: color,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(String title, List<ProductModel> products,
      ProductNotifier productNotifier, bool canEditProducts) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${products.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isMobile)
          ...products.map((product) => Consumer(
                builder: (context, ref, child) {
                  final currency = ref.watch(currentCurrencyProvider);
                  return _buildProductCard(context, product, productNotifier,
                      currency, canEditProducts);
                },
              ))
        else
          Consumer(
            builder: (context, ref, child) {
              final currency = ref.watch(currentCurrencyProvider);
              return _buildProductsTable(
                  products, productNotifier, currency, canEditProducts);
            },
          ),
      ],
    );
  }

  /// Dense, sortable-looking data table used on wide (desktop/tablet)
  /// screens instead of the tall per-product cards, matching the compact
  /// row layout of typical admin-panel product/inventory tables.
  Widget _buildProductsTable(
      List<ProductModel> products,
      ProductNotifier productNotifier,
      Currency currency,
      bool canEditProducts) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final headerColor =
        isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDarkMode
        ? AppColors.borderColor.withValues(alpha: 0.2)
        : AppColors.borderColor;

    Widget headerCell(String label,
        {int flex = 1, TextAlign align = TextAlign.left}) {
      return Expanded(
        flex: flex,
        child: Text(
          label,
          textAlign: align,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Container(
            color: headerColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                headerCell('PRODUCT', flex: 4),
                headerCell('CATEGORY', flex: 2),
                headerCell('PRICE', flex: 1, align: TextAlign.right),
                headerCell('COST', flex: 1, align: TextAlign.right),
                headerCell('STOCK', flex: 2, align: TextAlign.right),
                const SizedBox(width: 120, child: SizedBox.shrink()),
              ],
            ),
          ),
          ...products.asMap().entries.map((entry) {
            final index = entry.key;
            final product = entry.value;
            return _ProductTableRow(
              product: product,
              currency: currency,
              canEditProducts: canEditProducts,
              isDarkMode: isDarkMode,
              isLast: index == products.length - 1,
              borderColor: borderColor,
              formatStock: _formatStockQuantity,
              onTap: canEditProducts
                  ? () => context.go('/edit-product?id=${product.id}')
                  : null,
              onEdit: () {
                if (canEditProducts) {
                  context.go('/edit-product?id=${product.id}');
                } else {
                  AppSnackBar.show(
                    context,
                    const SnackBar(
                      content:
                          Text('You do not have permission to edit products.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              onAdjustStock: () =>
                  _showStockAdjustmentDialog(context, product, productNotifier),
              onDelete: () =>
                  _showDeleteDialog(context, product, productNotifier),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProductCard(
      BuildContext context,
      ProductModel product,
      ProductNotifier productNotifier,
      Currency currency,
      bool canEditProducts) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: canEditProducts
                  ? () => context.go('/edit-product?id=${product.id}')
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: MobileOptimization.getCardPadding(context),
                child: Row(
                  children: [
                    Hero(
                      tag: 'product_${product.id}',
                      child: CircleAvatar(
                        radius: MobileOptimization.isMobile(context) ? 20 : 24,
                        backgroundColor: product.isLowStock
                            ? AppColors.warning
                            : AppColors.success,
                        child: Text(
                          product.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MobileOptimization.getResponsiveSpacing(
                        context,
                        mobile: 12,
                        tablet: 14,
                        desktop: 16,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Category: ${product.category}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          if ((product.brand != null &&
                                  product.brand!.trim().isNotEmpty) ||
                              (product.modelName != null &&
                                  product.modelName!.trim().isNotEmpty))
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                [
                                  if (product.brand != null &&
                                      product.brand!.trim().isNotEmpty)
                                    product.brand!.trim(),
                                  if (product.modelName != null &&
                                      product.modelName!.trim().isNotEmpty)
                                    product.modelName!.trim(),
                                ].join(' '),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            'Price: ${currency.symbol}${product.price.toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primaryColor,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cost: ${currency.symbol}${product.cost.toStringAsFixed(2)}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.inventory,
                                size: 14,
                                color: product.isLowStock
                                    ? AppColors.warning
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatStockQuantity(product)} ${product.unit}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: product.isLowStock
                                          ? AppColors.warning
                                          : Colors.grey[600],
                                    ),
                              ),
                              if (product.isLowStock) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'LOW STOCK',
                                    style: TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            if (canEditProducts) {
                              context.go('/edit-product?id=${product.id}');
                            } else {
                              AppSnackBar.show(
                                context,
                                const SnackBar(
                                  content: Text(
                                      'You do not have permission to edit products.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            break;
                          case 'delete':
                            _showDeleteDialog(
                                context, product, productNotifier);
                            break;
                          case 'adjust_stock':
                            _showStockAdjustmentDialog(
                                context, product, productNotifier);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          enabled: canEditProducts,
                          child: ListTile(
                            leading: Icon(Icons.edit,
                                color: canEditProducts ? null : Colors.grey),
                            title: Text('Edit',
                                style: TextStyle(
                                    color:
                                        canEditProducts ? null : Colors.grey)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'adjust_stock',
                          child: ListTile(
                            leading: Icon(Icons.inventory),
                            title: Text('Adjust Stock'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text('Delete',
                                style: TextStyle(color: Colors.red)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, ProductModel product,
      ProductNotifier productNotifier) async {
    final currentUser = ref.read(authProvider).currentUser;
    final isAdmin = currentUser?.isAdmin ?? false;

    try {
      // Try to delete first
      await productNotifier.deleteProduct(product.id!);
      // Invalidate productsProvider to refresh dashboard and other views
      ref.invalidate(productsProvider);

      if (context.mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Product deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // If deletion failed due to sales constraint
      if (e.toString().contains('Cannot delete product') &&
          e.toString().contains('used in sales')) {
        if (context.mounted) {
          // Show dialog with force delete option for admins
          if (isAdmin) {
            final forceDelete = await ModernDialogBuilder.showConfirmDialog(
              context: context,
              title: 'Product Used in Sales',
              message:
                  'This product has been used in sales and cannot be deleted normally to maintain historical records.\n\n'
                  'As an admin, you can force delete this product, but this will:\n'
                  '• Remove the product from all records\n'
                  '• May affect historical sales reports\n'
                  '• Cannot be undone\n\n'
                  'Do you want to force delete this product?',
              confirmText: 'Force Delete',
              cancelText: 'Cancel',
              isDestructive: true,
              icon: Icons.warning_amber_rounded,
            );

            if (forceDelete == true) {
              try {
                await productNotifier.deleteProduct(product.id!,
                    forceDelete: true);
                ref.invalidate(productsProvider);

                if (context.mounted) {
                  AppSnackBar.show(
                    context,
                    const SnackBar(
                      content: Text('Product force deleted successfully'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (forceError) {
                if (context.mounted) {
                  AppSnackBar.show(
                    context,
                    SnackBar(
                      content: Text('Error: ${forceError.toString()}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            }
          } else {
            // Non-admin users just see the error
            AppSnackBar.show(
              context,
              SnackBar(
                content: Text(e.toString().replaceAll('Exception: ', '')),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } else {
        // Other errors
        if (context.mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  void _showStockAdjustmentDialog(BuildContext context, ProductModel product,
      ProductNotifier productNotifier) {
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();
    final referenceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust Stock - ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity Change',
                hintText: 'Enter positive for stock in, negative for stock out',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g., Purchase, Damage, Return',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'Reference (Optional)',
                hintText: 'Invoice number, etc.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = double.tryParse(quantityController.text) ?? 0;
              if (quantity != 0) {
                await productNotifier.adjustStock(
                  product.id!,
                  quantity,
                  reasonController.text.isNotEmpty
                      ? reasonController.text
                      : 'Manual adjustment',
                  reference: referenceController.text.isNotEmpty
                      ? referenceController.text
                      : null,
                );
                // Invalidate productsProvider to refresh dashboard and other views
                ref.invalidate(productsProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: Text('products_ui.adjust'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    final isDarkMode = ref.watch(isDarkModeProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF374151)
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 120,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, Object error, ProductNotifier productNotifier) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.errorColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Error loading products',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => productNotifier.refresh(),
            icon: const Icon(Icons.refresh),
            label: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }

  /// Verify admin password before allowing stock to zero operations
  Future<bool?> _verifyAdminPasswordForStockZero({
    required String title,
    required String message,
  }) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;
    String? errorMessage;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.lock, color: Color(0xFFF59E0B)),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Admin Password',
                    hintText: 'Enter your admin password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    errorText: errorMessage,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) async {
                    if (formKey.currentState?.validate() ?? false) {
                      await _checkPasswordForStockZero(
                        passwordController.text,
                        setDialogState,
                        (error) {
                          errorMessage = error;
                        },
                      );
                    }
                  },
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  await _checkPasswordForStockZero(
                    passwordController.text,
                    setDialogState,
                    (error) {
                      setDialogState(() {
                        errorMessage = error;
                      });
                    },
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
              ),
              child: Text('products_ui.verify'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if the entered password matches admin password
  Future<void> _checkPasswordForStockZero(
    String password,
    StateSetter setDialogState,
    Function(String?) setError,
  ) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final settings = await databaseService.getSettings();
      final adminPassword = settings['admin_password'];

      if (adminPassword == null) {
        setError('Admin password not configured');
        return;
      }

      // Compare with stored admin password
      if (PasswordHasher.verify(password, adminPassword)) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop(true);
        }
      } else {
        setError('Incorrect password. Please try again.');
      }
    } catch (e) {
      setError('Error verifying password: $e');
    }
  }
}

/// A single dense row in the desktop products table, with a hover
/// highlight and inline action icons (admin-panel style) instead of the
/// tall card layout used on mobile.
class _ProductTableRow extends StatefulWidget {
  const _ProductTableRow({
    required this.product,
    required this.currency,
    required this.canEditProducts,
    required this.isDarkMode,
    required this.isLast,
    required this.borderColor,
    required this.formatStock,
    required this.onEdit,
    required this.onAdjustStock,
    required this.onDelete,
    this.onTap,
  });

  final ProductModel product;
  final Currency currency;
  final bool canEditProducts;
  final bool isDarkMode;
  final bool isLast;
  final Color borderColor;
  final String Function(ProductModel) formatStock;
  final VoidCallback onEdit;
  final VoidCallback onAdjustStock;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  State<_ProductTableRow> createState() => _ProductTableRowState();
}

class _ProductTableRowState extends State<_ProductTableRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final currency = widget.currency;
    final isOutOfStock = product.stock <= 0;
    final stockColor = isOutOfStock
        ? AppColors.errorColor
        : (product.isLowStock ? AppColors.warningColor : Colors.grey[600]!);

    final subtitleParts = <String>[
      if (product.brand != null && product.brand!.trim().isNotEmpty)
        product.brand!.trim(),
      if (product.modelName != null && product.modelName!.trim().isNotEmpty)
        product.modelName!.trim(),
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _hovering
                ? (widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.04)
                    : AppColors.primaryColor.withValues(alpha: 0.03))
                : Colors.transparent,
            border: widget.isLast
                ? null
                : Border(bottom: BorderSide(color: widget.borderColor)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Product (avatar + name + subtitle)
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isOutOfStock || product.isLowStock
                          ? AppColors.warning
                          : AppColors.success,
                      child: Text(
                        product.name.isNotEmpty
                            ? product.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          if (subtitleParts.isNotEmpty)
                            Text(
                              subtitleParts.join(' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Category
              Expanded(
                flex: 2,
                child: Text(
                  product.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color:
                        widget.isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
              // Price
              Expanded(
                flex: 1,
                child: Text(
                  '${currency.symbol}${product.price.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              // Cost
              Expanded(
                flex: 1,
                child: Text(
                  '${currency.symbol}${product.cost.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              // Stock
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: stockColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.formatStock(product)} ${product.unit}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: stockColor,
                      ),
                    ),
                  ),
                ),
              ),
              // Actions
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Edit',
                      icon: Icon(Icons.edit_outlined,
                          color: widget.canEditProducts
                              ? Colors.grey[600]
                              : Colors.grey[300]),
                      onPressed: widget.onEdit,
                    ),
                    IconButton(
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Adjust Stock',
                      icon: Icon(Icons.inventory_2_outlined,
                          color: Colors.grey[600]),
                      onPressed: widget.onAdjustStock,
                    ),
                    IconButton(
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
