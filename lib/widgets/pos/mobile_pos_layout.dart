import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../providers/sale_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/customer_provider.dart';
import 'product_card_widget.dart';
import 'category_filter_widget.dart';
import 'cart_summary_widget.dart';
import 'customer_info_widget.dart';

/// Mobile-specific POS layout widget
/// Extracted from pos_screen.dart for better code organization
class MobilePosLayoutWidget extends ConsumerStatefulWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;
  final Function(ProductModel) onProductTap;
  final Function(ProductModel)? onProductLongPress;
  final List<CartItem> cart;
  final double discount;
  final String discountType;
  final bool isWholesaleMode;
  final String paymentType;
  final Map<String, double> itemPrices;
  final Map<String, double> itemDiscounts;
  final CustomerModel? selectedCustomer;

  const MobilePosLayoutWidget({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onProductTap,
    this.onProductLongPress,
    required this.cart,
    required this.discount,
    required this.discountType,
    required this.isWholesaleMode,
    required this.paymentType,
    required this.itemPrices,
    required this.itemDiscounts,
    this.selectedCustomer,
  });

  @override
  ConsumerState<MobilePosLayoutWidget> createState() => _MobilePosLayoutWidgetState();
}

class _MobilePosLayoutWidgetState extends ConsumerState<MobilePosLayoutWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productNotifierProvider);
    final customers = ref.watch(customersProvider);

    return Column(
      children: [
        // Category Filter
        CategoryFilterWidget(
          selectedCategory: widget.selectedCategory,
          onCategorySelected: widget.onCategorySelected,
          isMobile: true,
        ),
        const SizedBox(height: 8),
        // Tab Bar
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF3B82F6),
          tabs: const [
            Tab(
              icon: Icon(Icons.shopping_bag),
              text: 'Products',
            ),
            Tab(
              icon: Icon(Icons.shopping_cart),
              text: 'Cart',
            ),
          ],
        ),
        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Products Tab
              _buildProductsTab(products),
              // Cart Tab
              _buildCartTab(customers),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTab(AsyncValue<List<ProductModel>> products) {
    return products.when(
      data: (productList) {
        // Filter products by category
        final filteredProducts = widget.selectedCategory == 'all'
            ? productList
            : productList
                .where((p) => p.category.toLowerCase() ==
                    widget.selectedCategory.toLowerCase())
                .toList();

        if (filteredProducts.isEmpty) {
          return const Center(
            child: Text('No products found'),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemCount: filteredProducts.length,
          itemBuilder: (context, index) {
            final product = filteredProducts[index];
            return ProductCardWidget(
              product: product,
              onTap: () => widget.onProductTap(product),
              onLongPress: widget.onProductLongPress != null
                  ? () => widget.onProductLongPress!(product)
                  : null,
              isMobile: true,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading products: $error'),
      ),
    );
  }

  Widget _buildCartTab(AsyncValue<List<CustomerModel>> customers) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Info
          if (widget.selectedCustomer != null)
            CustomerInfoWidget(
              customer: widget.selectedCustomer,
              isCompact: true,
            ),
          const SizedBox(height: 16),
          // Cart Summary
          CartSummaryWidget(
            cart: widget.cart,
            discount: widget.discount,
            discountType: widget.discountType,
            isWholesaleMode: widget.isWholesaleMode,
            paymentType: widget.paymentType,
            itemPrices: widget.itemPrices,
            itemDiscounts: widget.itemDiscounts,
            isCompact: true,
          ),
          // TODO: Add cart items list here
          // This would require extracting the cart item widget
        ],
      ),
    );
  }
}






