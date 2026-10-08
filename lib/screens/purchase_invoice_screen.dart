import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:offline_pos_system/services/database_service.dart';
import '../models/purchase_order.dart';
import '../models/product.dart';
import '../models/currency.dart';
import '../models/supplier.dart';
import '../providers/purchase_order_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/product_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/auth_provider.dart';
import '../models/employee.dart';
import '../utils/input_formatters.dart';
import '../utils/mobile_optimization.dart';
import '../utils/touch_optimization.dart';
import '../widgets/app_snack_bar.dart';
import '../services/auto_refresh_service.dart';

class PurchaseInvoiceScreen extends ConsumerStatefulWidget {
  const PurchaseInvoiceScreen({super.key});

  @override
  ConsumerState<PurchaseInvoiceScreen> createState() =>
      _PurchaseInvoiceScreenState();
}

class _PurchaseInvoiceScreenState extends ConsumerState<PurchaseInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNoController = TextEditingController();
  final _notesController = TextEditingController();

  int? _selectedSupplierId;
  DateTime _invoiceDate = DateTime.now();
  DateTime _receiveDate = DateTime.now();
  List<PurchaseOrderItemModel> _items = [];
  bool _isSaving = false;
  int? _existingOrderId; // Track if we're editing an existing order

  bool _hasProcessedExtra = false;

  @override
  void initState() {
    super.initState();
    print('PurchaseInvoiceScreen: initState');
    _invoiceNoController.text = 'PI-${DateTime.now().millisecondsSinceEpoch}';
  }

  void _checkForPrefilledData() {
    if (_hasProcessedExtra) return;

    try {
      final extra = GoRouterState.of(context).extra;
      if (extra != null && extra is Map<String, dynamic> && _items.isEmpty) {
        _hasProcessedExtra = true;
        _handlePrefilledData(extra);
      }
    } catch (e) {
      // Ignore if context is not available yet
      debugPrint('Could not access route extra: $e');
    }
  }

  void _handlePrefilledData(Map<String, dynamic> extra) {
    // Set supplier
    final supplierId = _asInt(extra['supplierId']);
    if (supplierId != null) {
      setState(() {
        _selectedSupplierId = supplierId;
      });
    }

    // Set invoice number
    final invoiceNumber = _asString(extra['invoiceNumber']);
    if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
      _invoiceNoController.text = invoiceNumber;
    }

    // Set notes
    final notes = _asString(extra['notes']);
    if (notes != null) {
      _notesController.text = notes;
    }

    // Track existing order ID for updates
    final orderId = _asInt(extra['orderId']);
    if (orderId != null) {
      _existingOrderId = orderId;
    }

    // Set dates if provided
    final orderDate = _asDateTime(extra['orderDate']);
    if (orderDate != null) {
      _invoiceDate = orderDate;
    }
    final receivedDate = _asDateTime(extra['receivedDate']);
    if (receivedDate != null) {
      _receiveDate = receivedDate;
    }

    // Pre-fill items
    final preFillItemsRaw = extra['preFillItems'];
    if (preFillItemsRaw is List) {
      final preFillItems = preFillItemsRaw.whereType<Map>().toList();

      setState(() {
        _items = preFillItems.map((item) {
          final product = item['product'] is ProductModel
              ? item['product'] as ProductModel
              : null;
          final productId = _asInt(item['productId']) ?? 0;
          final quantity = _asDouble(item['quantity']) ?? 0;
          final unitCost = _asDouble(item['unitCost']) ?? 0;
          final subtotal = _asDouble(item['subtotal']) ?? 0;
          return PurchaseOrderItemModel(
            id: _asInt(item['id']), // Preserve item ID if editing
            purchaseOrderId: _existingOrderId ?? 0,
            productId: productId,
            quantity: quantity,
            unitCost: unitCost,
            subtotal: subtotal,
            discount: 0,
            tax: 0,
            total: subtotal,
            createdAt: DateTime.now(),
            product: product,
          );
        }).where((item) => item.productId > 0).toList();
      });
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.subtotal);
  double get _total => _subtotal;

  @override
  Widget build(BuildContext context) {
    // Check for pre-filled data from route
    _checkForPrefilledData();

    final currency = ref.watch(currentCurrencyProvider);
    final suppliersAsync = ref.watch(activeSuppliersProvider);

    final isMobileDevice = MobileOptimization.isMobile(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('purchase.invoice_stock_in'.tr()),
        leading: MobileOptimization.mobileIconButton(
          icon: Icons.arrow_back,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: Form(
          key: _formKey,
          child: Stack(
            children: [
              ListView(
                padding: MobileOptimization.getResponsivePadding(context),
              children: [
                TextFormField(
                  controller: _invoiceNoController,
                  decoration: InputDecoration(
                    labelText: 'Invoice No *',
                    border: const OutlineInputBorder(),
                    contentPadding: MobileOptimization.getTextFieldPadding(context),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                SizedBox(
                  height: MobileOptimization.getFormFieldSpacing(context),
                ),
                suppliersAsync.when(
                  data: (suppliers) => FormField<int>(
                    initialValue: _selectedSupplierId,
                    validator: (v) => v == null ? 'Required' : null,
                    builder: (field) => InkWell(
                      onTap: () => _showSupplierSearchDialog(suppliers),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Supplier *',
                          border: const OutlineInputBorder(),
                          suffixIcon: const Icon(Icons.search),
                          errorText: field.errorText,
                        ),
                        child: Text(
                          _getSelectedSupplierName(suppliers),
                          style: TextStyle(
                            color: _selectedSupplierId != null
                                ? null
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Text('purchase.failed_suppliers'.tr()),
                ),
                SizedBox(
                  height: MobileOptimization.getFormFieldSpacing(context),
                ),
                isMobileDevice
                    ? Column(
                        children: [
                          ListTile(
                            title: Text('purchase.invoice_date'.tr()),
                            subtitle: Text(
                                DateFormat('dd MMM yyyy').format(_invoiceDate)),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _invoiceDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (d != null) setState(() => _invoiceDate = d);
                            },
                            contentPadding: MobileOptimization.getListItemPadding(context),
                          ),
                          SizedBox(
                            height: MobileOptimization.getFormFieldSpacing(context) * 0.5,
                          ),
                          ListTile(
                            title: Text('purchase.receive_date'.tr()),
                            subtitle: Text(
                                DateFormat('dd MMM yyyy').format(_receiveDate)),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _receiveDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (d != null) setState(() => _receiveDate = d);
                            },
                            contentPadding: MobileOptimization.getListItemPadding(context),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: Text('purchase.invoice_date'.tr()),
                              subtitle: Text(
                                  DateFormat('dd MMM yyyy').format(_invoiceDate)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _invoiceDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (d != null) setState(() => _invoiceDate = d);
                              },
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              title: Text('purchase.receive_date'.tr()),
                              subtitle: Text(
                                  DateFormat('dd MMM yyyy').format(_receiveDate)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _receiveDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (d != null) setState(() => _receiveDate = d);
                              },
                            ),
                          ),
                        ],
                      ),
                const Divider(),
                isMobileDevice
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Items',
                            style: TextStyle(
                              fontSize: MobileOptimization.getResponsiveFontSize(
                                context,
                                mobile: 18,
                                tablet: 20,
                                desktop: 22,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            height: MobileOptimization.getFormFieldSpacing(context),
                          ),
                          MobileOptimization.mobileButton(
                            onPressed: _selectedSupplierId == null
                                ? null
                                : () => _addItem(currency),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add),
                                SizedBox(width: 8),
                                Text('Add Item'),
                              ],
                            ),
                            backgroundColor: const Color(0xFF3B82F6),
                            isFullWidth: true,
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Items',
                            style: TextStyle(
                              fontSize: MobileOptimization.getResponsiveFontSize(
                                context,
                                mobile: 18,
                                tablet: 20,
                                desktop: 22,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Tooltip(
                            message: _selectedSupplierId == null
                                ? 'Please select a supplier first'
                                : 'Add Item',
                            child: ElevatedButton.icon(
                              onPressed: _selectedSupplierId == null
                                  ? null
                                  : () => _addItem(currency),
                              icon: const Icon(Icons.add),
                              label: Text('purchase.add_item'.tr()),
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 12),
                if (_items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No items added yet')),
                    ),
                  )
                else
                  ..._items.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    final isReturn = item.quantity < 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isReturn ? Colors.red.shade50 : null,
                      child: ListTile(
                        leading: isReturn
                            ? Icon(Icons.arrow_back, color: Colors.red.shade700)
                            : Icon(Icons.inventory_2,
                                color: Colors.green.shade700),
                        title: Text(
                          item.product?.name ?? 'Unknown Product',
                          style: TextStyle(
                            fontWeight: isReturn ? FontWeight.w600 : null,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            if (item.quantity < 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border:
                                        Border.all(color: Colors.red.shade300),
                                  ),
                                  child: Text(
                                    'RETURN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                '${item.quantity} × ${currency.symbol}${item.unitCost.toStringAsFixed(2)} = ${currency.symbol}${item.subtotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: item.quantity < 0
                                      ? Colors.red.shade700
                                      : null,
                                  fontWeight: item.quantity < 0
                                      ? FontWeight.w600
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _editItem(currency, i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  size: 20, color: Colors.red),
                              onPressed: () =>
                                  setState(() => _items.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const Divider(height: 24),
                Card(
                  color: const Color(0xFFF1F5F9),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildTotalRow('Subtotal', _subtotal, currency),
                        const Divider(),
                        _buildTotalRow('Total', _total, currency, isBold: true),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: MobileOptimization.getFormFieldSpacing(context),
                ),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Remarks',
                    border: const OutlineInputBorder(),
                    contentPadding: MobileOptimization.getTextFieldPadding(context),
                  ),
                  maxLines: MobileOptimization.isMobile(context) ? 4 : 3,
                ),
                SizedBox(
                  height: MobileOptimization.getFormFieldSpacing(context) * 1.5,
                ),
                isMobileDevice
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MobileOptimization.mobileButton(
                            onPressed: _isSaving ? null : () => _saveInvoice(currency),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text('purchase.save_invoice'.tr(),
                                    style: TextStyle(color: Colors.white)),
                            backgroundColor: const Color(0xFF10B981),
                            isFullWidth: true,
                          ),
                          SizedBox(
                            height: MobileOptimization.getFormFieldSpacing(context),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showPurchaseInvoiceFinder,
                            icon: const Icon(Icons.search, size: 20),
                            label: Text('common.find'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              minimumSize: Size(
                                0,
                                MobileOptimization.isMobile(context)
                                    ? TouchOptimization.recommendedTouchTarget
                                    : 40,
                              ),
                              padding: MobileOptimization.isMobile(context)
                                  ? TouchOptimization.getTouchPadding()
                                  : const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : () => _saveInvoice(currency),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Text('purchase.save_invoice'.tr(),
                                      style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          SizedBox(
                            width: MobileOptimization.getResponsiveSpacing(
                              context,
                              mobile: 12,
                              tablet: 16,
                              desktop: 16,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showPurchaseInvoiceFinder,
                            icon: const Icon(Icons.search, size: 20),
                            label: Text('common.find'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
            if (_isSaving)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ),
          ],
        ),
    ));
  }

  Widget _buildTotalRow(String label, double amount, Currency currency,
      {bool isBold = false}) {
    final isNegative = amount < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            '${currency.symbol}${amount.abs().toStringAsFixed(2)}${isNegative ? ' (Credit)' : ''}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: isNegative ? Colors.red.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem(Currency currency) async {
    await showDialog(
      context: context,
      builder: (context) => _InvoiceItemDialog(
          currency: currency,
          onSave: (item) {
            setState(() => _items.add(item));
          }),
    );
  }

  Future<void> _editItem(Currency currency, int index) async {
    await showDialog(
      context: context,
      builder: (context) => _InvoiceItemDialog(
          currency: currency,
          item: _items[index],
          onSave: (item) {
            setState(() => _items[index] = item);
          }),
    );
  }

  Future<void> _showSupplierSearchDialog(List<SupplierModel> suppliers) async {
    await showDialog(
      context: context,
      builder: (context) => _SupplierSearchDialog(
        suppliers: suppliers,
        selectedSupplierId: _selectedSupplierId,
        onSelect: (supplierId) {
          setState(() => _selectedSupplierId = supplierId);
        },
      ),
    );
  }

  Future<void> _saveInvoice(Currency currency) async {
    if (!_formKey.currentState!.validate()) return;
    
    // Allow zero total invoices (when all items are deleted)
    // if (_items.isEmpty) {
    //   AppSnackBar.show(context,
    //       const SnackBar(content: Text('Please add at least one item')));
    //   return;
    // }
    
    if (_selectedSupplierId == null) {
      AppSnackBar.show(
          context, const SnackBar(content: Text('Please select a supplier')));
      return;
    }

    // Check supplier details before saving (credit limit logic disabled as per requirement)
    final databaseService = ref.read(databaseServiceProvider);
    final supplierData =
        await databaseService.getSupplierById(_selectedSupplierId!);

    if (supplierData != null) {
      final supplier = SupplierModel.fromSupplier(supplierData);
      double newBalance = supplier.currentBalance;
      double oldTotal = 0.0;

      // If editing, calculate the net change (subtract old total, add new total)
      if (_existingOrderId != null) {
        final existingOrder =
            await databaseService.getPurchaseOrderById(_existingOrderId!);
        if (existingOrder != null) {
          oldTotal = existingOrder.total;
          newBalance = supplier.currentBalance - oldTotal + _total;
        }
      } else {
        // For new invoice, add the total to current balance
        newBalance = supplier.currentBalance + _total;
      }

      // Show confirmation dialog for zero total invoices when editing
      if (_total == 0 && _existingOrderId != null && oldTotal > 0) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Expanded(child: Text('Zero Invoice Confirmation')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This invoice will be set to zero (all items deleted).'),
                const SizedBox(height: 8),
                Text(
                    'Original Invoice Amount: ${currency.symbol}${oldTotal.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                Text(
                  'New Balance: ${currency.symbol}${newBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: newBalance < 0 ? Colors.green.shade700 : null,
                  ),
                ),
                if (newBalance < 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Note: Supplier owes you ${currency.symbol}${newBalance.abs().toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.green.shade700, fontSize: 12),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: Text('common.confirm'.tr()),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }

      // For returns (negative total), show appropriate message
      if (_total < 0) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('purchase.confirm_return_title'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This invoice contains returns (negative quantities).'),
                const SizedBox(height: 8),
                Text(
                    'Invoice Amount: ${currency.symbol}${_total.abs().toStringAsFixed(2)} (Credit)'),
                const SizedBox(height: 8),
                Text(
                  'New Balance: ${currency.symbol}${newBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: newBalance < 0 ? Colors.green.shade700 : null,
                  ),
                ),
                if (newBalance < 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Note: Supplier owes you ${currency.symbol}${newBalance.abs().toStringAsFixed(2)}',
                    style:
                        TextStyle(color: Colors.green.shade700, fontSize: 12),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('purchase.confirm_return_btn'.tr()),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }

      // Supplier credit limit enforcement is disabled for now
    }

    final productIds = _items.map((item) => item.productId).toSet().toList();

    setState(() => _isSaving = true);
    try {
      // If editing existing order, update it; otherwise create new
      if (_existingOrderId != null) {
        // Load existing order to preserve original dates
        final existingOrder =
            await databaseService.getPurchaseOrderById(_existingOrderId!);

        if (existingOrder == null) {
          throw Exception('Order not found');
        }

        final order = PurchaseOrderModel(
          id: _existingOrderId,
          orderNumber: _invoiceNoController.text,
          supplierId: _selectedSupplierId!,
          orderDate: DateTime.parse(
              existingOrder.orderDate), // Keep original order date
          expectedDate: null,
          receivedDate: _receiveDate,
          subtotal: _subtotal,
          tax: 0,
          discount: 0,
          total: _total,
          status: PurchaseOrderStatus.received,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          createdAt: DateTime.parse(
              existingOrder.createdAt), // Keep original created date
          updatedAt: DateTime.now(),
        );

        // Update existing order instead of creating new one
        await ref
            .read(purchaseOrderNotifierProvider.notifier)
            .updatePurchaseInvoice(order, _items);
      } else {
        // Create new invoice
        final order = PurchaseOrderModel(
          orderNumber: _invoiceNoController.text,
          supplierId: _selectedSupplierId!,
          orderDate: _invoiceDate,
          expectedDate: null,
          receivedDate: _receiveDate,
          subtotal: _subtotal,
          tax: 0,
          discount: 0,
          total: _total,
          status: PurchaseOrderStatus.received,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await ref
            .read(purchaseOrderNotifierProvider.notifier)
            .createPurchaseInvoice(order, _items);
      }

      AutoRefreshService.refreshAfterPurchaseOperation(
        ref,
        supplierId: _selectedSupplierId!,
        productIds: productIds,
      );

      if (!mounted) return;
      AppSnackBar.show(
          context, const SnackBar(content: Text('Purchase invoice saved')));
      // Prefer pop if possible, otherwise go to dashboard to avoid blank screen
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        if (context.mounted) context.go('/');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showPurchaseInvoiceFinder() async {
    try {
      final currency = ref.read(currentCurrencyProvider);
      if (!mounted) return;

      // Get all employees for employee lookup
      final databaseService = ref.read(databaseServiceProvider);
      final employees = await databaseService.getAllEmployees();
      final currentUser = ref.read(authProvider).currentUser;

      // Fetch purchase orders directly from database to avoid loading state issues
      final purchaseOrdersRaw = await databaseService.getAllPurchaseOrders();
      
      // Enrich with supplier and items data
      final List<PurchaseOrderModel> purchaseOrders = [];
      for (final order in purchaseOrdersRaw) {
        final supplier = await databaseService.getSupplierById(order.supplierId);
        final items = await databaseService.getPurchaseOrderItems(order.id);

        // Enrich items with product data
        final List<PurchaseOrderItemModel> enrichedItems = [];
        for (final item in items) {
          final productModel = await databaseService.getProductById(item.productId);
          enrichedItems.add(PurchaseOrderItemModel.fromPurchaseOrderItem(
            item,
            product: productModel,
          ));
        }

        purchaseOrders.add(PurchaseOrderModel.fromPurchaseOrder(
          order,
          supplier: supplier != null ? SupplierModel.fromSupplier(supplier) : null,
          items: enrichedItems,
        ));
      }
      
      if (!mounted) return;

      // Filter only received invoices (purchase invoices)
      final invoices = purchaseOrders
          .where((order) => order.status == PurchaseOrderStatus.received)
          .toList();

      if (invoices.isEmpty) {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('No purchase invoices found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Group invoices by createdAt (bills created at the same time belong together)
      final Map<String, List<PurchaseOrderModel>> billsByTime = {};

      for (final invoice in invoices) {
        final createdAt = invoice.createdAt;
        // Round to nearest second for grouping
        final roundedDate = DateTime(
          createdAt.year,
          createdAt.month,
          createdAt.day,
          createdAt.hour,
          createdAt.minute,
          createdAt.second,
        );
        final timeKey = DateFormat('yyyy-MM-dd HH:mm:ss').format(roundedDate);

        if (!billsByTime.containsKey(timeKey)) {
          billsByTime[timeKey] = [];
        }
        billsByTime[timeKey]!.add(invoice);
      }

      // Convert to list of bills and sort by date (newest first)
      final bills = billsByTime.entries.toList()
        ..sort((a, b) {
          if (a.value.isEmpty || b.value.isEmpty) return 0;
          final dateA = a.value.first.createdAt;
          final dateB = b.value.first.createdAt;
          return dateB.compareTo(dateA);
        });

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            width: 600,
            height: 700,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long,
                          color: Color(0xFF2563EB), size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Purchase Invoice Bills',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
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
                  child: bills.isEmpty
                      ? const Center(
                          child: Text(
                            'No purchase invoices found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: bills.length,
                          itemBuilder: (context, index) {
                            final bill = bills[index];
                            final billInvoices = bill.value;
                            final billDate = billInvoices.first.createdAt;
                            final totalAmount = billInvoices.fold(
                                0.0, (sum, inv) => sum + inv.total);
                            final itemCount = billInvoices.fold(
                                0.0, (sum, inv) => sum + inv.items.length);
                            
                            // Get employee name from current user (currentUser is EmployeeModel)
                            String employeeName = 'System';
                            if (currentUser != null) {
                              // currentUser is already an EmployeeModel, so use it directly
                              employeeName = currentUser.name;
                            }

                            return _PurchaseInvoiceBillCard(
                              billDate: billDate,
                              invoiceCount: billInvoices.length,
                              itemCount: itemCount.toInt(),
                              totalAmount: totalAmount,
                              currency: currency,
                              employeeName: employeeName,
                              onTap: () {
                                Navigator.of(context).pop();
                                _showBillDetailsDialog(billInvoices, billDate, employees, currentUser);
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
          content: Text('Unable to load purchase invoices: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editInvoice(PurchaseOrderModel invoice) {
    if (!mounted) return;
    
    // Navigate to purchase invoice screen with invoice data
    final extra = {
      'orderId': invoice.id,
      'supplierId': invoice.supplierId,
      'invoiceNumber': invoice.orderNumber,
      'orderDate': invoice.orderDate,
      'receivedDate': invoice.receivedDate ?? invoice.orderDate,
      'notes': invoice.notes,
      'preFillItems': invoice.items.map((item) {
        return {
          'id': item.id,
          'productId': item.productId,
          'product': item.product,
          'quantity': item.quantity,
          'unitCost': item.unitCost,
          'subtotal': item.subtotal,
        };
      }).toList(),
    };
    
    context.push('/purchase-invoice', extra: extra);
  }

  void _showBillDetailsDialog(
      List<PurchaseOrderModel> invoices, DateTime billDate,
      List<EmployeeModel> employees, EmployeeModel? currentUser) {
    if (!mounted) return;
    final currency = ref.read(currentCurrencyProvider);
    
    // Get employee name (currentUser is already EmployeeModel)
    String employeeName = 'System';
    if (currentUser != null) {
      employeeName = currentUser.name;
    }

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
                            'Purchase Invoice Bill Details',
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (invoices.length == 1)
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _editInvoice(invoices.first);
                            },
                            icon: const Icon(Icons.edit, color: Color(0xFF3B82F6)),
                            tooltip: 'Edit Invoice',
                          ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: invoices.map((invoice) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        leading: const Icon(Icons.receipt,
                            color: Color(0xFF2563EB)),
                        title: Text(
                          'Invoice: ${invoice.orderNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (invoice.supplier != null)
                              Text('Supplier: ${invoice.supplier!.name}'),
                            Text(
                              'Date: ${DateFormat('dd/MM/yyyy').format(invoice.orderDate)}',
                            ),
                            Text(
                              'Total: ${currency.symbol}${invoice.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            Text(
                              'Created by: $employeeName',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF3B82F6)),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _editInvoice(invoice);
                          },
                          tooltip: 'Edit Invoice',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Items:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...invoice.items.map((item) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.product?.name ?? 'Unknown Product',
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        Text(
                                          'Qty: ${item.quantity.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          '${currency.symbol}${item.unitCost.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          '${currency.symbol}${item.total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                if (invoice.notes != null &&
                                    invoice.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Notes: ${invoice.notes}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseInvoiceBillCard extends StatelessWidget {
  final DateTime billDate;
  final int invoiceCount;
  final int itemCount;
  final double totalAmount;
  final Currency currency;
  final String employeeName;
  final VoidCallback onTap;

  const _PurchaseInvoiceBillCard({
    required this.billDate,
    required this.invoiceCount,
    required this.itemCount,
    required this.totalAmount,
    required this.currency,
    required this.employeeName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF2563EB),
                  size: 24,
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$invoiceCount invoice${invoiceCount > 1 ? 's' : ''} • $itemCount item${itemCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Created by: $employeeName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${currency.symbol}${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Searchable Supplier Dialog
class _SupplierSearchDialog extends StatefulWidget {
  final List<SupplierModel> suppliers;
  final int? selectedSupplierId;
  final Function(int) onSelect;

  const _SupplierSearchDialog({
    required this.suppliers,
    this.selectedSupplierId,
    required this.onSelect,
  });

  @override
  State<_SupplierSearchDialog> createState() => _SupplierSearchDialogState();
}

class _SupplierSearchDialogState extends State<_SupplierSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<SupplierModel> _filteredSuppliers = [];
  List<SupplierModel> _allSuppliers = [];

  @override
  void initState() {
    super.initState();
    // Create a fresh copy of the suppliers list to avoid reference issues
    _allSuppliers = List<SupplierModel>.from(widget.suppliers);
    _filteredSuppliers = List<SupplierModel>.from(_allSuppliers);
    _searchController.addListener(_filterSuppliers);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterSuppliers);
    _searchController.dispose();
    super.dispose();
  }

  void _filterSuppliers() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredSuppliers = List<SupplierModel>.from(_allSuppliers);
      } else {
        _filteredSuppliers = _allSuppliers.where((supplier) {
          final nameMatch = supplier.name.toLowerCase().contains(query);
          final phoneMatch = supplier.phone != null &&
              supplier.phone!.toLowerCase().contains(query);
          final emailMatch = supplier.email != null &&
              supplier.email!.toLowerCase().contains(query);
          return nameMatch || phoneMatch || emailMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.search, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search suppliers by name, phone, or email...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredSuppliers.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'No suppliers available'
                            : 'No suppliers found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredSuppliers.length,
                      itemBuilder: (context, index) {
                        final supplier = _filteredSuppliers[index];
                        final isSelected =
                            widget.selectedSupplierId == supplier.id;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected ? Colors.blue.shade50 : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                              child: Icon(
                                Icons.business,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                            ),
                            title: Text(
                              supplier.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (supplier.phone != null)
                                  Text('📞 ${supplier.phone}'),
                                if (supplier.email != null)
                                  Text('✉️ ${supplier.email}'),
                              ],
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.blue)
                                : null,
                            onTap: () {
                              final supplierId = supplier.id;
                              if (supplierId == null) return;
                              widget.onSelect(supplierId);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _PurchaseInvoiceScreenState {
  String _getSelectedSupplierName(List<SupplierModel> suppliers) {
    if (_selectedSupplierId == null) return 'Select Supplier';
    for (final supplier in suppliers) {
      if (supplier.id == _selectedSupplierId) {
        return supplier.name;
      }
    }
    return 'Select Supplier';
  }
}

class _InvoiceItemDialog extends ConsumerStatefulWidget {
  final Currency currency;
  final PurchaseOrderItemModel? item;
  final Function(PurchaseOrderItemModel) onSave;

  const _InvoiceItemDialog(
      {required this.currency, this.item, required this.onSave});

  @override
  ConsumerState<_InvoiceItemDialog> createState() => _InvoiceItemDialogState();
}

class _InvoiceItemDialogState extends ConsumerState<_InvoiceItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _unitCostController = TextEditingController();
  final _cashRetailController = TextEditingController();
  final _creditRetailController = TextEditingController();
  final _wholesaleCashController = TextEditingController();
  final _wholesaleCreditController = TextEditingController();
  final _marketPriceController = TextEditingController();
  int? _selectedProductId;
  ProductModel? _selectedProduct;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _selectedProductId = widget.item!.productId;
      _selectedProduct = widget.item!.product;
      _quantityController.text = widget.item!.quantity.toString();
      _unitCostController.text = widget.item!.unitCost.toString();
      
      // If product is not loaded but productId exists, load it from database
      if (_selectedProduct == null && _selectedProductId != null) {
        _loadProductFromDatabase(_selectedProductId!);
      } else if (_selectedProduct != null) {
        _cashRetailController.text = _selectedProduct!.price.toStringAsFixed(2);
        _creditRetailController.text =
            (_selectedProduct!.retailCredit ?? 0).toStringAsFixed(2);
        _wholesaleCashController.text =
            (_selectedProduct!.wholesaleCash ?? 0).toStringAsFixed(2);
        _wholesaleCreditController.text =
            (_selectedProduct!.wholesaleCredit ?? 0).toStringAsFixed(2);
        _marketPriceController.text =
            (_selectedProduct!.marketPrice ?? 0).toStringAsFixed(2);
      }
    }
  }

  Future<void> _loadProductFromDatabase(int productId) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final product = await databaseService.getProductById(productId);
      if (product != null && mounted) {
        setState(() {
          _selectedProduct = product;
          _cashRetailController.text = product.price.toStringAsFixed(2);
          _creditRetailController.text =
              (product.retailCredit ?? 0).toStringAsFixed(2);
          _wholesaleCashController.text =
              (product.wholesaleCash ?? 0).toStringAsFixed(2);
          _wholesaleCreditController.text =
              (product.wholesaleCredit ?? 0).toStringAsFixed(2);
          _marketPriceController.text =
              (product.marketPrice ?? 0).toStringAsFixed(2);
        });
      }
    } catch (e) {
      debugPrint('Error loading product: $e');
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitCostController.dispose();
    _cashRetailController.dispose();
    _creditRetailController.dispose();
    _wholesaleCashController.dispose();
    _wholesaleCreditController.dispose();
    _marketPriceController.dispose();
    super.dispose();
  }

  double get _quantity => double.tryParse(_quantityController.text) ?? 0;
  double get _unitCost => double.tryParse(_unitCostController.text) ?? 0;
  double get _cashRetail => double.tryParse(_cashRetailController.text) ?? 0;
  double get _creditRetail =>
      double.tryParse(_creditRetailController.text) ?? 0;
  double get _wholesaleCash =>
      double.tryParse(_wholesaleCashController.text) ?? 0;
  double get _wholesaleCredit =>
      double.tryParse(_wholesaleCreditController.text) ?? 0;
  double get _marketPrice => double.tryParse(_marketPriceController.text) ?? 0;
  double get _subtotal => _quantity * _unitCost;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.item == null
                            ? Icons.add_shopping_cart
                            : Icons.edit,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.item == null ? 'Add Item' : 'Edit Item',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Product Selection with Search
                productsAsync.when(
                  data: (products) {
                    if (products.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                                'No products available. Please add products first.'),
                          ],
                        ),
                      );
                    }
                    return InkWell(
                      onTap: () => _showProductSearchDialog(products),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Product *',
                          border: const OutlineInputBorder(),
                          suffixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade50,
                        ),
                        child: Text(
                          _selectedProduct != null
                              ? '${_selectedProduct!.name}${_selectedProduct!.barcode != null ? ' (${_selectedProduct!.barcode})' : ''}'
                              : 'Tap to search and select product',
                          style: TextStyle(
                            color:
                                _selectedProduct != null ? null : Colors.grey,
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Error loading products'),
                      ],
                    ),
                  ),
                ),

                if (_selectedProduct != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2,
                            color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stock: ${_selectedProduct!.stock.toStringAsFixed(2)} ${_selectedProduct!.unit}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              if (_selectedProduct!.cost > 0)
                                Text(
                                  'Default Cost: ${widget.currency.symbol}${_selectedProduct!.cost.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Quantity Field
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText: 'Quantity * (Use negative for returns)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.numbers),
                    filled: true,
                    fillColor:
                        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                    helperText:
                        'Positive: Purchase | Negative: Return to supplier',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  inputFormatters: [
                    DecimalInputFormatter(
                        maxDecimalPlaces: 2, allowNegative: true)
                  ],
                  validator: (v) {
                    if (v?.isEmpty == true) return 'Required';
                    final n = double.tryParse(v!);
                    if (n == null || n == 0) return 'Cannot be zero';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 16),

                // Purchase Rate (Unit Cost) Field
                TextFormField(
                  controller: _unitCostController,
                  decoration: InputDecoration(
                    labelText: 'Purchase Rate (${widget.currency.symbol}) *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.attach_money),
                    filled: true,
                    fillColor:
                        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                    helperText: _selectedProduct != null &&
                            _selectedProduct!.cost > 0
                        ? 'Suggested: ${widget.currency.symbol}${_selectedProduct!.cost.toStringAsFixed(2)}'
                        : null,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
                  validator: (v) {
                    if (v?.isEmpty == true) return 'Required';
                    final n = double.tryParse(v!);
                    if (n == null || n <= 0) return 'Must be greater than 0';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 20),

                // Pricing Section Header
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

                // Retail Cash Field
                TextFormField(
                  controller: _cashRetailController,
                  decoration: InputDecoration(
                    labelText: 'Retail Cash (${widget.currency.symbol}) *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.shopping_cart),
                    filled: true,
                    fillColor: Colors.yellow.shade50,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
                  validator: (v) {
                    if (v?.isEmpty == true) return 'Required';
                    final n = double.tryParse(v!);
                    if (n == null || n < 0) return 'Must be 0 or greater';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 16),

                // Retail Credit Field
                TextFormField(
                  controller: _creditRetailController,
                  decoration: InputDecoration(
                    labelText: 'Retail Credit (${widget.currency.symbol})',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.credit_card),
                    filled: true,
                    fillColor: Colors.green.shade50,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final n = double.tryParse(v);
                      if (n == null || n < 0) return 'Must be 0 or greater';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 16),

                // Wholesale Cash Field
                TextFormField(
                  controller: _wholesaleCashController,
                  decoration: InputDecoration(
                    labelText: 'Wholesale Cash (${widget.currency.symbol})',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.store),
                    filled: true,
                    fillColor: Colors.yellow.shade50,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final n = double.tryParse(v);
                      if (n == null || n < 0) return 'Must be 0 or greater';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 16),

                // Wholesale Credit Field
                TextFormField(
                  controller: _wholesaleCreditController,
                  decoration: InputDecoration(
                    labelText: 'Wholesale Credit (${widget.currency.symbol})',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.business),
                    filled: true,
                    fillColor: Colors.green.shade50,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final n = double.tryParse(v);
                      if (n == null || n < 0) return 'Must be 0 or greater';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 16),

                // Market Price Field
                TextFormField(
                  controller: _marketPriceController,
                  decoration: InputDecoration(
                    labelText: 'Market Price (${widget.currency.symbol})',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.trending_up),
                    filled: true,
                    fillColor: Colors.yellow.shade50,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final n = double.tryParse(v);
                      if (n == null || n < 0) return 'Must be 0 or greater';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 20),

                // Subtotal Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subtotal',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.currency.symbol}${_subtotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.calculate,
                        size: 48,
                        color: Colors.blue.shade700,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('common.cancel'.tr()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          
                          // Check if we have a product selected (either loaded or by ID)
                          if (_selectedProductId == null) {
                            AppSnackBar.show(
                              context,
                              const SnackBar(
                                content: Text('Please select a product'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          // If product is not loaded but we have productId, load it first
                          ProductModel? productToUse = _selectedProduct;
                          if (productToUse == null && _selectedProductId != null) {
                            try {
                              final databaseService = ref.read(databaseServiceProvider);
                              final product = await databaseService.getProductById(_selectedProductId!);
                              if (product != null) {
                                productToUse = product;
                              } else {
                                AppSnackBar.show(
                                  context,
                                  const SnackBar(
                                    content: Text('Product not found. Please select a valid product.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                            } catch (e) {
                              AppSnackBar.show(
                                context,
                                SnackBar(
                                  content: Text('Error loading product: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                          }

                          if (productToUse == null) {
                            AppSnackBar.show(
                              context,
                              const SnackBar(
                                content: Text('Please select a product'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          // Update product pricing with entered values
                          final updatedProduct = productToUse.copyWith(
                            cost: _unitCost,
                            price: _cashRetail,
                            retailCredit:
                                _creditRetail > 0 ? _creditRetail : null,
                            wholesaleCash:
                                _wholesaleCash > 0 ? _wholesaleCash : null,
                            wholesaleCredit: _wholesaleCredit > 0
                                ? _wholesaleCredit
                                : null,
                            marketPrice:
                                _marketPrice > 0 ? _marketPrice : null,
                          );

                          final item = PurchaseOrderItemModel(
                            id: widget.item?.id,
                            purchaseOrderId:
                                widget.item?.purchaseOrderId ?? 0,
                            productId: _selectedProductId!,
                            quantity: _quantity,
                            unitCost: _unitCost,
                            subtotal: _subtotal,
                            tax: 0,
                            discount: 0,
                            total: _subtotal,
                            createdAt: widget.item?.createdAt ?? DateTime.now(),
                            product: updatedProduct,
                          );
                          widget.onSave(item);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Save Item',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
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

  Future<void> _showProductSearchDialog(List<ProductModel> products) async {
    await showDialog(
      context: context,
      builder: (context) => _ProductSearchDialog(
        products: products,
        selectedProductId: _selectedProductId,
        currency: widget.currency,
        onSelect: (product) {
          setState(() {
            _selectedProductId = product.id;
            _selectedProduct = product;
            // Auto-fill all pricing fields if available
            if (_unitCostController.text.isEmpty && product.cost > 0) {
              _unitCostController.text = product.cost.toStringAsFixed(2);
            }
            _cashRetailController.text = product.price.toStringAsFixed(2);
            _creditRetailController.text =
                (product.retailCredit ?? 0).toStringAsFixed(2);
            _wholesaleCashController.text =
                (product.wholesaleCash ?? 0).toStringAsFixed(2);
            _wholesaleCreditController.text =
                (product.wholesaleCredit ?? 0).toStringAsFixed(2);
            _marketPriceController.text =
                (product.marketPrice ?? 0).toStringAsFixed(2);
          });
        },
      ),
    );
  }
}

// Searchable Product Dialog
class _ProductSearchDialog extends StatefulWidget {
  final List<ProductModel> products;
  final int? selectedProductId;
  final Currency currency;
  final Function(ProductModel) onSelect;

  const _ProductSearchDialog({
    required this.products,
    this.selectedProductId,
    required this.currency,
    required this.onSelect,
  });

  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<ProductModel> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    super.dispose();
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = widget.products;
      } else {
        _filteredProducts = widget.products.where((product) {
          return product.name.toLowerCase().contains(query) ||
              (product.barcode != null &&
                  product.barcode!.toLowerCase().contains(query));
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.search, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search products by name or barcode...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'No products available'
                            : 'No products found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final isSelected =
                            widget.selectedProductId == product.id;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected ? Colors.blue.shade50 : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                              child: Icon(
                                Icons.inventory_2,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                            ),
                            title: Text(
                              product.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (product.barcode != null)
                                  Text('📷 Barcode: ${product.barcode}'),
                                Text(
                                  '📦 Stock: ${product.stock.toStringAsFixed(2)} ${product.unit}',
                                  style: TextStyle(
                                    color: product.stock <= 0
                                        ? Colors.red
                                        : Colors.green.shade700,
                                  ),
                                ),
                                if (product.cost > 0)
                                  Text(
                                    '💰 Cost: ${widget.currency.symbol}${product.cost.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.blue)
                                : null,
                            onTap: () {
                              widget.onSelect(product);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
