import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/supplier_provider.dart';
import '../providers/supplier_payment_provider.dart';
import '../providers/purchase_order_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bank_provider.dart';
import '../services/database_service.dart';
import '../models/currency.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import '../models/purchase_order.dart';
import '../models/bank.dart';
import '../models/bank_payment.dart';
import '../utils/input_formatters.dart';
import '../utils/modern_dialog_builder.dart';
import 'supplier_payment_screen.dart';
import '../services/bulk_import_service.dart';
import '../utils/navigation_helper.dart';
import '../widgets/app_snack_bar.dart';

class SupplierLedgerScreen extends ConsumerStatefulWidget {
  final int supplierId;

  const SupplierLedgerScreen({super.key, required this.supplierId});

  @override
  ConsumerState<SupplierLedgerScreen> createState() =>
      _SupplierLedgerScreenState();
}

class _SupplierLedgerScreenState extends ConsumerState<SupplierLedgerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  DateTime _startDate = DateTime(2020);
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  void _refreshData() async {
    if (mounted) {
      setState(() {
        _isRefreshing = true;
      });

      ref.invalidate(supplierByIdProvider(widget.supplierId));
      ref.invalidate(supplierPaymentsByDateRangeProvider(
          (supplierId: widget.supplierId, start: _startDate, end: _endDate)));
      ref.invalidate(purchaseOrdersBySupplierProvider(widget.supplierId));
      ref.invalidate(supplierPaymentsProvider(widget.supplierId));
      ref.invalidate(supplierBalanceProvider(widget.supplierId));

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _handleImportSupplierLedger() async {
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
            context: context, message: 'Importing supplier payments...');
      }

      final databaseService = ref.read(databaseServiceProvider);
      final result = await BulkImportService.importSupplierLedgerFromExcel(
          databaseService, file);

      if (mounted) {
        NavigationHelper.safeCloseDialog(context);
        await ModernDialogBuilder.showInfoDialog(
          context: context,
          title: 'Import Completed',
          message: 'Inserted: ${result.inserted}\nSkipped: ${result.skipped}' +
              (result.errors.isNotEmpty
                  ? '\n\nErrors (first 3):\n${result.errors.take(3).join('\n')}'
                  : ''),
          icon: Icons.cloud_done_outlined,
          iconColor: const Color(0xFF10B981),
          buttonText: 'OK',
        );
      }

      _refreshData();
    } catch (e) {
      if (mounted) {
        NavigationHelper.safeCloseDialog(context);
        AppSnackBar.show(
          context,
          SnackBar(
              content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showChequeLookupDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('ledger.search_cheque'.tr()),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'ledger.cheque_number_label'.tr(),
              hintText: 'ledger.cheque_number_hint'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _searchCheque(controller.text.trim());
              },
              child: Text('common.search'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _searchCheque(String query) async {
    if (query.isEmpty) return;
    try {
      final payments = await ref.read(supplierPaymentsByDateRangeProvider(
              (supplierId: widget.supplierId, start: _startDate, end: _endDate))
          .future);
      final matches = payments
          .where((p) =>
              (p.paymentMethod == 'cheque') &&
              ((p.reference ?? '').toLowerCase().contains(query.toLowerCase())))
          .toList();

      if (!mounted) return;
      if (matches.isEmpty) {
        AppSnackBar.show(
          context,
          const SnackBar(content: Text('No matching cheques found')),
        );
        return;
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long),
                    const SizedBox(width: 8),
                    Text('Cheques matching "$query" (${matches.length})',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = matches[index];
                      return ListTile(
                        title: Text(p.reference ?? '-'),
                        subtitle: Text(
                            '${DateFormat('dd MMM yyyy').format(p.date)} · ${p.paymentMethod} · ${p.status}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Mark Cleared',
                              icon: const Icon(Icons.check_circle,
                                  color: Color(0xFF10B981)),
                              onPressed: () async {
                                final updated = p.copyWith(
                                    status: 'completed',
                                    updatedAt: DateTime.now());
                                await ref
                                    .read(supplierPaymentsProvider(
                                            widget.supplierId)
                                        .notifier)
                                    .updatePayment(updated);
                                if (mounted) Navigator.pop(context);
                                _refreshData();
                              },
                            ),
                            IconButton(
                              tooltip: 'Mark Pending',
                              icon: const Icon(Icons.schedule,
                                  color: Color(0xFFF59E0B)),
                              onPressed: () async {
                                final updated = p.copyWith(
                                    status: 'pending',
                                    updatedAt: DateTime.now());
                                await ref
                                    .read(supplierPaymentsProvider(
                                            widget.supplierId)
                                        .notifier)
                                    .updatePayment(updated);
                                if (mounted) Navigator.pop(context);
                                _refreshData();
                              },
                            ),
                            IconButton(
                              tooltip: 'Mark Cancelled',
                              icon: const Icon(Icons.cancel,
                                  color: Color(0xFFEF4444)),
                              onPressed: () async {
                                final updated = p.copyWith(
                                    status: 'cancelled',
                                    updatedAt: DateTime.now());
                                await ref
                                    .read(supplierPaymentsProvider(
                                            widget.supplierId)
                                        .notifier)
                                    .updatePayment(updated);
                                if (mounted) Navigator.pop(context);
                                _refreshData();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        SnackBar(
            content: Text('Search failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplierAsync = ref.watch(supplierByIdProvider(widget.supplierId));
    final purchaseOrdersAsync =
        ref.watch(purchaseOrdersBySupplierProvider(widget.supplierId));
    final paymentsAsync = ref.watch(supplierPaymentsByDateRangeProvider(
        (supplierId: widget.supplierId, start: _startDate, end: _endDate)));
    final currency = ref.watch(currentCurrencyProvider);
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F4FD),
      appBar: AppBar(
        title: Text('ledger.supplier'.tr()),
        backgroundColor: const Color(0xFF6BA6D3),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/suppliers');
            }
          },
          tooltip: 'Back',
        ),
        actions: [
          if (_isRefreshing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
              tooltip: 'Refresh Data',
            ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              final supplierAsync =
                  ref.read(supplierByIdProvider(widget.supplierId));
              final supplier = supplierAsync.valueOrNull;
              if (supplier != null) {
                await _showDownloadDateRangeDialog(supplier, currency);
              }
            },
            tooltip: 'Download PDF',
          ),
          if (currentUser?.isAdmin == true || currentUser?.isManager == true)
            IconButton(
              icon: const Icon(Icons.payment),
              onPressed: () => _navigateToPaymentScreen(),
              tooltip: 'Record Payment',
            ),
        ],
      ),
      body: Stack(
        children: [
          supplierAsync.when(
            data: (supplier) => _buildLedgerContent(
                supplier, purchaseOrdersAsync, paymentsAsync, currency),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _buildErrorWidget(error),
          ),
          if (_isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: const SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLedgerContent(
      SupplierModel? supplier,
      AsyncValue<List<PurchaseOrderModel>> purchaseOrdersAsync,
      AsyncValue<List<SupplierPaymentModel>> paymentsAsync,
      Currency currency) {
    if (supplier == null) {
      return const Center(
        child: Text('Supplier not found'),
      );
    }

    return Column(
      children: [
        _buildProfessionalSupplierInfo(supplier, currency, purchaseOrdersAsync),
        Expanded(
          child: Column(
            children: [
              Container(
                color: const Color(0xFF6BA6D3),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Purchase Invoices'),
                    Tab(text: 'Payment Details'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPurchaseInvoicesTab(purchaseOrdersAsync, currency),
                    _buildPaymentDetailsTab(paymentsAsync, currency),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalSupplierInfo(
      SupplierModel supplier,
      Currency currency,
      AsyncValue<List<PurchaseOrderModel>> purchaseOrdersAsync) {
    final basicFields = [
      _buildInfoField('Party Name', supplier.name),
      _buildInfoField('Other Name', supplier.contactPerson),
      _buildInfoField('Cell No.', supplier.phone),
      _buildInfoField('Address', supplier.address ?? 'N/A'),
      _buildEditableCodeField(supplier),
      _buildInfoField('Active', supplier.isActive ? 'Yes' : 'No'),
    ];

    final financialFields = [
      _buildInfoField(
        'Balance',
        '${currency.symbol}${(supplier.currentBalance - supplier.unclearCheque).toStringAsFixed(2)}',
      ),
      // Credit limit is intentionally hidden in the UI as per current requirement
      _buildInfoField('Credit Days', supplier.creditDays.toString()),
      _buildInfoField(
        'Unclear Cheque',
        '${currency.symbol}${supplier.unclearCheque.toStringAsFixed(2)}',
      ),
      _buildInfoField('Payment Terms', supplier.paymentTerms),
    ];

    return Container(
      color: const Color(0xFFE3F2FD),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResponsiveInfoGrid(basicFields),
          const SizedBox(height: 12),
          const Divider(color: Colors.grey, height: 1),
          const SizedBox(height: 12),
          _buildResponsiveInfoGrid(financialFields),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _generateLedgerReport(supplier, currency),
                icon: const Icon(Icons.description, color: Colors.black87),
                label: Text(
                  'ledger.ledger_report'.tr(),
                  style: const TextStyle(color: Colors.black87),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  final authState = ref.read(authProvider);
                  if (authState.currentUser?.isAdmin == true ||
                      authState.currentUser?.isManager == true ||
                      authState.currentUser?.isCashier == true) {
                    _navigateToPaymentScreen();
                  } else {
                    AppSnackBar.show(
                      context,
                      const SnackBar(
                          content: Text(
                              'Only admins, managers, and cashiers can record payments')),
                    );
                  }
                },
                icon: const Icon(Icons.attach_money, color: Colors.black87),
                label: Text(
                  'ledger.cash_received'.tr(),
                  style: const TextStyle(color: Colors.black87),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  final authState = ref.read(authProvider);
                  if (authState.currentUser?.isAdmin == true ||
                      authState.currentUser?.isManager == true) {
                    _showPartyBankPaymentDialog(supplier, currency);
                  } else {
                    AppSnackBar.show(
                      context,
                      const SnackBar(
                          content: Text(
                              'Only admins and managers can record payments')),
                    );
                  }
                },
                icon: const Icon(Icons.account_balance, color: Colors.black87),
                label: Text(
                  'ledger.bank_received'.tr(),
                  style: const TextStyle(color: Colors.black87),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(width: 8),
              Consumer(
                builder: (context, ref, child) {
                  final authState = ref.watch(authProvider);
                  final currentUser = authState.currentUser;
                  final canEdit = currentUser?.canEditSupplier() ?? false;
                  
                  if (!canEdit) return const SizedBox.shrink();
                  
                  return TextButton.icon(
                    onPressed: () => context.go('/edit-supplier?id=${supplier.id}'),
                    icon: const Icon(Icons.edit, color: Colors.black87),
                    label: Text(
                      'ledger.edit_supplier'.tr(),
                      style: const TextStyle(color: Colors.black87),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveInfoGrid(List<Widget> fields) {
    const spacing = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        int columns;
        if (availableWidth >= 900) {
          columns = 5;
        } else {
          columns = math.max(1, (availableWidth / 160).floor());
        }
        final effectiveColumns = math.max(columns, 1);
        final fieldWidth = math.max(
            140.0,
            (availableWidth - spacing * (effectiveColumns - 1)) /
                effectiveColumns);

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: fields
              .map(
                (field) => SizedBox(
                  width: fieldWidth,
                  child: field,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildEditableCodeField(SupplierModel supplier) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.currentUser?.isAdmin == true ||
        authState.currentUser?.isManager == true;
    final fallbackCode =
        'SUP-${supplier.id?.toString().padLeft(4, '0') ?? 'XXXX'}';
    final displayCode =
        supplier.code.trim().isEmpty ? fallbackCode : supplier.code;

    return InkWell(
      onTap: isAdmin ? () => _showEditSupplierCodeDialog(supplier) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Code',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.edit,
                    size: 14,
                    color: Colors.black87,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              displayCode,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSupplierCodeDialog(SupplierModel supplier) {
    final controller = TextEditingController(text: supplier.code);
    final regex = RegExp(r'^[A-Za-z0-9\-_]+$');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6BA6D3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.confirmation_number, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'EDIT SUPPLIER CODE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Supplier Code',
                  hintText: 'e.g., SUP-2312',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('common.cancel'.tr()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final newCode = controller.text.trim().toUpperCase();
                        if (newCode.isEmpty) {
                          AppSnackBar.show(
                            context,
                            const SnackBar(
                                content: Text('Code cannot be empty')),
                          );
                          return;
                        }
                        if (!regex.hasMatch(newCode)) {
                          AppSnackBar.show(
                            context,
                            const SnackBar(
                                content: Text(
                                    'Use only letters, numbers, hyphen, or underscore')),
                          );
                          return;
                        }
                        if (newCode == supplier.code.toUpperCase()) {
                          Navigator.pop(context);
                          return;
                        }

                        Navigator.pop(context);

                        try {
                          final updatedSupplier = supplier.copyWith(
                            code: newCode,
                            updatedAt: DateTime.now(),
                          );
                          await ref
                              .read(supplierNotifierProvider.notifier)
                              .updateSupplier(updatedSupplier);
                          if (mounted) {
                            AppSnackBar.show(
                              context,
                              const SnackBar(
                                content:
                                    Text('Supplier code updated successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _refreshData();
                          }
                        } catch (e) {
                          if (mounted) {
                            AppSnackBar.show(
                              context,
                              SnackBar(
                                content: Text('Error updating code: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6BA6D3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('common.save'.tr()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseInvoicesTab(
      AsyncValue<List<PurchaseOrderModel>> purchaseOrdersAsync,
      Currency currency) {
    return purchaseOrdersAsync.when(
      data: (purchaseOrders) {
        final filteredOrders = purchaseOrders
            .where((order) => _isDateInRange(order.orderDate))
            .toList();
        filteredOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

        if (filteredOrders.isEmpty) {
          return _buildEmptyState('No Purchase Invoices found');
        }

        final supplierAsync =
            ref.watch(supplierByIdProvider(widget.supplierId));
        double runningBalance =
            supplierAsync.valueOrNull?.currentBalance ?? 0.0;

        final reversedOrders = filteredOrders.reversed.toList();
        final ordersWithBalance = <PurchaseOrderWithBalance>[];

        for (var i = 0; i < reversedOrders.length; i++) {
          final order = reversedOrders[i];
          runningBalance += order.total;
          ordersWithBalance.add(PurchaseOrderWithBalance(
            order: order,
            previousBalance: i > 0
                ? ordersWithBalance[i - 1].balance
                : supplierAsync.valueOrNull?.currentBalance ?? 0.0,
            payableAmount: order.total,
            balance: runningBalance,
          ));
        }

        final finalList = ordersWithBalance.reversed.toList();
        final totalPayable =
            filteredOrders.fold<double>(0.0, (sum, order) => sum + order.total);

        final screenSize = MediaQuery.of(context).size;
        final isMobile = screenSize.width < 768;

        return Column(
          children: [
            if (!isMobile) ...[
              // Table Header (Desktop only)
              Container(
                color: const Color(0xFF6BA6D3),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _buildTableHeader('Order Date')),
                    Expanded(flex: 2, child: _buildTableHeader('Order No')),
                    Expanded(flex: 2, child: _buildTableHeader('Status')),
                    Expanded(flex: 2, child: _buildTableHeader('User')),
                    Expanded(flex: 2, child: _buildTableHeader('DateTime')),
                    Expanded(flex: 2, child: _buildTableHeader('Payable Rs.')),
                  ],
                ),
              ),
            ],
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(
                      purchaseOrdersBySupplierProvider(widget.supplierId));
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: isMobile
                    ? ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: finalList.length,
                        itemBuilder: (context, index) {
                          final orderWithBalance = finalList[index];
                          return _buildPurchaseOrderCard(
                              orderWithBalance, currency, index);
                        },
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: finalList.length,
                        itemBuilder: (context, index) {
                          final orderWithBalance = finalList[index];
                          return _buildPurchaseOrderRow(
                              orderWithBalance, currency, index);
                        },
                      ),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Spacer(),
                  const Text(
                    'Total:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${currency.symbol}${totalPayable.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6BA6D3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(error),
    );
  }

  Widget _buildTableHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildPurchaseOrderCard(
      PurchaseOrderWithBalance orderWithBalance, Currency currency, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFF6BA6D3).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () =>
            _showPurchaseOrderDetailsDialog(orderWithBalance.order, currency),
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
                      color: const Color(0xFF6BA6D3).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: Color(0xFF6BA6D3),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderWithBalance.order.orderNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd-MMM-yyyy')
                              .format(orderWithBalance.order.orderDate),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Invoice Time: ${DateFormat('dd-MM-yyyy hh:mm a').format(orderWithBalance.order.createdAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Generated By: N/A',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(orderWithBalance.order.status)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              _getStatusColor(orderWithBalance.order.status)),
                    ),
                    child: Text(
                      orderWithBalance.order.status.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(orderWithBalance.order.status),
                      ),
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
                  const Text(
                    'Payable Amount',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    '${currency.symbol}${orderWithBalance.payableAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF6BA6D3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.pending:
        return Colors.orange;
      case PurchaseOrderStatus.received:
        return Colors.green;
      case PurchaseOrderStatus.cancelled:
        return Colors.red;
      default:
        return const Color(0xFF6BA6D3);
    }
  }

  Widget _buildPurchaseOrderRow(
      PurchaseOrderWithBalance orderWithBalance, Currency currency, int index) {
    final isEven = index % 2 == 0;
    return InkWell(
      onTap: () =>
          _showPurchaseOrderDetailsDialog(orderWithBalance.order, currency),
      child: Container(
        color: isEven ? Colors.white : const Color(0xFFF5F5F5),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                DateFormat('dd-MM-yyyy')
                    .format(orderWithBalance.order.orderDate),
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                orderWithBalance.order.orderNumber,
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                orderWithBalance.order.status.name.toUpperCase(),
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'N/A',
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                DateFormat('dd-MM-yyyy hh:mm a')
                    .format(orderWithBalance.order.createdAt),
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                orderWithBalance.payableAmount.toStringAsFixed(2),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsTab(
      AsyncValue<List<SupplierPaymentModel>> paymentsAsync, Currency currency) {
    // Watch bank payments to check cheque status
    final bankPaymentsAsync = ref.watch(allBankPaymentsProvider);
    final supplierAsync = ref.watch(supplierByIdProvider(widget.supplierId));
    
    return paymentsAsync.when(
      data: (payments) {
        final filteredPayments =
            payments.where((payment) => _isDateInRange(payment.date)).toList();
        filteredPayments.sort((a, b) => b.date.compareTo(a.date));

        if (filteredPayments.isEmpty) {
          return _buildEmptyState('No Payment Details found');
        }

        double runningBalance =
            supplierAsync.valueOrNull?.currentBalance ?? 0.0;
        
        // Get bank payments for cheque status checking
        final bankPayments = bankPaymentsAsync.valueOrNull ?? [];
        final supplierName = supplierAsync.valueOrNull?.name ?? '';

        final reversedPayments = filteredPayments.reversed.toList();
        final paymentsWithBalance = <SupplierPaymentWithBalance>[];

        for (var i = 0; i < reversedPayments.length; i++) {
          final payment = reversedPayments[i];
          final isCheque = payment.paymentMethod == 'cheque';
          final isCancelled = payment.status == 'cancelled';
          final isCancelledCheque = isCheque && isCancelled;

          // Only reduce balance if payment is not a cancelled cheque
          if (!isCancelledCheque) {
            runningBalance -= payment.amount;
          }

          paymentsWithBalance.add(SupplierPaymentWithBalance(
            payment: payment,
            previousBalance: i > 0
                ? paymentsWithBalance[i - 1].balance
                : supplierAsync.valueOrNull?.currentBalance ?? 0.0,
            paidAmount: payment.amount,
            balance: runningBalance,
          ));
        }

        final finalList = paymentsWithBalance.reversed.toList();
        // Exclude cancelled cheques from totals
        final totalPaid = filteredPayments.fold<double>(0.0, (sum, payment) {
          final isCheque = payment.paymentMethod == 'cheque';
          final isCancelled = payment.status == 'cancelled';
          final isCancelledCheque = isCheque && isCancelled;
          if (isCancelledCheque) return sum;
          return sum + payment.amount;
        });
        final cashTotal = filteredPayments
            .where((p) => p.paymentMethod == 'cash')
            .fold<double>(0.0, (sum, p) => sum + p.amount);
        final bankTotal = filteredPayments
            .where((p) =>
                (p.paymentMethod == 'bank_transfer' ||
                    p.paymentMethod == 'cheque') &&
                !(p.paymentMethod == 'cheque' && p.status == 'cancelled'))
            .fold<double>(0.0, (sum, p) => sum + p.amount);

        // Total number of cheques in the filtered range (all cheque payments)
        final totalCheques = filteredPayments
            .where((p) => p.paymentMethod == 'cheque')
            .length;

        final screenSize = MediaQuery.of(context).size;
        final isMobile = screenSize.width < 768;

        return Column(
          children: [
            if (!isMobile) ...[
              // Table Header (Desktop only)
              Container(
                color: const Color(0xFF6BA6D3),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _buildTableHeader('Other Name')),
                    Expanded(flex: 2, child: _buildTableHeader('Bank / Cash')),
                    Expanded(flex: 2, child: _buildTableHeader('Cheque No')),
                    Expanded(flex: 2, child: _buildTableHeader('Cheque Date')),
                    Expanded(flex: 2, child: _buildTableHeader('Issue Date')),
                    Expanded(flex: 2, child: _buildTableHeader('Paid Amount')),
                    Expanded(flex: 2, child: _buildTableHeader('User')),
                    Expanded(
                        flex: 2,
                        child: _buildTableHeader('Cancel / Clear Date')),
                  ],
                ),
              ),
            ],
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(supplierPaymentsByDateRangeProvider((
                    supplierId: widget.supplierId,
                    start: _startDate,
                    end: _endDate
                  )));
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: isMobile
                    ? ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: finalList.length,
                        itemBuilder: (context, index) {
                          final paymentWithBalance = finalList[index];
                          return _buildSupplierPaymentCard(
                              paymentWithBalance, currency, index, bankPayments, supplierName);
                        },
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: finalList.length,
                        itemBuilder: (context, index) {
                          final paymentWithBalance = finalList[index];
                          return _buildSupplierPaymentRow(
                              paymentWithBalance, currency, index, bankPayments, supplierName);
                        },
                      ),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'CASH:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cashTotal.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'BANK:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          bankTotal.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Total:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  totalPaid.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Cheques:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  totalCheques.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4A90E2),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(error),
    );
  }

  Widget _buildSupplierPaymentCard(
      SupplierPaymentWithBalance paymentWithBalance,
      Currency currency,
      int index,
      List<BankPaymentModel> bankPayments,
      String supplierName) {
    final isNegative = paymentWithBalance.paidAmount < 0;
    final isCancelled = paymentWithBalance.payment.status == 'cancelled';
    final isCheque = paymentWithBalance.payment.paymentMethod == 'cheque';
    final isCancelledCheque = isCheque && isCancelled;
    
    // For cheques, check if it's unclear/pending by looking up bank payment status
    bool isUnclearPendingCheque = false;
    if (isCheque && !isCancelled && paymentWithBalance.payment.reference != null) {
      try {
        final matchingBankPayment = bankPayments.firstWhere(
          (bp) => bp.chequeNumber == paymentWithBalance.payment.reference &&
                  bp.partyName.toLowerCase() == supplierName.toLowerCase(),
        );
        final bankStatus = matchingBankPayment.status.toLowerCase();
        isUnclearPendingCheque = bankStatus == 'pending' || bankStatus == 'unclear';
      } catch (e) {
        // Bank payment not found, treat as normal payment
      }
    }
    
    final isPending = paymentWithBalance.payment.status == 'pending' || isUnclearPendingCheque;
    final isCompleted = (paymentWithBalance.payment.status == 'completed' || 
                        paymentWithBalance.payment.status == 'cleared') && !isUnclearPendingCheque;

    // Determine row color based on status
    final rowColor = isCancelledCheque
        ? Colors.red.shade50
        : (isCompleted
            ? Colors.green.shade50
            : (isPending ? Colors.orange.shade50 : Colors.white));

    // Determine text color based on status
    final textColor = isCancelledCheque
        ? Colors.red.shade700
        : (isCompleted
            ? Colors.green.shade700
            : (isPending ? Colors.orange.shade700 : const Color(0xFF1E293B)));

    // Determine status color for icon/border
    final statusColor = isCancelledCheque
        ? Colors.red
        : (isCompleted
            ? Colors.green
            : (isPending ? Colors.orange : const Color(0xFF6BA6D3)));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      color: rowColor,
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
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isCheque ? Icons.account_balance_wallet : Icons.money,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paymentWithBalance.payment.otherName?.isNotEmpty == true
                            ? paymentWithBalance.payment.otherName!
                            : paymentWithBalance.payment.paymentMethod
                                .toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getPaymentTypeDisplay(
                            paymentWithBalance.payment.paymentMethod),
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCancelledCheque)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: const Text(
                      'CANCELLED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (isCheque &&
                paymentWithBalance.payment.reference?.isNotEmpty == true) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cheque No',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          paymentWithBalance.payment.reference!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
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
                          'Cheque Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          paymentWithBalance.payment.chequeDate != null
                              ? DateFormat('dd-MM-yyyy').format(
                                  paymentWithBalance.payment.chequeDate!)
                              : 'Required',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: paymentWithBalance.payment.chequeDate == null
                                ? Colors.orange
                                : textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Issue Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd-MM-yyyy').format(
                          paymentWithBalance.payment.issueDate ??
                              paymentWithBalance.payment.date,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
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
                        'Paid Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currency.symbol}${paymentWithBalance.paidAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCancelledCheque
                              ? Colors.red.shade700
                              : (isNegative ? Colors.red : Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (paymentWithBalance.payment.createdBy != null &&
                paymentWithBalance.payment.createdBy!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'User: ${paymentWithBalance.payment.createdBy}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
            if (isCancelled ||
                paymentWithBalance.payment.status == 'cleared') ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCancelled ? Icons.cancel : Icons.check_circle,
                      size: 16,
                      color: isCancelled ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCancelled ? 'Payment Cancelled' : 'Payment Cleared',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isCancelled ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierPaymentRow(
      SupplierPaymentWithBalance paymentWithBalance,
      Currency currency,
      int index,
      List<BankPaymentModel> bankPayments,
      String supplierName) {
    final isEven = index % 2 == 0;
    final isNegative = paymentWithBalance.paidAmount < 0;
    final isCancelled = paymentWithBalance.payment.status == 'cancelled';
    final isCheque = paymentWithBalance.payment.paymentMethod == 'cheque';
    final isCancelledCheque = isCheque && isCancelled;
    
    // For cheques, check if it's unclear/pending by looking up bank payment status
    bool isUnclearPendingCheque = false;
    if (isCheque && !isCancelled && paymentWithBalance.payment.reference != null) {
      try {
        final matchingBankPayment = bankPayments.firstWhere(
          (bp) => bp.chequeNumber == paymentWithBalance.payment.reference &&
                  bp.partyName.toLowerCase() == supplierName.toLowerCase(),
        );
        final bankStatus = matchingBankPayment.status.toLowerCase();
        isUnclearPendingCheque = bankStatus == 'pending' || bankStatus == 'unclear';
      } catch (e) {
        // Bank payment not found, treat as normal payment
      }
    }
    
    final isPending = paymentWithBalance.payment.status == 'pending' || isUnclearPendingCheque;
    final isCompleted = (paymentWithBalance.payment.status == 'completed' || 
                        paymentWithBalance.payment.status == 'cleared') && !isUnclearPendingCheque;

    // Determine row color based on status
    Color rowColor;
    if (isCancelledCheque) {
      rowColor = Colors.red.shade50;
    } else if (isCompleted) {
      rowColor = Colors.green.shade50;
    } else if (isPending) {
      rowColor = Colors.orange.shade50;
    } else {
      rowColor = isEven ? Colors.white : const Color(0xFFF5F5F5);
    }

    // Determine text color based on status
    Color textColor;
    if (isCancelledCheque) {
      textColor = Colors.red.shade700;
    } else if (isCompleted) {
      textColor = Colors.green.shade700;
    } else if (isPending) {
      textColor = Colors.orange.shade700;
    } else {
      textColor = const Color(0xFF1E293B);
    }

    return Container(
      color: rowColor,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              paymentWithBalance.payment.otherName?.isNotEmpty == true
                  ? paymentWithBalance.payment.otherName!
                  : paymentWithBalance.payment.paymentMethod.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight:
                    isCancelledCheque ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _getPaymentTypeDisplay(paymentWithBalance.payment.paymentMethod),
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight:
                    isCancelledCheque ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              paymentWithBalance.payment.reference?.isNotEmpty == true
                  ? paymentWithBalance.payment.reference!
                  : '-',
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight:
                    isCancelledCheque ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              paymentWithBalance.payment.chequeDate != null
                  ? DateFormat('dd-MM-yyyy')
                      .format(paymentWithBalance.payment.chequeDate!)
                  : (isCheque ? 'Required' : '-'),
              style: TextStyle(
                fontSize: 13,
                color: isCheque && paymentWithBalance.payment.chequeDate == null
                    ? Colors.orange
                    : textColor,
                fontWeight:
                    isCancelledCheque ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd-MM-yyyy').format(
                paymentWithBalance.payment.issueDate ??
                    paymentWithBalance.payment.date,
              ),
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight:
                    isCancelledCheque ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              paymentWithBalance.paidAmount.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isCancelledCheque
                    ? Colors.red.shade700
                    : (isNegative ? Colors.red : Colors.green),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              paymentWithBalance.payment.createdBy ?? 'Unknown',
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight:
                    isCancelledCheque ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _getCancelOrClearDate(paymentWithBalance.payment) ?? '-',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isCancelledCheque ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentTypeDisplay(String method) {
    switch (method) {
      case 'cash':
        return 'CASH';
      case 'bank_transfer':
        return 'BANK';
      case 'cheque':
        return 'CHEQUE';
      default:
        return method.toUpperCase();
    }
  }

  String? _getCancelOrClearDate(SupplierPaymentModel payment) {
    // Use updatedAt as a proxy for status change date when cheque cleared/cancelled; otherwise null
    if (payment.paymentMethod == 'cheque') {
      if (payment.status == 'cancelled' ||
          payment.status == 'cleared' ||
          payment.status == 'completed') {
        return DateFormat('dd-MM-yyyy').format(payment.updatedAt);
      }
    }
    return null;
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(Object error) {
    return Center(
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
            'Error loading ledger',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(supplierByIdProvider(widget.supplierId));
              ref.invalidate(supplierPaymentsByDateRangeProvider((
                supplierId: widget.supplierId,
                start: _startDate,
                end: _endDate
              )));
              ref.invalidate(
                  purchaseOrdersBySupplierProvider(widget.supplierId));
            },
            child: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }

  bool _isDateInRange(DateTime date) {
    return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
        date.isBefore(_endDate.add(const Duration(days: 1)));
  }

  void _showPurchaseOrderDetailsDialog(
      PurchaseOrderModel order, Currency currency) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF6BA6D3),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_cart,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchase Order #${order.orderNumber}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            DateFormat('dd MMMM yyyy').format(order.orderDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (order.supplier != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: const Color(0xFFF8FAFC),
                          child: Row(
                            children: [
                              const Icon(Icons.business,
                                  color: Color(0xFF64748B)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.supplier!.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (order.supplier!.phone.isNotEmpty)
                                      Text(
                                        order.supplier!.phone,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: const Color(0xFFF8FAFC),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time,
                                color: Color(0xFF64748B), size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invoice Time: ${DateFormat('dd-MM-yyyy hh:mm a').format(order.createdAt)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Generated By: N/A',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                      color: Color(0xFFE2E8F0), width: 2),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Product',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Qty',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Rate',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B),
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B),
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...order.items.map((item) => Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                          color: Color(0xFFE2E8F0), width: 1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          item.product?.name ??
                                              'Unknown Product',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          item.quantity.toStringAsFixed(2),
                                          style: const TextStyle(fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '${currency.symbol}${item.unitCost.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 13),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '${currency.symbol}${item.total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                        'Subtotal:',
                        '${currency.symbol}${order.subtotal.toStringAsFixed(2)}',
                        false),
                    if (order.discount > 0)
                      _buildSummaryRow(
                          'Discount:',
                          '-${currency.symbol}${order.discount.toStringAsFixed(2)}',
                          false),
                    _buildSummaryRow(
                        'Total:',
                        '${currency.symbol}${order.total.toStringAsFixed(2)}',
                        true),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _printPurchaseInvoice(order, currency),
                            icon: const Icon(Icons.print, size: 18),
                            label: Text('common.print'.tr()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6BA6D3),
                              side: const BorderSide(color: Color(0xFF6BA6D3)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _editPurchaseInvoice(order);
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: Text('ledger.edit_add_items'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('common.close'.tr()),
                      ),
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

  Future<void> _printPurchaseInvoice(
      PurchaseOrderModel order, Currency currency) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final businessName =
          await databaseService.getSetting('business_name') ?? 'My Business';
      final businessAddress =
          await databaseService.getSetting('business_address') ?? '';
      final businessPhone =
          await databaseService.getSetting('business_phone') ?? '';

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'PURCHASE INVOICE',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    businessName,
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  if (businessAddress.isNotEmpty)
                    pw.Text(
                      businessAddress,
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  if (businessPhone.isNotEmpty)
                    pw.Text(
                      'Phone: $businessPhone',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            // Invoice Details
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Invoice No: ${order.orderNumber}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Date: ${DateFormat('dd MMM yyyy').format(order.orderDate)}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    if (order.receivedDate != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Received: ${DateFormat('dd MMM yyyy').format(order.receivedDate!)}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
                if (order.supplier != null)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Supplier Details',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        order.supplier!.name,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      if (order.supplier!.phone.isNotEmpty)
                        pw.Text(
                          'Phone: ${order.supplier!.phone}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      if (order.supplier!.address != null &&
                          order.supplier!.address!.isNotEmpty)
                        pw.Text(
                          order.supplier!.address!,
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 30),
            // Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Product',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Qty',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Rate',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Total',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                ...order.items.map((item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            item.product?.name ?? 'Unknown Product',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            item.quantity.toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 10),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${currency.symbol}${item.unitCost.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 10),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${currency.symbol}${item.total.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 10),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    )),
              ],
            ),
            pw.SizedBox(height: 20),
            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Subtotal:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '${currency.symbol}${order.subtotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (order.discount > 0)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Discount:',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            '-${currency.symbol}${order.discount.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total:',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '${currency.symbol}${order.total.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Notes:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      order.notes!,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Invoice PDF generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editPurchaseInvoice(PurchaseOrderModel order) {
    // Convert order items to the format expected by purchase invoice screen
    final preFillItems = order.items.map((item) {
      return {
        'id': item.id, // Include item ID for editing
        'productId': item.productId,
        'product': item.product,
        'quantity': item.quantity,
        'unitCost': item.unitCost,
        'subtotal': item.subtotal,
      };
    }).toList();

    // Navigate to purchase invoice screen with pre-filled data
    context.push(
      '/purchase-invoice',
      extra: {
        'supplierId': order.supplierId,
        'invoiceNumber': order.orderNumber,
        'orderDate': order.orderDate,
        'receivedDate': order.receivedDate ?? order.orderDate,
        'notes': order.notes,
        'preFillItems': preFillItems,
        'orderId':
            order.id, // Pass order ID so we can update existing order if needed
      },
    ).then((_) {
      _refreshData();
    });
  }

  Widget _buildSummaryRow(String label, String value, bool isTotal) {
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
              color: const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              color:
                  isTotal ? const Color(0xFF6BA6D3) : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPaymentScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SupplierPaymentScreen(supplierId: widget.supplierId),
      ),
    ).then((_) {
      _refreshData();
    });
  }

  void _showPartyBankPaymentDialog(SupplierModel supplier, Currency currency) {
    final amountController = TextEditingController();
    final chequeNoController = TextEditingController();
    final otherNameController = TextEditingController();
    final selectedBankNotifier = ValueNotifier<BankModel?>(null);
    final chequeDateNotifier = ValueNotifier<DateTime?>(null);

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final banksAsync = ref.watch(activeBanksProvider);

          return ValueListenableBuilder<BankModel?>(
            valueListenable: selectedBankNotifier,
            builder: (context, selectedBank, _) {
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return Dialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Container(
                        width: 600,
                        padding: const EdgeInsets.all(20),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6BA6D3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.account_balance,
                                    color: Colors.white),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'PARTY BANK PAYMENT',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ledger.party_name'.tr(),
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text(supplier.name),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: otherNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Other Name',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Bank Selection Dropdown
                          banksAsync.when(
                            data: (banks) {
                              if (banks.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    'No active banks found. Please add a bank first.',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Select Bank Account:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<BankModel>(
                                    value: selectedBank,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.account_balance),
                                    ),
                                    hint: Text('ledger.select_bank_hint'.tr()),
                                    items: banks.map((bank) {
                                      return DropdownMenuItem<BankModel>(
                                        value: bank,
                                        child: Text(
                                          bank.accountNumber != null &&
                                                  bank.accountNumber!.isNotEmpty
                                              ? '${bank.name} (${bank.accountNumber})'
                                              : bank.name,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (bank) {
                                      selectedBankNotifier.value = bank;
                                      setDialogState(() {});
                                    },
                                  ),
                                ],
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (error, stack) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Error loading banks: $error',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: chequeNoController,
                                  decoration: const InputDecoration(
                                    labelText: 'Cheq No',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: chequeDateNotifier.value ??
                                          DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 365)),
                                    );
                                    if (pickedDate != null) {
                                      chequeDateNotifier.value = pickedDate;
                                      setDialogState(() {});
                                    }
                                  },
                                  child: ValueListenableBuilder<DateTime?>(
                                    valueListenable: chequeDateNotifier,
                                    builder: (context, chequeDate, child) {
                                      return InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Cheque Date',
                                          border: OutlineInputBorder(),
                                          suffixIcon:
                                              Icon(Icons.calendar_today),
                                        ),
                                        child: Text(
                                          chequeDate != null
                                              ? DateFormat('dd-MM-yyyy')
                                                  .format(chequeDate)
                                              : 'Select Cheque Date',
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: amountController,
                            decoration: InputDecoration(
                              labelText: 'Cheq Amount',
                              border: const OutlineInputBorder(),
                              prefixText: currency.symbol,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              DecimalInputFormatter(maxDecimalPlaces: 2)
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('common.cancel'.tr()),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final selectedBank =
                                        selectedBankNotifier.value;
                                    if (selectedBank == null) {
                                      AppSnackBar.show(
                                        context,
                                        const SnackBar(
                                            content: Text(
                                                'Please select a bank account')),
                                      );
                                      return;
                                    }

                                    if (amountController.text.isEmpty) {
                                      AppSnackBar.show(
                                        context,
                                        const SnackBar(
                                            content: Text(
                                                'Please enter cheque amount')),
                                      );
                                      return;
                                    }

                                    final amount = double.tryParse(
                                            amountController.text) ??
                                        0.0;
                                    if (amount <= 0) {
                                      AppSnackBar.show(
                                        context,
                                        const SnackBar(
                                            content: Text(
                                                'Amount must be greater than 0')),
                                      );
                                      return;
                                    }

                                    Navigator.pop(context);

                                    try {
                                      // Get current user for createdBy field
                                      final currentUser = ref.read(authProvider).currentUser;
                                      final createdByName = currentUser?.name ?? 'Unknown';
                                      
                                      // Create supplier payment record
                                      final payment = SupplierPaymentModel(
                                        supplierId: widget.supplierId,
                                        amount: amount,
                                        paymentMethod: 'cheque',
                                        paymentType: 'payment',
                                        date: DateTime.now(),
                                        reference: chequeNoController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : chequeNoController.text.trim(),
                                        otherName: otherNameController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : otherNameController.text.trim(),
                                        createdBy: createdByName,
                                        createdAt: DateTime.now(),
                                        updatedAt: DateTime.now(),
                                      );

                                      await ref
                                          .read(supplierPaymentsProvider(
                                                  widget.supplierId)
                                              .notifier)
                                          .addPayment(payment);

                                      // Create bank payment record
                                      final databaseService =
                                          ref.read(databaseServiceProvider);
                                      final bankPayment = BankPaymentModel(
                                        bankId: selectedBank!.id!,
                                        partyName: supplier.name,
                                        otherName: otherNameController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : otherNameController.text.trim(),
                                        amount: amount,
                                        paymentType: 'cheque',
                                        chequeNumber: chequeNoController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : chequeNoController.text.trim(),
                                        chequeDate: chequeDateNotifier.value,
                                        issueDate: DateTime.now(),
                                        paidDate: DateTime.now(),
                                        previousBalance:
                                            selectedBank!.currentBalance,
                                        newBalance:
                                            selectedBank!.currentBalance +
                                                amount,
                                        status: 'pending',
                                        notes:
                                            'Supplier payment from ${supplier.name}',
                                        createdAt: DateTime.now(),
                                        updatedAt: DateTime.now(),
                                      );

                                      await databaseService
                                          .insertBankPayment(bankPayment);

                                      // Update bank balance
                                      final updatedBank =
                                          selectedBank!.copyWith(
                                        currentBalance:
                                            selectedBank!.currentBalance +
                                                amount,
                                        updatedAt: DateTime.now(),
                                      );
                                      await ref
                                          .read(bankNotifierProvider.notifier)
                                          .updateBank(updatedBank);

                                      // Update supplier's unclearCheque for pending cheques
                                      final currentSupplier = await ref.read(
                                          supplierByIdProvider(
                                                  widget.supplierId)
                                              .future);
                                      if (currentSupplier != null &&
                                          bankPayment.status == 'pending') {
                                        final updatedSupplier =
                                            currentSupplier.copyWith(
                                          unclearCheque:
                                              currentSupplier.unclearCheque +
                                                  amount,
                                          updatedAt: DateTime.now(),
                                        );
                                        await ref
                                            .read(supplierNotifierProvider
                                                .notifier)
                                            .updateSupplier(updatedSupplier);
                                        ref.invalidate(supplierByIdProvider(
                                            widget.supplierId));
                                      }

                                      // Refresh bank providers
                                      ref.invalidate(bankNotifierProvider);
                                      ref.invalidate(allBankPaymentsProvider);

                                      if (mounted) {
                                        AppSnackBar.show(
                                          context,
                                          const SnackBar(
                                            content: Text(
                                                'Bank payment recorded successfully'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        _refreshData();
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        AppSnackBar.show(
                                          context,
                                          SnackBar(
                                            content: Text(
                                                'Error recording payment: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6BA6D3),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: Text('ledger.save_payment'.tr()),
                                ),
                              ),
                            ],
                          ),
                        ]),
                      ));
                },
              );
            },
          );
        },
      ),
    ).then((_) {
      selectedBankNotifier.dispose();
      amountController.dispose();
      chequeNoController.dispose();
      otherNameController.dispose();
    });
  }

  Future<void> _showDownloadDateRangeDialog(
      SupplierModel supplier, Currency currency) async {
    DateTime selectedStartDate = _startDate;
    DateTime selectedEndDate = _endDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('ledger.pdf_date_range_title'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('ledger.start_date'.tr()),
                  subtitle:
                      Text(DateFormat('dd MMM yyyy').format(selectedStartDate)),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedStartDate,
                        firstDate: DateTime(2020),
                        lastDate:
                            selectedEndDate.subtract(const Duration(days: 1)),
                      );
                      if (date != null) {
                        setDialogState(() {
                          selectedStartDate = date;
                        });
                      }
                    },
                  ),
                ),
                ListTile(
                  title: Text('ledger.end_date'.tr()),
                  subtitle:
                      Text(DateFormat('dd MMM yyyy').format(selectedEndDate)),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedEndDate,
                        firstDate:
                            selectedStartDate.add(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (date != null) {
                        setDialogState(() {
                          selectedEndDate = date;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'PDF will be generated for the selected date range.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
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
                Navigator.pop(context);
                _downloadLedgerPDF(
                    supplier, currency, selectedStartDate, selectedEndDate);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6BA6D3),
                foregroundColor: Colors.white,
              ),
              child: Text('ledger.download_pdf'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadLedgerPDF(SupplierModel supplier, Currency currency,
      DateTime startDate, DateTime endDate) async {
    try {
      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Generating PDF...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final purchaseOrdersAsync =
          ref.watch(purchaseOrdersBySupplierProvider(widget.supplierId));
      final paymentsAsync = ref.watch(supplierPaymentsByDateRangeProvider(
          (supplierId: widget.supplierId, start: startDate, end: endDate)));

      await purchaseOrdersAsync.when(
        data: (purchaseOrders) async {
          await paymentsAsync.when(
            data: (payments) async {
              bool isCancelledCheque(SupplierPaymentModel payment) {
                return payment.paymentMethod == 'cheque' &&
                    payment.status == 'cancelled';
              }

              bool isDateInRange(DateTime date) {
                return date
                        .isAfter(startDate.subtract(const Duration(days: 1))) &&
                    date.isBefore(endDate.add(const Duration(days: 1)));
              }

              final filteredOrders = purchaseOrders
                  .where((o) => isDateInRange(o.orderDate))
                  .toList()
                ..sort((a, b) => a.orderDate.compareTo(b.orderDate));

              final filteredPayments = payments
                  .where((p) => isDateInRange(p.date))
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date));

              final openingPurchaseTotal = purchaseOrders
                  .where((o) => o.orderDate.isBefore(startDate))
                  .fold<double>(0.0, (sum, order) => sum + order.total);

              final openingPaymentTotal = payments
                  .where((p) => p.date.isBefore(startDate))
                  .fold<double>(
                      0.0,
                      (sum, payment) =>
                          sum +
                          (isCancelledCheque(payment) ? 0 : payment.amount));

              final openingBalance = openingPurchaseTotal - openingPaymentTotal;
              final transactionEntries = <SupplierLedgerTransaction>[];

              for (final order in filteredOrders) {
                transactionEntries.add(
                  SupplierLedgerTransaction(
                    type: SupplierLedgerType.purchase,
                    date: order.orderDate,
                    description: 'Purchase Order #${order.orderNumber}',
                    debit: order.total,
                    credit: 0,
                    method: 'Purchase',
                    reference: order.orderNumber,
                    otherName: supplier.name,
                    enteredBy: order.notes?.isNotEmpty == true
                        ? order.notes
                        : 'System',
                  ),
                );
              }

              for (final payment in filteredPayments) {
                final cancelledCheque = isCancelledCheque(payment);
                transactionEntries.add(
                  SupplierLedgerTransaction(
                    type: SupplierLedgerType.payment,
                    date: payment.date,
                    description: payment.otherName?.isNotEmpty == true
                        ? '${payment.otherName!}${cancelledCheque ? ' (CANCELLED)' : ''}'
                        : 'Payment - ${payment.paymentMethod}${cancelledCheque ? ' (CANCELLED)' : ''}',
                    debit: 0,
                    credit: cancelledCheque ? 0 : payment.amount,
                    method: payment.paymentMethod.toUpperCase(),
                    reference: payment.reference,
                    otherName: payment.otherName?.isNotEmpty == true
                        ? payment.otherName
                        : payment.note?.isNotEmpty == true
                            ? payment.note
                            : 'Payment',
                    enteredBy:
                        payment.createdBy ?? payment.paymentType.toUpperCase(),
                  ),
                );
              }

              transactionEntries.sort((a, b) => a.date.compareTo(b.date));

              double runningBalance = openingBalance;
              final ledgerTransactions = <SupplierLedgerTransaction>[];

              if (openingBalance.abs() > 0.0001) {
                ledgerTransactions.add(
                  SupplierLedgerTransaction(
                    type: SupplierLedgerType.opening,
                    date: startDate,
                    description: 'Opening Balance',
                    debit: openingBalance > 0 ? openingBalance : 0,
                    credit: openingBalance < 0 ? openingBalance.abs() : 0,
                    balance: openingBalance,
                    previousBalance: openingBalance,
                    method: 'Opening',
                    reference: null,
                    otherName: supplier.name,
                    enteredBy: 'System',
                  ),
                );
              }

              for (final transaction in transactionEntries) {
                transaction.previousBalance = runningBalance;
                runningBalance =
                    runningBalance + transaction.debit - transaction.credit;
                transaction.balance = runningBalance;
                ledgerTransactions.add(transaction);
              }

              final closingBalance = runningBalance;
              final balanceDifference =
                  (supplier.currentBalance - closingBalance).abs();

              final databaseService = ref.read(databaseServiceProvider);
              final businessName =
                  await databaseService.getSetting('business_name') ??
                      'My Business';
              final businessAddress =
                  await databaseService.getSetting('business_address') ?? '';
              final businessPhone =
                  await databaseService.getSetting('business_phone') ?? '';

              final pdf = pw.Document();

              pdf.addPage(
                pw.MultiPage(
                  pageFormat: PdfPageFormat.a4,
                  build: (context) => [
                    pw.Header(
                      level: 0,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SUPPLIER LEDGER REPORT',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            businessName,
                            style: pw.TextStyle(fontSize: 14),
                          ),
                          if (businessAddress.isNotEmpty)
                            pw.Text(
                              businessAddress,
                              style: pw.TextStyle(fontSize: 12),
                            ),
                          if (businessPhone.isNotEmpty)
                            pw.Text(
                              businessPhone,
                              style: pw.TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Supplier: ${supplier.name}',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (supplier.code != null &&
                              supplier.code!.isNotEmpty)
                            pw.Text(
                              'Code: ${supplier.code}',
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                          if (supplier.phone != null &&
                              supplier.phone!.isNotEmpty)
                            pw.Text(
                              'Phone: ${supplier.phone}',
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'Period: ${DateFormat('dd MMM yyyy').format(startDate)} to ${DateFormat('dd MMM yyyy').format(endDate)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'Opening Balance: ${currency.symbol}${openingBalance.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      children: [
                        pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Other Name',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Bank',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Paid Date',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('User',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Previous Balance',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold),
                                    textAlign: pw.TextAlign.right)),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Paid Amount',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold),
                                    textAlign: pw.TextAlign.right)),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Balance',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold),
                                    textAlign: pw.TextAlign.right)),
                          ],
                        ),
                        ...ledgerTransactions.map((transaction) {
                          final paidDate =
                              transaction.type == SupplierLedgerType.opening
                                  ? '—'
                                  : DateFormat('dd/MM/yyyy')
                                      .format(transaction.date);
                          final amountValue = transaction.amount;
                          final amountPrefix = transaction.debit > 0
                              ? '+'
                              : transaction.credit > 0
                                  ? '-'
                                  : '';
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  transaction.otherName ??
                                      transaction.description,
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  (transaction.method ??
                                          (transaction.type ==
                                                  SupplierLedgerType.purchase
                                              ? 'Purchase'
                                              : 'Payment'))
                                      .toUpperCase(),
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  paidDate,
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  transaction.enteredBy ?? '—',
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  '${currency.symbol}${transaction.previousBalance.toStringAsFixed(2)}',
                                  style: pw.TextStyle(fontSize: 10),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  '${amountPrefix.isNotEmpty ? amountPrefix : ''}${currency.symbol}${amountValue.toStringAsFixed(2)}',
                                  style: pw.TextStyle(fontSize: 10),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  '${currency.symbol}${transaction.balance.toStringAsFixed(2)}',
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Closing Balance:',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                '${currency.symbol}${closingBalance.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Current Balance:',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                '${currency.symbol}${supplier.currentBalance.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (balanceDifference > 0.01)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(top: 6),
                              child: pw.Text(
                                'Difference (Current - Closing): ${currency.symbol}${(supplier.currentBalance - closingBalance).toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    pw.Spacer(),
                    pw.Divider(),
                    pw.Text(
                      'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              );

              // Save PDF to file
              final bytes = await pdf.save();
              
              // Sanitize filename for Windows compatibility
              String sanitizeFileName(String name) {
                // Remove invalid Windows filename characters: < > : " / \ | ? *
                return name
                    .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
                    .replaceAll(RegExp(r'\s+'), '_')
                    .replaceAll(RegExp(r'_+'), '_')
                    .trim();
              }
              
              final sanitizedSupplierName = sanitizeFileName(supplier.name);
              final fileName =
                  'Supplier_Ledger_${sanitizedSupplierName}_${DateFormat('yyyyMMdd').format(startDate)}_to_${DateFormat('yyyyMMdd').format(endDate)}.pdf';

              if (mounted) {
                try {
                  // Try Printing.sharePdf first (works well on most platforms including Windows)
                  await Printing.sharePdf(
                    bytes: bytes,
                    filename: fileName,
                  );

                  AppSnackBar.show(
                    context,
                    SnackBar(
                      content: Text('PDF generated successfully: $fileName'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                } catch (shareError) {
                  // Fallback: Save to Documents directory (more accessible on Windows)
                  try {
                    Directory directory;
                    try {
                      // Use application documents directory (works on Windows)
                      directory = await getApplicationDocumentsDirectory();
                    } catch (e) {
                      // Fallback to temporary directory
                      directory = await getTemporaryDirectory();
                    }
                    
                    // Ensure directory exists
                    if (!await directory.exists()) {
                      await directory.create(recursive: true);
                    }
                    
                    final file = File('${directory.path}/$fileName');
                    await file.writeAsBytes(bytes);
                    
                    // Try Share.shareXFiles
                    try {
                      await Share.shareXFiles(
                        [XFile(file.path)],
                        text: 'Supplier Ledger Report: ${supplier.name}',
                        subject: 'Supplier Ledger PDF',
                      );
                    } catch (shareError2) {
                      // If sharing fails, at least the file is saved - show path to user
                      if (mounted) {
                        AppSnackBar.show(
                          context,
                          SnackBar(
                            content: Text('PDF saved to: ${file.path}'),
                            backgroundColor: Colors.blue,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                      return;
                    }

                    AppSnackBar.show(
                      context,
                      SnackBar(
                        content: Text('PDF saved successfully: $fileName'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } catch (e) {
                    if (mounted) {
                      AppSnackBar.show(
                        context,
                        SnackBar(
                          content: Text('Error saving PDF: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              }
            },
            loading: () async {},
            error: (error, stack) async {
              if (mounted) {
                AppSnackBar.show(
                  context,
                  SnackBar(
                    content: Text('Error generating PDF: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          );
        },
        loading: () async {},
        error: (error, stack) async {
          if (mounted) {
            AppSnackBar.show(
              context,
              SnackBar(
                content: Text('Error generating PDF: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error downloading PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateLedgerReport(
      SupplierModel supplier, Currency currency) async {
    try {
      final purchaseOrdersAsync =
          ref.watch(purchaseOrdersBySupplierProvider(widget.supplierId));
      final paymentsAsync = ref.watch(supplierPaymentsByDateRangeProvider(
          (supplierId: widget.supplierId, start: _startDate, end: _endDate)));

      await purchaseOrdersAsync.when(
        data: (purchaseOrders) async {
          await paymentsAsync.when(
            data: (payments) async {
              bool isCancelledCheque(SupplierPaymentModel payment) {
                return payment.paymentMethod == 'cheque' &&
                    payment.status == 'cancelled';
              }

              final filteredOrders = purchaseOrders
                  .where((o) => _isDateInRange(o.orderDate))
                  .toList()
                ..sort((a, b) => a.orderDate.compareTo(b.orderDate));

              final filteredPayments = payments
                  .where((p) => _isDateInRange(p.date))
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date));

              final openingPurchaseTotal = purchaseOrders
                  .where((o) => o.orderDate.isBefore(_startDate))
                  .fold<double>(0.0, (sum, order) => sum + order.total);

              final openingPaymentTotal = payments
                  .where((p) => p.date.isBefore(_startDate))
                  .fold<double>(
                      0.0,
                      (sum, payment) =>
                          sum +
                          (isCancelledCheque(payment) ? 0 : payment.amount));

              final openingBalance = openingPurchaseTotal - openingPaymentTotal;
              final transactionEntries = <SupplierLedgerTransaction>[];

              for (final order in filteredOrders) {
                transactionEntries.add(
                  SupplierLedgerTransaction(
                    type: SupplierLedgerType.purchase,
                    date: order.orderDate,
                    description: 'Purchase Order #${order.orderNumber}',
                    debit: order.total,
                    credit: 0,
                    method: 'Purchase',
                    reference: order.orderNumber,
                    otherName: supplier.name,
                    enteredBy: order.notes?.isNotEmpty == true
                        ? order.notes
                        : 'System',
                  ),
                );
              }

              for (final payment in filteredPayments) {
                final cancelledCheque = isCancelledCheque(payment);
                transactionEntries.add(
                  SupplierLedgerTransaction(
                    type: SupplierLedgerType.payment,
                    date: payment.date,
                    description: payment.otherName?.isNotEmpty == true
                        ? '${payment.otherName!}${cancelledCheque ? ' (CANCELLED)' : ''}'
                        : 'Payment - ${payment.paymentMethod}${cancelledCheque ? ' (CANCELLED)' : ''}',
                    debit: 0,
                    credit: cancelledCheque ? 0 : payment.amount,
                    method: payment.paymentMethod.toUpperCase(),
                    reference: payment.reference,
                    otherName: payment.otherName?.isNotEmpty == true
                        ? payment.otherName
                        : payment.note?.isNotEmpty == true
                            ? payment.note
                            : 'Payment',
                    enteredBy: payment.paymentType.toUpperCase(),
                  ),
                );
              }

              transactionEntries.sort((a, b) => a.date.compareTo(b.date));

              double runningBalance = openingBalance;
              final ledgerTransactions = <SupplierLedgerTransaction>[];

              if (openingBalance.abs() > 0.0001) {
                ledgerTransactions.add(
                  SupplierLedgerTransaction(
                    type: SupplierLedgerType.opening,
                    date: _startDate,
                    description: 'Opening Balance',
                    debit: openingBalance > 0 ? openingBalance : 0,
                    credit: openingBalance < 0 ? openingBalance.abs() : 0,
                    balance: openingBalance,
                    previousBalance: openingBalance,
                    method: 'Opening',
                    reference: null,
                    otherName: supplier.name,
                    enteredBy: 'System',
                  ),
                );
              }

              for (final transaction in transactionEntries) {
                transaction.previousBalance = runningBalance;
                runningBalance =
                    runningBalance + transaction.debit - transaction.credit;
                transaction.balance = runningBalance;
                ledgerTransactions.add(transaction);
              }

              final closingBalance = runningBalance;
              final balanceDifference =
                  (supplier.currentBalance - closingBalance).abs();

              final databaseService = ref.read(databaseServiceProvider);
              final businessName =
                  await databaseService.getSetting('business_name') ??
                      'My Business';
              final businessAddress =
                  await databaseService.getSetting('business_address') ?? '';
              final businessPhone =
                  await databaseService.getSetting('business_phone') ?? '';

              final pdf = pw.Document();

              pdf.addPage(
                pw.MultiPage(
                  pageFormat: PdfPageFormat.a4,
                  build: (context) => [
                    pw.Header(
                      level: 0,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SUPPLIER LEDGER REPORT',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            businessName,
                            style: pw.TextStyle(fontSize: 14),
                          ),
                          if (businessAddress.isNotEmpty)
                            pw.Text(
                              businessAddress,
                              style: pw.TextStyle(fontSize: 12),
                            ),
                          if (businessPhone.isNotEmpty)
                            pw.Text(
                              businessPhone,
                              style: pw.TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Supplier Information',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            children: [
                              pw.Expanded(
                                child: pw.Text('Name: ${supplier.name}'),
                              ),
                              pw.Expanded(
                                child: pw.Text('Phone: ${supplier.phone}'),
                              ),
                            ],
                          ),
                          if (supplier.address?.isNotEmpty ?? false)
                            pw.Text('Address: ${supplier.address}'),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            children: [
                              pw.Expanded(
                                child: pw.Text(
                                  'Balance: ${currency.symbol}${supplier.currentBalance.toStringAsFixed(2)}',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold),
                                ),
                              ),


                            ],
                          ),
                          pw.SizedBox(height: 6),
                          pw.Row(
                            children: [
                              pw.Expanded(
                                child: pw.Text(
                                  'Unclear Cheque: ${currency.symbol}${supplier.unclearCheque.toStringAsFixed(2)}',
                                ),
                              ),
                              pw.SizedBox(width: 10),
                              pw.Expanded(child: pw.SizedBox()),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'Period: ${DateFormat('dd MMM yyyy').format(_startDate)} to ${DateFormat('dd MMM yyyy').format(_endDate)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'Opening Balance: ${currency.symbol}${openingBalance.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      children: [
                        pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Other Name',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Bank',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Paid Date',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('User',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Previous Balance',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold),
                                    textAlign: pw.TextAlign.right)),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Paid Amount',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold),
                                    textAlign: pw.TextAlign.right)),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('Balance',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold),
                                    textAlign: pw.TextAlign.right)),
                          ],
                        ),
                        ...ledgerTransactions.map((transaction) {
                          final paidDate =
                              transaction.type == SupplierLedgerType.opening
                                  ? '—'
                                  : DateFormat('dd/MM/yyyy')
                                      .format(transaction.date);
                          final amountValue = transaction.amount;
                          final amountPrefix = transaction.debit > 0
                              ? '+'
                              : transaction.credit > 0
                                  ? '-'
                                  : '';
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  transaction.otherName ??
                                      transaction.description,
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  (transaction.method ??
                                          (transaction.type ==
                                                  SupplierLedgerType.purchase
                                              ? 'Purchase'
                                              : 'Payment'))
                                      .toUpperCase(),
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  paidDate,
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  transaction.enteredBy ?? '—',
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  '${currency.symbol}${transaction.previousBalance.toStringAsFixed(2)}',
                                  style: pw.TextStyle(fontSize: 10),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  '${amountPrefix.isNotEmpty ? amountPrefix : ''}${currency.symbol}${amountValue.toStringAsFixed(2)}',
                                  style: pw.TextStyle(fontSize: 10),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  '${currency.symbol}${transaction.balance.toStringAsFixed(2)}',
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Closing Balance:',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                '${currency.symbol}${closingBalance.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Current Balance:',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                '${currency.symbol}${supplier.currentBalance.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (balanceDifference > 0.01)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(top: 6),
                              child: pw.Text(
                                'Difference (Current - Closing): ${currency.symbol}${(supplier.currentBalance - closingBalance).toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    pw.Spacer(),
                    pw.Divider(),
                    pw.Text(
                      'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              );

              // Show ledger report in-app with print option
              if (mounted) {
                await showDialog(
                  context: context,
                  builder: (context) => _SupplierLedgerReportDialog(
                    supplier: supplier,
                    currency: currency,
                    businessName: businessName,
                    businessAddress: businessAddress,
                    businessPhone: businessPhone,
                    supplierId: widget.supplierId,
                    initialStartDate: _startDate,
                    initialEndDate: _endDate,
                  ),
                );
              }
            },
            loading: () async {},
            error: (error, stack) async {
              if (mounted) {
                AppSnackBar.show(
                  context,
                  const SnackBar(
                    content: Text('Error loading payments data'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          );
        },
        loading: () {},
        error: (error, stack) {
          if (mounted) {
            AppSnackBar.show(
              context,
              const SnackBar(
                content: Text('Error loading purchase orders data'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog(SupplierModel supplier) async {
    final confirmed = await ModernDialogBuilder.showConfirmDialog(
      context: context,
      title: 'Delete Supplier',
      message:
          'Are you sure you want to delete "${supplier.name}"?\n\nThis action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      icon: Icons.delete_outline,
    );

    if (confirmed == true) {
      try {
        await ref
            .read(supplierNotifierProvider.notifier)
            .deleteSupplier(supplier.id!);
        // Invalidate all supplier-related providers to refresh the UI
        ref.invalidate(supplierNotifierProvider);
        ref.invalidate(supplierByIdProvider(supplier.id!));
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Supplier deleted successfully'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          // Navigate back to suppliers screen
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/suppliers');
          }
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Error deleting supplier: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }
}

// Helper classes
enum SupplierLedgerType { opening, purchase, payment }

class SupplierLedgerTransaction {
  final SupplierLedgerType type;
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  double balance;
  double previousBalance;
  final String? method;
  final String? reference;
  final String? otherName;
  final String? enteredBy;

  SupplierLedgerTransaction({
    required this.type,
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    this.balance = 0.0,
    this.previousBalance = 0.0,
    this.method,
    this.reference,
    this.otherName,
    this.enteredBy,
  });

  double get amount => debit > 0 ? debit : credit;
}

// Supplier Ledger Report Dialog Widget
class _SupplierLedgerReportDialog extends ConsumerStatefulWidget {
  final SupplierModel supplier;
  final Currency currency;
  final String businessName;
  final String businessAddress;
  final String businessPhone;
  final int supplierId;
  final DateTime initialStartDate;
  final DateTime initialEndDate;

  const _SupplierLedgerReportDialog({
    required this.supplier,
    required this.currency,
    required this.businessName,
    required this.businessAddress,
    required this.businessPhone,
    required this.supplierId,
    required this.initialStartDate,
    required this.initialEndDate,
  });

  @override
  ConsumerState<_SupplierLedgerReportDialog> createState() =>
      _SupplierLedgerReportDialogState();
}

class _SupplierLedgerReportDialogState
    extends ConsumerState<_SupplierLedgerReportDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  List<SupplierLedgerTransaction> _transactions = [];
  double _closingBalance = 0.0;
  double _openingBalance = 0.0;
  double _balanceDifference = 0.0;
  pw.Document? _pdf;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _loadLedgerData();
  }

  Future<void> _loadLedgerData() async {
    setState(() => _isLoading = true);
    try {
      final purchaseOrdersAsync = await ref
          .read(purchaseOrdersBySupplierProvider(widget.supplierId).future);
      final paymentsAsync = await ref.read(supplierPaymentsByDateRangeProvider(
              (supplierId: widget.supplierId, start: _startDate, end: _endDate))
          .future);

      final filteredOrders = purchaseOrdersAsync.where((o) {
        return o.orderDate
                .isAfter(_startDate.subtract(const Duration(days: 1))) &&
            o.orderDate.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      final filteredPayments = paymentsAsync.where((p) {
        return p.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
            p.date.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      filteredOrders.sort((a, b) => a.orderDate.compareTo(b.orderDate));
      filteredPayments.sort((a, b) => a.date.compareTo(b.date));

      bool isCancelledCheque(SupplierPaymentModel payment) {
        return payment.paymentMethod == 'cheque' &&
            payment.status == 'cancelled';
      }

      final openingPurchaseTotal = purchaseOrdersAsync
          .where((o) => o.orderDate.isBefore(_startDate))
          .fold<double>(0.0, (sum, order) => sum + order.total);

      final openingPaymentTotal = paymentsAsync
          .where((p) => p.date.isBefore(_startDate))
          .fold<double>(
              0.0,
              (sum, payment) =>
                  sum + (isCancelledCheque(payment) ? 0 : payment.amount));

      final openingBalance = openingPurchaseTotal - openingPaymentTotal;
      final transactionEntries = <SupplierLedgerTransaction>[];

      for (final order in filteredOrders) {
        transactionEntries.add(
          SupplierLedgerTransaction(
            type: SupplierLedgerType.purchase,
            date: order.orderDate,
            description: 'Purchase Order #${order.orderNumber}',
            debit: order.total,
            credit: 0,
            method: 'Purchase',
            reference: order.orderNumber,
            otherName: widget.supplier.name,
            enteredBy: order.notes?.isNotEmpty == true ? order.notes : 'System',
          ),
        );
      }
      for (final payment in filteredPayments) {
        final cancelledCheque = isCancelledCheque(payment);
        transactionEntries.add(
          SupplierLedgerTransaction(
            type: SupplierLedgerType.payment,
            date: payment.date,
            description: payment.otherName?.isNotEmpty == true
                ? '${payment.otherName!}${cancelledCheque ? ' (CANCELLED)' : ''}'
                : 'Payment - ${payment.paymentMethod}${cancelledCheque ? ' (CANCELLED)' : ''}',
            debit: 0,
            credit: cancelledCheque ? 0 : payment.amount,
            method: payment.paymentMethod.toUpperCase(),
            reference: payment.reference,
            otherName: payment.otherName?.isNotEmpty == true
                ? payment.otherName
                : payment.note?.isNotEmpty == true
                    ? payment.note
                    : 'Payment',
            enteredBy: payment.paymentType.toUpperCase(),
          ),
        );
      }

      transactionEntries.sort((a, b) => a.date.compareTo(b.date));

      double runningBalance = openingBalance;
      final transactions = <SupplierLedgerTransaction>[];

      if (openingBalance.abs() > 0.0001) {
        transactions.add(
          SupplierLedgerTransaction(
            type: SupplierLedgerType.opening,
            date: _startDate,
            description: 'Opening Balance',
            debit: openingBalance > 0 ? openingBalance : 0,
            credit: openingBalance < 0 ? openingBalance.abs() : 0,
            balance: openingBalance,
            previousBalance: openingBalance,
            method: 'Opening',
            reference: null,
            otherName: widget.supplier.name,
            enteredBy: 'System',
          ),
        );
      }

      for (final transaction in transactionEntries) {
        transaction.previousBalance = runningBalance;
        runningBalance =
            runningBalance + transaction.debit - transaction.credit;
        transaction.balance = runningBalance;
        transactions.add(transaction);
      }

      _openingBalance = openingBalance;
      _closingBalance = runningBalance;
      _balanceDifference =
          (widget.supplier.currentBalance - _closingBalance).abs();
      _transactions = transactions;

      // Generate PDF
      final databaseService = ref.read(databaseServiceProvider);
      final businessName =
          await databaseService.getSetting('business_name') ?? 'My Business';
      final businessAddress =
          await databaseService.getSetting('business_address') ?? '';
      final businessPhone =
          await databaseService.getSetting('business_phone') ?? '';

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SUPPLIER LEDGER REPORT',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(businessName, style: pw.TextStyle(fontSize: 14)),
                  if (businessAddress.isNotEmpty)
                    pw.Text(businessAddress, style: pw.TextStyle(fontSize: 12)),
                  if (businessPhone.isNotEmpty)
                    pw.Text(businessPhone, style: pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Supplier Information',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(
                          child: pw.Text('Name: ${widget.supplier.name}')),
                      pw.Expanded(
                          child: pw.Text('Phone: ${widget.supplier.phone}')),
                    ],
                  ),
                  if (widget.supplier.address?.isNotEmpty ?? false)
                    pw.Text('Address: ${widget.supplier.address}'),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(
                          child: pw.Text(
                              'Balance: ${widget.currency.symbol}${widget.supplier.currentBalance.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                      // Credit limit intentionally hidden from printed report as per requirement
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
                'Period: ${DateFormat('dd MMM yyyy').format(_startDate)} to ${DateFormat('dd MMM yyyy').format(_endDate)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text(
                'Opening Balance: ${widget.currency.symbol}${_openingBalance.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Other Name',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Bank',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Paid Date',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('User',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Previous Balance',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Paid Amount',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Balance',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right)),
                  ],
                ),
                ...transactions.map((transaction) {
                  final paidDate =
                      transaction.type == SupplierLedgerType.opening
                          ? '—'
                          : DateFormat('dd/MM/yyyy').format(transaction.date);
                  final method = (transaction.method ??
                          (transaction.type == SupplierLedgerType.purchase
                              ? 'Purchase'
                              : 'Payment'))
                      .toUpperCase();
                  final amountValue = transaction.amount;
                  final amountPrefix = transaction.debit > 0
                      ? '+'
                      : transaction.credit > 0
                          ? '-'
                          : '';
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                              transaction.otherName ?? transaction.description,
                              style: pw.TextStyle(fontSize: 10))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(method,
                              style: pw.TextStyle(fontSize: 10))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(paidDate,
                              style: pw.TextStyle(fontSize: 10))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(transaction.enteredBy ?? '—',
                              style: pw.TextStyle(fontSize: 10))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                              '${widget.currency.symbol}${transaction.previousBalance.toStringAsFixed(2)}',
                              style: pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.right)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                              '${amountPrefix.isNotEmpty ? amountPrefix : ''}${widget.currency.symbol}${amountValue.toStringAsFixed(2)}',
                              style: pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.right)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                              '${widget.currency.symbol}${transaction.balance.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                  fontSize: 10, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right)),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Closing Balance:',
                          style: pw.TextStyle(
                              fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                          '${widget.currency.symbol}${_closingBalance.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Current Balance:',
                          style: pw.TextStyle(
                              fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                          '${widget.currency.symbol}${widget.supplier.currentBalance.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  if (_balanceDifference > 0.01)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 6),
                      child: pw.Text(
                        'Difference (Current - Closing): ${widget.currency.symbol}${(widget.supplier.currentBalance - _closingBalance).toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red),
                      ),
                    ),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
                'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center),
          ],
        ),
      );

      _pdf = pdf;
    } catch (e) {
      debugPrint('Error loading ledger data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    if (!mounted) return;

    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: isStartDate ? _startDate : _endDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );

      if (picked != null && mounted) {
        setState(() {
          if (isStartDate) {
            _startDate = picked;
          } else {
            _endDate = picked;
          }
        });
        await _loadLedgerData();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error selecting date: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDatePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _selectDate(context, true),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 8),
                    Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('to', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _selectDate(context, false),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 8),
                    Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printReport(BuildContext context) async {
    if (_pdf == null) {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Please wait for report to load'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final bytes = await _pdf!.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
      );
      if (context.mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Printing ledger report...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error printing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Dialog(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading ledger report...'),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SUPPLIER LEDGER REPORT',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.businessName,
                          style: const TextStyle(fontSize: 14)),
                      if (widget.businessAddress.isNotEmpty)
                        Text(widget.businessAddress,
                            style: const TextStyle(fontSize: 12)),
                      if (widget.businessPhone.isNotEmpty)
                        Text(widget.businessPhone,
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),

            // Date Picker
            _buildDatePicker(),
            const SizedBox(height: 16),

            // Supplier Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Supplier Information',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text('Name: ${widget.supplier.name}')),
                      Expanded(child: Text('Phone: ${widget.supplier.phone}')),
                    ],
                  ),
                  if (widget.supplier.address?.isNotEmpty ?? false)
                    Text('Address: ${widget.supplier.address}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Balance: ${widget.currency.symbol}${widget.supplier.currentBalance.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Credit limit intentionally hidden in on-screen summary as per requirement
                    ],
                  ),
                ],
              ),
            ),
            // Print Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _printReport(context),
                  icon: const Icon(Icons.print),
                  label: Text('common.print'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Transactions Table
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor:
                        MaterialStateProperty.all(Colors.grey.shade200),
                    columns: const [
                      DataColumn(
                          label: Text('Other Name',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Bank',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Paid Date',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('User',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Prev Balance',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                      DataColumn(
                          label: Text('Paid Amount',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                      DataColumn(
                          label: Text('Balance',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                    ],
                    rows: _transactions.map((transaction) {
                      final paidDate = transaction.type ==
                              SupplierLedgerType.opening
                          ? '—'
                          : DateFormat('dd/MM/yyyy').format(transaction.date);
                      final method = (transaction.method ??
                              (transaction.type == SupplierLedgerType.purchase
                                  ? 'Purchase'
                                  : 'Payment'))
                          .toUpperCase();
                      final amountValue = transaction.amount;
                      final amountPrefix = transaction.debit > 0
                          ? '+'
                          : transaction.credit > 0
                              ? '-'
                              : '';
                      return DataRow(
                        cells: [
                          DataCell(Text(transaction.otherName ??
                              transaction.description)),
                          DataCell(Text(method)),
                          DataCell(Text(paidDate)),
                          DataCell(Text(transaction.enteredBy ?? '—')),
                          DataCell(Text(
                              '${widget.currency.symbol}${transaction.previousBalance.toStringAsFixed(2)}')),
                          DataCell(Text(
                              '${amountPrefix.isNotEmpty ? amountPrefix : ''}${widget.currency.symbol}${amountValue.toStringAsFixed(2)}')),
                          DataCell(
                            Text(
                              '${widget.currency.symbol}${transaction.balance.toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Footer
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PurchaseOrderWithBalance {
  final PurchaseOrderModel order;
  final double previousBalance;
  final double payableAmount;
  final double balance;

  PurchaseOrderWithBalance({
    required this.order,
    required this.previousBalance,
    required this.payableAmount,
    required this.balance,
  });
}

class SupplierPaymentWithBalance {
  final SupplierPaymentModel payment;
  final double previousBalance;
  final double paidAmount;
  final double balance;

  SupplierPaymentWithBalance({
    required this.payment,
    required this.previousBalance,
    required this.paidAmount,
    required this.balance,
  });
}
