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
import '../models/bank.dart';
import '../providers/customer_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../services/database_service.dart';
import '../utils/input_formatters.dart';
import '../utils/modern_dialog_builder.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/payment.dart';
import '../models/currency.dart';
import '../models/employee.dart';
import '../models/product.dart';
import 'customer_payment_screen.dart';
import '../services/bulk_import_service.dart';
import '../utils/navigation_helper.dart';
import '../providers/bank_provider.dart';
import '../models/bank_payment.dart';
import '../theme/app_theme.dart';
import '../widgets/enhanced_print_preview.dart';
import '../widgets/app_snack_bar.dart';

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  final int customerId;

  const CustomerLedgerScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerLedgerScreen> createState() =>
      _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen>
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

      ref.invalidate(customerByIdProvider(widget.customerId));
      ref.invalidate(salesByCustomerProvider(widget.customerId));
      ref.invalidate(paymentsByCustomerProvider(widget.customerId));
      ref.invalidate(saleNotifierProvider);
      ref.invalidate(paymentNotifierProvider);

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _handleImportCustomerLedgerFromText() async {
    // Show warning first
    final proceed = await ModernDialogBuilder.showConfirmDialog(
      context: context,
      title: 'Legacy Data Import',
      message: 'This import is for migrating legacy data from another POS system.\n\n'
          '⚠️ WARNING:\n'
          '• This will create sales and payment records\n'
          '• A system product "LEGACY-IMPORT-ITEM" will be created/used\n'
          '• Only use this for specific customer legacy data migration\n'
          '• This feature is for one-time data migration only\n\n'
          'Do you want to continue?',
      icon: Icons.warning_amber_rounded,
      confirmText: 'Yes, Continue',
      cancelText: 'Cancel',
    );

    if (proceed != true) return;

    final textController = TextEditingController();
    bool isImporting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('ledger.import_customer_legacy'.tr()),
          content: SizedBox(
            width: 600,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'ledger.legacy_import_warning'.tr(),
                    style: const TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: textController,
                    maxLines: null,
                    expands: true,
                    decoration: InputDecoration(
                      hintText: 'ledger.paste_here_hint'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    enabled: !isImporting,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isImporting
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: isImporting
                  ? null
                  : () async {
                    if (textController.text.trim().isEmpty) {
                      AppSnackBar.show(
                        context,
                        SnackBar(
                            content: Text('ledger.paste_required'.tr())),
                      );
                      return;
                    }
                    setState(() => isImporting = true);
                    try {
                      final databaseService =
                          ref.read(databaseServiceProvider);
                      final importResult =
                          await BulkImportService.importCustomerLedgerFromText(
                              databaseService, textController.text);
                      if (mounted) {
                        Navigator.of(context).pop(true);
                        await ModernDialogBuilder.showInfoDialog(
                          context: context,
                          title: 'Legacy Import Completed',
                          message:
                              '✅ Records imported: ${importResult.inserted}\n'
                              '⏭️ Skipped: ${importResult.skipped}\n\n'
                              'Note: This import creates historical records only.\n'
                              'The system product "LEGACY-IMPORT-ITEM-DO-NOT-USE" was used for sales entries.' +
                              (importResult.errors.isNotEmpty
                                  ? '\n\n⚠️ Errors (first 5):\n${importResult.errors.take(5).join('\n')}'
                                  : ''),
                          icon: Icons.cloud_done_outlined,
                          iconColor: const Color(0xFF10B981),
                          buttonText: 'OK',
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        AppSnackBar.show(
                          context,
                          SnackBar(
                              content: Text('Import failed: $e'),
                              backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => isImporting = false);
                      }
                    }
                  },
              child: isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('ledger.import_btn'.tr()),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _handleImportCustomerLedger() async {
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
            context: context, message: 'Importing customer payments...');
      }

      final databaseService = ref.read(databaseServiceProvider);
      final result = await BulkImportService.importCustomerLedgerFromExcel(
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

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerByIdProvider(widget.customerId));
    final salesAsync = ref.watch(salesByCustomerProvider(widget.customerId));
    final paymentsAsync =
        ref.watch(paymentsByCustomerProvider(widget.customerId));
    final currency = ref.watch(currentCurrencyProvider);
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;

    ref.listen<AsyncValue<List<SaleModel>>>(
        salesByCustomerProvider(widget.customerId), (previous, next) {
      if (next.hasValue && mounted) {
        setState(() {});
      }
    });

    ref.listen<AsyncValue<List<PaymentModel>>>(
        paymentsByCustomerProvider(widget.customerId), (previous, next) {
      if (next.hasValue && mounted) {
        setState(() {});
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFE8F4FD),
      appBar: AppBar(
        title: Text('ledger.customer'.tr()),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/customers');
            }
          },
          tooltip: 'Back',
        ),
        actions: [
          // Only show text import to admins/managers (legacy data import)
          if (currentUser?.isAdmin == true || currentUser?.isManager == true)
            IconButton(
              onPressed: _handleImportCustomerLedgerFromText,
              icon: const Icon(Icons.text_fields),
              tooltip: 'Import Legacy Data (Text/CSV) - Admin Only',
            ),
          IconButton(
            onPressed: _handleImportCustomerLedger,
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Payments (.xlsx)',
          ),
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
          if (currentUser?.isAdmin == true || currentUser?.isManager == true)
            IconButton(
              icon: const Icon(Icons.payment),
              onPressed: () => _navigateToPaymentScreen(),
              tooltip: 'Record Payment',
            ),
          Builder(
            builder: (context) {
              final customer = customerAsync.valueOrNull;
              if ((currentUser?.isAdmin == true ||
                      currentUser?.isManager == true) &&
                  customer != null)
                return IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () =>
                      context.go('/edit-customer?id=${customer.id}'),
                  tooltip: 'Edit Customer',
                );
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          customerAsync.when(
            data: (customer) => _buildLedgerContent(
                customer, salesAsync, paymentsAsync, currency),
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
      CustomerModel? customer,
      AsyncValue<List<SaleModel>> salesAsync,
      AsyncValue<List<PaymentModel>> paymentsAsync,
      Currency currency) {
    if (customer == null) {
      return const Center(
        child: Text('Customer not found'),
      );
    }

    return Column(
      children: [
        // Customer Info Section - Professional Layout
        _buildProfessionalCustomerInfo(customer, currency),

        // Tabs for Sale Invoices and Payment Detail
        Expanded(
          child: Column(
            children: [
              Container(
                color: const Color(0xFF4A90E2),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Sale Invoices'),
                    Tab(text: 'Payment Detail'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSaleInvoicesTab(salesAsync, currency),
                    _buildPaymentDetailTab(paymentsAsync, currency),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalCustomerInfo(
      CustomerModel customer, Currency currency) {
    final basicFields = [
      _buildInfoField('Name', customer.name),
      _buildInfoField('Address', customer.address ?? 'N/A'),
      _buildInfoField('Cell No.', customer.phone),
      _buildInfoField('CNIC #', 'N/A'),
      _buildInfoField(
          'Code', 'CUS-${customer.id?.toString().padLeft(3, '0') ?? 'XXX'}'),
      _buildInfoField('Active', customer.isActive ? 'Yes' : 'No'),
    ];

    final financialFields = [
      _buildInfoField(
        'Balance',
        '${currency.symbol}${customer.totalDue.toStringAsFixed(2)}',
      ),
      _buildInfoField(
        'Credit Limit',
        '${currency.symbol}${customer.creditLimit.toStringAsFixed(2)}',
      ),
      _buildInfoField(
        'Unclear Cheque',
        '${currency.symbol}${customer.unclearCheque.toStringAsFixed(2)}',
      ),
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
                onPressed: () => _generateLedgerReport(customer, currency),
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
                    _showCustomerBankPaymentDialog(customer, currency);
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
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleInvoicesTab(
      AsyncValue<List<SaleModel>> salesAsync, Currency currency) {
    return salesAsync.when(
      data: (sales) {
        // Filter sales by date range
        final filteredSales =
            sales.where((sale) => _isDateInRange(sale.date)).toList();

        // Sort by date (newest first)
        filteredSales.sort((a, b) => b.date.compareTo(a.date));

        if (filteredSales.isEmpty) {
          return _buildEmptyState('No Sale Invoices found');
        }

        // Calculate running balance (assuming we start with customer total due)
        final customerAsync =
            ref.watch(customerByIdProvider(widget.customerId));
        double runningBalance = customerAsync.valueOrNull?.totalDue ?? 0.0;

        // Reverse to show oldest first for proper balance calculation
        final reversedSales = filteredSales.reversed.toList();
        final salesWithBalance = <SaleWithBalance>[];

        for (var i = 0; i < reversedSales.length; i++) {
          final sale = reversedSales[i];
          runningBalance -= sale.total; // Decrease balance when adding sale
          salesWithBalance.add(SaleWithBalance(
            sale: sale,
            previousBalance: i > 0
                ? salesWithBalance[i - 1].balance
                : customerAsync.valueOrNull?.totalDue ?? 0.0,
            payableAmount: sale.total,
            balance: runningBalance,
          ));
        }

        // Reverse back to show newest first
        final finalList = salesWithBalance.reversed.toList();
        final totalPayable =
            filteredSales.fold<double>(0.0, (sum, sale) => sum + sale.total);

        final screenSize = MediaQuery.of(context).size;
        final isMobile = screenSize.width < 768;

        return Column(
          children: [
            if (!isMobile) ...[
              // Table Header (Desktop only)
              Container(
                color: const Color(0xFF4A90E2),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _buildTableHeader('Sale Date')),
                    Expanded(flex: 3, child: _buildTableHeader('Time')),
                    Expanded(flex: 2, child: _buildTableHeader('Invoice No')),
                    Expanded(flex: 2, child: _buildTableHeader('User')),
                    Expanded(flex: 2, child: _buildTableHeader('Payable Rs.')),
                  ],
                ),
              ),
            ],
            // Table Body / Card View
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(salesByCustomerProvider(widget.customerId));
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: isMobile
                    ? ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: finalList.length,
                        itemBuilder: (context, index) {
                          final saleWithBalance = finalList[index];
                          return _buildSaleCard(
                              saleWithBalance, currency, index);
                        },
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: finalList.length,
                        itemBuilder: (context, index) {
                          final saleWithBalance = finalList[index];
                          return _buildSaleRow(
                              saleWithBalance, currency, index);
                        },
                      ),
              ),
            ),
            // Total
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
                      color: Color(0xFF4A90E2),
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

  Widget _buildSaleCard(
      SaleWithBalance saleWithBalance, Currency currency, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showInvoiceDetailsDialog(saleWithBalance.sale, currency),
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
                      color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: Color(0xFF4A90E2),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SINVO-${saleWithBalance.sale.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd-MMM-yy hh:mm a')
                              .format(saleWithBalance.sale.createdAt),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Invoice Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd-MM-yyyy')
                              .format(saleWithBalance.sale.date),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
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
                          'Issued By',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          saleWithBalance.sale.cashier?.name ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
                    '${currency.symbol}${saleWithBalance.payableAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF4A90E2),
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

  Widget _buildSaleRow(
      SaleWithBalance saleWithBalance, Currency currency, int index) {
    final isEven = index % 2 == 0;
    return InkWell(
      onTap: () => _showInvoiceDetailsDialog(saleWithBalance.sale, currency),
      child: Container(
        color: isEven ? Colors.white : const Color(0xFFF5F5F5),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                DateFormat('dd-MM-yyyy').format(saleWithBalance.sale.date),
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                DateFormat('dd-MMM-yy hh:mm a')
                    .format(saleWithBalance.sale.createdAt),
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'SINVO-${saleWithBalance.sale.id}',
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                saleWithBalance.sale.cashier?.name ?? 'N/A',
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                saleWithBalance.payableAmount.toStringAsFixed(2),
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

  void _showInvoiceDetailsDialog(SaleModel sale, Currency currency) {
    final currentUser = ref.read(authProvider).currentUser;
    final isAdmin =
        currentUser?.isAdmin == true || currentUser?.isManager == true;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF4A90E2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice #SINVO-${sale.id}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            DateFormat('dd MMMM yyyy, hh:mm a')
                                .format(sale.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Issued by: ${sale.cashier?.name ?? 'Unknown'}',
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
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
              // Invoice Items
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Customer Info
                      if (sale.customer != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: const Color(0xFFF8FAFC),
                          child: Row(
                            children: [
                              const Icon(Icons.person,
                                  color: Color(0xFF64748B)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sale.customer!.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (sale.customer!.phone.isNotEmpty)
                                      Text(
                                        sale.customer!.phone,
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
                      // Items Table
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Table Header
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
                            // Items
                            ...sale.items.map(
                              (item) => Container(
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
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.product?.name ?? 'Unknown Product',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: (item.product?.isActive == false)
                                                    ? Colors.grey
                                                    : null,
                                              ),
                                            ),
                                          ),
                                          if (item.product?.isActive == false) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(3),
                                                border: Border.all(
                                                  color: Colors.red,
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: const Text(
                                                'Deleted',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item.qty.toStringAsFixed(2),
                                        style: const TextStyle(fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${currency.symbol}${item.price.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 13),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${currency.symbol}${((item.price * item.qty) - item.discount).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer with Summary
              Builder(
                builder: (context) {
                  // Calculate subtotal from items (price * qty - item discount)
                  final subtotal = sale.items.fold<double>(
                    0.0,
                    (sum, item) => sum + ((item.price * item.qty) - item.discount),
                  );
                  return Container(
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
                            '${currency.symbol}${subtotal.toStringAsFixed(2)}',
                            false),
                        if (sale.discount > 0)
                          _buildSummaryRow(
                              'Discount:',
                              '-${currency.symbol}${sale.discount.toStringAsFixed(2)}',
                              false),
                        _buildSummaryRow(
                            'Total:',
                            '${currency.symbol}${(subtotal - sale.discount).toStringAsFixed(2)}',
                            true),
                      ],
                    ),
                  );
                },
              ),
              
              // Remarks Section
              if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remarks',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sale.notes!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(dialogContext);
                              await _printSaleInvoice(sale);
                            },
                            icon: const Icon(Icons.print, size: 18),
                            label: Text('common.print'.tr()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4A90E2),
                              side: const BorderSide(color: Color(0xFF4A90E2)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _editSale(sale);
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: Text('ledger.edit_add_items'.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
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
                  isTotal ? const Color(0xFF4A90E2) : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  int _generateTemporaryItemId() => -DateTime.now().microsecondsSinceEpoch;

  String _saleItemControllerKey(SaleItemModel item) {
    return '${item.productId}_${item.id}';
  }

  Future<void> _printSaleInvoice(SaleModel sale) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EnhancedPrintPreview(
            sale: sale,
            databaseService: databaseService,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error opening print preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editSale(SaleModel sale) async {
    if (sale.id == null) {
      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Unable to edit this invoice. Missing sale ID.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Load sale data properly
    SaleModel? loadedSale;
    try {
      final saleAsync = ref.read(saleByIdProvider(sale.id!));
      
      // Wait for data to be available
      loadedSale = await saleAsync.when(
        data: (saleData) => saleData,
        loading: () async {
          // Wait for data to load
          await Future.delayed(const Duration(milliseconds: 200));
          final refreshed = ref.read(saleByIdProvider(sale.id!));
          return await refreshed.when(
            data: (saleData) => saleData,
            loading: () => null,
            error: (_, __) => null,
          );
        },
        error: (_, __) => null,
      );
    } catch (e) {
      debugPrint('Error loading sale for editing: $e');
      loadedSale = null;
    }
    
    if (loadedSale != null && mounted) {
      _showEditSaleDialog(loadedSale);
    } else if (mounted) {
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text('Sale #${sale.id} could not be loaded for editing.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditSaleDialog(SaleModel sale) {
    final currency = ref.read(currentCurrencyProvider);
    final priceControllers = <String, TextEditingController>{};
    final quantityControllers = <String, TextEditingController>{};
    final editableItems = List<SaleItemModel>.from(sale.items);

    for (var i = 0; i < editableItems.length; i++) {
      var item = editableItems[i];
      if (item.id == null) {
        item = item.copyWith(id: _generateTemporaryItemId());
        editableItems[i] = item;
      }
      final key = _saleItemControllerKey(item);
      priceControllers[key] =
          TextEditingController(text: item.price.toStringAsFixed(2));
      quantityControllers[key] =
          TextEditingController(text: item.qty.toStringAsFixed(2));
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                double calculateSubtotal() {
                  double subtotal = 0;
                  for (final item in editableItems) {
                    final key = _saleItemControllerKey(item);
                    final price =
                        double.tryParse(priceControllers[key]?.text ?? '') ??
                            item.price;
                    final qty =
                        double.tryParse(quantityControllers[key]?.text ?? '') ??
                            item.qty;
                    subtotal += price * qty;
                  }
                  return subtotal;
                }

                final subtotal = calculateSubtotal();
                final discountAmount = sale.discount;
                final finalTotal = subtotal - discountAmount;

                String formatAmount(double amount) {
                  final formatted = amount.abs().toStringAsFixed(2);
                  return '${amount < 0 ? '-' : ''}${currency.symbol}$formatted';
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.edit,
                            color: Color(0xFFF59E0B), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Sale #${sale.id}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateFormat('dd/MM/yyyy hh:mm a')
                                    .format(sale.date),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Add Item Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showAddItemDialog(
                            sale,
                            editableItems,
                            priceControllers,
                            quantityControllers,
                            setDialogState,
                          );
                        },
                        icon: const Icon(Icons.add, size: 20),
                        label: Text('ledger.add_item_line'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Items List
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: editableItems.length,
                        itemBuilder: (context, index) {
                          final item = editableItems[index];
                          final key = _saleItemControllerKey(item);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item.product?.name ??
                                              'Unknown Product',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red, size: 20),
                                        onPressed: () {
                                          setDialogState(() {
                                            priceControllers[key]?.dispose();
                                            quantityControllers[key]?.dispose();
                                            priceControllers.remove(key);
                                            quantityControllers.remove(key);
                                            editableItems.removeAt(index);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: quantityControllers[key],
                                          decoration: InputDecoration(
                                            labelText: 'Quantity',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8),
                                          ),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            DecimalInputFormatter(
                                                maxDecimalPlaces: 2),
                                          ],
                                          onChanged: (_) =>
                                              setDialogState(() {}),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: priceControllers[key],
                                          decoration: InputDecoration(
                                            labelText: 'Price',
                                            prefixText: '${currency.symbol} ',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8),
                                          ),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            DecimalInputFormatter(
                                                maxDecimalPlaces: 2),
                                          ],
                                          onChanged: (_) =>
                                              setDialogState(() {}),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Current Subtotal',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              Text(
                                formatAmount(subtotal),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          if (discountAmount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Discount',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  formatAmount(-discountAmount),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Invoice Total',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                formatAmount(finalTotal),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action Buttons
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _deleteSale(sale);
                              Navigator.pop(dialogContext);
                            },
                            icon: const Icon(Icons.delete, size: 18),
                            label: Text('ledger.delete_sale'.tr()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await _saveSaleChanges(
                                sale,
                                editableItems,
                                priceControllers,
                                quantityControllers,
                                dialogContext,
                              );
                            },
                            icon: const Icon(Icons.save, size: 18),
                            label: Text('ledger.save_changes'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showAddItemDialog(
    SaleModel sale,
    List<SaleItemModel> editableItems,
    Map<String, TextEditingController> priceControllers,
    Map<String, TextEditingController> quantityControllers,
    StateSetter setDialogState,
  ) {
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (productDialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.5,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setProductDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.add_shopping_cart,
                            color: Color(0xFF3B82F6), size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Add Item to Sale',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(productDialogContext),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Search Field
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFF3B82F6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onChanged: (value) {
                        setProductDialogState(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Products List
                    Expanded(
                      child: ref.watch(productsProvider).when(
                            data: (products) {
                              final filtered = searchQuery.isEmpty
                                  ? products.where((p) => p.id != null).toList()
                                  : products
                                      .where((p) =>
                                          p.id != null &&
                                          p.name
                                              .toLowerCase()
                                              .contains(searchQuery))
                                      .toList();

                              if (filtered.isEmpty) {
                                return const Center(
                                    child: Text('No products found'));
                              }

                              return ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final product = filtered[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFF3B82F6)
                                            .withOpacity(0.1),
                                        child: Text(
                                          product.name[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFF3B82F6),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(product.name),
                                      subtitle: Text(
                                        '${ref.read(currentCurrencyProvider).symbol}${product.price.toStringAsFixed(2)}',
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.add,
                                            color: Color(0xFF3B82F6)),
                                        onPressed: () {
                                          final newItem = SaleItemModel(
                                            id: _generateTemporaryItemId(),
                                            saleId: sale.id!,
                                            productId: product.id!,
                                            qty: 1,
                                            price: product.price,
                                            subtotal: product.price,
                                            discount: 0,
                                            createdAt: DateTime.now(),
                                            product: product,
                                          );

                                          final key =
                                              _saleItemControllerKey(newItem);
                                          priceControllers[key] =
                                              TextEditingController(
                                                  text: newItem.price
                                                      .toStringAsFixed(2));
                                          quantityControllers[key] =
                                              TextEditingController(
                                                  text: newItem.qty
                                                      .toStringAsFixed(2));

                                          setDialogState(() {
                                            editableItems.add(newItem);
                                          });

                                          Navigator.pop(productDialogContext);
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (error, stack) =>
                                Center(child: Text('Error: $error')),
                          ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveSaleChanges(
    SaleModel sale,
    List<SaleItemModel> editableItems,
    Map<String, TextEditingController> priceControllers,
    Map<String, TextEditingController> quantityControllers,
    BuildContext dialogContext,
  ) async {
    try {
      final updatedItems = <SaleItemModel>[];
      double newTotal = 0;

      for (var item in editableItems) {
        if (item.id == null) {
          item = item.copyWith(id: _generateTemporaryItemId());
        }
        final key = _saleItemControllerKey(item);
        final newPrice =
            double.tryParse(priceControllers[key]?.text ?? '') ?? item.price;
        final newQty =
            double.tryParse(quantityControllers[key]?.text ?? '') ?? item.qty;
        final newSubtotal = newPrice * newQty;

        updatedItems.add(
          item.copyWith(
            qty: newQty,
            price: newPrice,
            subtotal: newSubtotal,
          ),
        );

        newTotal += newSubtotal;
      }

      final discountAmount = sale.discount;
      final finalTotal = newTotal - discountAmount;

      // When invoice total is zero or negative, ensure due is also zero and update status/payment type
      // This ensures the customer balance is correctly recalculated
      double newDue = 0.0;
      double newPaid = 0.0;
      SaleStatus newStatus = SaleStatus.paid;
      PaymentType newPaymentType = PaymentType.cash;

      if (finalTotal <= 0) {
        // Zero invoice - nothing due, nothing paid
        newDue = 0.0;
        newPaid = 0.0;
        newStatus = SaleStatus.paid;
        newPaymentType = PaymentType.cash;
      } else {
        // Non-zero invoice - recalculate due based on new total
        // Preserve the original payment structure but adjust due proportionally
        final originalTotal = sale.total > 0 ? sale.total : 1.0; // Avoid division by zero
        final ratio = finalTotal / originalTotal;
        
        // Adjust paid amount proportionally, but don't exceed new total
        newPaid = (sale.paid * ratio).clamp(0.0, finalTotal);
        newDue = (finalTotal - newPaid).clamp(0.0, finalTotal);
        
        // Update status based on new due amount
        if (newDue <= 0.01) {
          newStatus = SaleStatus.paid;
        } else if (newDue >= finalTotal - 0.01) {
          newStatus = SaleStatus.unpaid;
        } else {
          newStatus = SaleStatus.partial;
        }
        
        // Keep original payment type
        newPaymentType = sale.paymentType;
      }

      final updatedSale = sale.copyWith(
        total: finalTotal,
        due: newDue,
        paid: newPaid,
        status: newStatus,
        paymentType: newPaymentType,
        items: updatedItems,
      );

      final saleNotifier = ref.read(saleNotifierProvider.notifier);
      await saleNotifier.updateSale(updatedSale);
      saleNotifier.refresh();

      // Invalidate all sales-related providers
      ref.invalidate(salesProvider);
      ref.invalidate(salesByDateRangeProvider);
      ref.invalidate(salesSummaryProvider);
      ref.invalidate(saleNotifierProvider);
      ref.invalidate(saleByIdProvider(sale.id!));
      
      // Invalidate customer-specific providers to update balance and totals
      ref.invalidate(customerByIdProvider(widget.customerId));
      ref.invalidate(salesByCustomerProvider(widget.customerId));
      ref.invalidate(customerSalesProvider(widget.customerId));
      ref.invalidate(customerLedgerProvider(widget.customerId));
      ref.invalidate(customersProvider);
      ref.invalidate(customersWithDueProvider);
      ref.invalidate(customerNotifierProvider);
      
      // Invalidate product providers
      ref.read(productNotifierProvider.notifier).refresh();
      ref.invalidate(productsProvider);

      Navigator.pop(dialogContext);

      // Wait a bit for database to update customer balance
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        // Force refresh customer data to get updated balance
        ref.invalidate(customerByIdProvider(widget.customerId));
        await ref.read(customerByIdProvider(widget.customerId).future);
        
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Sale updated successfully'),
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
            content: Text('Error updating sale: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSale(SaleModel sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Sale?'),
          ],
        ),
        content: Text(
            'Are you sure you want to delete Sale #${sale.id}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final saleNotifier = ref.read(saleNotifierProvider.notifier);
        await saleNotifier.deleteSale(sale.id!);
        saleNotifier.refresh();

        // Invalidate all sales-related providers
        ref.invalidate(salesProvider);
        ref.invalidate(salesByDateRangeProvider);
        ref.invalidate(salesSummaryProvider);
        ref.invalidate(saleNotifierProvider);
        ref.invalidate(saleByIdProvider(sale.id!));
        
        // Invalidate customer-specific providers to update balance and totals
        ref.invalidate(customerByIdProvider(widget.customerId));
        ref.invalidate(salesByCustomerProvider(widget.customerId));
        ref.invalidate(customerSalesProvider(widget.customerId));
        ref.invalidate(customerLedgerProvider(widget.customerId));
        ref.invalidate(customersProvider);
        ref.invalidate(customersWithDueProvider);
        ref.invalidate(customerNotifierProvider);
        
        // Invalidate product providers (stock may have changed)
        ref.read(productNotifierProvider.notifier).refresh();
        ref.invalidate(productsProvider);

        // Wait a bit for database to update customer balance
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          // Force refresh customer data to get updated balance
          ref.invalidate(customerByIdProvider(widget.customerId));
          await ref.read(customerByIdProvider(widget.customerId).future);
          
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Sale #${sale.id} deleted successfully'),
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
              content: Text('Error deleting sale: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildPaymentDetailTab(
      AsyncValue<List<PaymentModel>> paymentsAsync, Currency currency) {
    return paymentsAsync.when(
      data: (payments) {
        final filteredPayments =
            payments.where((payment) => _isDateInRange(payment.date)).toList();
        filteredPayments.sort((a, b) => b.date.compareTo(a.date));

        if (filteredPayments.isEmpty) {
          return _buildEmptyState('No Payment Details found');
        }

        final customerAsync =
            ref.watch(customerByIdProvider(widget.customerId));
        // Calculate the initial balance by adding all payments back to current balance
        // This gives us the balance BEFORE any payments were made
        // Exclude cancelled cheques from the calculation
        final currentBalance = customerAsync.valueOrNull?.totalDue ?? 0.0;
        final totalAllPayments = filteredPayments.fold<double>(0.0, (sum, p) {
          final isCheque = p.paymentMethod == PaymentMethod.cheque;
          final note = p.note?.toLowerCase() ?? '';
          final isCancelledCheque = isCheque &&
              (note.contains('cancelled') || note.contains('cancel'));

          // Exclude cancelled cheques from total
          if (isCancelledCheque) {
            return sum;
          }
          return sum + p.amount;
        });
        double runningBalance = currentBalance +
            totalAllPayments; // Start with balance before payments

        final reversedPayments = filteredPayments.reversed.toList();
        final paymentsWithBalance = <PaymentWithBalance>[];

        for (var i = 0; i < reversedPayments.length; i++) {
          final payment = reversedPayments[i];
          final isCheque = payment.paymentMethod == PaymentMethod.cheque;
          final note = payment.note?.toLowerCase() ?? '';
          final isCancelledCheque = isCheque &&
              (note.contains('cancelled') || note.contains('cancel'));

          final previousBalance = runningBalance;

          // Only decrease balance if payment is not a cancelled cheque
          if (!isCancelledCheque) {
            runningBalance -=
                payment.amount; // Decrease balance when payment received
          }

          // Allow negative running balance to represent advance credit

          paymentsWithBalance.add(PaymentWithBalance(
            payment: payment,
            previousBalance: previousBalance,
            paidAmount: payment.amount,
            balance: runningBalance,
          ));
        }

        final finalList = paymentsWithBalance.reversed.toList();
        // Exclude cancelled cheques from total
        final totalPaid = filteredPayments.fold<double>(0.0, (sum, payment) {
          final isCheque = payment.paymentMethod == PaymentMethod.cheque;
          final note = payment.note?.toLowerCase() ?? '';
          final isCancelledCheque = isCheque &&
              (note.contains('cancelled') || note.contains('cancel'));
          if (isCancelledCheque) return sum;
          return sum + payment.amount;
        });

        // Total number of cheques in the filtered range (all cheque payments)
        final totalCheques = filteredPayments
            .where((p) => p.paymentMethod == PaymentMethod.cheque)
            .length;

        final screenSize = MediaQuery.of(context).size;
        final isMobile = screenSize.width < 768;

        return Column(
          children: [
            if (!isMobile) ...[
              // Table Header (Desktop only)
              Container(
                color: const Color(0xFF4A90E2),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _buildTableHeader('Other Name')),
                    Expanded(flex: 1, child: _buildTableHeader('BANK')),
                    Expanded(flex: 2, child: _buildTableHeader('Paid Date')),
                    Expanded(flex: 2, child: _buildTableHeader('Cheque No')),
                    Expanded(flex: 2, child: _buildTableHeader('Issue Date')),
                    Expanded(flex: 2, child: _buildTableHeader('Cheque Date')),
                    Expanded(flex: 2, child: _buildTableHeader('User')),
                    Expanded(
                        flex: 2, child: _buildTableHeader('Previous Balance')),
                    Expanded(flex: 2, child: _buildTableHeader('Paid Amount')),
                    Expanded(flex: 2, child: _buildTableHeader('Balance')),
                  ],
                ),
              ),
            ],
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(paymentsByCustomerProvider(widget.customerId));
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: isMobile
                    ? ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: finalList.length,
                        itemBuilder: (context, index) {
                          final paymentWithBalance = finalList[index];
                          return _buildPaymentCard(
                              paymentWithBalance, currency, index);
                        },
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: finalList.length,
                        itemBuilder: (context, index) {
                          final paymentWithBalance = finalList[index];
                          return _buildPaymentRow(
                              paymentWithBalance, currency, index);
                        },
                      ),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Show total number of cheques in this ledger range
                  Row(
                    children: [
                      const Text(
                        'Cheques:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        totalCheques.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                    ],
                  ),
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
                    '${currency.symbol}${totalPaid.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
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

  Widget _buildPaymentCard(
      PaymentWithBalance paymentWithBalance, Currency currency, int index) {
    final isNegative = paymentWithBalance.paidAmount < 0;
    final isCheque =
        paymentWithBalance.payment.paymentMethod == PaymentMethod.cheque;

    // Determine status and colors
    String displayStatus = '';
    Color statusColor = const Color(0xFF4A90E2);
    Color rowColor = Colors.white;
    Color textColor = const Color(0xFF1E293B);

    if (isCheque) {
      final chequeNumber =
          _extractChequeNumber(paymentWithBalance.payment.note ?? '');
      if (chequeNumber != null) {
        return FutureBuilder(
          future:
              ref.read(bankPaymentsByChequeNumberProvider(chequeNumber).future),
          builder: (context, snapshot) {
            String status = 'pending';
            if (snapshot.connectionState == ConnectionState.done &&
                (snapshot.data?.isNotEmpty ?? false)) {
              status = snapshot.data!.first.status.toLowerCase();
            } else {
              final note = paymentWithBalance.payment.note?.toLowerCase() ?? '';
              if (note.contains('cancel')) {
                status = 'cancelled';
              } else if (note.contains('clear')) {
                status = 'cleared';
              } else if (note.contains('unclear') || note.contains('pending')) {
                status = 'unclear';
              } else {
                status = 'unclear';
              }
            }

            final bankPayment =
                snapshot.data?.isNotEmpty == true ? snapshot.data!.first : null;
            statusColor = _chequeStatusColor(status);
            rowColor = status == 'cancelled'
                ? Colors.red.shade50
                : status == 'cleared'
                    ? Colors.green.shade50
                    : Colors.yellow.shade50; // Yellow for pending
            textColor = status == 'cancelled'
                ? Colors.red.shade700
                : status == 'cleared'
                    ? Colors.green.shade700
                    : Colors.amber.shade800; // Yellow/Amber for pending (better readability)
            displayStatus = status.toUpperCase();

            return _buildPaymentCardContent(
              paymentWithBalance,
              currency,
              statusColor,
              rowColor,
              textColor,
              displayStatus,
              isNegative,
              bankPayment,
              chequeNumber,
            );
          },
        );
      }
    }

    // For non-cheque payments
    displayStatus = paymentWithBalance.payment.paymentMethod.name.toUpperCase();
    return _buildPaymentCardContent(
      paymentWithBalance,
      currency,
      statusColor,
      rowColor,
      textColor,
      displayStatus,
      isNegative,
      null,
      null,
    );
  }

  Widget _buildPaymentCardContent(
    PaymentWithBalance paymentWithBalance,
    Currency currency,
    Color statusColor,
    Color rowColor,
    Color textColor,
    String displayStatus,
    bool isNegative,
    BankPaymentModel? bankPayment,
    String? chequeNumber,
  ) {
    final isCheque =
        paymentWithBalance.payment.paymentMethod == PaymentMethod.cheque;

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
                      Row(
                        children: [
                          if (isCheque && displayStatus.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                border: Border.all(color: statusColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                displayStatus,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              paymentWithBalance.payment.note?.isNotEmpty ==
                                      true
                                  ? paymentWithBalance.payment.note!
                                  : paymentWithBalance
                                      .payment.paymentMethod.name
                                      .toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd-MMM-yyyy')
                            .format(paymentWithBalance.payment.date),
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isCheque && (bankPayment != null || chequeNumber != null)) ...[
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
                          bankPayment?.chequeNumber ?? chequeNumber ?? '-',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (bankPayment != null && bankPayment.issueDate != null)
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
                            DateFormat('dd-MM-yyyy')
                                .format(bankPayment.issueDate),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (bankPayment != null && bankPayment.chequeDate != null)
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
                            DateFormat('dd-MM-yyyy')
                                .format(bankPayment.chequeDate!),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor,
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
                        'Previous Balance',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currency.symbol}${paymentWithBalance.previousBalance.toStringAsFixed(2)}',
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
                        'Balance',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currency.symbol}${paymentWithBalance.balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.badge, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recorded by: ${paymentWithBalance.payment.processedBy?.name ?? 'Unknown'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (paymentWithBalance.payment.processedBy?.roleDisplayName !=
                    null)
                  Text(
                    paymentWithBalance.payment.processedBy!.roleDisplayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            if (bankPayment != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance,
                        size: 16, color: AppColors.primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Bank Payment',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryColor,
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

  Widget _buildPaymentRow(
      PaymentWithBalance paymentWithBalance, Currency currency, int index) {
    final isEven = index % 2 == 0;
    final isNegative = paymentWithBalance.paidAmount < 0;
    final isCheque =
        paymentWithBalance.payment.paymentMethod == PaymentMethod.cheque;

    // If it's a cheque and we can extract cheque number, fetch bank payment to determine status colors
    if (isCheque) {
      final chequeNumber =
          _extractChequeNumber(paymentWithBalance.payment.note ?? '');
      if (chequeNumber != null) {
        return FutureBuilder(
          future:
              ref.read(bankPaymentsByChequeNumberProvider(chequeNumber).future),
          builder: (context, snapshot) {
            String status = 'pending';
            if (snapshot.connectionState == ConnectionState.done &&
                (snapshot.data?.isNotEmpty ?? false)) {
              status = snapshot.data!.first.status.toLowerCase();
            } else {
              // Fallback to note parsing if bank payment not found yet
              final note = paymentWithBalance.payment.note?.toLowerCase() ?? '';
              if (note.contains('cancel')) {
                status = 'cancelled';
              } else if (note.contains('clear')) {
                status = 'cleared';
              } else if (note.contains('unclear') || note.contains('pending')) {
                status = 'unclear';
              } else {
                status =
                    'unclear'; // Default for cheque payments without status
              }
            }

            final statusColor = _chequeStatusColor(status);
            final rowColor = status == 'cancelled'
                ? Colors.red.shade50
                : status == 'cleared'
                    ? Colors.green.shade50
                    : Colors.yellow.shade50; // Yellow for pending
            final textColor = status == 'cancelled'
                ? Colors.red.shade700
                : status == 'cleared'
                    ? Colors.green.shade700
                    : Colors.amber.shade800; // Yellow/Amber for pending (better readability)

            final bankPayment =
                snapshot.data?.isNotEmpty == true ? snapshot.data!.first : null;

            return Container(
              color: rowColor,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            border: Border.all(color: statusColor),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            paymentWithBalance.payment.note?.isNotEmpty == true
                                ? paymentWithBalance.payment.note!
                                : paymentWithBalance.payment.paymentMethod.name
                                    .toUpperCase(),
                            style: TextStyle(
                                fontSize: 13,
                                color: textColor,
                                fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      bankPayment != null ? 'Bank' : '-',
                      style: TextStyle(fontSize: 13, color: textColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      DateFormat('dd-MM-yyyy')
                          .format(paymentWithBalance.payment.date),
                      style: TextStyle(
                          fontSize: 13,
                          color: textColor,
                          fontWeight: status == 'cancelled'
                              ? FontWeight.bold
                              : FontWeight.normal),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      bankPayment?.chequeNumber ?? chequeNumber ?? '-',
                      style: TextStyle(
                          fontSize: 13,
                          color: textColor,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      bankPayment != null && bankPayment.issueDate != null
                          ? DateFormat('dd-MM-yyyy')
                              .format(bankPayment.issueDate)
                          : '-',
                      style: TextStyle(fontSize: 13, color: textColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      bankPayment != null && bankPayment.chequeDate != null
                          ? DateFormat('dd-MM-yyyy')
                              .format(bankPayment.chequeDate!)
                          : '-',
                      style: TextStyle(fontSize: 13, color: textColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      paymentWithBalance.payment.processedBy?.name ?? 'Unknown',
                      style: TextStyle(fontSize: 13, color: textColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      paymentWithBalance.previousBalance.toStringAsFixed(2),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: status == 'cancelled'
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: textColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      paymentWithBalance.paidAmount.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: status == 'cancelled'
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: status == 'cancelled'
                            ? Colors.red.shade700
                            : (isNegative ? Colors.red : Colors.green),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      paymentWithBalance.balance.toStringAsFixed(2),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: status == 'cancelled'
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: textColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    }

    // Non-cheque (or cheque without number) fallback styling
    // For cheques without number, check note for status
    Color rowColor = isEven ? Colors.white : const Color(0xFFF5F5F5);
    Color textColor = const Color(0xFF1E293B);
    String displayStatus = '';

    if (isCheque) {
      final note = paymentWithBalance.payment.note?.toLowerCase() ?? '';
      String status = 'unclear';
      if (note.contains('cancel')) {
        status = 'cancelled';
      } else if (note.contains('clear')) {
        status = 'cleared';
      } else if (note.contains('pending') || note.contains('unclear')) {
        status = 'unclear';
      }

      displayStatus = status.toUpperCase();
      rowColor = status == 'cancelled'
          ? Colors.red.shade50
          : status == 'cleared'
              ? Colors.green.shade50
              : Colors.yellow.shade50; // Yellow for pending
      textColor = status == 'cancelled'
          ? Colors.red.shade700
          : status == 'cleared'
              ? Colors.green.shade700
              : Colors.amber.shade800; // Yellow/Amber for pending (better readability)
    }

    // For non-cheque payments, try to get cheque details if available
    final chequeNumber = isCheque
        ? _extractChequeNumber(paymentWithBalance.payment.note ?? '')
        : null;

    return Container(
      color: rowColor,
      padding: const EdgeInsets.all(12),
      child: chequeNumber != null && isCheque
          ? FutureBuilder(
              future: ref.read(
                  bankPaymentsByChequeNumberProvider(chequeNumber).future),
              builder: (context, snapshot) {
                final bankPayment = snapshot.data?.isNotEmpty == true
                    ? snapshot.data!.first
                    : null;
                return _buildPaymentRowContent(
                  paymentWithBalance,
                  textColor,
                  displayStatus,
                  isNegative,
                  bankPayment,
                  chequeNumber,
                );
              },
            )
          : _buildPaymentRowContent(
              paymentWithBalance,
              textColor,
              displayStatus,
              isNegative,
              null,
              null,
            ),
    );
  }

  Color _chequeStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'cancelled':
      case 'cancel':
        return Colors.red; // Red for cancelled
      case 'cleared':
      case 'clear':
      case 'completed':
        return Colors.green; // Green for cleared/accepted/completed
      case 'unclear':
      case 'pending':
      default:
        return Colors.yellow; // Yellow for unclear/pending
    }
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
              ref.invalidate(customerByIdProvider(widget.customerId));
              ref.invalidate(salesByCustomerProvider(widget.customerId));
              ref.invalidate(paymentsByCustomerProvider(widget.customerId));
            },
            child: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRowContent(
    PaymentWithBalance paymentWithBalance,
    Color textColor,
    String displayStatus,
    bool isNegative,
    BankPaymentModel? bankPayment,
    String? chequeNumber,
  ) {
    final isCheque =
        paymentWithBalance.payment.paymentMethod == PaymentMethod.cheque;
    final normalizedStatus = displayStatus.toLowerCase();
    final isCancelledStatus = normalizedStatus == 'cancelled';
    final statusColorValue = _chequeStatusColor(normalizedStatus);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isCheque && displayStatus.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColorValue.withValues(alpha: 0.12),
                    border: Border.all(color: statusColorValue),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColorValue,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  paymentWithBalance.payment.note?.isNotEmpty == true
                      ? paymentWithBalance.payment.note!
                      : paymentWithBalance.payment.paymentMethod.name
                          .toUpperCase(),
                  style: TextStyle(
                      fontSize: 13,
                      color: textColor,
                      fontWeight:
                          isCheque ? FontWeight.w600 : FontWeight.normal),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            bankPayment != null ? 'Bank' : '-',
            style: TextStyle(fontSize: 13, color: textColor),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            DateFormat('dd-MM-yyyy').format(paymentWithBalance.payment.date),
            style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: displayStatus == 'CANCELLED'
                    ? FontWeight.bold
                    : FontWeight.normal),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            bankPayment?.chequeNumber ?? chequeNumber ?? '-',
            style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: isCheque ? FontWeight.w600 : FontWeight.normal),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            bankPayment != null && bankPayment.issueDate != null
                ? DateFormat('dd-MM-yyyy').format(bankPayment.issueDate)
                : '-',
            style: TextStyle(fontSize: 13, color: textColor),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            bankPayment != null && bankPayment.chequeDate != null
                ? DateFormat('dd-MM-yyyy').format(bankPayment.chequeDate!)
                : '-',
            style: TextStyle(fontSize: 13, color: textColor),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            paymentWithBalance.payment.processedBy?.name ?? 'Unknown',
            style: TextStyle(fontSize: 13, color: textColor),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            paymentWithBalance.previousBalance.toStringAsFixed(2),
            style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isCancelledStatus ? FontWeight.bold : FontWeight.w500,
                color: textColor),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            paymentWithBalance.paidAmount.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 13,
              fontWeight: isCancelledStatus ? FontWeight.bold : FontWeight.w600,
              color: isCancelledStatus
                  ? Colors.red.shade700
                  : (isNegative ? Colors.red : Colors.green),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            paymentWithBalance.balance.toStringAsFixed(2),
            style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isCancelledStatus ? FontWeight.bold : FontWeight.w600,
                color: textColor),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildChequeDatesForCustomer(PaymentWithBalance paymentWithBalance,
      Color textColor, bool isCancelledCheque,
      {bool datesOnly = false}) {
    final isCheque =
        paymentWithBalance.payment.paymentMethod == PaymentMethod.cheque;
    if (!isCheque) {
      return Text(
        datesOnly ? '-' : '—',
        style: TextStyle(
            fontSize: 13,
            color: textColor,
            fontWeight:
                isCancelledCheque ? FontWeight.bold : FontWeight.normal),
        textAlign: TextAlign.center,
      );
    }

    final chequeNumber =
        _extractChequeNumber(paymentWithBalance.payment.note ?? '');
    if (chequeNumber == null) {
      return Text(
        datesOnly ? '-' : '—',
        style: TextStyle(
            fontSize: 13,
            color: textColor,
            fontWeight:
                isCancelledCheque ? FontWeight.bold : FontWeight.normal),
        textAlign: TextAlign.center,
      );
    }

    return FutureBuilder(
      future: ref.read(bankPaymentsByChequeNumberProvider(chequeNumber).future),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Text('…',
              style: TextStyle(fontSize: 13, color: textColor),
              textAlign: TextAlign.center);
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Text('-',
              style: TextStyle(fontSize: 13, color: textColor),
              textAlign: TextAlign.center);
        }
        final bp = list.first;
        final chequeDateStr = bp.chequeDate != null
            ? DateFormat('dd-MM-yyyy').format(bp.chequeDate!)
            : '-';
        final issueDateStr = bp.issueDate != null
            ? DateFormat('dd-MM-yyyy').format(bp.issueDate!)
            : '-';
        final text = datesOnly
            ? 'Chq: $chequeDateStr'
            : 'Chq: $chequeDateStr | Iss: $issueDateStr';
        return Text(
          text,
          style: TextStyle(
              fontSize: 13,
              color: textColor,
              fontWeight:
                  isCancelledCheque ? FontWeight.bold : FontWeight.normal),
          textAlign: TextAlign.center,
        );
      },
    );
  }

  String? _extractChequeNumber(String note) {
    // Expected in note like: "Cheque #123 - Pending" or "Customer cheque payment (CHQ-123): ..."
    // First try to extract from "Cheque #XXX" format
    final chequeHashRegex =
        RegExp(r'cheque\s*#\s*([^\s\-]+)', caseSensitive: false);
    final chequeHashMatch = chequeHashRegex.firstMatch(note);
    if (chequeHashMatch != null) {
      return chequeHashMatch.group(1)?.trim();
    }

    // Fallback to parentheses format: "Customer cheque payment (CHQ-123): ..."
    final regex = RegExp(r'\(([^)]+)\)');
    final match = regex.firstMatch(note);
    if (match != null) {
      final inside = match.group(1) ?? '';
      if (inside.isNotEmpty &&
          (inside.toLowerCase().contains('chq') || inside.length >= 3)) {
        return inside.trim();
      }
    }
    return null;
  }

  bool _isDateInRange(DateTime date) {
    return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
        date.isBefore(_endDate.add(const Duration(days: 1)));
  }

  void _navigateToPaymentScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomerPaymentScreen(customerId: widget.customerId),
      ),
    ).then((_) {
      _refreshData();
    });
  }

  void _showCustomerBankPaymentDialog(
      CustomerModel customer, Currency currency) {
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
                                    'CUSTOMER BANK PAYMENT',
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
                                    Text('ledger.customer_name_label'.tr(),
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text(customer.name),
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

                                    if (chequeNoController.text
                                        .trim()
                                        .isEmpty) {
                                      AppSnackBar.show(
                                        context,
                                        const SnackBar(
                                            content: Text(
                                                'Please enter cheque number')),
                                      );
                                      return;
                                    }

                                    if (chequeDateNotifier.value == null) {
                                      AppSnackBar.show(
                                        context,
                                        const SnackBar(
                                            content: Text(
                                                'Please select cheque date')),
                                      );
                                      return;
                                    }

                                    // Store dialog context before closing
                                    final dialogContext = context;
                                    
                                    Navigator.pop(dialogContext);

                                    try {
                                      // Create customer payment record
                                      final currentUser =
                                          ref.read(authProvider).currentUser;
                                      final baseNoteText =
                                          'Cheque #${chequeNoController.text.trim()} - Pending';
                                      final otherName =
                                          otherNameController.text.trim();
                                      String? storedNote = baseNoteText;
                                      if (otherName.isNotEmpty) {
                                        storedNote =
                                            '$baseNoteText | Other Name: $otherName';
                                      }

                                      final payment = PaymentModel(
                                        customerId: widget.customerId,
                                        amount: amount,
                                        paymentMethod: PaymentMethod.cheque,
                                        date: DateTime.now(),
                                        note: storedNote,
                                        createdAt: DateTime.now(),
                                        processedByEmployeeId: currentUser?.id,
                                      );
                                      final paymentNotifier = ref.read(
                                          paymentNotifierProvider.notifier);
                                      final paymentId = await paymentNotifier
                                          .addPayment(payment);
                                      if (paymentId <= 0) {
                                        throw Exception(
                                            'Failed to create payment record');
                                      }

                                      // CRITICAL: Get fresh customer data directly from database
                                      // Payment creation reduces balance, now we need to update unclearCheque
                                      // Use database service directly to get absolute latest data
                                      final databaseService =
                                          ref.read(databaseServiceProvider);
                                      final currentCustomer = await databaseService
                                          .getCustomerById(widget.customerId);
                                      
                                      if (currentCustomer == null) {
                                        throw Exception('Customer not found');
                                      }

                                      // Create bank payment record
                                      final bankPayment = BankPaymentModel(
                                        bankId: selectedBank!.id!,
                                        partyName: customer.name,
                                        otherName: otherName.isNotEmpty
                                            ? otherName
                                            : customer.phone,
                                        amount: amount,
                                        paymentType: 'cheque',
                                        chequeNumber:
                                            chequeNoController.text.trim(),
                                        chequeDate: chequeDateNotifier.value,
                                        issueDate: DateTime.now(),
                                        paidDate: chequeDateNotifier.value ??
                                            DateTime.now(),
                                        previousBalance:
                                            selectedBank!.currentBalance,
                                        newBalance:
                                            selectedBank!.currentBalance +
                                                amount,
                                        status: 'pending',
                                        notes:
                                            'Customer cheque payment (${chequeNoController.text.trim()}): Pending',
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

                                      // CRITICAL: Update customer's unclearCheque for cheque payments
                                      // Payment record already created (reduced balance), now add to unclearCheque
                                      final newUnclearCheque = currentCustomer.unclearCheque + amount;
                                      final updatedCustomer =
                                          currentCustomer.copyWith(
                                        unclearCheque: newUnclearCheque,
                                        updatedAt: DateTime.now(),
                                      );
                                      
                                      // Update customer in database
                                      await databaseService.updateCustomer(updatedCustomer);
                                      
                                      // Verify the update by reading back from database
                                      final verifiedCustomer = await databaseService
                                          .getCustomerById(widget.customerId);
                                      if (verifiedCustomer != null && 
                                          (verifiedCustomer.unclearCheque - newUnclearCheque).abs() > 0.01) {
                                        // Update didn't work, try again with direct database update
                                        debugPrint('Warning: unclearCheque update verification failed. Retrying...');
                                        final retryCustomer = verifiedCustomer.copyWith(
                                          unclearCheque: newUnclearCheque,
                                          updatedAt: DateTime.now(),
                                        );
                                        await databaseService.updateCustomer(retryCustomer);
                                      }

                                      // CRITICAL: Refresh ALL customer-related providers to update UI
                                      // This ensures unclear cheque updates appear in customer ledger immediately
                                      ref.invalidate(customersProvider);
                                      ref.invalidate(customersWithDueProvider);
                                      ref.invalidate(customerNotifierProvider);
                                      ref.invalidate(customerByIdProvider(widget.customerId));
                                      ref.invalidate(customerPaymentsProvider(widget.customerId));
                                      ref.invalidate(customerSalesProvider(widget.customerId));
                                      ref.invalidate(customerLedgerProvider(widget.customerId));
                                      ref.invalidate(bankNotifierProvider);
                                      ref.invalidate(allBankPaymentsProvider);
                                      
                                      // Force refresh by invalidating customer by ID again to ensure UI updates
                                      await Future.delayed(const Duration(milliseconds: 100));
                                      ref.invalidate(customerByIdProvider(widget.customerId));
                                      ref.invalidate(customerLedgerProvider(widget.customerId));
                                      
                                      debugPrint('✅ Cheque payment created: Amount=$amount, unclearCheque updated from ${currentCustomer.unclearCheque} to $newUnclearCheque');

                                      // Use the widget's context (from the screen) instead of dialog context
                                      if (mounted) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
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
                                        });
                                      }
                                    } catch (e) {
                                      // Use the widget's context (from the screen) instead of dialog context
                                      if (mounted) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
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
                                        });
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

  Future<void> _generateLedgerReport(
      CustomerModel customer, Currency currency) async {
    try {
      // CRITICAL: Get sales and payments data using read instead of watch
      final salesAsync =
          await ref.read(salesByCustomerProvider(widget.customerId).future);
      final paymentsAsync =
          await ref.read(paymentsByCustomerProvider(widget.customerId).future);

      if (salesAsync != null && paymentsAsync != null) {
        final sales = salesAsync;
        final payments = paymentsAsync;

        try {
          // Filter by date range
          final filteredSales =
              sales.where((s) => _isDateInRange(s.date)).toList();
          final filteredPayments =
              payments.where((p) => _isDateInRange(p.date)).toList();

          // Calculate opening balance (transactions before the selected period)
          final openingSalesTotal = sales
              .where((s) => s.date.isBefore(_startDate))
              .fold<double>(0.0, (sum, sale) => sum + sale.total);
          final openingPaymentsTotal = payments
              .where((p) => p.date.isBefore(_startDate))
              .fold<double>(0.0, (sum, payment) => sum + payment.amount);
          final openingBalance = openingSalesTotal - openingPaymentsTotal;

          // Prepare ledger transactions within range
          final transactionEntries = <LedgerTransaction>[];

          filteredSales.sort((a, b) => a.date.compareTo(b.date));
          for (final sale in filteredSales) {
            transactionEntries.add(
              LedgerTransaction(
                type: LedgerType.sale,
                date: sale.date,
                description: 'Sale Invoice #SINVO-${sale.id}',
                debit: sale.total,
                credit: 0,
              ),
            );
          }

          filteredPayments.sort((a, b) => a.date.compareTo(b.date));
          for (final payment in filteredPayments) {
            final isCheque = payment.paymentMethod == PaymentMethod.cheque;
            final note = payment.note?.toLowerCase() ?? '';
            final isCancelledCheque = isCheque &&
                (note.contains('cancelled') || note.contains('cancel'));

            transactionEntries.add(
              LedgerTransaction(
                type: LedgerType.payment,
                date: payment.date,
                description: payment.note?.isNotEmpty == true
                    ? '${payment.note!}${isCancelledCheque ? ' (CANCELLED)' : ''}'
                    : 'Payment - ${payment.paymentMethod.name}${isCancelledCheque ? ' (CANCELLED)' : ''}',
                debit: 0,
                credit: isCancelledCheque
                    ? 0
                    : payment.amount, // Exclude cancelled cheques from credit
              ),
            );
          }

          transactionEntries.sort((a, b) => a.date.compareTo(b.date));

          // Calculate running balance
          double runningBalance = openingBalance;
          final transactions = <LedgerTransaction>[];

          if (openingBalance.abs() > 0.0001) {
            final openingTransaction = LedgerTransaction(
              type: LedgerType.opening,
              date: _startDate,
              description: 'Opening Balance',
              debit: openingBalance > 0 ? openingBalance : 0,
              credit: openingBalance < 0 ? openingBalance.abs() : 0,
              balance: openingBalance,
            );
            transactions.add(openingTransaction);
          }

          for (final transaction in transactionEntries) {
            runningBalance =
                runningBalance + transaction.debit - transaction.credit;
            transaction.balance = runningBalance;
            transactions.add(transaction);
          }

          final closingBalance = runningBalance;

          // Get business info
          final databaseService = ref.read(databaseServiceProvider);
          final businessName =
              await databaseService.getSetting('business_name') ??
                  'My Business';
          final businessAddress =
              await databaseService.getSetting('business_address') ?? '';
          final businessPhone =
              await databaseService.getSetting('business_phone') ?? '';

          // Prepare summary balances
          final currentBalance = customer.totalDue;
          final balanceDifference = (currentBalance - closingBalance).abs();

          // Generate PDF
          final pdf = pw.Document();

          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4,
              build: (context) => [
                // Header
                pw.Header(
                  level: 0,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CUSTOMER LEDGER REPORT',
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

                // Customer Information
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Customer Information',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text('Name: ${customer.name}'),
                          ),
                          pw.Expanded(
                            child: pw.Text('Phone: ${customer.phone}'),
                          ),
                        ],
                      ),
                      if (customer.address?.isNotEmpty ?? false)
                        pw.Text('Address: ${customer.address}'),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              'Balance: ${currency.symbol}${customer.totalDue.toStringAsFixed(2)}',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              'Credit Limit: ${currency.symbol}${customer.creditLimit.toStringAsFixed(2)}',
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              'Unclear Cheque: ${currency.symbol}${customer.unclearCheque.toStringAsFixed(2)}',
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

                // Date Range
                pw.Text(
                  'Period: ${DateFormat('dd MMM yyyy').format(_startDate)} to ${DateFormat('dd MMM yyyy').format(_endDate)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),

                // Transactions Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Date',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Description',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Cheque Date',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Debit',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Credit',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Balance',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Transaction Rows
                    ...transactions.map((transaction) => pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                DateFormat('dd/MM/yyyy')
                                    .format(transaction.date),
                                style: pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                transaction.description,
                                style: pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                transaction.chequeDate != null
                                    ? DateFormat('dd/MM/yyyy')
                                        .format(transaction.chequeDate!)
                                    : transaction.chequeIssueDate != null
                                        ? DateFormat('dd/MM/yyyy').format(
                                            transaction.chequeIssueDate!)
                                        : '-',
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Container(
                                alignment: pw.Alignment.centerRight,
                                constraints:
                                    const pw.BoxConstraints(minWidth: 60),
                                child: pw.Text(
                                  transaction.debit > 0
                                      ? '${currency.symbol}${transaction.debit.toStringAsFixed(2)}'
                                      : '-',
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Container(
                                alignment: pw.Alignment.centerRight,
                                constraints:
                                    const pw.BoxConstraints(minWidth: 60),
                                child: pw.Text(
                                  transaction.credit > 0
                                      ? '${currency.symbol}${transaction.credit.toStringAsFixed(2)}'
                                      : '-',
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Container(
                                alignment: pw.Alignment.centerRight,
                                constraints:
                                    const pw.BoxConstraints(minWidth: 60),
                                child: pw.Text(
                                  '${currency.symbol}${transaction.balance.toStringAsFixed(2)}',
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold),
                                ),
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
                    border: pw.Border.all(color: PdfColors.black),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
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
                      if (balanceDifference > 0.01)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 6),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Current Balance:',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.normal,
                                ),
                              ),
                              pw.Text(
                                '${currency.symbol}${currentBalance.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Footer
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
              builder: (context) => _LedgerReportDialog(
                customer: customer,
                currency: currency,
                businessName: businessName,
                businessAddress: businessAddress,
                businessPhone: businessPhone,
                customerId: widget.customerId,
                initialStartDate: _startDate,
                initialEndDate: _endDate,
              ),
            );
          }
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
      } else {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Error loading ledger data'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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

  void _showDeleteDialog(CustomerModel customer) async {
    final confirmed = await ModernDialogBuilder.showConfirmDialog(
      context: context,
      title: 'Delete Customer',
      message:
          'Are you sure you want to delete "${customer.name}"?\n\nThis will permanently delete:\n• All associated sales\n• All associated payments\n• The customer record\n\nStock will be restored for all sold items.\n\nThis action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      icon: Icons.delete_outline,
    );

    if (confirmed == true) {
      try {
        await ref
            .read(customerNotifierProvider.notifier)
            .deleteCustomer(customer.id!);
        // Invalidate related providers - don't invalidate customerNotifierProvider as it already refreshed
        ref.invalidate(customerByIdProvider(customer.id!));
        ref.invalidate(customersProvider);
        ref.invalidate(customersWithDueProvider);

        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Customer deleted successfully'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          // Navigate back to customers screen
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/customers');
          }
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Error deleting customer: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }
}

// Helper classes
enum LedgerType { opening, sale, payment }

class LedgerTransaction {
  final LedgerType type;
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  double balance;
  final DateTime? chequeDate;
  final DateTime? chequeIssueDate;
  final String? chequeNumber;

  LedgerTransaction({
    required this.type,
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    this.balance = 0.0,
    this.chequeDate,
    this.chequeIssueDate,
    this.chequeNumber,
  });
}

// Ledger Report Dialog Widget
class _LedgerReportDialog extends ConsumerStatefulWidget {
  final CustomerModel customer;
  final Currency currency;
  final String businessName;
  final String businessAddress;
  final String businessPhone;
  final int customerId;
  final DateTime initialStartDate;
  final DateTime initialEndDate;

  const _LedgerReportDialog({
    required this.customer,
    required this.currency,
    required this.businessName,
    required this.businessAddress,
    required this.businessPhone,
    required this.customerId,
    required this.initialStartDate,
    required this.initialEndDate,
  });

  @override
  ConsumerState<_LedgerReportDialog> createState() =>
      _LedgerReportDialogState();
}

class _LedgerReportDialogState extends ConsumerState<_LedgerReportDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  List<LedgerTransaction> _transactions = [];
  pw.Document? _pdf;
  bool _isLoading = false;
  double _openingBalance = 0;
  double _closingBalance = 0;
  double _currentBalance = 0;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _loadLedgerData();
  }

  String? _extractChequeNumber(String note) {
    // Expected in note like: "Cheque #123 - Pending" or "Customer cheque payment (CHQ-123): ..."
    // First try to extract from "Cheque #XXX" format
    final chequeHashRegex =
        RegExp(r'cheque\s*#\s*([^\s\-]+)', caseSensitive: false);
    final chequeHashMatch = chequeHashRegex.firstMatch(note);
    if (chequeHashMatch != null) {
      return chequeHashMatch.group(1)?.trim();
    }

    // Fallback to parentheses format: "Customer cheque payment (CHQ-123): ..."
    final regex = RegExp(r'\(([^)]+)\)');
    final match = regex.firstMatch(note);
    if (match != null) {
      final inside = match.group(1) ?? '';
      if (inside.isNotEmpty &&
          (inside.toLowerCase().contains('chq') || inside.length >= 3)) {
        return inside.trim();
      }
    }
    return null;
  }

  Future<void> _loadLedgerData() async {
    setState(() => _isLoading = true);
    try {
      final salesAsync =
          await ref.read(salesByCustomerProvider(widget.customerId).future);
      final paymentsAsync =
          await ref.read(paymentsByCustomerProvider(widget.customerId).future);

      if (salesAsync != null && paymentsAsync != null) {
        final sales = salesAsync;
        final payments = paymentsAsync;

        final filteredSales = sales.where((s) {
          return s.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
              s.date.isBefore(_endDate.add(const Duration(days: 1)));
        }).toList();

        final filteredPayments = payments.where((p) {
          return p.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
              p.date.isBefore(_endDate.add(const Duration(days: 1)));
        }).toList();

        filteredSales.sort((a, b) => a.date.compareTo(b.date));
        filteredPayments.sort((a, b) => a.date.compareTo(b.date));

        final openingSalesTotal = sales
            .where((s) => s.date.isBefore(_startDate))
            .fold<double>(0.0, (sum, sale) => sum + sale.total);
        final openingPaymentsTotal = payments
            .where((p) => p.date.isBefore(_startDate))
            .fold<double>(0.0, (sum, payment) => sum + payment.amount);
        final openingBalance = openingSalesTotal - openingPaymentsTotal;

        final transactionEntries = <LedgerTransaction>[];

        for (final sale in filteredSales) {
          transactionEntries.add(
            LedgerTransaction(
              type: LedgerType.sale,
              date: sale.date,
              description: 'Sale Invoice #SINVO-${sale.id}',
              debit: sale.total,
              credit: 0,
            ),
          );
        }

        for (final payment in filteredPayments) {
          final isCheque = payment.paymentMethod == PaymentMethod.cheque;
          final note = payment.note?.toLowerCase() ?? '';
          final isCancelledCheque = isCheque &&
              (note.contains('cancelled') || note.contains('cancel'));

          DateTime? chequeDate;
          DateTime? chequeIssueDate;
          String? chequeNumber;

          if (isCheque) {
            chequeNumber = _extractChequeNumber(payment.note ?? '');
            if (chequeNumber != null && chequeNumber!.isNotEmpty) {
              try {
                final bankPayments = await ref.read(
                    bankPaymentsByChequeNumberProvider(chequeNumber!).future);
                if (bankPayments.isNotEmpty) {
                  final bankPayment = bankPayments.first;
                  chequeDate = bankPayment.chequeDate;
                  chequeIssueDate = bankPayment.issueDate;
                }
              } catch (_) {
                // Ignore lookup errors – we'll fall back to placeholders
              }
            }
          }

          transactionEntries.add(
            LedgerTransaction(
              type: LedgerType.payment,
              date: payment.date,
              description: payment.note?.isNotEmpty == true
                  ? '${payment.note!}${isCancelledCheque ? ' (CANCELLED)' : ''}'
                  : 'Payment - ${payment.paymentMethod.name}${isCancelledCheque ? ' (CANCELLED)' : ''}',
              debit: 0,
              credit: isCancelledCheque ? 0 : payment.amount,
              chequeDate: chequeDate,
              chequeIssueDate: chequeIssueDate,
              chequeNumber: chequeNumber,
            ),
          );
        }

        transactionEntries.sort((a, b) => a.date.compareTo(b.date));

        double runningBalance = openingBalance;
        final transactions = <LedgerTransaction>[];

        if (openingBalance.abs() > 0.0001) {
          final openingTransaction = LedgerTransaction(
            type: LedgerType.opening,
            date: _startDate,
            description: 'Opening Balance',
            debit: openingBalance > 0 ? openingBalance : 0,
            credit: openingBalance < 0 ? openingBalance.abs() : 0,
            balance: openingBalance,
          );
          transactions.add(openingTransaction);
        }

        for (final transaction in transactionEntries) {
          runningBalance =
              runningBalance + transaction.debit - transaction.credit;
          transaction.balance = runningBalance;
          transactions.add(transaction);
        }

        final closingBalance = runningBalance;
        final currentBalance = widget.customer.totalDue;
        final balanceDifference = (currentBalance - closingBalance).abs();

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
                      'CUSTOMER LEDGER REPORT',
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(businessName, style: pw.TextStyle(fontSize: 14)),
                    if (businessAddress.isNotEmpty)
                      pw.Text(businessAddress,
                          style: pw.TextStyle(fontSize: 12)),
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
                    pw.Text('Customer Information',
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                            child: pw.Text('Name: ${widget.customer.name}')),
                        pw.Expanded(
                            child: pw.Text('Phone: ${widget.customer.phone}')),
                      ],
                    ),
                    if (widget.customer.address?.isNotEmpty ?? false)
                      pw.Text('Address: ${widget.customer.address}'),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                            child: pw.Text(
                                'Balance: ${widget.currency.symbol}${widget.customer.totalDue.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold))),
                        pw.Expanded(
                            child: pw.Text(
                                'Credit Limit: ${widget.currency.symbol}${widget.customer.creditLimit.toStringAsFixed(2)}')),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                  'Period: ${DateFormat('dd MMM yyyy').format(_startDate)} to ${DateFormat('dd MMM yyyy').format(_endDate)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
                          child: pw.Text('Date',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Description',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Cheque Date',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.center)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Debit',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Credit',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Balance',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  ...transactions.map((transaction) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              transaction.type == LedgerType.opening
                                  ? '—'
                                  : DateFormat('dd/MM/yyyy')
                                      .format(transaction.date),
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(transaction.description,
                                style: pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              transaction.chequeDate != null
                                  ? DateFormat('dd/MM/yyyy')
                                      .format(transaction.chequeDate!)
                                  : transaction.chequeIssueDate != null
                                      ? DateFormat('dd/MM/yyyy')
                                          .format(transaction.chequeIssueDate!)
                                      : '-',
                              style: pw.TextStyle(
                                  fontSize: 10, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Container(
                              alignment: pw.Alignment.centerRight,
                              constraints:
                                  const pw.BoxConstraints(minWidth: 60),
                              child: pw.Text(
                                transaction.debit > 0
                                    ? '${widget.currency.symbol}${transaction.debit.toStringAsFixed(2)}'
                                    : '-',
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Container(
                              alignment: pw.Alignment.centerRight,
                              constraints:
                                  const pw.BoxConstraints(minWidth: 60),
                              child: pw.Text(
                                transaction.credit > 0
                                    ? '${widget.currency.symbol}${transaction.credit.toStringAsFixed(2)}'
                                    : '-',
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Container(
                              alignment: pw.Alignment.centerRight,
                              constraints:
                                  const pw.BoxConstraints(minWidth: 60),
                              child: pw.Text(
                                '${widget.currency.symbol}${transaction.balance.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Closing Balance:',
                          style: pw.TextStyle(
                              fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '${widget.currency.symbol}${closingBalance.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              fontSize: 16, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    if (balanceDifference > 0.01)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 6),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Current Balance:',
                              style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.normal),
                            ),
                            pw.Text(
                              '${widget.currency.symbol}${currentBalance.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.normal),
                            ),
                          ],
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

        if (mounted) {
          setState(() {
            _transactions = transactions;
            _openingBalance = openingBalance;
            _closingBalance = closingBalance;
            _currentBalance = currentBalance;
            _pdf = pdf;
            _isLoading = false;
          });
        } else {
          _transactions = transactions;
          _openingBalance = openingBalance;
          _closingBalance = closingBalance;
          _currentBalance = currentBalance;
          _pdf = pdf;
          _isLoading = false;
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        } else {
          _isLoading = false;
        }
      }
    } catch (e) {
      debugPrint('Error loading ledger data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      } else {
        _isLoading = false;
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
                        'CUSTOMER LEDGER REPORT',
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

            // Customer Info
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
                    'Customer Information',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text('Name: ${widget.customer.name}')),
                      Expanded(child: Text('Phone: ${widget.customer.phone}')),
                    ],
                  ),
                  if (widget.customer.address?.isNotEmpty ?? false)
                    Text('Address: ${widget.customer.address}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Balance: ${widget.currency.symbol}${widget.customer.totalDue.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Credit Limit: ${widget.currency.symbol}${widget.customer.creditLimit.toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor:
                        MaterialStateProperty.all(Colors.grey.shade200),
                    columns: const [
                      DataColumn(
                          label: Text('Date',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Description',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Cheque Date',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Debit',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                      DataColumn(
                          label: Text('Credit',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                      DataColumn(
                          label: Text('Balance',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                    ],
                    rows: _transactions.map((transaction) {
                      final paidDate = transaction.type == LedgerType.opening
                          ? '—'
                          : DateFormat('dd/MM/yyyy').format(transaction.date);
                      final chequeDateText = transaction.chequeDate != null
                          ? DateFormat('dd/MM/yyyy')
                              .format(transaction.chequeDate!)
                          : transaction.chequeIssueDate != null
                              ? DateFormat('dd/MM/yyyy')
                                  .format(transaction.chequeIssueDate!)
                              : (transaction.type == LedgerType.payment
                                  ? '-'
                                  : '—');
                      final debitText = transaction.debit > 0
                          ? '${widget.currency.symbol}${transaction.debit.toStringAsFixed(2)}'
                          : '-';
                      final creditText = transaction.credit > 0
                          ? '${widget.currency.symbol}${transaction.credit.toStringAsFixed(2)}'
                          : '-';
                      return DataRow(
                        cells: [
                          DataCell(Text(paidDate)),
                          DataCell(Text(transaction.description)),
                          DataCell(Text(chequeDateText)),
                          DataCell(Text(debitText)),
                          DataCell(Text(creditText)),
                          DataCell(
                            Text(
                              '${widget.currency.symbol}${transaction.balance.toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
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

class SaleWithBalance {
  final SaleModel sale;
  final double previousBalance;
  final double payableAmount;
  final double balance;

  SaleWithBalance({
    required this.sale,
    required this.previousBalance,
    required this.payableAmount,
    required this.balance,
  });
}

class PaymentWithBalance {
  final PaymentModel payment;
  final double previousBalance;
  final double paidAmount;
  final double balance;

  PaymentWithBalance({
    required this.payment,
    required this.previousBalance,
    required this.paidAmount,
    required this.balance,
  });
}
