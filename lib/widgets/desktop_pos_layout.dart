import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
// Removed unnecessary import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/currency.dart';
import '../providers/currency_provider.dart';
import 'context_menu.dart';

class DesktopPosLayout extends ConsumerStatefulWidget {
  final List<ProductModel> products;
  final List<CustomerModel> customers;
  final List<SaleItemModel> cartItems;
  final CustomerModel? selectedCustomer;
  final String orderType;
  final String paymentType;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final Function(ProductModel) onAddToCart;
  final Function(SaleItemModel) onRemoveFromCart;
  final Function(SaleItemModel, int) onUpdateQuantity;
  final Function(CustomerModel?) onSelectCustomer;
  final Function(String) onOrderTypeChanged;
  final Function(String) onPaymentTypeChanged;
  final VoidCallback onCheckout;
  final VoidCallback onClearCart;
  final VoidCallback onHoldOrder;
  final VoidCallback onLoadOrder;
  final Function(String) onSearch;
  final Function(String) onCategoryFilter;
  final String searchQuery;
  final String selectedCategory;

  const DesktopPosLayout({
    super.key,
    required this.products,
    required this.customers,
    required this.cartItems,
    required this.selectedCustomer,
    required this.orderType,
    required this.paymentType,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.onUpdateQuantity,
    required this.onSelectCustomer,
    required this.onOrderTypeChanged,
    required this.onPaymentTypeChanged,
    required this.onCheckout,
    required this.onClearCart,
    required this.onHoldOrder,
    required this.onLoadOrder,
    required this.onSearch,
    required this.onCategoryFilter,
    required this.searchQuery,
    required this.selectedCategory,
  });

  @override
  ConsumerState<DesktopPosLayout> createState() => _DesktopPosLayoutState();
}

class _DesktopPosLayoutState extends ConsumerState<DesktopPosLayout> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  // bool _showCustomerSearch = false; // Removed unused field
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    _selectedCategory = widget.selectedCategory;

    // Set up keyboard shortcuts
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        // Focus search when F key is pressed
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final currency = ref.watch(currentCurrencyProvider);

    return SizedBox(
      height: screenSize.height - 100,
      child: Row(
        children: [
          // Left Panel - Products
          Expanded(
            flex: 2,
            child: _buildProductsPanel(),
          ),

          // Right Panel - Cart and Checkout
          SizedBox(
            width: 400,
            child: _buildCartPanel(currency),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Search and Category Filter
          _buildSearchAndFilterBar(),

          // Products Grid
          Expanded(
            child: _buildProductsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: widget.onSearch,
            decoration: InputDecoration(
              hintText: 'Search products... (Press F to focus)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  widget.onSearch('');
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF3B82F6), width: 2),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Category Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('all', 'All Products'),
                const SizedBox(width: 8),
                _buildCategoryChip('electronics', 'Electronics'),
                const SizedBox(width: 8),
                _buildCategoryChip('clothing', 'Clothing'),
                const SizedBox(width: 8),
                _buildCategoryChip('food', 'Food'),
                const SizedBox(width: 8),
                _buildCategoryChip('books', 'Books'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _selectedCategory == category;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = category;
        });
        widget.onCategoryFilter(category);
      },
      selectedColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
      checkmarkColor: const Color(0xFF3B82F6),
    );
  }

  Widget _buildProductsGrid() {
    final filteredProducts = widget.products.where((product) {
      final matchesSearch = product.name
              .toLowerCase()
              .contains(widget.searchQuery.toLowerCase()) ||
          product.barcode?.contains(widget.searchQuery) == true;
      final matchesCategory =
          _selectedCategory == 'all' || product.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(ProductModel product) {
    return ProductContextMenu(
      productId: product.id.toString(),
      productName: product.name,
      isInStock: product.stock > 0,
      onViewDetails: () => _showProductDetails(product),
      onEdit: () => _editProduct(product),
      onAdjustStock: () => _adjustStock(product),
      onViewHistory: () => _viewProductHistory(product),
      onDuplicate: () => _duplicateProduct(product),
      onDelete: () => _deleteProduct(product),
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: () => widget.onAddToCart(product),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image Placeholder
                Container(
                  height: 80,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.inventory,
                    size: 32,
                    color: Color(0xFF94A3B8),
                  ),
                ),

                const SizedBox(height: 8),

                // Product Name
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Price and Stock
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${ref.watch(currentCurrencyProvider).symbol}${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: product.stock > 0
                            ? const Color(0xFF10B981).withValues(alpha: 0.1)
                            : const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${product.stock}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: product.stock > 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
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
  }

  Widget _buildCartPanel(Currency currency) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Cart Header
          _buildCartHeader(),

          // Customer Selection
          _buildCustomerSelection(),

          // Cart Items
          Expanded(
            child: _buildCartItems(),
          ),

          // Order Summary
          _buildOrderSummary(currency),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildCartHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Current Order',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: widget.onHoldOrder,
                icon: const Icon(Icons.pause),
                tooltip: 'Hold Order',
              ),
              IconButton(
                onPressed: widget.onLoadOrder,
                icon: const Icon(Icons.play_arrow),
                tooltip: 'Load Order',
              ),
              IconButton(
                onPressed: widget.onClearCart,
                icon: const Icon(Icons.clear),
                tooltip: 'Clear Cart',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customerSearchController,
                  onChanged: (value) {
                    // Handle customer search
                  },
                  decoration: InputDecoration(
                    hintText: 'Search customer...',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  // Open customer selection dialog
                },
                icon: const Icon(Icons.add),
                tooltip: 'Add Customer',
              ),
            ],
          ),
          if (widget.selectedCustomer != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFF3B82F6),
                    child: Text(
                      widget.selectedCustomer!.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.selectedCustomer!.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => widget.onSelectCustomer(null),
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: 'Remove Customer',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItems() {
    if (widget.cartItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 16),
            Text(
              'Cart is empty',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
              ),
            ),
            Text(
              'Add products to get started',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: widget.cartItems.length,
      itemBuilder: (context, index) {
        final item = widget.cartItems[index];
        return _buildCartItem(item);
      },
    );
  }

  Widget _buildCartItem(SaleItemModel item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product?.name ?? 'Unknown Product',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  '${ref.watch(currentCurrencyProvider).symbol}${(item.product?.price ?? 0).toStringAsFixed(2)} each',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Quantity Controls
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    widget.onUpdateQuantity(item, (item.qty - 1).toInt()),
                icon: const Icon(Icons.remove, size: 16),
                tooltip: 'Decrease Quantity',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${item.qty.toInt()}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    widget.onUpdateQuantity(item, (item.qty + 1).toInt()),
                icon: const Icon(Icons.add, size: 16),
                tooltip: 'Increase Quantity',
              ),
            ],
          ),

          // Remove Button
          IconButton(
            onPressed: () => widget.onRemoveFromCart(item),
            icon: const Icon(Icons.delete, size: 16, color: Color(0xFFEF4444)),
            tooltip: 'Remove Item',
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(Currency currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', currency.symbol, widget.subtotal),
          _buildSummaryRow('Tax', currency.symbol, widget.tax),
          _buildSummaryRow('Discount', '-${currency.symbol}', widget.discount),
          const Divider(),
          _buildSummaryRow('Total', currency.symbol, widget.total,
              isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String symbol, double amount,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color:
                  isTotal ? const Color(0xFF1E293B) : const Color(0xFF64748B),
            ),
          ),
          Text(
            '$symbol${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color:
                  isTotal ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Order Type Selection
          Row(
            children: [
              Expanded(
                child: _buildOrderTypeButton(
                    'dine_in', 'Dine In', Icons.restaurant),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildOrderTypeButton(
                    'take_away', 'Take Away', Icons.takeout_dining),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildOrderTypeButton(
                    'delivery', 'Delivery', Icons.delivery_dining),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Payment Type Selection
          Row(
            children: [
              Expanded(
                child: _buildPaymentTypeButton('cash', 'Cash', Icons.money),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _buildPaymentTypeButton('card', 'Card', Icons.credit_card),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Checkout Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: widget.cartItems.isNotEmpty ? widget.onCheckout : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Checkout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeButton(String type, String label, IconData icon) {
    final isSelected = widget.orderType == type;

    return OutlinedButton.icon(
      onPressed: () => widget.onOrderTypeChanged(type),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            isSelected ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
        side: BorderSide(
          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
        ),
        backgroundColor:
            isSelected ? const Color(0xFF3B82F6).withValues(alpha: 0.1) : null,
      ),
    );
  }

  Widget _buildPaymentTypeButton(String type, String label, IconData icon) {
    final isSelected = widget.paymentType == type;

    return OutlinedButton.icon(
      onPressed: () => widget.onPaymentTypeChanged(type),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            isSelected ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
        side: BorderSide(
          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
        ),
        backgroundColor:
            isSelected ? const Color(0xFF3B82F6).withValues(alpha: 0.1) : null,
      ),
    );
  }

  // Action methods
  void _showProductDetails(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Price: ${ref.watch(currentCurrencyProvider).symbol}${product.price}'),
            Text('Stock: ${product.stock}'),
            Text('Category: ${product.category}'),
            if (product.barcode != null) Text('Barcode: ${product.barcode}'),
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

  void _editProduct(ProductModel product) {
    // Navigate to edit product screen
  }

  void _adjustStock(ProductModel product) {
    // Show stock adjustment dialog
  }

  void _viewProductHistory(ProductModel product) {
    // Navigate to product history screen
  }

  void _duplicateProduct(ProductModel product) {
    // Duplicate product functionality
  }

  void _deleteProduct(ProductModel product) {
    // Delete product functionality
  }
}
