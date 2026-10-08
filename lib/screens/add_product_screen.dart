import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../providers/product_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/category_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_settings_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/product_ingredient.dart';
import '../utils/input_formatters.dart';
import '../utils/mobile_optimization.dart';
import '../services/database_service.dart';
import '../widgets/app_snack_bar.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final int? productId;

  const AddProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _discountController = TextEditingController();
  final _taxController = TextEditingController();
  final _unitController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  final _reorderQuantityController = TextEditingController();
  final _retailCreditController = TextEditingController();
  final _marketPriceController = TextEditingController();
  final _maxLevelController = TextEditingController();
  final _packingModeController = TextEditingController();
  final _wholesaleCashController = TextEditingController();
  final _wholesaleCreditController = TextEditingController();

  // Mobile Shop specific controllers
  final _brandController = TextEditingController();
  final _modelNameController = TextEditingController();
  final _storageCapacityController = TextEditingController();
  final _ramController = TextEditingController();
  final _colorController = TextEditingController();
  final _conditionController = TextEditingController();
  final _unlockStatusController = TextEditingController();
  final _warrantyStatusController = TextEditingController();
  final _warrantyPeriodController = TextEditingController();
  final _warrantyProviderController = TextEditingController();
  final _displaySizeController = TextEditingController();
  final _batteryCapacityController = TextEditingController();
  final _cameraSpecsController = TextEditingController();
  final _operatingSystemController = TextEditingController();
  final _networkTypeController = TextEditingController();
  final _simCardTypeController = TextEditingController();
  final _tradeInValueController = TextEditingController();
  final _boxContentsController = TextEditingController();

  // Restaurant specific controllers
  final _courseTypeController = TextEditingController();
  final _preparationTimeController = TextEditingController();
  final _allergensController = TextEditingController();
  final _modifiersController = TextEditingController();
  final _dietaryInfoController = TextEditingController();

  // FocusNodes for Enter key navigation (Windows-style)
  final _nameFocusNode = FocusNode();
  final _categoryFocusNode = FocusNode();
  final _barcodeFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _costFocusNode = FocusNode();
  final _discountFocusNode = FocusNode();
  final _taxFocusNode = FocusNode();
  final _stockFocusNode = FocusNode();
  final _unitFocusNode = FocusNode();
  final _reorderLevelFocusNode = FocusNode();
  final _reorderQuantityFocusNode = FocusNode();
  final _packingModeFocusNode = FocusNode();
  final _retailCreditFocusNode = FocusNode();
  final _marketPriceFocusNode = FocusNode();
  final _maxLevelFocusNode = FocusNode();
  final _wholesaleCashFocusNode = FocusNode();
  final _wholesaleCreditFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  // Mobile Shop specific focus nodes
  final _brandFocusNode = FocusNode();
  final _modelNameFocusNode = FocusNode();
  final _storageCapacityFocusNode = FocusNode();
  final _ramFocusNode = FocusNode();
  final _colorFocusNode = FocusNode();
  final _conditionFocusNode = FocusNode();
  final _unlockStatusFocusNode = FocusNode();
  final _warrantyStatusFocusNode = FocusNode();
  final _warrantyPeriodFocusNode = FocusNode();
  final _warrantyProviderFocusNode = FocusNode();
  final _displaySizeFocusNode = FocusNode();
  final _batteryCapacityFocusNode = FocusNode();
  final _cameraSpecsFocusNode = FocusNode();
  final _operatingSystemFocusNode = FocusNode();
  final _networkTypeFocusNode = FocusNode();
  final _simCardTypeFocusNode = FocusNode();
  final _tradeInValueFocusNode = FocusNode();
  final _boxContentsFocusNode = FocusNode();

  // Restaurant specific focus nodes
  final _courseTypeFocusNode = FocusNode();
  final _preparationTimeFocusNode = FocusNode();
  final _allergensFocusNode = FocusNode();
  final _modifiersFocusNode = FocusNode();
  final _dietaryInfoFocusNode = FocusNode();

  bool _isLoading = false;
  ProductModel? _existingProduct;
  String? _selectedCategory;
  bool _showNewCategoryField = false;
  String _productType = 'product'; // 'product' or 'service'
  bool _isEditingEnabled =
      false; // Controls whether fields are editable when editing a product

  // Ingredients management (for restaurant)
  List<ProductIngredientModel> _ingredients = [];
  List<ProductModel> _allProducts = []; // For ingredient selection

  // Common units
  final List<String> _units = [
    'pcs',
    'kg',
    'g',
    'liter',
    'ml',
    'box',
    'pack',
    'dozen',
    'pair',
  ];

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    // No dummy/default data - fields start empty for clean user input
    // Defaults will be set conditionally based on business nature after first build

    if (widget.productId != null) {
      // Use WidgetsBinding to ensure the widget is fully built before loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadProduct();
      });
    } else {
      // For new products, set minimal defaults
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Unit is always required by database
          if (_unitController.text.isEmpty) {
            _unitController.text = 'pcs';
          }
          if (_discountController.text.isEmpty) {
            _discountController.text = '0';
          }
          if (_taxController.text.isEmpty) {
            _taxController.text = '0';
          }
          if (_stockController.text.isEmpty) {
            _stockController.text = '0';
          }
          if (_reorderLevelController.text.isEmpty) {
            _reorderLevelController.text = '10';
          }
          if (_reorderQuantityController.text.isEmpty) {
            _reorderQuantityController.text = '50';
          }
        }
      });
    }
  }

  Future<void> _loadProduct() async {
    // Invalidate the provider first to clear any cached data
    ref.invalidate(productByIdProvider(widget.productId!));

    // Now fetch fresh product data from the database
    final product =
        await ref.read(productByIdProvider(widget.productId!).future);
    if (product != null) {
      if (mounted) {
        setState(() {
          _existingProduct = product;
          _nameController.text = product.name;
          _selectedCategory = product.category;
          _categoryController.text = product.category;
          _productType = product.productType ?? 'product';
          _priceController.text = product.price.toString();
          _costController.text = product.cost.toString();
          _stockController.text = product.stock.toString();
          _barcodeController.text = product.barcode ?? '';
          _discountController.text = product.discount.toString();
          _taxController.text = product.tax.toString();
          _unitController.text = product.unit;
          _descriptionController.text = product.description ?? '';
          _reorderLevelController.text = product.reorderLevel.toString();
          _reorderQuantityController.text = product.reorderQuantity.toString();
          _retailCreditController.text = product.retailCredit?.toString() ?? '';
          _marketPriceController.text = product.marketPrice?.toString() ?? '';
          _maxLevelController.text = product.maxLevel?.toString() ?? '';
          _packingModeController.text = product.packingMode ?? '';
          _wholesaleCashController.text =
              product.wholesaleCash?.toString() ?? '';
          _wholesaleCreditController.text =
              product.wholesaleCredit?.toString() ?? '';
          // Load mobile shop fields
          _brandController.text = product.brand ?? '';
          _modelNameController.text = product.modelName ?? '';
          _storageCapacityController.text = product.storageCapacity ?? '';
          _ramController.text = product.ram ?? '';
          _colorController.text = product.color ?? '';
          _conditionController.text = product.condition ?? '';
          _unlockStatusController.text = product.unlockStatus ?? '';
          _warrantyStatusController.text = product.warrantyStatus ?? '';
          _warrantyPeriodController.text = product.warrantyPeriod ?? '';
          _warrantyProviderController.text = product.warrantyProvider ?? '';
          _displaySizeController.text = product.displaySize ?? '';
          _batteryCapacityController.text = product.batteryCapacity ?? '';
          _cameraSpecsController.text = product.cameraSpecs ?? '';
          _operatingSystemController.text = product.operatingSystem ?? '';
          _networkTypeController.text = product.networkType ?? '';
          _simCardTypeController.text = product.simCardType ?? '';
          _tradeInValueController.text = product.tradeInValue?.toString() ?? '';
          _boxContentsController.text = product.boxContents ?? '';
          // Load restaurant fields
          _courseTypeController.text = product.courseType ?? '';
          _preparationTimeController.text =
              product.preparationTime?.toString() ?? '';
          _allergensController.text = product.allergens ?? '';
          _modifiersController.text = product.modifiers ?? '';
          _dietaryInfoController.text = product.dietaryInfo ?? '';
          _isEditingEnabled =
              false; // Always start in read-only mode when editing
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    _reorderLevelController.dispose();
    _reorderQuantityController.dispose();
    _retailCreditController.dispose();
    _marketPriceController.dispose();
    _maxLevelController.dispose();
    _packingModeController.dispose();
    _wholesaleCashController.dispose();
    _wholesaleCreditController.dispose();
    // Dispose mobile shop controllers
    _brandController.dispose();
    _modelNameController.dispose();
    _storageCapacityController.dispose();
    _ramController.dispose();
    _colorController.dispose();
    _conditionController.dispose();
    _unlockStatusController.dispose();
    _warrantyStatusController.dispose();
    _warrantyPeriodController.dispose();
    _warrantyProviderController.dispose();
    _displaySizeController.dispose();
    _batteryCapacityController.dispose();
    _cameraSpecsController.dispose();
    _operatingSystemController.dispose();
    _networkTypeController.dispose();
    _simCardTypeController.dispose();
    _tradeInValueController.dispose();
    _boxContentsController.dispose();
    // Dispose restaurant controllers
    _courseTypeController.dispose();
    _preparationTimeController.dispose();
    _allergensController.dispose();
    _modifiersController.dispose();
    _dietaryInfoController.dispose();

    // Dispose FocusNodes
    _nameFocusNode.dispose();
    _categoryFocusNode.dispose();
    _barcodeFocusNode.dispose();
    _priceFocusNode.dispose();
    _costFocusNode.dispose();
    _discountFocusNode.dispose();
    _taxFocusNode.dispose();
    _stockFocusNode.dispose();
    _unitFocusNode.dispose();
    _reorderLevelFocusNode.dispose();
    _reorderQuantityFocusNode.dispose();
    _packingModeFocusNode.dispose();
    _retailCreditFocusNode.dispose();
    _marketPriceFocusNode.dispose();
    _maxLevelFocusNode.dispose();
    _wholesaleCashFocusNode.dispose();
    _wholesaleCreditFocusNode.dispose();
    _descriptionFocusNode.dispose();
    // Dispose mobile shop focus nodes
    _brandFocusNode.dispose();
    _modelNameFocusNode.dispose();
    _storageCapacityFocusNode.dispose();
    _ramFocusNode.dispose();
    _colorFocusNode.dispose();
    _conditionFocusNode.dispose();
    _unlockStatusFocusNode.dispose();
    _warrantyStatusFocusNode.dispose();
    _warrantyPeriodFocusNode.dispose();
    _warrantyProviderFocusNode.dispose();
    _displaySizeFocusNode.dispose();
    _batteryCapacityFocusNode.dispose();
    _cameraSpecsFocusNode.dispose();
    _operatingSystemFocusNode.dispose();
    _networkTypeFocusNode.dispose();
    _simCardTypeFocusNode.dispose();
    _tradeInValueFocusNode.dispose();
    _boxContentsFocusNode.dispose();
    // Dispose restaurant focus nodes
    _courseTypeFocusNode.dispose();
    _preparationTimeFocusNode.dispose();
    _allergensFocusNode.dispose();
    _modifiersFocusNode.dispose();
    _dietaryInfoFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;

    // Watch product changes to update stock in real-time when editing
    if (widget.productId != null) {
      // Listen for product stock changes and update the stock controller
      ref.listen(productByIdProvider(widget.productId!), (previous, next) {
        if (next.hasValue && next.value != null && mounted) {
          final previousStock = previous?.value?.stock;
          final currentStock = next.value!.stock;

          // Only update if stock actually changed (with small tolerance for floating point)
          if (previousStock == null ||
              (currentStock - previousStock).abs() > 0.001) {
            final newStockStr = currentStock.toString();
            // Only update if the displayed value is different
            if (_stockController.text != newStockStr) {
              setState(() {
                _stockController.text = newStockStr;
                // Also update the existing product reference
                _existingProduct = next.value;
              });
            }
          }
        }
      });
    }

    // Check permission if editing (not adding new)
    if (widget.productId != null &&
        currentUser != null &&
        !currentUser.canManageProducts()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text(
                  'You do not have permission to edit products. Only administrators or managers with permission can edit products.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          context.go('/products');
        }
      });
      return Scaffold(
        appBar: AppBar(
          title: Text('common.access_denied'.tr()),
        ),
        body: const Center(
          child: Text('You do not have permission to edit products.'),
        ),
      );
    }

    final isDarkMode = ref.watch(isDarkModeProvider);
    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (mounted) {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/products');
              }
            }
          },
        ),
        title: Text(
          widget.productId == null ? 'Add New Product' : 'Edit Product',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (widget.productId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _showDeleteDialog,
              tooltip: 'Delete Product',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : MobileOptimization.keyboardAwareForm(
              child: Padding(
                padding: EdgeInsets.all(
                  MobileOptimization.isMobile(context) ? 12 : 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.productId != null)
                        _buildEnableEditingCheckbox(),
                      if (widget.productId != null)
                        SizedBox(
                            height: MobileOptimization.getFormFieldSpacing(
                                context)),
                      _buildBasicInfoSection(categoriesAsync),
                      SizedBox(
                          height:
                              MobileOptimization.getFormFieldSpacing(context)),
                      _buildInventorySection(),
                      SizedBox(
                          height:
                              MobileOptimization.getFormFieldSpacing(context)),
                      _buildAdditionalInfoSection(),
                      SizedBox(
                          height:
                              MobileOptimization.getFormFieldSpacing(context)),
                      _buildMobileShopSection(),
                      SizedBox(
                          height:
                              MobileOptimization.getFormFieldSpacing(context)),
                      _buildRestaurantSection(),
                      SizedBox(
                          height:
                              MobileOptimization.getFormFieldSpacing(context)),
                      _buildIngredientsSection(),
                      if (widget.productId != null) ...[
                        SizedBox(
                            height: MobileOptimization.getFormFieldSpacing(
                                    context) *
                                0.75),
                        Row(
                          children: [
                            Expanded(child: _buildLedgerButton()),
                            SizedBox(
                                width: MobileOptimization.isMobile(context)
                                    ? 8
                                    : 12),
                            Expanded(child: _buildPurchaseRateHistoryButton()),
                          ],
                        ),
                      ],
                      SizedBox(
                          height:
                              MobileOptimization.isMobile(context) ? 32 : 24),
                      _buildActionButtons(),
                      SizedBox(
                          height:
                              MobileOptimization.isMobile(context) ? 24 : 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  bool get _isReadOnly => widget.productId != null && !_isEditingEnabled;

  InputDecoration _getInputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
  }) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: _isReadOnly
              ? (isDarkMode ? const Color(0xFF374151) : Colors.grey.shade300)
              : (isDarkMode ? const Color(0xFF374151) : Colors.grey.shade400),
          width: _isReadOnly ? 1.0 : 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: _isReadOnly
              ? (isDarkMode ? const Color(0xFF374151) : Colors.grey.shade300)
              : (isDarkMode ? const Color(0xFF374151) : Colors.grey.shade400),
          width: _isReadOnly ? 1.0 : 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: _isReadOnly
              ? (isDarkMode ? const Color(0xFF374151) : Colors.grey.shade300)
              : Theme.of(context).primaryColor,
          width: _isReadOnly ? 1.0 : 2.0,
        ),
      ),
      filled: true,
      fillColor: _isReadOnly
          ? (isDarkMode ? const Color(0xFF2A2F36) : Colors.grey.shade50)
          : (isDarkMode ? AppColors.surfaceDark : Colors.white),
    );
  }

  Widget _buildEnableEditingCheckbox() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color:
          _isEditingEnabled ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _isEditingEnabled ? Icons.edit : Icons.lock_outline,
              color: _isEditingEnabled
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF757575),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditingEnabled
                        ? 'Editing Mode Enabled'
                        : 'Read-Only Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isEditingEnabled
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF424242),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isEditingEnabled
                        ? 'All fields are now editable'
                        : 'Enable editing to modify product details',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isEditingEnabled
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isEditingEnabled,
              onChanged: widget.productId == null ? null : _handleEditingToggle,
              activeColor: const Color(0xFF4CAF50),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection(
      AsyncValue<List<CategoryModel>> categoriesAsync) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Basic Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              readOnly: _isReadOnly,
              decoration: _getInputDecoration(
                labelText: 'Product Name *',
                hintText: 'Enter product name',
                prefixIcon: Icons.shopping_bag_outlined,
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _categoryFocusNode.requestFocus(),
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              data: (categories) {
                final categoryNames = categories
                    .map((c) => c.name)
                    .toSet()
                    .toList(); // Use Set to remove duplicates

                // Ensure selected category is in the list, otherwise set to null
                if (_selectedCategory != null &&
                    !categoryNames.contains(_selectedCategory)) {
                  _selectedCategory = null;
                }

                return Column(
                  children: [
                    if (!_showNewCategoryField)
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        onChanged: _isReadOnly
                            ? null
                            : (value) {
                                if (value == '__new__') {
                                  setState(() {
                                    _showNewCategoryField = true;
                                    _categoryController.clear();
                                  });
                                } else {
                                  setState(() {
                                    _selectedCategory = value;
                                  });
                                }
                              },
                        decoration: _getInputDecoration(
                          labelText: 'Category *',
                          hintText: 'Select a category',
                          prefixIcon: Icons.category_outlined,
                        ),
                        items: [
                          ...categoryNames.map((cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              )),
                          const DropdownMenuItem(
                            value: '__new__',
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline,
                                    size: 20, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Add New Category',
                                    style: TextStyle(color: Colors.green)),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _categoryController,
                              focusNode: _categoryFocusNode,
                              readOnly: _isReadOnly,
                              decoration: _getInputDecoration(
                                labelText: 'New Category *',
                                hintText: 'Enter new category name',
                                prefixIcon: Icons.category_outlined,
                              ),
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  _barcodeFocusNode.requestFocus(),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Category is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              if (mounted) {
                                setState(() {
                                  _showNewCategoryField = false;
                                  _categoryController.text =
                                      _selectedCategory ?? '';
                                });
                              }
                            },
                            tooltip: 'Cancel new category',
                          ),
                        ],
                      ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => TextFormField(
                controller: _categoryController,
                focusNode: _categoryFocusNode,
                readOnly: _isReadOnly,
                decoration: _getInputDecoration(
                  labelText: 'Category *',
                  hintText: 'Enter category',
                  prefixIcon: Icons.category_outlined,
                ),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _barcodeFocusNode.requestFocus(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Category is required';
                  }
                  return null;
                },
              ),
            ),
            // Product Type selector for salon business
            if (false) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.category,
                      color: ref.watch(isDarkModeProvider)
                          ? const Color(0xFF64748B)
                          : Colors.grey),
                  const SizedBox(width: 12),
                  const Text(
                    'Product Type: ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'product',
                        groupValue: _productType,
                        onChanged: _isReadOnly
                            ? null
                            : (value) {
                                setState(() {
                                  _productType = value!;
                                  // Reset stock fields to defaults when switching to product
                                  if (value == 'product') {
                                    if (_stockController.text.isEmpty ||
                                        _stockController.text == '0') {
                                      _stockController.text = '0';
                                    }
                                    if (_reorderLevelController.text.isEmpty ||
                                        _reorderLevelController.text == '0') {
                                      _reorderLevelController.text = '10';
                                    }
                                    if (_reorderQuantityController
                                            .text.isEmpty ||
                                        _reorderQuantityController.text ==
                                            '0') {
                                      _reorderQuantityController.text = '50';
                                    }
                                  }
                                });
                              },
                      ),
                      Text('add_product_scr.type_product'.tr()),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: 'service',
                        groupValue: _productType,
                        onChanged: _isReadOnly
                            ? null
                            : (value) {
                                setState(() {
                                  _productType = value!;
                                  // Clear stock for services (services don't have inventory)
                                  if (value == 'service') {
                                    _stockController.text = '0';
                                    _reorderLevelController.text = '0';
                                    _reorderQuantityController.text = '0';
                                  }
                                });
                              },
                      ),
                      Text('add_product_scr.type_service'.tr()),
                    ],
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              readOnly: _isReadOnly,
              decoration: _getInputDecoration(
                labelText: 'Barcode (Optional)',
                hintText: 'Scan or enter barcode',
                prefixIcon: Icons.qr_code_scanner,
              ).copyWith(
                suffixIcon: _isReadOnly
                    ? null
                    : MobileOptimization.mobileIconButton(
                        icon: Icons.camera_alt,
                        onPressed: _scanBarcode,
                        tooltip: 'Scan Barcode',
                      ),
              ),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _priceFocusNode.requestFocus(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Inventory',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Show stock field only for products (not services in salon)
                if (!(false && _productType == 'service'))
                  Expanded(
                    flex: 2,
                    child: Builder(
                      builder: (context) {
                        final businessNature = 'retail';
                        final isRetail = businessNature == 'retail';
                        final allowOpeningStock = ref
                            .watch(inventorySettingsProvider)
                            .allowOpeningStockOnProductCreate;
                        final isCreatingProduct = widget.productId == null;
                        final canEnterOpeningStock = isRetail &&
                            isCreatingProduct &&
                            allowOpeningStock &&
                            !_isReadOnly;
                        // Existing stock is never directly edited here; all
                        // later changes retain an auditable stock movement.
                        final isReadOnlyStock =
                            isRetail && (!canEnterOpeningStock || _isReadOnly);

                        return TextFormField(
                          controller: _stockController,
                          focusNode: _stockFocusNode,
                          readOnly: isReadOnlyStock,
                          enabled: !isReadOnlyStock && !_isReadOnly,
                          decoration: _getInputDecoration(
                            labelText: 'Current Stock *',
                            hintText: '0',
                            prefixIcon: Icons.inventory,
                          ).copyWith(
                            helperText: isRetail
                                ? widget.productId != null
                                    ? 'Current stock is read-only. Use Purchase Invoice or Stock Movement to change it.'
                                    : allowOpeningStock
                                        ? 'Enter opening stock. An Opening Stock ledger entry will be created.'
                                        : 'Opening stock is disabled in Settings. Receive stock through a Purchase Invoice.'
                                : 'Enter the current stock quantity for this product.',
                            helperStyle: TextStyle(
                              fontSize: 11,
                              color: isDarkMode
                                  ? const Color(0xFF94A3B8)
                                  : Colors.grey.shade600,
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _reorderLevelFocusNode.requestFocus(),
                          inputFormatters: [
                            DecimalInputFormatter(maxDecimalPlaces: 2),
                          ],
                        );
                      },
                    ),
                  ),
                if (!(false && _productType == 'service'))
                  const SizedBox(width: 12),
                // Unit field - always visible (services might use "session", "hour", etc.)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _unitController.text.isNotEmpty
                        ? _unitController.text
                        : 'pcs',
                    onChanged: _isReadOnly
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _unitController.text = value;
                              });
                            }
                          },
                    decoration: _getInputDecoration(
                      labelText: false && _productType == 'service'
                          ? 'Unit (e.g., session, hour)'
                          : 'Unit *',
                      prefixIcon: Icons.straighten,
                    ),
                    items: _units
                        .map((unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ))
                        .toList(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            // Show info message for services (no stock management needed)
            if (false && _productType == 'service') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Services do not require stock management. Stock will be automatically set to 0.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Hide reorder fields for services in salon business
            if (!(false && _productType == 'service')) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _reorderLevelController,
                      focusNode: _reorderLevelFocusNode,
                      readOnly: _isReadOnly,
                      decoration: _getInputDecoration(
                        labelText: 'Reorder Level',
                        hintText: '10',
                        prefixIcon: Icons.warning_amber,
                      ).copyWith(
                        helperText: 'Alert when stock is low',
                        helperStyle: TextStyle(
                            fontSize: 11,
                            color: isDarkMode
                                ? const Color(0xFF94A3B8)
                                : Colors.grey.shade600),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          _reorderQuantityFocusNode.requestFocus(),
                      inputFormatters: [
                        DecimalInputFormatter(maxDecimalPlaces: 2),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _reorderQuantityController,
                      focusNode: _reorderQuantityFocusNode,
                      readOnly: _isReadOnly,
                      decoration: _getInputDecoration(
                        labelText: 'Reorder Qty',
                        hintText: '50',
                        prefixIcon: Icons.add_shopping_cart,
                      ).copyWith(
                        helperText: 'Quantity to reorder',
                        helperStyle: TextStyle(
                            fontSize: 11,
                            color: isDarkMode
                                ? const Color(0xFF94A3B8)
                                : Colors.grey.shade600),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _priceFocusNode.requestFocus(),
                      inputFormatters: [
                        DecimalInputFormatter(maxDecimalPlaces: 2),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleEditingToggle(bool value) {
    setState(() {
      _isEditingEnabled = value;
    });
    if (!value) {
      FocusScope.of(context).unfocus();
    } else {
      // Provide quick focus feedback by highlighting name field when enabling edit mode
      Future.microtask(() {
        if (mounted && !_isReadOnly) {
          _nameFocusNode.requestFocus();
        }
      });
    }
  }

  Widget _buildAdditionalInfoSection() {
    final currency = ref.watch(currentCurrencyProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Additional Pricing
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.store,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Additional Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.price_change,
                      color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Product Pricing',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 640;
                final fieldWidth = isWide
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;

                Widget buildPriceField({
                  required TextEditingController controller,
                  required FocusNode focusNode,
                  required String label,
                  required IconData icon,
                  required Color fillColor,
                  bool requiredField = false,
                  FocusNode? nextFocus,
                }) {
                  return SizedBox(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: _isReadOnly,
                      decoration: _getInputDecoration(
                        labelText:
                            '$label (${currency.symbol})${requiredField ? ' *' : ''}',
                        prefixIcon: icon,
                      ).copyWith(
                        prefixText: '${currency.symbol} ',
                        fillColor: _isReadOnly
                            ? (isDarkMode
                                ? const Color(0xFF2A2F36)
                                : Colors.grey.shade50)
                            : fillColor,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: nextFocus != null
                          ? TextInputAction.next
                          : TextInputAction.done,
                      inputFormatters: [
                        DecimalInputFormatter(maxDecimalPlaces: 2),
                      ],
                      validator: (value) {
                        if (!requiredField &&
                            (value == null || value.isEmpty)) {
                          return null;
                        }
                        if ((value == null || value.isEmpty) && requiredField) {
                          return 'Required';
                        }
                        final number = double.tryParse(value!);
                        if (number == null || number < 0) {
                          return 'Must be 0 or greater';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (nextFocus != null) {
                          nextFocus.requestFocus();
                        } else {
                          focusNode.unfocus();
                        }
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  );
                }

                final businessNature = 'retail';
                final isSalon = businessNature == 'salon';

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    buildPriceField(
                      controller: _priceController,
                      focusNode: _priceFocusNode,
                      label: isSalon ? 'Price' : 'Retail Cash',
                      icon: Icons.shopping_cart,
                      fillColor: Colors.yellow.shade50,
                      requiredField: true,
                      nextFocus: _costFocusNode,
                    ),
                    buildPriceField(
                      controller: _costController,
                      focusNode: _costFocusNode,
                      label: 'Cost Price',
                      icon: Icons.money_off,
                      fillColor: Colors.orange.shade50,
                      requiredField: true,
                      nextFocus: isSalon ? null : _retailCreditFocusNode,
                    ),
                    // Hide retail credit, wholesale, and market price for salon
                    if (!isSalon) ...[
                      buildPriceField(
                        controller: _retailCreditController,
                        focusNode: _retailCreditFocusNode,
                        label: 'Retail Credit',
                        icon: Icons.credit_card,
                        fillColor: Colors.green.shade50,
                        nextFocus: _wholesaleCashFocusNode,
                      ),
                      buildPriceField(
                        controller: _wholesaleCashController,
                        focusNode: _wholesaleCashFocusNode,
                        label: 'Wholesale Cash',
                        icon: Icons.store,
                        fillColor: Colors.yellow.shade50,
                        nextFocus: _wholesaleCreditFocusNode,
                      ),
                      buildPriceField(
                        controller: _wholesaleCreditController,
                        focusNode: _wholesaleCreditFocusNode,
                        label: 'Wholesale Credit',
                        icon: Icons.business,
                        fillColor: Colors.green.shade50,
                        nextFocus: _marketPriceFocusNode,
                      ),
                      buildPriceField(
                        controller: _marketPriceController,
                        focusNode: _marketPriceFocusNode,
                        label: 'Market Price',
                        icon: Icons.trending_up,
                        fillColor: Colors.yellow.shade50,
                        nextFocus: _packingModeFocusNode,
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: _priceController,
              builder: (context, _, __) {
                return ValueListenableBuilder(
                  valueListenable: _costController,
                  builder: (context, _, __) {
                    final price = double.tryParse(_priceController.text) ?? 0;
                    final cost = double.tryParse(_costController.text) ?? 0;
                    final profit = price - cost;
                    final profitMargin = cost > 0 ? ((profit / cost) * 100) : 0;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: profit >= 0
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: profit >= 0
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profit',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                '${currency.symbol} ${profit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: profit >= 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Margin',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                '${profitMargin.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: profit >= 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _packingModeController,
              focusNode: _packingModeFocusNode,
              readOnly: _isReadOnly,
              decoration: _getInputDecoration(
                labelText: 'Packing Mode',
                hintText: 'e.g., tin, box, bottle',
                prefixIcon: Icons.inventory_2,
              ),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _descriptionFocusNode.requestFocus(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileShopSection() {
    final businessNature = 'retail';

    // Only show mobile shop section if business nature is mobile_shop
    if (businessNature != 'mobile_shop') {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.phone_android,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mobile Phone Specifications',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Info box for accessories
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note: This section is for phones only. For accessories (cases, chargers, cables, etc.), use accessory categories and they will be sold without IMEI requirement.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Brand and Model
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brandController,
                    focusNode: _brandFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Brand',
                      hintText: 'e.g., Samsung, Apple, Xiaomi',
                      prefixIcon: Icons.branding_watermark,
                    ),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _modelNameFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _modelNameController,
                    focusNode: _modelNameFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Model Name',
                      hintText: 'e.g., iPhone 14 Pro, Galaxy S23',
                      prefixIcon: Icons.phone_android,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _storageCapacityFocusNode.requestFocus(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Storage, RAM, Color
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _storageCapacityController,
                    focusNode: _storageCapacityFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Storage',
                      hintText: 'e.g., 128GB, 256GB',
                      prefixIcon: Icons.storage,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _ramFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _ramController,
                    focusNode: _ramFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'RAM',
                      hintText: 'e.g., 8GB, 12GB',
                      prefixIcon: Icons.memory,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _colorFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _colorController,
                    focusNode: _colorFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Color',
                      hintText: 'e.g., Space Gray, Midnight',
                      prefixIcon: Icons.palette,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _conditionFocusNode.requestFocus(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Condition and Unlock Status
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _conditionController.text.isEmpty
                        ? null
                        : _conditionController.text,
                    onChanged: _isReadOnly
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _conditionController.text = value;
                              });
                            }
                          },
                    decoration: _getInputDecoration(
                      labelText: 'Condition',
                      prefixIcon: Icons.verified,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'new', child: Text('New')),
                      DropdownMenuItem(
                          value: 'refurbished', child: Text('Refurbished')),
                      DropdownMenuItem(value: 'used', child: Text('Used')),
                      DropdownMenuItem(
                          value: 'open_box', child: Text('Open Box')),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unlockStatusController,
                    focusNode: _unlockStatusFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Unlock Status',
                      hintText: 'e.g., Unlocked, Locked to Carrier',
                      prefixIcon: Icons.lock_outline,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _warrantyStatusFocusNode.requestFocus(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Warranty Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user,
                      color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Warranty Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _warrantyStatusController,
                    focusNode: _warrantyStatusFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Warranty Status',
                      hintText: 'e.g., Under Warranty',
                      prefixIcon: Icons.shield,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _warrantyPeriodFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _warrantyPeriodController,
                    focusNode: _warrantyPeriodFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Warranty Period',
                      hintText: 'e.g., 12 months',
                      prefixIcon: Icons.calendar_today,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _warrantyProviderFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _warrantyProviderController,
                    focusNode: _warrantyProviderFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Warranty Provider',
                      hintText: 'e.g., Manufacturer, Store',
                      prefixIcon: Icons.business,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _displaySizeFocusNode.requestFocus(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Technical Specifications
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.settings, color: Colors.purple.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Technical Specifications',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _displaySizeController,
                    focusNode: _displaySizeFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Display Size',
                      hintText: 'e.g., 6.1", 6.7"',
                      prefixIcon: Icons.smartphone,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _batteryCapacityFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _batteryCapacityController,
                    focusNode: _batteryCapacityFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Battery Capacity',
                      hintText: 'e.g., 4000 mAh',
                      prefixIcon: Icons.battery_charging_full,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _cameraSpecsFocusNode.requestFocus(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cameraSpecsController,
                    focusNode: _cameraSpecsFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Camera Specs',
                      hintText: 'e.g., 48MP + 12MP + 12MP',
                      prefixIcon: Icons.camera_alt,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _operatingSystemFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _operatingSystemController,
                    focusNode: _operatingSystemFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Operating System',
                      hintText: 'e.g., iOS 17, Android 14',
                      prefixIcon: Icons.phone_android,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _networkTypeFocusNode.requestFocus(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _networkTypeController,
                    focusNode: _networkTypeFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Network Type',
                      hintText: 'e.g., 4G, 5G, Dual SIM',
                      prefixIcon: Icons.signal_cellular_alt,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _simCardTypeFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _simCardTypeController,
                    focusNode: _simCardTypeFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'SIM Card Type',
                      hintText: 'e.g., Nano SIM, eSIM',
                      prefixIcon: Icons.sim_card,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _tradeInValueFocusNode.requestFocus(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Trade-in Value and Box Contents
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tradeInValueController,
                    focusNode: _tradeInValueFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Trade-in Value',
                      hintText: 'For used phones',
                      prefixIcon: Icons.swap_horiz,
                    ).copyWith(
                      prefixText:
                          '${ref.watch(currentCurrencyProvider).symbol} ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      DecimalInputFormatter(maxDecimalPlaces: 2),
                    ],
                    onFieldSubmitted: (_) =>
                        _boxContentsFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _boxContentsController,
                    focusNode: _boxContentsFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Box Contents',
                      hintText: 'e.g., Charger, Cable, Case',
                      prefixIcon: Icons.inventory_2,
                    ),
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantSection() {
    final businessNature = 'retail';

    // Only show restaurant section if business nature is restaurant
    if (businessNature != 'restaurant') {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Restaurant Menu Item Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Course Type
            DropdownButtonFormField<String>(
              value: _courseTypeController.text.isEmpty
                  ? null
                  : _courseTypeController.text,
              onChanged: _isReadOnly
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _courseTypeController.text = value;
                        });
                      }
                    },
              decoration: _getInputDecoration(
                labelText: 'Course Type',
                prefixIcon: Icons.restaurant_menu,
              ),
              items: const [
                DropdownMenuItem(value: 'appetizer', child: Text('Appetizer')),
                DropdownMenuItem(
                    value: 'main_course', child: Text('Main Course')),
                DropdownMenuItem(value: 'dessert', child: Text('Dessert')),
                DropdownMenuItem(value: 'beverage', child: Text('Beverage')),
                DropdownMenuItem(value: 'combo', child: Text('Combo Meal')),
              ],
            ),
            const SizedBox(height: 16),
            // Preparation Time and Dietary Info
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _preparationTimeController,
                    focusNode: _preparationTimeFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Preparation Time (minutes)',
                      hintText: 'e.g., 15, 30',
                      prefixIcon: Icons.timer,
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _dietaryInfoFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _dietaryInfoController,
                    focusNode: _dietaryInfoFocusNode,
                    readOnly: _isReadOnly,
                    decoration: _getInputDecoration(
                      labelText: 'Dietary Info',
                      hintText: 'e.g., vegetarian, vegan, halal',
                      prefixIcon: Icons.eco,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _allergensFocusNode.requestFocus(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Allergens
            TextFormField(
              controller: _allergensController,
              focusNode: _allergensFocusNode,
              readOnly: _isReadOnly,
              decoration: _getInputDecoration(
                labelText: 'Allergens',
                hintText: 'e.g., nuts, dairy, gluten (comma-separated)',
                prefixIcon: Icons.warning,
              ),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _modifiersFocusNode.requestFocus(),
            ),
            const SizedBox(height: 16),
            // Modifiers/Add-ons
            TextFormField(
              controller: _modifiersController,
              focusNode: _modifiersFocusNode,
              readOnly: _isReadOnly,
              decoration: _getInputDecoration(
                labelText: 'Available Modifiers/Add-ons',
                hintText:
                    'e.g., Extra cheese, Spicy, No onions (comma-separated)',
                prefixIcon: Icons.add_circle_outline,
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection() {
    final businessNature = 'retail';

    // Only show ingredients section if business nature is restaurant
    if (businessNature != 'restaurant') {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shopping_basket,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ingredients / Components (Optional)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                  ),
                ),
                if (!_isReadOnly)
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: () => _showAddIngredientDialog(),
                    tooltip: 'Add Ingredient',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Define ingredients for ingredient-level costing. Stock will be auto-deducted when this item is sold.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDarkMode
                        ? const Color(0xFF94A3B8)
                        : Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 16),
            if (_ingredients.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No ingredients added yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ),
              )
            else
              ..._ingredients.asMap().entries.map((entry) {
                final index = entry.key;
                final ingredient = entry.value;
                return _buildIngredientCard(ingredient, index);
              }),
            if (_ingredients.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildIngredientCostSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientCard(ProductIngredientModel ingredient, int index) {
    final currency = ref.watch(currentCurrencyProvider);
    final isDarkMode = ref.watch(isDarkModeProvider);
    final ingredientName =
        ingredient.ingredientProduct?.name ?? 'Unknown Product';
    final cost = ingredient.calculateCost();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDarkMode ? const Color(0xFF2A2F36) : Colors.grey.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Text(
            '${index + 1}',
            style: TextStyle(
                color: Colors.green.shade700, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          ingredientName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${ingredient.quantity} ${ingredient.unit}',
              style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode
                      ? const Color(0xFF94A3B8)
                      : Colors.grey.shade700),
            ),
            Text(
              ingredient.costType == IngredientCostType.fixedCost
                  ? 'Fixed Cost: ${currency.symbol}${ingredient.fixedCost?.toStringAsFixed(2) ?? '0.00'}'
                  : 'Cost: ${currency.symbol}${cost.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode
                      ? const Color(0xFF94A3B8)
                      : Colors.grey.shade700),
            ),
          ],
        ),
        trailing: !_isReadOnly
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeIngredient(index),
                tooltip: 'Remove Ingredient',
              )
            : null,
      ),
    );
  }

  Widget _buildIngredientCostSummary() {
    final currency = ref.watch(currentCurrencyProvider);
    double totalCost = 0.0;
    for (final ingredient in _ingredients) {
      totalCost += ingredient.calculateCost();
    }

    final sellingPrice = double.tryParse(_priceController.text) ?? 0.0;
    final profit = sellingPrice - totalCost;
    final profitMargin = sellingPrice > 0 ? (profit / sellingPrice) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Ingredient Cost:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                ),
              ),
              Text(
                '${currency.symbol}${totalCost.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          if (sellingPrice > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selling Price:',
                  style: TextStyle(color: Colors.blue.shade700),
                ),
                Text(
                  '${currency.symbol}${sellingPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Profit per Item:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: profit >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
                Text(
                  '${currency.symbol}${profit.toStringAsFixed(2)} (${profitMargin.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: profit >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddIngredientDialog() async {
    // Load only ingredients (products with category "Ingredients")
    final databaseService = ref.read(databaseServiceProvider);
    final allProducts = await databaseService.getAllProducts();
    // Filter to show only ingredients
    _allProducts = allProducts
        .where((p) => p.category.toLowerCase() == 'ingredients')
        .toList();

    if (_allProducts.isEmpty) {
      // Show message if no ingredients exist
      if (mounted) {
        final shouldCreate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text('No Ingredients Found'),
              ],
            ),
            content: const Text(
              'You need to create ingredients first before adding them to menu items.\n\nWould you like to go to the Ingredients screen to create ingredients?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('common.cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('add_product_scr.go_ingredients'.tr()),
              ),
            ],
          ),
        );

        if (shouldCreate == true && mounted) {
          Navigator.pop(context); // Close ingredient dialog
          context.push('/ingredients');
        }
      }
      return;
    }

    ProductModel? selectedProduct;
    final quantityController = TextEditingController(text: '1');
    final unitController = TextEditingController(text: 'pcs');
    final fixedCostController = TextEditingController();
    IngredientCostType selectedCostType = IngredientCostType.quantityBased;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('add_product_scr.add_ingredient'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ProductModel>(
                        decoration: const InputDecoration(
                          labelText: 'Select Ingredient',
                          prefixIcon: Icon(Icons.inventory_2),
                        ),
                        items: _allProducts.map((product) {
                          return DropdownMenuItem(
                            value: product,
                            child: Text(
                                '${product.name} (${product.stock} ${product.unit})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedProduct = value;
                            if (value != null) {
                              unitController.text = value.unit;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        // Navigate to Ingredients screen to create new ingredient
                        Navigator.pop(
                            context); // Close the ingredient dialog first
                        await context.push('/ingredients');
                        // Refresh ingredients list after returning
                        if (mounted) {
                          final databaseService =
                              ref.read(databaseServiceProvider);
                          final allProducts =
                              await databaseService.getAllProducts();
                          setState(() {
                            // Update to show only ingredients
                            _allProducts = allProducts
                                .where((p) =>
                                    p.category.toLowerCase() == 'ingredients')
                                .toList();
                          });
                          // Re-open the ingredient dialog if ingredients are now available
                          if (_allProducts.isNotEmpty && mounted) {
                            _showAddIngredientDialog();
                          }
                        }
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: Text('add_product_scr.new_label'.tr()),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select an ingredient from your ingredients list. Click "New" to create a new ingredient.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          prefixIcon: Icon(Icons.straighten),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<IngredientCostType>(
                  decoration: const InputDecoration(
                    labelText: 'Cost Type',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  value: selectedCostType,
                  items: const [
                    DropdownMenuItem(
                      value: IngredientCostType.quantityBased,
                      child: Text('Quantity-based (from inventory cost)'),
                    ),
                    DropdownMenuItem(
                      value: IngredientCostType.fixedCost,
                      child: Text('Fixed Cost (e.g., packing, bun)'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCostType =
                          value ?? IngredientCostType.quantityBased;
                    });
                  },
                ),
                if (selectedCostType == IngredientCostType.fixedCost) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fixedCostController,
                    decoration: InputDecoration(
                      labelText: 'Fixed Cost',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      prefixText: ref.watch(currentCurrencyProvider).symbol,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedProduct == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please select an ingredient product')),
                  );
                  return;
                }
                final quantity = double.tryParse(quantityController.text) ?? 0;
                if (quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a valid quantity')),
                  );
                  return;
                }
                if (selectedCostType == IngredientCostType.fixedCost) {
                  final fixedCost =
                      double.tryParse(fixedCostController.text) ?? 0;
                  if (fixedCost <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a valid fixed cost')),
                    );
                    return;
                  }
                }

                final ingredient = ProductIngredientModel(
                  productId: widget.productId ??
                      0, // Will be updated when product is saved
                  ingredientProductId: selectedProduct!.id!,
                  quantity: quantity,
                  unit: unitController.text.trim(),
                  costType: selectedCostType,
                  fixedCost: selectedCostType == IngredientCostType.fixedCost
                      ? double.tryParse(fixedCostController.text)
                      : null,
                  sortOrder: _ingredients.length,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  ingredientProduct: selectedProduct,
                );

                setState(() {
                  _ingredients.add(ingredient);
                });
                Navigator.pop(context);
              },
              child: Text('common.add'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
      // Update sort orders
      for (int i = 0; i < _ingredients.length; i++) {
        _ingredients[i] = _ingredients[i].copyWith(sortOrder: i);
      }
    });
  }

  Widget _buildLedgerButton() {
    return ElevatedButton.icon(
      onPressed: () {
        if (widget.productId != null) {
          context.push('/product-ledger?id=${widget.productId}');
        }
      },
      icon: const Icon(Icons.receipt_long),
      label: Text('add_product_scr.item_ledger'.tr()),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: const Color(0xFFF59E0B),
      ),
    );
  }

  Widget _buildPurchaseRateHistoryButton() {
    return ElevatedButton.icon(
      onPressed: () {
        if (widget.productId != null) {
          _showPurchaseRateHistory();
        }
      },
      icon: const Icon(Icons.history),
      label: Text('add_product_scr.purchase_rate_history'.tr()),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: const Color(0xFF3B82F6),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isLoading
                ? null
                : () {
                    if (mounted) {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        // If we can't pop, navigate to products screen
                        context.go('/products');
                      }
                    }
                  },
            icon: const Icon(Icons.close),
            label: Text('common.cancel'.tr()),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: (_isLoading || _isReadOnly) ? null : _saveProduct,
            icon: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(widget.productId == null ? Icons.add : Icons.save),
            label: Text(
              widget.productId == null ? 'Add Product' : 'Update Product',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _scanBarcode() async {
    if (!mounted) return;

    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => const ProductBarcodeScannerScreen(),
        ),
      );

      if (mounted && result != null && result.isNotEmpty) {
        setState(() {
          _barcodeController.text = result;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error scanning barcode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProduct() async {
    // Run all TextFormField validators (price/cost >= 0, category/unit required, etc.)
    // before touching the database.
    if (!(_formKey.currentState?.validate() ?? true)) {
      return;
    }

    // Basic check for product name
    if (_nameController.text.trim().isEmpty) {
      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Please enter product name'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final databaseService = ref.read(databaseServiceProvider);
      final trimmedName = _nameController.text.trim();
      final existingByName =
          await databaseService.getProductByName(trimmedName);

      final isDuplicate = existingByName != null &&
          (widget.productId == null || existingByName.id != widget.productId);

      if (isDuplicate) {
        if (mounted) {
          setState(() => _isLoading = false);
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text(
                  'Product name already exists. Please use a different name.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final trimmedBarcode = _barcodeController.text.trim();
      if (trimmedBarcode.isNotEmpty) {
        final existingByBarcode =
            await databaseService.getProductsByBarcode(trimmedBarcode);
        final isBarcodeDuplicate = existingByBarcode
            .any((p) => widget.productId == null || p.id != widget.productId);
        if (isBarcodeDuplicate) {
          if (mounted) {
            setState(() => _isLoading = false);
            AppSnackBar.show(
              context,
              const SnackBar(
                content: Text(
                    'This barcode is already used by another product. Please use a different barcode.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      final category = _showNewCategoryField
          ? _categoryController.text.trim()
          : _selectedCategory ?? _categoryController.text.trim();

      // Safe parsing with fallback values to prevent crashes
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final cost = double.tryParse(_costController.text) ?? 0.0;

      // Stock management: Services always have stock = 0, products can have stock
      final businessNature = 'retail';
      final isService = businessNature == 'salon' && _productType == 'service';
      final isRetail = businessNature == 'retail';
      final allowOpeningStock =
          ref.read(inventorySettingsProvider).allowOpeningStockOnProductCreate;

      double stock = 0.0;
      if (isService) {
        // Services don't have stock - always set to 0
        stock = 0.0;
      } else if (isRetail) {
        if (widget.productId != null) {
          // For editing products: fetch latest stock from database
          final latestProduct =
              await ref.read(productByIdProvider(widget.productId!).future);
          stock = latestProduct?.stock ?? 0.0;
        } else if (allowOpeningStock) {
          stock = double.tryParse(_stockController.text.trim()) ?? 0.0;
          if (!stock.isFinite || stock < 0) {
            throw const FormatException(
              'Opening stock must be a non-negative number.',
            );
          }
        }
        // When disabled, new retail products start at zero and stock is
        // received through Purchase Invoice / Stock Movement.
      } else {
        // For non-retail businesses: allow direct stock entry from form
        stock = double.tryParse(
                _stockController.text.isEmpty ? '0' : _stockController.text) ??
            0.0;
      }

      // Reorder levels: Services don't need reorder levels (no stock to reorder)
      double reorderLevel = 0.0;
      double reorderQuantity = 0.0;
      if (!isService) {
        reorderLevel = double.tryParse(_reorderLevelController.text.isEmpty
                ? '10'
                : _reorderLevelController.text) ??
            10.0;
        reorderQuantity = double.tryParse(
                _reorderQuantityController.text.isEmpty
                    ? '50'
                    : _reorderQuantityController.text) ??
            50.0;
      }
      final discount = (double.tryParse(_discountController.text.isEmpty
                  ? '0'
                  : _discountController.text) ??
              0.0)
          .clamp(0.0, double.infinity);
      final tax = (double.tryParse(
                  _taxController.text.isEmpty ? '0' : _taxController.text) ??
              0.0)
          .clamp(0.0, double.infinity);
      // For salon business: retail credit, wholesale, and market price are not used
      final isSalon = businessNature == 'salon';
      final retailCredit = isSalon
          ? null
          : (_retailCreditController.text.isNotEmpty
              ? double.tryParse(_retailCreditController.text)
              : null);
      final marketPrice = isSalon
          ? null
          : (_marketPriceController.text.isNotEmpty
              ? double.tryParse(_marketPriceController.text)
              : null);
      final maxLevel = _maxLevelController.text.isNotEmpty
          ? double.tryParse(_maxLevelController.text)
          : null;
      final wholesaleCash = isSalon
          ? null
          : (_wholesaleCashController.text.isNotEmpty
              ? double.tryParse(_wholesaleCashController.text)
              : null);
      final wholesaleCredit = isSalon
          ? null
          : (_wholesaleCreditController.text.isNotEmpty
              ? double.tryParse(_wholesaleCreditController.text)
              : null);

      // Parse mobile shop fields
      final tradeInValue = _tradeInValueController.text.isNotEmpty
          ? double.tryParse(_tradeInValueController.text)
          : null;

      // Parse restaurant fields
      final preparationTime = _preparationTimeController.text.isNotEmpty
          ? int.tryParse(_preparationTimeController.text)
          : null;

      // Ensure unit is never empty (required by database)
      final unit = _unitController.text.trim().isEmpty
          ? 'pcs'
          : _unitController.text.trim();

      final product = ProductModel(
        id: _existingProduct?.id,
        name: _nameController.text.trim(),
        category: category,
        productType: _productType,
        price: price,
        cost: cost,
        stock: stock,
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        discount: discount,
        tax: tax,
        unit: unit,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        reorderLevel: reorderLevel,
        reorderQuantity: reorderQuantity,
        company: _existingProduct?.company,
        marketPrice: marketPrice,
        maxLevel: maxLevel,
        packingMode: _packingModeController.text.trim().isEmpty
            ? null
            : _packingModeController.text.trim(),
        wholesaleCash: wholesaleCash,
        wholesaleCredit: wholesaleCredit,
        retailCredit: retailCredit,
        brand: _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        modelName: _modelNameController.text.trim().isEmpty
            ? null
            : _modelNameController.text.trim(),
        storageCapacity: _storageCapacityController.text.trim().isEmpty
            ? null
            : _storageCapacityController.text.trim(),
        ram: _ramController.text.trim().isEmpty
            ? null
            : _ramController.text.trim(),
        color: _colorController.text.trim().isEmpty
            ? null
            : _colorController.text.trim(),
        condition: _conditionController.text.trim().isEmpty
            ? null
            : _conditionController.text.trim(),
        unlockStatus: _unlockStatusController.text.trim().isEmpty
            ? null
            : _unlockStatusController.text.trim(),
        warrantyStatus: _warrantyStatusController.text.trim().isEmpty
            ? null
            : _warrantyStatusController.text.trim(),
        warrantyPeriod: _warrantyPeriodController.text.trim().isEmpty
            ? null
            : _warrantyPeriodController.text.trim(),
        warrantyProvider: _warrantyProviderController.text.trim().isEmpty
            ? null
            : _warrantyProviderController.text.trim(),
        displaySize: _displaySizeController.text.trim().isEmpty
            ? null
            : _displaySizeController.text.trim(),
        batteryCapacity: _batteryCapacityController.text.trim().isEmpty
            ? null
            : _batteryCapacityController.text.trim(),
        cameraSpecs: _cameraSpecsController.text.trim().isEmpty
            ? null
            : _cameraSpecsController.text.trim(),
        operatingSystem: _operatingSystemController.text.trim().isEmpty
            ? null
            : _operatingSystemController.text.trim(),
        networkType: _networkTypeController.text.trim().isEmpty
            ? null
            : _networkTypeController.text.trim(),
        simCardType: _simCardTypeController.text.trim().isEmpty
            ? null
            : _simCardTypeController.text.trim(),
        tradeInValue: tradeInValue,
        boxContents: _boxContentsController.text.trim().isEmpty
            ? null
            : _boxContentsController.text.trim(),
        // Restaurant fields
        courseType: _courseTypeController.text.trim().isEmpty
            ? null
            : _courseTypeController.text.trim(),
        preparationTime: preparationTime,
        allergens: _allergensController.text.trim().isEmpty
            ? null
            : _allergensController.text.trim(),
        modifiers: _modifiersController.text.trim().isEmpty
            ? null
            : _modifiersController.text.trim(),
        dietaryInfo: _dietaryInfoController.text.trim().isEmpty
            ? null
            : _dietaryInfoController.text.trim(),
        createdAt: _existingProduct?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final productNotifier = ref.read(productNotifierProvider.notifier);

      int? savedProductId;
      if (widget.productId == null) {
        // Opening stock and its ledger movement are committed together.
        savedProductId = allowOpeningStock && stock > 0
            ? await databaseService.insertProductWithOpeningStock(product)
            : await databaseService.insertProduct(product);
        // Refresh the notifier to update the list (don't call addProduct as it would insert again)
        productNotifier.refresh();
        // Invalidate productsProvider to refresh dashboard and other views
        ref.invalidate(productsProvider);
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Product added successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        savedProductId = widget.productId;
        await productNotifier.updateProduct(product);
        // Invalidate product caches so reopened forms show fresh data
        ref.invalidate(productsProvider);
        ref.invalidate(productByIdProvider(widget.productId!));

        // Reload the product to get the latest stock value from database
        if (widget.productId != null) {
          await _loadProduct();
        }

        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Product updated successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // Save ingredients for restaurant products
      if (businessNature == 'restaurant' && savedProductId != null) {
        try {
          // Delete existing ingredients first (for updates)
          await databaseService.deleteIngredientsByProductId(savedProductId);

          // Save new ingredients
          for (final ingredient in _ingredients) {
            final ingredientToSave = ingredient.copyWith(
              productId: savedProductId,
              updatedAt: DateTime.now(),
            );
            await databaseService.insertIngredient(ingredientToSave);
          }

          // Update product cost from ingredients if ingredients exist
          if (_ingredients.isNotEmpty) {
            final calculatedCost = await databaseService
                .calculateProductCostFromIngredients(savedProductId);
            final updatedProduct = product.copyWith(
              id: savedProductId,
              cost: calculatedCost,
              updatedAt: DateTime.now(),
            );
            await productNotifier.updateProduct(updatedProduct);
          }
        } catch (ingredientError) {
          debugPrint('Error saving ingredients: $ingredientError');
          // Continue even if ingredient save fails - product is already saved
          if (mounted) {
            AppSnackBar.show(
              context,
              SnackBar(
                content: Text(
                    'Product saved but ingredient error occurred: ${ingredientError.toString()}'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }

      // Navigate back after successful save
      if (mounted) {
        // Add a small delay to ensure SnackBar is shown
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          // Always try to pop first, then fallback to go
          if (context.canPop()) {
            context.pop(true); // Return true to indicate success
          } else {
            // If we can't pop, navigate to products screen
            context.go('/products');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Product'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${_nameController.text}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (mounted) {
                Navigator.pop(context);
                setState(() => _isLoading = true);
              }

              try {
                final productNotifier =
                    ref.read(productNotifierProvider.notifier);
                await productNotifier.deleteProduct(widget.productId!);
                // Invalidate productsProvider to refresh dashboard and other views
                ref.invalidate(productsProvider);

                if (mounted) {
                  AppSnackBar.show(
                    context,
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Product deleted successfully'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  if (context.canPop()) {
                    context.pop(true);
                  } else {
                    // If we can't pop, navigate to products screen
                    context.go('/products');
                  }
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.show(
                    context,
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Error: $e')),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _showPurchaseRateHistory() async {
    if (widget.productId == null) return;

    final databaseService = ref.read(databaseServiceProvider);

    // Fetch purchase order items for this product
    final purchaseRows = await databaseService.db.customSelect(
      '''
      SELECT 
        poi.id AS item_id,
        po.id AS order_id,
        po.order_number AS invoice_no,
        po.order_date AS purchase_date,
        poi.quantity AS quantity,
        poi.unit_cost AS price,
        poi.total AS amount,
        sup.name AS supplier_name
      FROM purchase_order_items poi
      INNER JOIN purchase_orders po ON po.id = poi.purchase_order_id
      LEFT JOIN suppliers sup ON sup.id = po.supplier_id
      WHERE poi.product_id = ?
      ORDER BY po.order_date DESC
      ''',
      variables: [drift.Variable<int>(widget.productId!)],
      readsFrom: {
        databaseService.db.purchaseOrderItems,
        databaseService.db.purchaseOrders,
        databaseService.db.suppliers
      },
    ).get();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _PurchaseRateHistoryDialog(
        productName:
            _nameController.text.isEmpty ? 'Product' : _nameController.text,
        purchaseData: purchaseRows,
        databaseService: databaseService,
        onUpdate: () {
          if (widget.productId != null) {
            _loadProduct();
          }
        },
      ),
    );
  }
}

// Barcode Scanner Screen for the Add Product form.
// Named distinctly from lib/screens/barcode_scanner_screen.dart's
// BarcodeScannerScreen (different contract: this one pops a String).
class ProductBarcodeScannerScreen extends StatefulWidget {
  const ProductBarcodeScannerScreen({super.key});

  @override
  State<ProductBarcodeScannerScreen> createState() =>
      _ProductBarcodeScannerScreenState();
}

class _ProductBarcodeScannerScreenState
    extends State<ProductBarcodeScannerScreen> {
  // mobile_scanner has no Windows/Linux/macOS desktop implementation, so the
  // camera controller must only be created on Android/iOS — otherwise
  // starting the camera throws a MissingPluginException on desktop.
  final bool _cameraSupported = Platform.isAndroid || Platform.isIOS;
  MobileScannerController? cameraController;
  bool _isScanned = false;
  final _manualBarcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_cameraSupported) {
      cameraController = MobileScannerController();
    }
  }

  @override
  void dispose() {
    cameraController?.dispose();
    _manualBarcodeController.dispose();
    super.dispose();
  }

  void _handleBarcodeDetected(String barcode) {
    if (_isScanned || !mounted) return;

    _isScanned = true;

    // Stop the scanner immediately
    cameraController?.stop();

    // Navigate after the current frame completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(barcode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraSupported) {
      // Windows/Linux/macOS: mobile_scanner has no desktop camera backend,
      // so fall back to manual entry instead of crashing.
      return Scaffold(
        appBar: AppBar(title: Text('barcode_scr.enter_title'.tr())),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                'barcode_scr.windows_not_available'.tr(),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _manualBarcodeController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.of(context).pop(value.trim());
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final value = _manualBarcodeController.text.trim();
                    if (value.isNotEmpty) {
                      Navigator.of(context).pop(value);
                    }
                  },
                  child: Text('barcode_scr.enter_manually'.tr()),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('barcode_scr.scan_title'.tr()),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController!.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
              },
            ),
            onPressed: () => cameraController!.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController!,
            onDetect: (capture) {
              if (_isScanned) return;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                  _handleBarcodeDetected(barcode.rawValue!);
                  return;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Position the barcode within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseRateHistoryDialog extends StatefulWidget {
  final String productName;
  final dynamic purchaseData;
  final DatabaseService databaseService;
  final VoidCallback onUpdate;

  const _PurchaseRateHistoryDialog({
    required this.productName,
    required this.purchaseData,
    required this.databaseService,
    required this.onUpdate,
  });

  @override
  State<_PurchaseRateHistoryDialog> createState() =>
      _PurchaseRateHistoryDialogState();
}

class _PurchaseRateHistoryDialogState
    extends State<_PurchaseRateHistoryDialog> {
  late List<Map<String, dynamic>> _editableData;
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _priceControllers = {};
  final Map<int, TextEditingController> _supplierControllers = {};
  final Map<int, TextEditingController> _dateControllers = {};

  @override
  void initState() {
    super.initState();
    _editableData = (widget.purchaseData as List)
        .map((row) => {
              'item_id': row.read<int?>('item_id'),
              'order_id': row.read<int?>('order_id'),
              'supplier_name': row.read<String?>('supplier_name') ?? '',
              'purchase_date': row.read<String?>('purchase_date') ?? '',
              'quantity': row.read<double?>('quantity') ?? 0.0,
              'price': row.read<double?>('price') ?? 0.0,
              'amount': row.read<double?>('amount') ?? 0.0,
            })
        .toList();

    for (var data in _editableData) {
      final itemId = data['item_id'] as int;
      _qtyControllers[itemId] = TextEditingController(
        text: data['quantity'].toString(),
      );
      _priceControllers[itemId] = TextEditingController(
        text: data['price'].toString(),
      );
      _supplierControllers[itemId] = TextEditingController(
        text: data['supplier_name'].toString(),
      );
      final dateStr = data['purchase_date'] as String;
      DateTime? purchaseDate;
      try {
        purchaseDate = DateTime.parse(dateStr);
      } catch (e) {
        purchaseDate = DateTime.now();
      }
      _dateControllers[itemId] = TextEditingController(
        text: DateFormat('dd-MM-yyyy').format(purchaseDate),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    for (final controller in _supplierControllers.values) {
      controller.dispose();
    }
    for (final controller in _dateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateAmount(int itemId) {
    final qty = double.tryParse(_qtyControllers[itemId]?.text ?? '0') ?? 0.0;
    final price =
        double.tryParse(_priceControllers[itemId]?.text ?? '0') ?? 0.0;
    final amount = qty * price;

    setState(() {
      final index = _editableData.indexWhere((d) => d['item_id'] == itemId);
      if (index != -1) {
        _editableData[index]['quantity'] = qty;
        _editableData[index]['price'] = price;
        _editableData[index]['amount'] = amount;
      }
    });
  }

  double get _totalQty =>
      _editableData.fold(0.0, (sum, d) => sum + (d['quantity'] as double));
  double get _totalAmount =>
      _editableData.fold(0.0, (sum, d) => sum + (d['amount'] as double));

  Future<void> _saveChanges() async {
    try {
      for (var data in _editableData) {
        final itemId = data['item_id'] as int;
        final qty =
            double.tryParse(_qtyControllers[itemId]?.text ?? '0') ?? 0.0;
        final price =
            double.tryParse(_priceControllers[itemId]?.text ?? '0') ?? 0.0;
        final amount = qty * price;

        final items = await widget.databaseService
            .getPurchaseOrderItems(data['order_id'] as int);
        final item = items.firstWhere((i) => i.id == itemId);

        final updatedItem = item.copyWith(
          quantity: qty,
          unitCost: price,
          total: amount,
        );

        await widget.databaseService.updatePurchaseOrderItem(updatedItem);
      }

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Purchase history updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onUpdate();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error updating purchase history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Item Name: ${widget.productName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Table Header
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: Row(
                children: [
                  _buildHeaderCell('Supplier Name', flex: 2),
                  _buildHeaderCell('Purchase Date', flex: 1),
                  _buildHeaderCell('Qty', flex: 1),
                  _buildHeaderCell('Price', flex: 1),
                  _buildHeaderCell('Amount', flex: 1, isLast: true),
                ],
              ),
            ),
            // Table Body
            Expanded(
              child: ListView.builder(
                itemCount: _editableData.length,
                itemBuilder: (context, index) {
                  final data = _editableData[index];
                  final itemId = data['item_id'] as int;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        left: BorderSide(color: Colors.grey[400]!),
                        right: BorderSide(color: Colors.grey[400]!),
                        bottom: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildEditableCell(
                          controller: _supplierControllers[itemId]!,
                          flex: 2,
                        ),
                        _buildEditableCell(
                          controller: _dateControllers[itemId]!,
                          flex: 1,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
                          ],
                        ),
                        _buildEditableCell(
                          controller: _qtyControllers[itemId]!,
                          flex: 1,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            DecimalInputFormatter(maxDecimalPlaces: 2),
                          ],
                          onChanged: (_) => _updateAmount(itemId),
                        ),
                        _buildEditableCell(
                          controller: _priceControllers[itemId]!,
                          flex: 1,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            DecimalInputFormatter(maxDecimalPlaces: 2),
                          ],
                          onChanged: (_) => _updateAmount(itemId),
                        ),
                        _buildReadOnlyCell(
                          data['amount'].toStringAsFixed(2),
                          flex: 1,
                          textAlign: TextAlign.right,
                          isLast: true,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Total Row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Total :',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _totalQty.toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _totalAmount.toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: Text('common.close'.tr()),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: Text('add_product_scr.save_changes'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1, bool isLast = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  right: BorderSide(color: Colors.grey[400]!),
                ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.grey[900],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableCell({
    required TextEditingController controller,
    int flex = 1,
    TextAlign textAlign = TextAlign.left,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
    bool isLast = false,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  right: BorderSide(color: Colors.grey[400]!),
                ),
        ),
        child: TextField(
          controller: controller,
          textAlign: textAlign,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            isDense: true,
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyCell(String text,
      {int flex = 1,
      TextAlign textAlign = TextAlign.left,
      bool isLast = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  right: BorderSide(color: Colors.grey[400]!),
                ),
        ),
        child: Text(
          text,
          textAlign: textAlign,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
