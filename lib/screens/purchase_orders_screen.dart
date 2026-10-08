import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/purchase_order.dart';
import '../models/product.dart';
import '../models/currency.dart';
import '../providers/purchase_order_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/product_provider.dart';
import '../providers/currency_provider.dart';
import '../utils/input_formatters.dart';
import '../models/supplier.dart';
import '../widgets/app_snack_bar.dart';

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() =>
      _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> {
  String _selectedStatus = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(purchaseOrderNotifierProvider);
    final currency = ref.watch(currentCurrencyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'purchase.history_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
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
            onPressed: () {
              ref.read(purchaseOrderNotifierProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh, color: Color(0xFF3B82F6)),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () => _showAddPurchaseOrderDialog(currency),
            icon: const Icon(Icons.add, color: Color(0xFF3B82F6)),
            tooltip: 'Add Purchase Order',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Status Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by order number or supplier...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) {
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildStatusChip('Pending', 'pending'),
                      const SizedBox(width: 8),
                      _buildStatusChip('Received', 'received'),
                      const SizedBox(width: 8),
                      _buildStatusChip('Cancelled', 'cancelled'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Purchase Orders List
          Expanded(
            child: ordersAsync.when(
              data: (orders) => _buildPurchaseOrdersList(orders, currency),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(purchaseOrderNotifierProvider.notifier)
                          .refresh(),
                      child: Text('common.retry'.tr()),
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

  Widget _buildStatusChip(String label, String status) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (mounted) {
          setState(() {
            _selectedStatus = status;
          });
        }
      },
      selectedColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
      checkmarkColor: const Color(0xFF3B82F6),
    );
  }

  Widget _buildPurchaseOrdersList(
      List<PurchaseOrderModel> orders, Currency currency) {
    // Filter by status
    var filteredOrders = _selectedStatus == 'all'
        ? orders
        : orders
            .where((order) => order.status.name == _selectedStatus)
            .toList();

    // Filter by search
    if (_searchController.text.isNotEmpty) {
      final searchLower = _searchController.text.toLowerCase();
      filteredOrders = filteredOrders.where((order) {
        final orderNumberMatch =
            order.orderNumber.toLowerCase().contains(searchLower);
        final supplierMatch =
            order.supplier?.name.toLowerCase().contains(searchLower) ?? false;
        return orderNumberMatch || supplierMatch;
      }).toList();
    }

    if (filteredOrders.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return _buildPurchaseOrderCard(order, currency);
      },
    );
  }

  Widget _buildPurchaseOrderCard(PurchaseOrderModel order, Currency currency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewPurchaseOrder(order, currency),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.supplier?.name ?? 'Unknown Supplier',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(order.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    'Order: ${DateFormat('MMM dd, yyyy').format(order.orderDate)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (order.expectedDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'Expected: ${DateFormat('MMM dd, yyyy').format(order.expectedDate!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: order.isOverdue
                            ? Colors.red
                            : const Color(0xFF64748B),
                      ),
                    ),
                    if (order.isOverdue)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.warning, size: 14, color: Colors.red),
                      ),
                  ],
                ),
              ],
              if (order.receivedDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Received: ${DateFormat('MMM dd, yyyy').format(order.receivedDate!)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 24),
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
                        '${currency.symbol}${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (order.isPending) ...[
                        IconButton(
                          onPressed: () => _receivePurchaseOrder(order),
                          icon: const Icon(Icons.check_circle_outline,
                              color: Colors.green),
                          tooltip: 'Receive Order',
                        ),
                        IconButton(
                          onPressed: () => _cancelPurchaseOrder(order),
                          icon: const Icon(Icons.cancel_outlined,
                              color: Colors.red),
                          tooltip: 'Cancel Order',
                        ),
                        IconButton(
                          onPressed: () => _editPurchaseOrder(order, currency),
                          icon:
                              const Icon(Icons.edit, color: Color(0xFF3B82F6)),
                          tooltip: 'Edit',
                        ),
                      ] else ...[
                        IconButton(
                          onPressed: () => _viewPurchaseOrder(order, currency),
                          icon: const Icon(Icons.visibility,
                              color: Color(0xFF3B82F6)),
                          tooltip: 'View Details',
                        ),
                        IconButton(
                          onPressed: () =>
                              _reorderPurchaseOrder(order, currency),
                          icon: const Icon(Icons.repeat,
                              color: Color(0xFF10B981)),
                          tooltip: 'Reorder (Duplicate)',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(PurchaseOrderStatus status) {
    Color color;
    String text;

    switch (status) {
      case PurchaseOrderStatus.pending:
        color = const Color(0xFFF59E0B);
        text = 'Pending';
        break;
      case PurchaseOrderStatus.received:
        color = const Color(0xFF10B981);
        text = 'Received';
        break;
      case PurchaseOrderStatus.cancelled:
        color = const Color(0xFFEF4444);
        text = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Purchase Orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first purchase order to get started',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                _showAddPurchaseOrderDialog(ref.read(currentCurrencyProvider)),
            icon: const Icon(Icons.add),
            label: Text('purchase.create_order'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddPurchaseOrderDialog(Currency currency) async {
    await showDialog(
      context: context,
      builder: (context) => PurchaseOrderDialog(currency: currency),
    );
  }

  Future<void> _editPurchaseOrder(
      PurchaseOrderModel order, Currency currency) async {
    await showDialog(
      context: context,
      builder: (context) => PurchaseOrderDialog(
        currency: currency,
        order: order,
      ),
    );
  }

  void _viewPurchaseOrder(PurchaseOrderModel order, Currency currency) {
    // Implementation continues in next message due to length
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase Order ${order.orderNumber}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Supplier', order.supplier?.name ?? 'Unknown'),
              _buildDetailRow('Order Date',
                  DateFormat('MMM dd, yyyy').format(order.orderDate)),
              if (order.expectedDate != null)
                _buildDetailRow('Expected Date',
                    DateFormat('MMM dd, yyyy').format(order.expectedDate!)),
              if (order.receivedDate != null)
                _buildDetailRow('Received Date',
                    DateFormat('MMM dd, yyyy').format(order.receivedDate!)),
              _buildDetailRow('Status', order.status.name.toUpperCase()),
              const Divider(height: 24),
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...order.items
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product?.name ?? 'Unknown Product',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '${item.quantity} × ${currency.symbol}${item.unitCost.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${currency.symbol}${item.total.toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
              const Divider(height: 24),
              _buildDetailRow('Subtotal',
                  '${currency.symbol}${order.subtotal.toStringAsFixed(2)}'),
              if (order.discount > 0)
                _buildDetailRow('Discount',
                    '-${currency.symbol}${order.discount.toStringAsFixed(2)}'),
              if (order.tax > 0)
                _buildDetailRow(
                    'Tax', '${currency.symbol}${order.tax.toStringAsFixed(2)}'),
              _buildDetailRow('Total',
                  '${currency.symbol}${order.total.toStringAsFixed(2)}',
                  isBold: true),
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const Divider(height: 24),
                Text('common.notes_label'.tr(),
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(order.notes!),
              ],
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

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Future<void> _receivePurchaseOrder(PurchaseOrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('purchase.receive_order_title'.tr()),
        content: Text(
            'Mark ${order.orderNumber} as received and update stock levels?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('purchase.receive_btn'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true && order.id != null) {
      try {
        await ref
            .read(purchaseOrderNotifierProvider.notifier)
            .receivePurchaseOrder(order.id!);
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Purchase order received and stock updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelPurchaseOrder(PurchaseOrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('purchase.cancel_order_title'.tr()),
        content: Text('Are you sure you want to cancel ${order.orderNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.no'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('purchase.cancel_order_btn'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true && order.id != null) {
      try {
        await ref
            .read(purchaseOrderNotifierProvider.notifier)
            .cancelPurchaseOrder(order.id!);
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Purchase order cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _reorderPurchaseOrder(
      PurchaseOrderModel order, Currency currency) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('purchase.reorder_title'.tr()),
        content:
            Text('Create a new purchase order based on ${order.orderNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('purchase.reorder_btn'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Create a new order based on the existing one
        final newOrderNumber = 'PO-${DateTime.now().millisecondsSinceEpoch}';

        // Clone the order items
        final newItems = order.items.map((item) {
          return PurchaseOrderItemModel(
            purchaseOrderId: 0, // Will be set after order creation
            productId: item.productId,
            quantity: item.quantity,
            unitCost: item.unitCost,
            subtotal: item.subtotal,
            discount: item.discount,
            tax: item.tax,
            total: item.total,
            notes: item.notes,
            createdAt: DateTime.now(),
            product: item.product,
          );
        }).toList();

        // Create new purchase order
        final newOrder = PurchaseOrderModel(
          orderNumber: newOrderNumber,
          supplierId: order.supplierId,
          orderDate: DateTime.now(),
          expectedDate: DateTime.now().add(const Duration(days: 7)),
          subtotal: order.subtotal,
          tax: order.tax,
          discount: order.discount,
          total: order.total,
          status: PurchaseOrderStatus.pending,
          notes: 'Reordered from ${order.orderNumber}',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          supplier: order.supplier,
        );

        // Save the new purchase order
        await ref
            .read(purchaseOrderNotifierProvider.notifier)
            .addPurchaseOrder(newOrder, newItems);

        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Purchase order reordered: $newOrderNumber'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {
                  // The list will auto-refresh, but you could scroll to the new order
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Error reordering: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// Purchase Order Dialog for Add/Edit
class PurchaseOrderDialog extends ConsumerStatefulWidget {
  final Currency currency;
  final PurchaseOrderModel? order;

  const PurchaseOrderDialog({
    super.key,
    required this.currency,
    this.order,
  });

  @override
  ConsumerState<PurchaseOrderDialog> createState() =>
      _PurchaseOrderDialogState();
}

class _PurchaseOrderDialogState extends ConsumerState<PurchaseOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _orderNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final _taxController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');

  int? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  DateTime? _expectedDate;
  List<PurchaseOrderItemModel> _items = [];

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _orderNumberController.text = widget.order!.orderNumber;
      _notesController.text = widget.order!.notes ?? '';
      _taxController.text = widget.order!.tax.toString();
      _discountController.text = widget.order!.discount.toString();
      _selectedSupplierId = widget.order!.supplierId;
      _orderDate = widget.order!.orderDate;
      _expectedDate = widget.order!.expectedDate;
      _items = List.from(widget.order!.items);
    } else {
      // Generate order number
      _orderNumberController.text =
          'PO-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  void dispose() {
    _orderNumberController.dispose();
    _notesController.dispose();
    _taxController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.subtotal);
  double get _tax => double.tryParse(_taxController.text) ?? 0;
  double get _discount => double.tryParse(_discountController.text) ?? 0;
  double get _total => _subtotal + _tax - _discount;

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(activeSuppliersProvider);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.order == null
                ? 'Add Purchase Order'
                : 'Edit Purchase Order'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Order Number
                TextFormField(
                  controller: _orderNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Order Number *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Supplier Selection
                suppliersAsync.when(
                  data: (suppliers) {
                    if (suppliers.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                              'No suppliers available. Add suppliers first.'),
                        ),
                      );
                    }
                    return FormField<int>(
                      initialValue: _selectedSupplierId,
                      validator: (value) => value == null ? 'Required' : null,
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
                            _selectedSupplierId != null
                                ? (suppliers
                                    .firstWhere(
                                      (s) => s.id == _selectedSupplierId,
                                      orElse: () => suppliers.first,
                                    )
                                    .name)
                                : 'Select Supplier',
                            style: TextStyle(
                              color: _selectedSupplierId != null
                                  ? null
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Text('purchase.err_suppliers'.tr()),
                ),
                const SizedBox(height: 16),

                // Date Selection
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text('purchase.order_date'.tr()),
                        subtitle:
                            Text(DateFormat('MMM dd, yyyy').format(_orderDate)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _orderDate,
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            if (mounted) {
                              setState(() => _orderDate = date);
                            }
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: Text('purchase.expected_date'.tr()),
                        subtitle: Text(_expectedDate != null
                            ? DateFormat('MMM dd, yyyy').format(_expectedDate!)
                            : 'Not set'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _expectedDate ??
                                DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            if (mounted) {
                              setState(() => _expectedDate = date);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(),

                // Items Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Items',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: Text('purchase.add_item'.tr()),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Items List
                if (_items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No items added yet')),
                    ),
                  )
                else
                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item.product?.name ?? 'Unknown Product'),
                        subtitle: Text(
                          '${item.quantity} × ${widget.currency.symbol}${item.unitCost.toStringAsFixed(2)} = ${widget.currency.symbol}${item.subtotal.toStringAsFixed(2)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _editItem(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  size: 20, color: Colors.red),
                              onPressed: () {
                                if (mounted) {
                                  setState(() {
                                    _items.removeAt(index);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                const Divider(height: 32),

                // Tax and Discount
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _taxController,
                        decoration: InputDecoration(
                          labelText: 'Tax (${widget.currency.symbol})',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          DecimalInputFormatter(maxDecimalPlaces: 2),
                        ],
                        onChanged: (_) {
                          if (mounted) {
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _discountController,
                        decoration: InputDecoration(
                          labelText: 'Discount (${widget.currency.symbol})',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          DecimalInputFormatter(maxDecimalPlaces: 2),
                        ],
                        onChanged: (_) {
                          if (mounted) {
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Totals
                Card(
                  color: const Color(0xFFF1F5F9),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildTotalRow('Subtotal', _subtotal),
                        if (_discount > 0)
                          _buildTotalRow('Discount', -_discount),
                        if (_tax > 0) _buildTotalRow('Tax', _tax),
                        const Divider(),
                        _buildTotalRow('Total', _total, isBold: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _savePurchaseOrder,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF3B82F6),
              ),
              child: Text(
                widget.order == null
                    ? 'Create Purchase Order'
                    : 'Update Purchase Order',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
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
            '${widget.currency.symbol}${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem() async {
    await showDialog(
      context: context,
      builder: (context) => ItemDialog(
        currency: widget.currency,
        onSave: (item) {
          if (mounted) {
            setState(() {
              _items.add(item);
            });
          }
        },
      ),
    );
  }

  Future<void> _editItem(int index) async {
    await showDialog(
      context: context,
      builder: (context) => ItemDialog(
        currency: widget.currency,
        item: _items[index],
        onSave: (item) {
          if (mounted) {
            setState(() {
              _items[index] = item;
            });
          }
        },
      ),
    );
  }

  Future<void> _savePurchaseOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      AppSnackBar.show(
        context,
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }
    if (_selectedSupplierId == null) {
      AppSnackBar.show(
        context,
        const SnackBar(content: Text('Please select a supplier')),
      );
      return;
    }

    try {
      final order = PurchaseOrderModel(
        id: widget.order?.id,
        orderNumber: _orderNumberController.text,
        supplierId: _selectedSupplierId!,
        orderDate: _orderDate,
        expectedDate: _expectedDate,
        subtotal: _subtotal,
        tax: _tax,
        discount: _discount,
        total: _total,
        status: widget.order?.status ?? PurchaseOrderStatus.pending,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        createdAt: widget.order?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.order == null) {
        await ref
            .read(purchaseOrderNotifierProvider.notifier)
            .addPurchaseOrder(order, _items);
      } else {
        // Only allow editing if order is pending
        if (widget.order!.status != PurchaseOrderStatus.pending) {
          if (mounted) {
            AppSnackBar.show(
              context,
              const SnackBar(
                content: Text('Only pending orders can be edited'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        await ref
            .read(purchaseOrderNotifierProvider.notifier)
            .updatePurchaseOrder(order, _items);
      }

      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(widget.order == null
                ? 'Purchase order created successfully'
                : 'Purchase order updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showSupplierSearchDialog(List<SupplierModel> suppliers) async {
    await showDialog(
      context: context,
      builder: (context) => _SupplierSearchDialog(
        suppliers: suppliers,
        selectedSupplierId: _selectedSupplierId,
        onSelect: (supplierId) {
          if (mounted) {
            setState(() => _selectedSupplierId = supplierId);
          }
        },
      ),
    );
  }
}

// Supplier Search Dialog
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
                              widget.onSelect(supplier.id ?? 0);
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

// Item Dialog for adding/editing purchase order items
class ItemDialog extends ConsumerStatefulWidget {
  final Currency currency;
  final PurchaseOrderItemModel? item;
  final Function(PurchaseOrderItemModel) onSave;

  const ItemDialog({
    super.key,
    required this.currency,
    this.item,
    required this.onSave,
  });

  @override
  ConsumerState<ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends ConsumerState<ItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _unitCostController = TextEditingController();

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
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  double get _quantity => double.tryParse(_quantityController.text) ?? 0;
  double get _unitCost => double.tryParse(_unitCostController.text) ?? 0;
  double get _subtotal => _quantity * _unitCost;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return AlertDialog(
      title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product Selection
              productsAsync.when(
                data: (products) {
                  if (products.isEmpty) {
                    return Text('purchase.no_products'.tr());
                  }
                  return DropdownButtonFormField<int>(
                    value: _selectedProductId,
                    decoration: const InputDecoration(
                      labelText: 'Product *',
                      border: OutlineInputBorder(),
                    ),
                    items: products.map((product) {
                      return DropdownMenuItem(
                        value: product.id,
                        child: Text(
                            '${product.name} - ${product.barcode ?? 'No Barcode'}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _selectedProductId = value;
                          if (products.isNotEmpty) {
                            _selectedProduct = products.firstWhere(
                              (p) => p.id == value,
                              orElse: () => products
                                  .first, // Safe fallback - already checked isEmpty
                            );
                          }
                        });
                      }
                    },
                    validator: (value) => value == null ? 'Required' : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text('purchase.err_products'.tr()),
              ),
              const SizedBox(height: 16),

              // Quantity
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  DecimalInputFormatter(maxDecimalPlaces: 2),
                ],
                validator: (value) {
                  if (value?.isEmpty == true) return 'Required';
                  if (double.tryParse(value!) == null ||
                      double.parse(value) <= 0) {
                    return 'Must be greater than 0';
                  }
                  return null;
                },
                onChanged: (_) {
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 16),

              // Unit Cost
              TextFormField(
                controller: _unitCostController,
                decoration: InputDecoration(
                  labelText: 'Unit Cost (${widget.currency.symbol}) *',
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  DecimalInputFormatter(maxDecimalPlaces: 2),
                ],
                validator: (value) {
                  if (value?.isEmpty == true) return 'Required';
                  if (double.tryParse(value!) == null ||
                      double.parse(value) <= 0) {
                    return 'Must be greater than 0';
                  }
                  return null;
                },
                onChanged: (_) {
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 16),

              // Subtotal Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('reports.subtotal'.tr(),
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${widget.currency.symbol}${_subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate() && _selectedProduct != null) {
              final item = PurchaseOrderItemModel(
                id: widget.item?.id,
                purchaseOrderId: widget.item?.purchaseOrderId ?? 0,
                productId: _selectedProductId!,
                quantity: _quantity,
                unitCost: _unitCost,
                subtotal: _subtotal,
                tax: 0,
                discount: 0,
                total: _subtotal,
                createdAt: DateTime.now(),
                product: _selectedProduct,
              );
              widget.onSave(item);
              Navigator.pop(context);
            }
          },
          child: Text('common.save'.tr()),
        ),
      ],
    );
  }
}
