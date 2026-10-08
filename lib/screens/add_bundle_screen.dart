import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/bundle_provider.dart';
import '../providers/product_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/category_provider.dart';
import '../models/product_bundle.dart';
import '../models/product.dart';
import '../utils/input_formatters.dart';
import '../utils/modern_dialog_builder.dart';
import '../widgets/app_snack_bar.dart';

class AddBundleScreen extends ConsumerStatefulWidget {
  final int? bundleId;

  const AddBundleScreen({super.key, this.bundleId});

  @override
  ConsumerState<AddBundleScreen> createState() => _AddBundleScreenState();
}

class _AddBundleScreenState extends ConsumerState<AddBundleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isLoading = false;
  ProductBundleModel? _existingBundle;
  String? _selectedCategory;
  List<ProductBundleItemModel> _bundleItems = [];
  List<ProductModel> _availableProducts = [];
  List<ProductModel> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    if (widget.bundleId != null) {
      _loadBundle();
    }
    _loadProducts();
  }

  Future<void> _loadBundle() async {
    final bundle = await ref.read(bundleByIdProvider(widget.bundleId!).future);
    if (bundle != null && mounted) {
      setState(() {
        _existingBundle = bundle;
        _nameController.text = bundle.name;
        _descriptionController.text = bundle.description ?? '';
        _priceController.text = bundle.price.toString();
        _categoryController.text = bundle.category ?? '';
        _selectedCategory = bundle.category;
        _bundleItems = List.from(bundle.items);
      });
    }
  }

  Future<void> _loadProducts() async {
    final products = await ref.read(productsProvider.future);
    if (mounted) {
      setState(() {
        _availableProducts = products;
        _filteredProducts = products;
      });
    }
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _availableProducts;
      } else {
        _filteredProducts = _availableProducts
            .where((product) =>
                product.name.toLowerCase().contains(query.toLowerCase()) ||
                (product.barcode?.toLowerCase().contains(query.toLowerCase()) ??
                    false))
            .toList();
      }
    });
  }

  void _addProductToBundle(ProductModel product) {
    final existingIndex = _bundleItems.indexWhere(
        (item) => item.product.id == product.id);
    
    if (existingIndex >= 0) {
      setState(() {
        _bundleItems[existingIndex] = ProductBundleItemModel(
          id: _bundleItems[existingIndex].id,
          bundleId: _bundleItems[existingIndex].bundleId,
          product: product,
          quantity: _bundleItems[existingIndex].quantity + 1,
          price: _bundleItems[existingIndex].price,
        );
      });
    } else {
      setState(() {
        _bundleItems.add(ProductBundleItemModel(
          bundleId: _existingBundle?.id ?? 0,
          product: product,
          quantity: 1,
        ));
      });
    }
    _updateBundlePrice();
    _searchController.clear();
    _filterProducts('');
  }

  void _removeProductFromBundle(int index) {
    setState(() {
      _bundleItems.removeAt(index);
    });
    _updateBundlePrice();
  }

  void _updateProductQuantity(int index, double quantity) {
    if (quantity <= 0) {
      _removeProductFromBundle(index);
      return;
    }
    setState(() {
      _bundleItems[index] = ProductBundleItemModel(
        id: _bundleItems[index].id,
        bundleId: _bundleItems[index].bundleId,
        product: _bundleItems[index].product,
        quantity: quantity,
        price: _bundleItems[index].price,
      );
    });
    _updateBundlePrice();
  }

  void _updateBundlePrice() {
    if (_bundleItems.isEmpty) return;
    
    // Calculate total cost
    final totalCost = _bundleItems.fold(0.0, (sum, item) {
      return sum + (item.product.cost * item.quantity);
    });

    // Calculate suggested price (with discount)
    final totalRegularPrice = _bundleItems.fold(0.0, (sum, item) {
      return sum + (item.effectivePrice * item.quantity);
    });

    // If price is not set or is 0, suggest a discounted price (10% off)
    if (_priceController.text.isEmpty || 
        double.tryParse(_priceController.text) == 0) {
      final suggestedPrice = totalRegularPrice * 0.9;
      setState(() {
        _priceController.text = suggestedPrice.toStringAsFixed(2);
      });
    }
  }

  Future<void> _saveBundle() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bundleItems.isEmpty) {
      AppSnackBar.show(
        context,
        const SnackBar(
          content: Text('Please add at least one product to the bundle'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final price = double.tryParse(_priceController.text) ?? 0;
      final totalCost = _bundleItems.fold(0.0, (sum, item) {
        return sum + (item.product.cost * item.quantity);
      });

      final bundle = ProductBundleModel(
        id: _existingBundle?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        price: price,
        cost: totalCost,
        category: _selectedCategory,
        isActive: true,
        createdAt: _existingBundle?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        items: _bundleItems,
      );

      final notifier = ref.read(bundleNotifierProvider.notifier);
      if (widget.bundleId != null) {
        await notifier.updateBundle(bundle);
      } else {
        await notifier.createBundle(bundle);
      }

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
                'Bundle ${widget.bundleId != null ? 'updated' : 'created'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error saving bundle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currentCurrencyProvider);
    final categoriesAsync = ref.watch(productCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bundleId != null ? 'Edit Bundle' : 'Create Bundle'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveBundle,
              child: Text('common.save'.tr()),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    Text(
                      'Basic Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Bundle Name *',
                        hintText: 'e.g., Family Combo, Starter Pack',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter bundle name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Bundle description (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    // Category
                    categoriesAsync.when(
                      data: (categories) => DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...categories.map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                            _categoryController.text = value ?? '';
                          });
                        },
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: 24),
                    // Bundle Price
                    Text(
                      'Pricing',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Bundle Price *',
                        prefixText: '${currency.symbol} ',
                        hintText: '0.00',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        DecimalInputFormatter(maxDecimalPlaces: 2),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter bundle price';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'Please enter a valid price';
                        }
                        return null;
                      },
                    ),
                    if (_bundleItems.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Regular Price: ${currency.symbol}${_bundleItems.fold(0.0, (sum, item) => sum + (item.effectivePrice * item.quantity)).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Discount: ${currency.symbol}${(_bundleItems.fold(0.0, (sum, item) => sum + (item.effectivePrice * item.quantity)) - (double.tryParse(_priceController.text) ?? 0)).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Add Products
                    Text(
                      'Bundle Items',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    // Product Search
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search Products',
                        hintText: 'Search by name or barcode',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterProducts('');
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: _filterProducts,
                    ),
                    const SizedBox(height: 16),
                    // Product List
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _filteredProducts.isEmpty
                          ? const Center(child: Text('No products found'))
                          : ListView.builder(
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                return ListTile(
                                  title: Text(product.name),
                                  subtitle: Text(
                                      '${currency.symbol}${product.price.toStringAsFixed(2)} | Stock: ${product.stock.toStringAsFixed(0)}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () => _addProductToBundle(product),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 24),
                    // Bundle Items List
                    if (_bundleItems.isNotEmpty) ...[
                      Text(
                        'Items in Bundle',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._bundleItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(item.product.name),
                            subtitle: Text(
                                '${currency.symbol}${item.effectivePrice.toStringAsFixed(2)} each'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () {
                                    if (item.quantity > 1) {
                                      _updateProductQuantity(
                                          index, item.quantity - 1);
                                    } else {
                                      _removeProductFromBundle(index);
                                    }
                                  },
                                ),
                                Text(
                                  item.quantity.toStringAsFixed(0),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () => _updateProductQuantity(
                                      index, item.quantity + 1),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _removeProductFromBundle(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

