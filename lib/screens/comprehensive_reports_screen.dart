import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/expense.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/payment_provider.dart' as payment_provider;
import '../providers/currency_provider.dart';
import '../providers/stock_movement_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/bank_provider.dart' as bank_provider;
import '../utils/quantity_formatter.dart';
import '../models/currency.dart';
import '../models/payment.dart';
import '../models/sale.dart';
import '../models/employee.dart';
import '../models/customer.dart';
import '../models/supplier_payment.dart';
import '../models/supplier.dart';
import '../models/bank_payment.dart';
import '../services/database_service.dart';
import 'item_wise_sales_report_screen.dart';
import 'payment_detail_screen.dart';
import '../providers/expense_head_provider.dart';
import '../database/database.dart';
import '../widgets/app_snack_bar.dart';

// ==================== OVERVIEW DATA STRUCTURES ====================

class SalesDataByEmployee {
  final String employeeName;
  final double retailCashSale;
  final double retailCashProfit;
  final double retailCreditSale;
  final double retailCreditProfit;
  final double wholesaleCashSale;
  final double wholesaleCashProfit;
  final double wholesaleCreditSale;
  final double wholesaleCreditProfit;
  final double stockMovementSale;
  final double stockMovementProfit;
  final double totalSale;
  final double totalProfit;

  SalesDataByEmployee({
    required this.employeeName,
    this.retailCashSale = 0,
    this.retailCashProfit = 0,
    this.retailCreditSale = 0,
    this.retailCreditProfit = 0,
    this.wholesaleCashSale = 0,
    this.wholesaleCashProfit = 0,
    this.wholesaleCreditSale = 0,
    this.wholesaleCreditProfit = 0,
    this.stockMovementSale = 0,
    this.stockMovementProfit = 0,
    this.totalSale = 0,
    this.totalProfit = 0,
  });
}

class SalesDataSummary {
  final List<SalesDataByEmployee> byEmployee;
  final double totalSales;
  final double totalCost;
  final double totalProfit;
  final double cashSaleTotal;
  final double cashSaleProfit;

  SalesDataSummary({
    required this.byEmployee,
    this.totalSales = 0,
    this.totalCost = 0,
    this.totalProfit = 0,
    this.cashSaleTotal = 0,
    this.cashSaleProfit = 0,
  });
}

class PaymentDataByEmployee {
  final String employeeName;
  final double creditCashReceived;
  final double creditChequeReceived;
  final double partyBankPayment;
  final double partyCashPayment;
  final double partyChequePayment;
  final double total;

  PaymentDataByEmployee({
    required this.employeeName,
    this.creditCashReceived = 0,
    this.creditChequeReceived = 0,
    this.partyBankPayment = 0,
    this.partyCashPayment = 0,
    this.partyChequePayment = 0,
    this.total = 0,
  });
}

class PaymentDataSummary {
  final List<PaymentDataByEmployee> byEmployee;
  final double totalCreditCashReceived;
  final double totalCreditChequeReceived;
  final double totalPartyBankPayment;
  final double totalPartyCashPayment;
  final double totalPartyChequePayment;
  final double grandTotal;

  PaymentDataSummary({
    required this.byEmployee,
    this.totalCreditCashReceived = 0,
    this.totalCreditChequeReceived = 0,
    this.totalPartyBankPayment = 0,
    this.totalPartyCashPayment = 0,
    this.totalPartyChequePayment = 0,
    this.grandTotal = 0,
  });
}

class ReceivableCredit {
  final double retailCredit;
  final double wholesaleCredit;
  final double unclearCheque;
  final double total;

  ReceivableCredit({
    this.retailCredit = 0,
    this.wholesaleCredit = 0,
    this.unclearCheque = 0,
    this.total = 0,
  });
}

class DailySummary {
  final double cashSale;
  final double recovery;
  final double total;
  final double expense;
  final double paymentToParty;
  final double netBalance;

  DailySummary({
    this.cashSale = 0,
    this.recovery = 0,
    this.total = 0,
    this.expense = 0,
    this.paymentToParty = 0,
    this.netBalance = 0,
  });
}

final _allSupplierPaymentsProvider =
    FutureProvider.family<List<SupplierPaymentModel>, DateRangeFilter>(
        (ref, range) async {
  // React to refresh ticks so dependents update in real-time after mutations
  ref.watch(payment_provider.paymentsRefreshTickProvider);
  final databaseService = ref.watch(databaseServiceProvider);
  final suppliers = await databaseService.getAllSuppliers();
  final payments = <SupplierPaymentModel>[];

  for (final supplier in suppliers) {
    if (supplier.id != null) {
      final supplierPayments =
          await databaseService.getSupplierPaymentsByDateRange(
        supplier.id!,
        range.start,
        range.end,
      );
      payments.addAll(supplierPayments);
    }
  }

  return payments;
});

class ComprehensiveReportsScreen extends ConsumerStatefulWidget {
  const ComprehensiveReportsScreen({super.key});

  @override
  ConsumerState<ComprehensiveReportsScreen> createState() =>
      _ComprehensiveReportsScreenState();
}

class _ComprehensiveReportsScreenState
    extends ConsumerState<ComprehensiveReportsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isExporting = false;
  int _selectedReportIndex = 0; // For mobile dropdown
  final TextEditingController _minExpenseAmountController =
      TextEditingController();
  final TextEditingController _maxExpenseAmountController =
      TextEditingController();
  final TextEditingController _expenseHeadDropdownController =
      TextEditingController(text: 'All');
  String? _selectedExpenseHeadFilter;
  double _overviewSalesTableScale = 1.0;
  static const double _overviewSalesMinScale = 0.8;
  static const double _overviewSalesMaxScale = 1.6;
  final ScrollController _overviewSalesHorizontalController =
      ScrollController();

  final List<Map<String, dynamic>> _reportTabs = const [
    {'title': 'Overview', 'icon': Icons.dashboard},
    {'title': 'Sales Analytics', 'icon': Icons.trending_up},
    {'title': 'Item List', 'icon': Icons.inventory_2},
    {'title': 'Low Stock', 'icon': Icons.trending_down},
    {'title': 'Day End', 'icon': Icons.calendar_today},
    {'title': 'Payments', 'icon': Icons.payments},
    {'title': 'Cash Report', 'icon': Icons.money},
    {'title': 'Credit Report', 'icon': Icons.credit_card},
    {'title': 'Stock Movement', 'icon': Icons.move_up},
    {'title': 'Profit Analysis', 'icon': Icons.account_balance_wallet},
    {'title': 'Monthly Report', 'icon': Icons.calendar_month},
    {'title': 'Monthly P&L', 'icon': Icons.account_balance},
    {'title': 'Expense Report', 'icon': Icons.receipt_long},
    {'title': 'Wholesale Report', 'icon': Icons.store},
    {'title': 'Item-wise Sales', 'icon': Icons.assessment},
    {'title': 'Daily Comprehensive', 'icon': Icons.table_chart},
  ];

  @override
  void initState() {
    super.initState();
    // Default both dates to today on first load to show today's data automatically
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = today;
    _endDate = today;
    // TabController is kept for compatibility but not actively used for UI
    _tabController = TabController(length: _reportTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _minExpenseAmountController.dispose();
    _maxExpenseAmountController.dispose();
    _expenseHeadDropdownController.dispose();
    _overviewSalesHorizontalController.dispose();
    super.dispose();
  }

  void _updateSelectedIndexFromRoute() {
    final uri = GoRouterState.of(context).uri;
    final tabParam = uri.queryParameters['tab'];
    int? newTabIndex;

    if (tabParam != null) {
      final tabIndex = int.tryParse(tabParam);
      if (tabIndex != null && tabIndex >= 0 && tabIndex < _reportTabs.length) {
        newTabIndex = tabIndex;
      }
    } else {
      // Default to Overview (index 0) if no tab parameter
      newTabIndex = 0;
    }

    // Update selected index if it changed
    if (newTabIndex != null && newTabIndex != _selectedReportIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // Reset dates to today when switching to Overview (index 0), Payment (index 5), Cash Report (index 6) or Credit Report (index 7)
        if (newTabIndex == 0 ||
            newTabIndex == 5 ||
            newTabIndex == 6 ||
            newTabIndex == 7) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          setState(() {
            _selectedReportIndex = newTabIndex!;
            _startDate = today;
            _endDate = today;
          });

          // Invalidate providers to refresh data with today's date
          final startBoundary = DateTime(today.year, today.month, today.day);
          final endBoundary =
              DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

          ref.invalidate(salesProvider);
          ref.invalidate(payment_provider.paymentsByDateRangeProvider(
            payment_provider.DateRange(start: startBoundary, end: endBoundary),
          ));
          ref.invalidate(_allSupplierPaymentsProvider(
            DateRangeFilter(start: startBoundary, end: endBoundary),
          ));
          ref.invalidate(bank_provider.bankPaymentsByDateRangeProvider(
            (start: startBoundary, end: endBoundary),
          ));
          ref.invalidate(expenseSummaryProvider(
            DateRangeFilter(start: startBoundary, end: endBoundary),
          ));
        } else {
          setState(() {
            _selectedReportIndex = newTabIndex!;
          });
        }
        // Update tab controller to keep it in sync (even though UI doesn't use it)
        if (_tabController.index != newTabIndex) {
          _tabController.animateTo(newTabIndex ?? 0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update selected index from route on every build
    _updateSelectedIndexFromRoute();

    // Get current report title
    final currentReportTitle = _selectedReportIndex < _reportTabs.length
        ? _reportTabs[_selectedReportIndex]['title'] as String
        : 'All Reports';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          currentReportTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: _buildReportContent(_selectedReportIndex),
    );
  }

  Widget _buildReportContent(int index) {
    switch (index) {
      case 0:
        return _buildOverviewReport();
      case 1:
        return _buildSalesAnalyticsReport();
      case 2:
        return _buildItemListReport();
      case 3:
        return _buildLowStockReport();
      case 4:
        return _buildDayEndReport();
      case 5:
        return _buildPaymentReport();
      case 6:
        return _buildCashReport();
      case 7:
        return _buildCreditReport();
      case 8:
        return _buildStockMovementReport();
      case 9:
        return _buildProfitAnalysisReport();
      case 10:
        return _buildMonthlyReport();
      case 11:
        return _buildMonthlyProfitLossReport();
      case 12:
        return _buildExpenseReport();
      case 13:
        return _buildWholesaleReport();
      case 14:
        return _buildItemWiseSalesReport();
      case 15:
        return _buildDailyComprehensiveReport();
      default:
        return _buildOverviewReport();
    }
  }

  /// Minimal Daily Comprehensive Report tab to avoid indefinite loading.
  /// Can be extended to full spec later; shows friendly message when no data.
  Widget _buildDailyComprehensiveReport() {
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;
    final isAdmin = currentUser?.isAdmin == true;
    final isManager = currentUser?.isManager == true;
    if (!(isAdmin || isManager)) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _buildEmptyState('Access denied'),
      );
    }
    final currency = ref.watch(currentCurrencyProvider);
    final DateTime start =
        DateTime(_startDate.year, _startDate.month, _startDate.day);
    final DateTime end =
        DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999);
    final salesAsync = ref.watch(salesProvider);
    final paymentsAsync =
        ref.watch(payment_provider.paymentsByDateRangeProvider(
      payment_provider.DateRange(start: start, end: end),
    ));
    final databaseService = ref.watch(databaseServiceProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('misc.daily_comprehensive'.tr(),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
              'reports.date_range_caption'.tr(namedArgs: {
                'from': DateFormat('dd MMM yyyy').format(start),
                'to': DateFormat('dd MMM yyyy').format(end),
              }),
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          Expanded(
            child: salesAsync.when(
              data: (sales) => paymentsAsync.when(
                data: (payments) {
                  return FutureBuilder<List<EmployeeModel>>(
                    future: databaseService.getAllEmployees(),
                    builder: (context, employeesSnap) {
                      if (!employeesSnap.hasData) {
                        return _buildEmptyState('Loading users...');
                      }
                      final employees = employeesSnap.data ?? [];

                      // Filter sales by date and employee scope
                      var filteredSales = sales
                          .where((s) =>
                              !s.date.isBefore(start) && !s.date.isAfter(end))
                          .toList();
                      if (!isAdmin &&
                          (isManager || currentUser?.isCashier == true)) {
                        final uid = currentUser?.id;
                        if (uid != null) {
                          filteredSales = filteredSales
                              .where((s) => (s.cashierId ?? -1) == uid)
                              .toList();
                        }
                      }

                      // Filter payments by date and employee scope
                      var filteredPayments = payments
                          .where((p) =>
                              !p.date.isBefore(start) && !p.date.isAfter(end))
                          .toList();
                      if (!isAdmin &&
                          (isManager || currentUser?.isCashier == true)) {
                        final uid = currentUser?.id;
                        if (uid != null) {
                          filteredPayments = filteredPayments
                              .where(
                                  (p) => (p.processedByEmployeeId ?? -1) == uid)
                              .toList();
                        }
                      }

                      if (filteredSales.isEmpty && filteredPayments.isEmpty) {
                        return _buildEmptyState(
                            'No data found for selected range');
                      }

                      // Group sales by employee (cashierId)
                      Map<int, List<SaleModel>> salesByUser = {};
                      for (final s in filteredSales) {
                        final uid = s.cashierId ?? -1;
                        salesByUser.putIfAbsent(uid, () => []);
                        salesByUser[uid]!.add(s);
                      }

                      // Helper to compute sale and profit
                      double saleTotal(List<SaleModel> list) =>
                          list.fold(0.0, (sum, s) => sum + s.total);
                      double profitTotal(List<SaleModel> list) =>
                          list.fold(0.0, (sum, s) {
                            final cost = s.items.fold(
                                0.0,
                                (cs, i) =>
                                    cs + ((i.product?.cost ?? 0) * i.qty));
                            return sum + (s.total - cost);
                          });

                      // Build per-user rows
                      final headerCells = <String>[
                        'User',
                        'Retail Cash: Sale',
                        if (isAdmin) 'Retail Cash: Profit',
                        'Retail Credit: Sale',
                        if (isAdmin) 'Retail Credit: Profit',
                        'Stock Movement: Sale',
                        if (isAdmin) 'Stock Movement: Profit',
                        'Wholesale Cash: Sale',
                        if (isAdmin) 'Wholesale Cash: Profit',
                        'Wholesale Credit: Sale',
                        if (isAdmin) 'Wholesale Credit: Profit',
                        'TOTAL',
                      ];

                      List<List<String>> userRows = [];
                      double gRetailCash = 0,
                          gRetailCredit = 0,
                          gSm = 0,
                          gWcash = 0,
                          gWcredit = 0;
                      double gPRetailCash = 0,
                          gPRetailCredit = 0,
                          gPSm = 0,
                          gPWcash = 0,
                          gPWcredit = 0;

                      List<int> userIds = salesByUser.keys.toList()..sort();
                      if (userIds.isEmpty &&
                          (isManager || currentUser?.isCashier == true) &&
                          currentUser?.id != null) {
                        userIds = [currentUser!.id!];
                      }

                      for (final uid in userIds) {
                        final emp = employees.firstWhere(
                          (e) => e.id == uid,
                          orElse: () => EmployeeModel(
                            id: uid,
                            name: uid == -1 ? 'Unknown' : 'User $uid',
                            phone: '',
                            employeeId: 'EMP',
                            hireDate: DateTime.now(),
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );
                        final list = salesByUser[uid] ?? [];

                        // Split sales by retail/wholesale and cash/card vs credit using isWholesale + paymentType
                        final retailCashList = list
                            .where((s) =>
                                (s.paymentType == PaymentType.cash ||
                                    s.paymentType == PaymentType.card) &&
                                !s.isWholesale)
                            .toList();
                        final wholesaleCashList = list
                            .where((s) =>
                                (s.paymentType == PaymentType.cash ||
                                    s.paymentType == PaymentType.card) &&
                                s.isWholesale)
                            .toList();
                        final retailCreditList = list
                            .where((s) =>
                                s.paymentType == PaymentType.credit &&
                                !s.isWholesale)
                            .toList();
                        final wholesaleCreditList = list
                            .where((s) =>
                                s.paymentType == PaymentType.credit &&
                                s.isWholesale)
                            .toList();

                        final retailCash = saleTotal(retailCashList);
                        final pRetailCash = profitTotal(retailCashList);
                        final retailCredit = saleTotal(retailCreditList);
                        final pRetailCredit = profitTotal(retailCreditList);
                        final smSale = 0.0,
                            pSmSale =
                                0.0; // No explicit stock movement flag available here
                        final wCash = saleTotal(wholesaleCashList),
                            pWcash = profitTotal(wholesaleCashList);
                        final wCredit = saleTotal(wholesaleCreditList),
                            pWcredit = profitTotal(wholesaleCreditList);
                        final total = retailCash +
                            retailCredit +
                            smSale +
                            wCash +
                            wCredit;

                        gRetailCash += retailCash;
                        gPRetailCash += pRetailCash;
                        gRetailCredit += retailCredit;
                        gPRetailCredit += pRetailCredit;
                        gSm += smSale;
                        gPSm += pSmSale;
                        gWcash += wCash;
                        gPWcash += pWcash;
                        gWcredit += wCredit;
                        gPWcredit += pWcredit;

                        userRows.add([
                          emp.name.toUpperCase(),
                          '${currency.symbol}${retailCash.toStringAsFixed(0)}',
                          if (isAdmin)
                            '${currency.symbol}${pRetailCash.toStringAsFixed(0)}',
                          '${currency.symbol}${retailCredit.toStringAsFixed(0)}',
                          if (isAdmin)
                            '${currency.symbol}${pRetailCredit.toStringAsFixed(0)}',
                          '${currency.symbol}${smSale.toStringAsFixed(0)}',
                          if (isAdmin)
                            '${currency.symbol}${pSmSale.toStringAsFixed(0)}',
                          '${currency.symbol}${wCash.toStringAsFixed(0)}',
                          if (isAdmin)
                            '${currency.symbol}${pWcash.toStringAsFixed(0)}',
                          '${currency.symbol}${wCredit.toStringAsFixed(0)}',
                          if (isAdmin)
                            '${currency.symbol}${pWcredit.toStringAsFixed(0)}',
                          '${currency.symbol}${total.toStringAsFixed(0)}',
                        ]);
                      }

                      // Totals row
                      final grandTotal =
                          gRetailCash + gRetailCredit + gSm + gWcash + gWcredit;
                      final totalsRow = <String>[
                        'TOTAL',
                        '${currency.symbol}${gRetailCash.toStringAsFixed(0)}',
                        if (isAdmin)
                          '${currency.symbol}${gPRetailCash.toStringAsFixed(0)}',
                        '${currency.symbol}${gRetailCredit.toStringAsFixed(0)}',
                        if (isAdmin)
                          '${currency.symbol}${gPRetailCredit.toStringAsFixed(0)}',
                        '${currency.symbol}${gSm.toStringAsFixed(0)}',
                        if (isAdmin)
                          '${currency.symbol}${gPSm.toStringAsFixed(0)}',
                        '${currency.symbol}${gWcash.toStringAsFixed(0)}',
                        if (isAdmin)
                          '${currency.symbol}${gPWcash.toStringAsFixed(0)}',
                        '${currency.symbol}${gWcredit.toStringAsFixed(0)}',
                        if (isAdmin)
                          '${currency.symbol}${gPWcredit.toStringAsFixed(0)}',
                        '${currency.symbol}${grandTotal.toStringAsFixed(0)}',
                      ];

                      // Credit Cash Received and Party Cash Payment by user
                      Map<String, double> creditCashByUser = {};
                      for (final p in filteredPayments.where((p) =>
                          p.paymentMethod == PaymentMethod.cash &&
                          p.amount > 0)) {
                        final uname = p.processedBy?.name ?? 'Unknown';
                        creditCashByUser.update(uname, (v) => v + p.amount,
                            ifAbsent: () => p.amount);
                      }
                      // Supplier payments - infer user by otherName if available
                      // Note: supplier payments list is not provided by a provider here; use 0 until integrated, or fetch if already on screen elsewhere.
                      // For now, show only credit cash received as per available data; party cash payment will remain zero unless integrated.
                      Map<String, double> partyCashByUser = {};

                      // Build lower table rows
                      final lowerHeaders = [
                        'User',
                        'CREDIT CASH RECEIVED',
                        'PARTY CASH PAYMENT'
                      ];
                      List<List<String>> lowerRows = [];
                      final allNames = {
                        ...creditCashByUser.keys,
                        ...partyCashByUser.keys
                      }.toList()
                        ..sort();
                      double totalCreditReceived = 0, totalPartyCash = 0;
                      for (final name in allNames) {
                        final cr = creditCashByUser[name] ?? 0;
                        final pc = partyCashByUser[name] ?? 0;
                        totalCreditReceived += cr;
                        totalPartyCash += pc;
                        lowerRows.add([
                          name.toUpperCase(),
                          '${currency.symbol}${cr.toStringAsFixed(0)}',
                          '${currency.symbol}${pc.toStringAsFixed(0)}',
                        ]);
                      }

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCustomTable(headers: headerCells, rows: [
                              ...userRows,
                              totalsRow,
                            ]),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricBox(
                                    'Cash Sale Total Amount',
                                    '${currency.symbol}${gRetailCash.toStringAsFixed(0)}',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (isAdmin)
                                  Expanded(
                                    child: _buildMetricBox(
                                      'Cash Sale Total Profit',
                                      '${currency.symbol}${gPRetailCash.toStringAsFixed(0)}',
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildCustomTable(
                              headers: lowerHeaders,
                              rows: [
                                ...lowerRows,
                                [
                                  'Total',
                                  '${currency.symbol}${totalCreditReceived.toStringAsFixed(0)}',
                                  '${currency.symbol}${totalPartyCash.toStringAsFixed(0)}'
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => _buildEmptyState('Loading daily payments...'),
                error: (e, _) => _buildEmptyState('Failed to load payments'),
              ),
              loading: () => _buildEmptyState('Loading daily sales...'),
              error: (e, _) => _buildEmptyState('Failed to load sales'),
            ),
          ),
        ],
      ),
    );
  }

  List<ExpenseModel> _applyExpenseFilters(List<ExpenseModel> expenses) {
    final startBoundary =
        DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endBoundary =
        DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999);
    final selectedHead = _selectedExpenseHeadFilter;
    final minAmount = double.tryParse(_minExpenseAmountController.text.trim());
    final maxAmount = double.tryParse(_maxExpenseAmountController.text.trim());

    return expenses.where((exp) {
      final dateMatch =
          !exp.date.isBefore(startBoundary) && !exp.date.isAfter(endBoundary);
      final headMatch = selectedHead == null ||
          exp.category.toLowerCase() == selectedHead.toLowerCase() ||
          exp.title.toLowerCase() == selectedHead.toLowerCase();
      final minMatch = minAmount == null || exp.amount >= minAmount;
      final maxMatch = maxAmount == null || exp.amount <= maxAmount;
      return dateMatch && headMatch && minMatch && maxMatch;
    }).toList();
  }

  Widget _buildExpenseFilterControls(
      AsyncValue<List<ExpenseHead>> headsAsync, Currency currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expense Filters',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              headsAsync.when(
                data: (heads) {
                  final headNames = <String>{'All'};
                  headNames.addAll(heads.map((h) => h.name));
                  final sortedHeads = headNames.toList()..sort();
                  final displayValue = _selectedExpenseHeadFilter ?? 'All';

                  // Update controller if value changed externally
                  if (_expenseHeadDropdownController.text != displayValue) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _expenseHeadDropdownController.text = displayValue;
                      }
                    });
                  }

                  return StatefulBuilder(
                    builder: (context, setLocalState) {
                      return Autocomplete<String>(
                        initialValue: TextEditingValue(text: displayValue),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return sortedHeads;
                          }
                          final query = textEditingValue.text.toLowerCase();
                          return sortedHeads.where((head) {
                            return head.toLowerCase().contains(query);
                          }).toList();
                        },
                        displayStringForOption: (String option) => option,
                        fieldViewBuilder: (
                          BuildContext context,
                          TextEditingController textEditingController,
                          FocusNode focusNode,
                          VoidCallback onFieldSubmitted,
                        ) {
                          // Initialize the controller text on first build
                          if (textEditingController.text.isEmpty ||
                              (textEditingController.text != displayValue &&
                                  displayValue != 'All')) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                textEditingController.text = displayValue;
                                _expenseHeadDropdownController.text =
                                    displayValue;
                              }
                            });
                          }

                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Expense Head',
                              hintText: 'Search or select expense head...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: textEditingController
                                          .text.isNotEmpty &&
                                      textEditingController.text != 'All'
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        textEditingController.clear();
                                        _expenseHeadDropdownController.clear();
                                        setState(() {
                                          _selectedExpenseHeadFilter = null;
                                        });
                                        setLocalState(() {});
                                      },
                                    )
                                  : null,
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                            onChanged: (value) {
                              setLocalState(() {});
                            },
                            onSubmitted: (String value) {
                              onFieldSubmitted();
                            },
                          );
                        },
                        onSelected: (String selection) {
                          setState(() {
                            _selectedExpenseHeadFilter =
                                selection == 'All' ? null : selection;
                            _expenseHeadDropdownController.text = selection;
                          });
                        },
                        optionsViewBuilder: (
                          BuildContext context,
                          AutocompleteOnSelected<String> onSelected,
                          Iterable<String> options,
                        ) {
                          if (options.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    final String option =
                                        options.elementAt(index);
                                    final bool isSelected =
                                        option == displayValue;
                                    return InkWell(
                                      onTap: () {
                                        onSelected(option);
                                      },
                                      child: Container(
                                        color: isSelected
                                            ? Colors.blue.withValues(alpha: 0.1)
                                            : Colors.transparent,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  option,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                              if (isSelected)
                                                const Icon(
                                                  Icons.check,
                                                  size: 18,
                                                  color: Colors.blue,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (error, stack) => Text('Error loading heads: $error'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minExpenseAmountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'\d*\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Min Amount',
                        prefixText: currency.symbol,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxExpenseAmountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'\d*\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Max Amount',
                        prefixText: currency.symbol,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
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

  Widget _buildExpenseExportBar(
      List<ExpenseModel> filteredExpenses, Currency currency) {
    final isDisabled = _isExporting || filteredExpenses.isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: isDisabled
                ? null
                : () => _exportExpenseToPDF(filteredExpenses, currency),
            tooltip: 'Export to PDF',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: isDisabled
                ? null
                : () => _exportExpenseToExcel(filteredExpenses, currency),
            tooltip: 'Export to Excel',
          ),
        ],
      ),
    );
  }

  // ==================== OVERVIEW REPORT ====================
  Widget _buildOverviewReport() {
    final salesAsync = ref.watch(salesProvider);
    final productsAsync = ref.watch(productNotifierProvider);
    final currency = ref.watch(currentCurrencyProvider);

    // Create proper date boundaries with full day range
    final startBoundary =
        DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endBoundary =
        DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999);

    final expenseSummary = ref.watch(expenseSummaryProvider(DateRangeFilter(
      start: startBoundary,
      end: endBoundary,
    )));
    final paymentsAsync = ref.watch(
        payment_provider.paymentsByDateRangeProvider(payment_provider.DateRange(
      start: startBoundary,
      end: endBoundary,
    )));
    final databaseService = ref.watch(databaseServiceProvider);

    return Column(
      children: [
        // Date Picker
        _buildDatePicker(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final startBoundary =
                  DateTime(_startDate.year, _startDate.month, _startDate.day);
              final endBoundary = DateTime(
                  _endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999);
              ref.invalidate(salesProvider);
              ref.invalidate(productNotifierProvider);
              ref.invalidate(expenseSummaryProvider(
                  DateRangeFilter(start: startBoundary, end: endBoundary)));
              ref.invalidate(payment_provider.paymentsByDateRangeProvider(
                  payment_provider.DateRange(
                      start: startBoundary, end: endBoundary)));
              ref.invalidate(_allSupplierPaymentsProvider(
                  DateRangeFilter(start: startBoundary, end: endBoundary)));
              ref.invalidate(bank_provider.bankPaymentsByDateRangeProvider(
                  (start: startBoundary, end: endBoundary)));
            },
            child: salesAsync.when(
              data: (sales) {
                final startBoundary =
                    DateTime(_startDate.year, _startDate.month, _startDate.day);
                final endBoundary = DateTime(_endDate.year, _endDate.month,
                    _endDate.day, 23, 59, 59, 999);
                final filteredSales = sales.where((sale) {
                  final saleDate = sale.date;
                  return !saleDate.isBefore(startBoundary) &&
                      !saleDate.isAfter(endBoundary);
                }).toList();

                return productsAsync.when(
                  data: (products) {
                    return expenseSummary.when(
                      data: (expenseData) {
                        return paymentsAsync.when(
                          data: (payments) {
                            final supplierPaymentsAsync = ref.watch(
                                _allSupplierPaymentsProvider(DateRangeFilter(
                              start: startBoundary,
                              end: endBoundary,
                            )));
                            final bankPaymentsAsync = ref.watch(
                                bank_provider.bankPaymentsByDateRangeProvider((
                              start: startBoundary,
                              end: endBoundary,
                            )));

                            return FutureBuilder<List<EmployeeModel>>(
                              future: databaseService.getAllEmployees(),
                              builder: (context, employeesSnapshot) {
                                return FutureBuilder<List<CustomerModel>>(
                                  future: databaseService.getAllCustomers(),
                                  builder: (context, customersSnapshot) {
                                    return supplierPaymentsAsync.when(
                                      data: (supplierPayments) {
                                        return bankPaymentsAsync.when(
                                          data: (bankPayments) {
                                            if (!employeesSnapshot.hasData ||
                                                !customersSnapshot.hasData) {
                                              return const Center(
                                                  child:
                                                      CircularProgressIndicator());
                                            }

                                            final employees =
                                                employeesSnapshot.data ?? [];
                                            final customers =
                                                customersSnapshot.data ?? [];

                                            // Calculate sales data by employee and type
                                            final salesData =
                                                _calculateSalesData(
                                                    filteredSales, employees);

                                            // Calculate payment data by employee (including supplier and bank payments)
                                            final paymentData =
                                                _calculatePaymentData(
                                              payments,
                                              supplierPayments,
                                              bankPayments,
                                              employees,
                                            );

                                            // Calculate stock value
                                            final stockValue =
                                                products.fold<double>(
                                                    0.0,
                                                    (sum, p) =>
                                                        sum +
                                                        (p.stock * p.cost));

                                            // Calculate receivable credit
                                            final receivableCredit =
                                                _calculateReceivableCredit(
                                                    customers);

                                            // Calculate daily summary
                                            final dailySummary =
                                                _calculateDailySummary(
                                              filteredSales,
                                              payments,
                                              supplierPayments,
                                              bankPayments,
                                              expenseData.totalExpense,
                                            );

                                            return SingleChildScrollView(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Top Section - Sales Table
                                                  _buildSalesTable(
                                                      salesData, currency),
                                                  const SizedBox(height: 24),

                                                  // Cash Sale Cards
                                                  _buildCashSaleCards(
                                                      salesData, currency),
                                                  const SizedBox(height: 24),

                                                  // Payment Table
                                                  _buildPaymentTable(
                                                      paymentData, currency),
                                                  const SizedBox(height: 24),

                                                  // Bottom Section - Three Panels
                                                  _buildBottomPanels(
                                                    stockValue,
                                                    receivableCredit,
                                                    dailySummary,
                                                    currency,
                                                  ),
                                                  const SizedBox(height: 24),

                                                  // Export Buttons
                                                  _buildExportButtons(
                                                    () =>
                                                        _exportOverviewToExcel(
                                                      filteredSales,
                                                      products,
                                                      salesData.totalSales,
                                                      salesData.totalProfit,
                                                      salesData.totalSales -
                                                          salesData.totalCost,
                                                      expenseData.totalExpense,
                                                      currency,
                                                    ),
                                                    () => _exportOverviewToPDF(
                                                      filteredSales,
                                                      products,
                                                      salesData.totalSales,
                                                      salesData.totalProfit,
                                                      salesData.totalSales -
                                                          salesData.totalCost,
                                                      expenseData.totalExpense,
                                                      currency,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          loading: () => const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                          error: (error, stack) => Center(
                                              child: Text(
                                                  'Error loading bank payments: $error')),
                                        );
                                      },
                                      loading: () => const Center(
                                          child: CircularProgressIndicator()),
                                      error: (error, stack) => Center(
                                          child: Text(
                                              'Error loading supplier payments: $error')),
                                    );
                                  },
                                );
                              },
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stack) => Center(
                              child: Text('Error loading payments: $error')),
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) =>
                          Center(child: Text('Error loading expenses: $error')),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      Center(child: Text('Error loading products: $error')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== CALCULATION METHODS ====================

  SalesDataSummary _calculateSalesData(
      List<SaleModel> sales, List<EmployeeModel> employees) {
    final Map<int, SalesDataByEmployee> employeeData = {};

    // Initialize all employees
    for (final employee in employees) {
      if (employee.id != null) {
        employeeData[employee.id!] =
            SalesDataByEmployee(employeeName: employee.name);
      }
    }

    // Add "Unknown" for sales without employee
    employeeData[-1] = SalesDataByEmployee(employeeName: 'Unknown');

    double totalSales = 0;
    double totalCost = 0;
    double cashSaleTotal = 0;
    double cashSaleProfit = 0;

    for (final sale in sales) {
      final employeeId = sale.cashierId ?? -1;
      if (!employeeData.containsKey(employeeId)) {
        employeeData[employeeId] = SalesDataByEmployee(employeeName: 'Unknown');
      }
      final employee = employeeData[employeeId]!;

      // Calculate cost and profit
      final saleCost = sale.items.fold<double>(0.0, (sum, item) {
        return sum + ((item.product?.cost ?? 0) * item.qty);
      });
      final saleProfit = sale.total - saleCost;

      totalSales += sale.total;
      totalCost += saleCost;

      // Determine sale type
      final isRetail = !sale.isWholesale;
      final isCash = sale.paymentType == PaymentType.cash;
      final isCredit = sale.paymentType == PaymentType.credit;

      // Check if it's stock movement (you may need to adjust this logic)
      final isStockMovement = false; // Adjust based on your business logic

      SalesDataByEmployee updated;
      if (isStockMovement) {
        updated = SalesDataByEmployee(
          employeeName: employee.employeeName,
          retailCashSale: employee.retailCashSale,
          retailCashProfit: employee.retailCashProfit,
          retailCreditSale: employee.retailCreditSale,
          retailCreditProfit: employee.retailCreditProfit,
          wholesaleCashSale: employee.wholesaleCashSale,
          wholesaleCashProfit: employee.wholesaleCashProfit,
          wholesaleCreditSale: employee.wholesaleCreditSale,
          wholesaleCreditProfit: employee.wholesaleCreditProfit,
          stockMovementSale: employee.stockMovementSale + sale.total,
          stockMovementProfit: employee.stockMovementProfit + saleProfit,
          totalSale: employee.totalSale + sale.total,
          totalProfit: employee.totalProfit + saleProfit,
        );
      } else if (isRetail && isCash) {
        updated = SalesDataByEmployee(
          employeeName: employee.employeeName,
          retailCashSale: employee.retailCashSale + sale.total,
          retailCashProfit: employee.retailCashProfit + saleProfit,
          retailCreditSale: employee.retailCreditSale,
          retailCreditProfit: employee.retailCreditProfit,
          wholesaleCashSale: employee.wholesaleCashSale,
          wholesaleCashProfit: employee.wholesaleCashProfit,
          wholesaleCreditSale: employee.wholesaleCreditSale,
          wholesaleCreditProfit: employee.wholesaleCreditProfit,
          stockMovementSale: employee.stockMovementSale,
          stockMovementProfit: employee.stockMovementProfit,
          totalSale: employee.totalSale + sale.total,
          totalProfit: employee.totalProfit + saleProfit,
        );
        cashSaleTotal += sale.total;
        cashSaleProfit += saleProfit;
      } else if (isRetail && isCredit) {
        updated = SalesDataByEmployee(
          employeeName: employee.employeeName,
          retailCashSale: employee.retailCashSale,
          retailCashProfit: employee.retailCashProfit,
          retailCreditSale: employee.retailCreditSale + sale.total,
          retailCreditProfit: employee.retailCreditProfit + saleProfit,
          wholesaleCashSale: employee.wholesaleCashSale,
          wholesaleCashProfit: employee.wholesaleCashProfit,
          wholesaleCreditSale: employee.wholesaleCreditSale,
          wholesaleCreditProfit: employee.wholesaleCreditProfit,
          stockMovementSale: employee.stockMovementSale,
          stockMovementProfit: employee.stockMovementProfit,
          totalSale: employee.totalSale + sale.total,
          totalProfit: employee.totalProfit + saleProfit,
        );
      } else if (!isRetail && isCash) {
        updated = SalesDataByEmployee(
          employeeName: employee.employeeName,
          retailCashSale: employee.retailCashSale,
          retailCashProfit: employee.retailCashProfit,
          retailCreditSale: employee.retailCreditSale,
          retailCreditProfit: employee.retailCreditProfit,
          wholesaleCashSale: employee.wholesaleCashSale + sale.total,
          wholesaleCashProfit: employee.wholesaleCashProfit + saleProfit,
          wholesaleCreditSale: employee.wholesaleCreditSale,
          wholesaleCreditProfit: employee.wholesaleCreditProfit,
          stockMovementSale: employee.stockMovementSale,
          stockMovementProfit: employee.stockMovementProfit,
          totalSale: employee.totalSale + sale.total,
          totalProfit: employee.totalProfit + saleProfit,
        );
        cashSaleTotal += sale.total;
        cashSaleProfit += saleProfit;
      } else {
        // !isRetail && isCredit
        updated = SalesDataByEmployee(
          employeeName: employee.employeeName,
          retailCashSale: employee.retailCashSale,
          retailCashProfit: employee.retailCashProfit,
          retailCreditSale: employee.retailCreditSale,
          retailCreditProfit: employee.retailCreditProfit,
          wholesaleCashSale: employee.wholesaleCashSale,
          wholesaleCashProfit: employee.wholesaleCashProfit,
          wholesaleCreditSale: employee.wholesaleCreditSale + sale.total,
          wholesaleCreditProfit: employee.wholesaleCreditProfit + saleProfit,
          stockMovementSale: employee.stockMovementSale,
          stockMovementProfit: employee.stockMovementProfit,
          totalSale: employee.totalSale + sale.total,
          totalProfit: employee.totalProfit + saleProfit,
        );
      }

      employeeData[employeeId] = updated;
    }

    return SalesDataSummary(
      byEmployee: employeeData.values.toList(),
      totalSales: totalSales,
      totalCost: totalCost,
      totalProfit: totalSales - totalCost,
      cashSaleTotal: cashSaleTotal,
      cashSaleProfit: cashSaleProfit,
    );
  }

  Future<List<SupplierPaymentModel>> _getAllSupplierPayments(
      DatabaseService databaseService) async {
    // Get all suppliers first
    final suppliers = await databaseService.getAllSuppliers();
    final allPayments = <SupplierPaymentModel>[];

    // Get payments for each supplier within date range
    for (final supplier in suppliers) {
      if (supplier.id != null) {
        final payments = await databaseService.getSupplierPaymentsByDateRange(
          supplier.id!,
          _startDate,
          _endDate,
        );
        allPayments.addAll(payments);
      }
    }

    return allPayments;
  }

  PaymentDataSummary _calculatePaymentData(
    List<PaymentModel> customerPayments,
    List<SupplierPaymentModel> supplierPayments,
    List<BankPaymentModel> bankPayments,
    List<EmployeeModel> employees,
  ) {
    final Map<int, PaymentDataByEmployee> employeeData = {};

    // Initialize all employees
    for (final employee in employees) {
      if (employee.id != null) {
        employeeData[employee.id!] =
            PaymentDataByEmployee(employeeName: employee.name);
      }
    }

    // Add "admin" entry for admin payments
    employeeData[-999] = PaymentDataByEmployee(employeeName: 'admin');

    // Add "Unknown" for payments without employee
    employeeData[-1] = PaymentDataByEmployee(employeeName: 'Unknown');

    double totalCreditCashReceived = 0;
    double totalCreditChequeReceived = 0;
    double totalPartyBankPayment = 0;
    double totalPartyCashPayment = 0;
    double totalPartyChequePayment = 0;

    // Process customer payments (credit cash received)
    // CRITICAL: Filter out cancelled cheques
    for (final payment in customerPayments) {
      // Skip cancelled cheques
      if (payment.paymentMethod == PaymentMethod.cheque) {
        final note = payment.note?.toLowerCase() ?? '';
        if (note.contains('cancelled') || note.contains('cancel')) {
          continue; // Skip cancelled cheques
        }
      }
      // Determine employee name: "admin" if processed by admin, otherwise employee name
      String employeeName = 'Unknown';
      int employeeId = -1;

      if (payment.processedBy != null) {
        if (payment.processedBy!.isAdmin) {
          employeeName = 'admin';
          employeeId = -999; // Special ID for admin
        } else {
          employeeName = payment.processedBy!.name;
          employeeId = payment.processedByEmployeeId ?? -1;
        }
      } else if (payment.processedByEmployeeId != null) {
        // Fallback: find employee by ID if processedBy is null
        final emp = employees.firstWhere(
          (e) => e.id == payment.processedByEmployeeId,
          orElse: () => EmployeeModel(
            id: payment.processedByEmployeeId,
            name: 'Unknown',
            username: '',
            phone: '',
            role: EmployeeRole.staff,
            employeeId: '',
            hireDate: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        if (emp.isAdmin) {
          employeeName = 'admin';
          employeeId = -999;
        } else {
          employeeName = emp.name;
          employeeId = payment.processedByEmployeeId!;
        }
      }

      // Initialize employee data if not exists
      if (!employeeData.containsKey(employeeId)) {
        employeeData[employeeId] =
            PaymentDataByEmployee(employeeName: employeeName);
      }

      final employee = employeeData[employeeId]!;
      final isChequePayment = payment.paymentMethod == PaymentMethod.cheque;

      final updated = PaymentDataByEmployee(
        employeeName: employeeName,
        creditCashReceived: employee.creditCashReceived +
            (isChequePayment ? 0 : payment.amount),
        creditChequeReceived: employee.creditChequeReceived +
            (isChequePayment ? payment.amount : 0),
        partyBankPayment: employee.partyBankPayment,
        partyCashPayment: employee.partyCashPayment,
        partyChequePayment: employee.partyChequePayment,
        total: employee.total + payment.amount,
      );

      employeeData[employeeId] = updated;
      if (isChequePayment) {
        totalCreditChequeReceived += payment.amount;
      } else {
        totalCreditCashReceived += payment.amount;
      }
    }

    // Process supplier payments (party payments)
    for (final payment in supplierPayments) {
      // Determine employee name from createdBy field
      String employeeName = 'Unknown';
      int employeeId = -1;

      if (payment.createdBy != null && payment.createdBy!.isNotEmpty) {
        // Find employee by name
        final emp = employees.firstWhere(
          (e) => e.name.toLowerCase() == payment.createdBy!.toLowerCase(),
          orElse: () => EmployeeModel(
            id: null,
            name: payment.createdBy!,
            username: '',
            phone: '',
            role: EmployeeRole.staff,
            employeeId: '',
            hireDate: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (emp.id != null) {
          if (emp.isAdmin) {
            employeeName = 'admin';
            employeeId = -999; // Special ID for admin
          } else {
            employeeName = emp.name;
            employeeId = emp.id!;
          }
        } else {
          // Employee not found, use createdBy name as-is
          employeeName = payment.createdBy!;
          employeeId = -1;
        }
      }

      // Initialize employee data if not exists
      if (!employeeData.containsKey(employeeId)) {
        employeeData[employeeId] =
            PaymentDataByEmployee(employeeName: employeeName);
      }

      final employee = employeeData[employeeId]!;
      PaymentDataByEmployee updated = employee;

      final method = payment.paymentMethod.toLowerCase();
      final status = payment.status.toLowerCase();

      if (method == 'bank_transfer') {
        updated = PaymentDataByEmployee(
          employeeName: employeeName,
          creditCashReceived: employee.creditCashReceived,
          creditChequeReceived: employee.creditChequeReceived,
          partyBankPayment: employee.partyBankPayment + payment.amount,
          partyCashPayment: employee.partyCashPayment,
          partyChequePayment: employee.partyChequePayment,
          total: employee.total + payment.amount,
        );
        totalPartyBankPayment += payment.amount;
      } else if (method == 'cash') {
        updated = PaymentDataByEmployee(
          employeeName: employeeName,
          creditCashReceived: employee.creditCashReceived,
          creditChequeReceived: employee.creditChequeReceived,
          partyBankPayment: employee.partyBankPayment,
          partyCashPayment: employee.partyCashPayment + payment.amount,
          partyChequePayment: employee.partyChequePayment,
          total: employee.total + payment.amount,
        );
        totalPartyCashPayment += payment.amount;
      } else if (method == 'cheque' && status != 'cancelled') {
        updated = PaymentDataByEmployee(
          employeeName: employeeName,
          creditCashReceived: employee.creditCashReceived,
          creditChequeReceived: employee.creditChequeReceived,
          partyBankPayment: employee.partyBankPayment,
          partyCashPayment: employee.partyCashPayment,
          partyChequePayment: employee.partyChequePayment + payment.amount,
          total: employee.total + payment.amount,
        );
        totalPartyChequePayment += payment.amount;
      }

      employeeData[employeeId] = updated;
    }

    // Process bank payments (party payments via bank)
    // CRITICAL: Try to match bank payments with supplier/customer payments to get employee
    for (final payment in bankPayments) {
      // Skip cancelled payments
      final status = payment.status.toLowerCase();
      if (status == 'cancelled') {
        continue;
      }

      // Try to find matching supplier payment first
      String employeeName = 'Unknown';
      int employeeId = -1;

      // Match by amount, date, and cheque number (if available)
      SupplierPaymentModel? matchingSupplierPayment;
      try {
        if (payment.chequeNumber != null && payment.chequeNumber!.isNotEmpty) {
          // Match by cheque number, amount, and date
          matchingSupplierPayment = supplierPayments.firstWhere(
            (sp) =>
                sp.paymentMethod == 'cheque' &&
                sp.status != 'cancelled' &&
                sp.reference == payment.chequeNumber &&
                sp.amount == payment.amount &&
                sp.date.difference(payment.issueDate).inDays.abs() <= 1,
          );
        } else {
          // Match by amount and date only
          matchingSupplierPayment = supplierPayments.firstWhere(
            (sp) =>
                (sp.paymentMethod == 'cheque' ||
                    sp.paymentMethod == 'bank_transfer') &&
                sp.status != 'cancelled' &&
                sp.amount == payment.amount &&
                sp.date.difference(payment.issueDate).inDays.abs() <= 1,
          );
        }
      } catch (e) {
        // No matching supplier payment found
      }

      // If found supplier payment, use its createdBy
      if (matchingSupplierPayment != null &&
          matchingSupplierPayment.createdBy != null &&
          matchingSupplierPayment.createdBy!.isNotEmpty) {
        final emp = employees.firstWhere(
          (e) =>
              e.name.toLowerCase() ==
              matchingSupplierPayment!.createdBy!.toLowerCase(),
          orElse: () => EmployeeModel(
            id: null,
            name: matchingSupplierPayment!.createdBy!,
            username: '',
            phone: '',
            role: EmployeeRole.staff,
            employeeId: '',
            hireDate: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (emp.id != null) {
          if (emp.isAdmin) {
            employeeName = 'admin';
            employeeId = -999;
          } else {
            employeeName = emp.name;
            employeeId = emp.id!;
          }
        } else {
          employeeName = matchingSupplierPayment.createdBy!;
          employeeId = -1;
        }
      } else {
        // Try to match with customer payment by cheque number
        if (payment.chequeNumber != null && payment.chequeNumber!.isNotEmpty) {
          try {
            final matchingCustomerPayment = customerPayments.firstWhere(
              (cp) =>
                  cp.paymentMethod == PaymentMethod.cheque &&
                  cp.note?.contains(payment.chequeNumber!) == true &&
                  cp.amount == payment.amount &&
                  cp.date.difference(payment.issueDate).inDays.abs() <= 1,
            );

            // Use customer payment's processedBy
            if (matchingCustomerPayment.processedBy != null) {
              if (matchingCustomerPayment.processedBy!.isAdmin) {
                employeeName = 'admin';
                employeeId = -999;
              } else {
                employeeName = matchingCustomerPayment.processedBy!.name;
                employeeId =
                    matchingCustomerPayment.processedByEmployeeId ?? -1;
              }
            } else if (matchingCustomerPayment.processedByEmployeeId != null) {
              final emp = employees.firstWhere(
                (e) => e.id == matchingCustomerPayment.processedByEmployeeId,
                orElse: () => EmployeeModel(
                  id: matchingCustomerPayment.processedByEmployeeId,
                  name: 'Unknown',
                  username: '',
                  phone: '',
                  role: EmployeeRole.staff,
                  employeeId: '',
                  hireDate: DateTime.now(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
              if (emp.isAdmin) {
                employeeName = 'admin';
                employeeId = -999;
              } else {
                employeeName = emp.name;
                employeeId = matchingCustomerPayment.processedByEmployeeId!;
              }
            }
          } catch (e) {
            // No matching customer payment found, use Unknown
          }
        }
      }

      // Initialize employee data if not exists
      if (!employeeData.containsKey(employeeId)) {
        employeeData[employeeId] =
            PaymentDataByEmployee(employeeName: employeeName);
      }

      final employee = employeeData[employeeId]!;
      PaymentDataByEmployee updated = employee;

      final paymentType = payment.paymentType.toLowerCase();

      if (paymentType == 'transfer' || paymentType == 'withdrawal') {
        updated = PaymentDataByEmployee(
          employeeName: employeeName,
          creditCashReceived: employee.creditCashReceived,
          creditChequeReceived: employee.creditChequeReceived,
          partyBankPayment: employee.partyBankPayment + payment.amount,
          partyCashPayment: employee.partyCashPayment,
          partyChequePayment: employee.partyChequePayment,
          total: employee.total + payment.amount,
        );
        totalPartyBankPayment += payment.amount;
      } else if (paymentType == 'cheque') {
        updated = PaymentDataByEmployee(
          employeeName: employeeName,
          creditCashReceived: employee.creditCashReceived,
          creditChequeReceived: employee.creditChequeReceived,
          partyBankPayment: employee.partyBankPayment,
          partyCashPayment: employee.partyCashPayment,
          partyChequePayment: employee.partyChequePayment + payment.amount,
          total: employee.total + payment.amount,
        );
        totalPartyChequePayment += payment.amount;
      }

      employeeData[employeeId] = updated;
    }

    return PaymentDataSummary(
      byEmployee: employeeData.values.toList(),
      totalCreditCashReceived: totalCreditCashReceived,
      totalCreditChequeReceived: totalCreditChequeReceived,
      totalPartyBankPayment: totalPartyBankPayment,
      totalPartyCashPayment: totalPartyCashPayment,
      totalPartyChequePayment: totalPartyChequePayment,
      grandTotal: totalCreditCashReceived +
          totalCreditChequeReceived +
          totalPartyBankPayment +
          totalPartyCashPayment +
          totalPartyChequePayment,
    );
  }

  ReceivableCredit _calculateReceivableCredit(List<CustomerModel> customers) {
    double retailCredit = 0;
    double wholesaleCredit = 0;
    double unclearCheque = 0;

    for (final customer in customers) {
      if (customer.isRetailCustomer) {
        retailCredit += customer.totalDue;
      }
      if (customer.isWholesaleCustomer) {
        wholesaleCredit += customer.totalDue;
      }
      unclearCheque += customer.unclearCheque;
    }

    return ReceivableCredit(
      retailCredit: retailCredit,
      wholesaleCredit: wholesaleCredit,
      unclearCheque: unclearCheque,
      total: retailCredit + wholesaleCredit + unclearCheque,
    );
  }

  DailySummary _calculateDailySummary(
    List<SaleModel> sales,
    List<PaymentModel> customerPayments,
    List<SupplierPaymentModel> supplierPayments,
    List<BankPaymentModel> bankPayments,
    double expenses,
  ) {
    // Cash sales (retail + wholesale cash)
    final cashSales = sales
        .where((s) => s.paymentType == PaymentType.cash)
        .fold<double>(0.0, (sum, s) => sum + s.total);

    // Recovery (credit cash received from customer payments)
    // Only include cash payments, exclude cheque and bank transfer
    final recovery = customerPayments
        .where((p) => p.paymentMethod == PaymentMethod.cash)
        .fold<double>(
            0.0,
            (sum, p) =>
                sum + (p.amount.isNaN || p.amount.isInfinite ? 0.0 : p.amount));

    // Payment to party (amounts going out to suppliers/parties)
    // 1) Cash supplier payments (existing behavior)
    final supplierPaymentsTotal = supplierPayments
        .where((p) => p.paymentMethod == 'cash')
        .fold<double>(
            0.0,
            (sum, p) =>
                sum + (p.amount.isNaN || p.amount.isInfinite ? 0.0 : p.amount));

    // 2) Bank cheque payments given to parties (e.g. cheques issued to suppliers)
    // Include only non-cancelled cheque bank payments.
    final bankChequePaymentsTotal = bankPayments
        .where((bp) =>
            bp.paymentType == 'cheque' &&
            bp.status.toLowerCase() != 'cancelled')
        .fold<double>(
            0.0,
            (sum, bp) =>
                sum +
                (bp.amount.isNaN || bp.amount.isInfinite ? 0.0 : bp.amount));

    final paymentToParty = supplierPaymentsTotal + bankChequePaymentsTotal;

    final total = cashSales + recovery;
    final netBalance = total - expenses - paymentToParty;

    return DailySummary(
      cashSale: cashSales,
      recovery: recovery,
      total: total,
      expense: expenses,
      paymentToParty: paymentToParty,
      netBalance: netBalance,
    );
  }

  // ==================== UI BUILDING METHODS ====================

  Widget _buildSalesTable(SalesDataSummary salesData, Currency currency) {
    return Card(
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Table',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Zoom ${(_overviewSalesTableScale * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                _buildZoomIconButton(
                  icon: Icons.zoom_out,
                  tooltip: 'Zoom Out',
                  onPressed: _overviewSalesTableScale > _overviewSalesMinScale
                      ? () => _adjustOverviewSalesScale(-0.1)
                      : null,
                ),
                const SizedBox(width: 8),
                _buildZoomIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Reset Zoom',
                  onPressed: _overviewSalesTableScale == 1.0
                      ? null
                      : () => _setOverviewSalesScale(1.0),
                ),
                const SizedBox(width: 8),
                _buildZoomIconButton(
                  icon: Icons.zoom_in,
                  tooltip: 'Zoom In',
                  onPressed: _overviewSalesTableScale < _overviewSalesMaxScale
                      ? () => _adjustOverviewSalesScale(0.1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Scrollbar(
                controller: _overviewSalesHorizontalController,
                thumbVisibility: true,
                trackVisibility: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _overviewSalesHorizontalController,
                  scrollDirection: Axis.horizontal,
                  child: Transform.scale(
                    scale: _overviewSalesTableScale,
                    alignment: Alignment.topLeft,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                          const Color(0xFFADD8E6)), // Light blue
                      columns: [
                        const DataColumn(
                            label: Text('User',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        // Retail Cash
                        DataColumn(
                            label:
                                _buildSubColumnHeader('RETAIL CASH', 'Sale')),
                        DataColumn(
                            label:
                                _buildSubColumnHeader('RETAIL CASH', 'Profit')),
                        // Retail Credit
                        DataColumn(
                            label:
                                _buildSubColumnHeader('RETAIL CREDIT', 'Sale')),
                        DataColumn(
                            label: _buildSubColumnHeader(
                                'RETAIL CREDIT', 'Profit')),
                        // Stock Movement
                        DataColumn(
                            label: _buildSubColumnHeader(
                                'STOCK MOVEMENT', 'Sale')),
                        DataColumn(
                            label: _buildSubColumnHeader(
                                'STOCK MOVEMENT', 'Profit')),
                        // Wholesale Cash
                        DataColumn(
                            label: _buildSubColumnHeader(
                                'WHOLESALE CASH', 'Sale')),
                        DataColumn(
                            label: _buildSubColumnHeader(
                                'WHOLESALE CASH', 'Profit')),
                        // Wholesale Credit
                        DataColumn(
                            label: _buildSubColumnHeader(
                                'WHOLESALE CREDIT', 'Sale')),
                        DataColumn(
                            label: _buildSubColumnHeader(
                                'WHOLESALE CREDIT', 'Profit')),
                        // Total
                        DataColumn(
                            label: _buildSubColumnHeader('TOTAL', 'Sale')),
                        DataColumn(
                            label: _buildSubColumnHeader('TOTAL', 'Profit')),
                      ],
                      rows: [
                        ...salesData.byEmployee.map((data) => DataRow(
                              cells: [
                                DataCell(Text(data.employeeName)),
                                DataCell(_buildSaleCell(
                                    data.retailCashSale, currency)),
                                DataCell(_buildProfitCell(
                                    data.retailCashProfit, currency)),
                                DataCell(_buildSaleCell(
                                    data.retailCreditSale, currency)),
                                DataCell(_buildProfitCell(
                                    data.retailCreditProfit, currency)),
                                DataCell(_buildSaleCell(
                                    data.stockMovementSale, currency)),
                                DataCell(_buildProfitCell(
                                    data.stockMovementProfit, currency)),
                                DataCell(_buildSaleCell(
                                    data.wholesaleCashSale, currency)),
                                DataCell(_buildProfitCell(
                                    data.wholesaleCashProfit, currency)),
                                DataCell(_buildSaleCell(
                                    data.wholesaleCreditSale, currency)),
                                DataCell(_buildProfitCell(
                                    data.wholesaleCreditProfit, currency)),
                                DataCell(
                                    _buildSaleCell(data.totalSale, currency)),
                                DataCell(_buildProfitCell(
                                    data.totalProfit, currency)),
                              ],
                            )),
                        // TOTAL row
                        DataRow(
                          color: MaterialStateProperty.all(Colors.grey[100]),
                          cells: [
                            DataCell(Text('TOTAL',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(_buildSaleCell(
                              salesData.byEmployee.fold(
                                  0.0, (sum, e) => sum + e.retailCashSale),
                              currency,
                              isBold: true,
                            )),
                            DataCell(_buildProfitCell(
                              salesData.byEmployee.fold(
                                  0.0, (sum, e) => sum + e.retailCashProfit),
                              currency,
                              isBold: true,
                            )),
                            DataCell(_buildSaleCell(
                              salesData.byEmployee.fold(
                                  0.0, (sum, e) => sum + e.retailCreditSale),
                              currency,
                              isBold: true,
                            )),
                            DataCell(_buildProfitCell(
                              salesData.byEmployee.fold(
                                  0.0, (sum, e) => sum + e.retailCreditProfit),
                              currency,
                              isBold: true,
                            )),
                            DataCell(_buildSaleCell(
                              salesData.byEmployee.fold(
                                  0.0, (sum, e) => sum + e.stockMovementSale),
                              currency,
                              isBold: true,
                            )),
                            DataCell(_buildProfitCell(
                              salesData.byEmployee.fold(
                                  0.0, (sum, e) => sum + e.stockMovementProfit),
                              currency,
                              isBold: true,
                            )),
                            DataCell(_buildSaleCell(
                              salesData.byEmployee.fold(
                                  0.0, (sum, e) => sum + e.wholesaleCashSale),
                              currency,
                              isBold: true,
                            )),
                            DataCell(_buildProfitCell(
                              salesData.byEmployee.fold(
                                  0.0, (sum, e) => sum + e.wholesaleCashProfit),
                              currency,
                              isBold: true,
                            )),
                            DataCell(_buildSaleCell(
                              salesData.byEmployee.fold(
                                  0.0, (sum, e) => sum + e.wholesaleCreditSale),
                              currency,
                              isBold: true,
                            )),
                            DataCell(_buildProfitCell(
                              salesData.byEmployee.fold(0.0,
                                  (sum, e) => sum + e.wholesaleCreditProfit),
                              currency,
                              isBold: true,
                            )),
                            DataCell(_buildSaleCell(
                                salesData.totalSales, currency,
                                isBold: true)),
                            DataCell(_buildProfitCell(
                                salesData.totalProfit, currency,
                                isBold: true)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ))
          ],
        ),
      ),
    );
  }

  Widget _buildZoomIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(36, 36),
          side: BorderSide(
            color: onPressed == null
                ? Colors.grey.shade300
                : const Color(0xFF3B82F6),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onPressed == null ? Colors.grey : const Color(0xFF1E3A8A),
        ),
      ),
    );
  }

  void _adjustOverviewSalesScale(double delta) {
    setState(() {
      _overviewSalesTableScale = (_overviewSalesTableScale + delta)
          .clamp(_overviewSalesMinScale, _overviewSalesMaxScale);
    });
  }

  void _setOverviewSalesScale(double value) {
    setState(() {
      _overviewSalesTableScale =
          value.clamp(_overviewSalesMinScale, _overviewSalesMaxScale);
    });
  }

  Widget _buildSubColumnHeader(String main, String sub) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(main,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        Text(sub, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildSaleCell(double value, Currency currency,
      {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5DC), // Beige
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${currency.symbol}${_formatNumber(value)}',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildProfitCell(double value, Currency currency,
      {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF90EE90).withValues(alpha: 0.3), // Light green
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${currency.symbol}${_formatNumber(value)}',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: Colors.green[700],
        ),
      ),
    );
  }

  Widget _buildCashSaleCards(SalesDataSummary salesData, Currency currency) {
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Cash Sale Total Amount',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${currency.symbol}${_formatNumber(salesData.cashSaleTotal)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Cash Sale Total Profit',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${currency.symbol}${_formatNumber(salesData.cashSaleProfit)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTable(PaymentDataSummary paymentData, Currency currency) {
    return Card(
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Table',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                    const Color(0xFFE0F7FA)), // Light cyan
                columns: const [
                  DataColumn(
                      label: Text('User',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('CREDIT CASH RECEIVED',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('CREDIT CHEQUE RECEIVED',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('PARTY BANK PAYMENT',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('PARTY CASH PAYMENT',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('PARTY CHEQUE PAYMENT',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('TOTAL',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: [
                  ...paymentData.byEmployee
                      .where((data) =>
                          data.total > 0) // Only show employees with payments
                      .map((data) => DataRow(
                            cells: [
                              DataCell(Text(data.employeeName)),
                              DataCell(Text(
                                '${currency.symbol}${_formatNumber(data.creditCashReceived)}',
                                textAlign: TextAlign.right,
                              )),
                              DataCell(Text(
                                '${currency.symbol}${_formatNumber(data.creditChequeReceived)}',
                                textAlign: TextAlign.right,
                              )),
                              DataCell(Text(
                                '${currency.symbol}${_formatNumber(data.partyBankPayment)}',
                                textAlign: TextAlign.right,
                              )),
                              DataCell(Text(
                                '${currency.symbol}${_formatNumber(data.partyCashPayment)}',
                                textAlign: TextAlign.right,
                              )),
                              DataCell(Text(
                                '${currency.symbol}${_formatNumber(data.partyChequePayment)}',
                                textAlign: TextAlign.right,
                              )),
                              DataCell(Text(
                                '${currency.symbol}${_formatNumber(data.total)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              )),
                            ],
                          )),
                  // TOTAL row
                  DataRow(
                    color: MaterialStateProperty.all(Colors.grey[100]),
                    cells: [
                      DataCell(Text('TOTAL',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(
                        '${currency.symbol}${_formatNumber(paymentData.totalCreditCashReceived)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )),
                      DataCell(Text(
                        '${currency.symbol}${_formatNumber(paymentData.totalCreditChequeReceived)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )),
                      DataCell(Text(
                        '${currency.symbol}${_formatNumber(paymentData.totalPartyBankPayment)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )),
                      DataCell(Text(
                        '${currency.symbol}${_formatNumber(paymentData.totalPartyCashPayment)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )),
                      DataCell(Text(
                        '${currency.symbol}${_formatNumber(paymentData.totalPartyChequePayment)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )),
                      DataCell(Text(
                        '${currency.symbol}${_formatNumber(paymentData.grandTotal)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanels(
    double stockValue,
    ReceivableCredit receivableCredit,
    DailySummary dailySummary,
    Currency currency,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        if (isMobile) {
          return Column(
            children: [
              _buildCurrentStockPanel(stockValue, currency),
              const SizedBox(height: 16),
              _buildReceivableCreditPanel(receivableCredit, currency),
              const SizedBox(height: 16),
              _buildDailySummaryPanel(dailySummary, currency),
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildCurrentStockPanel(stockValue, currency)),
              const SizedBox(width: 16),
              Expanded(
                  child:
                      _buildReceivableCreditPanel(receivableCredit, currency)),
              const SizedBox(width: 16),
              Expanded(child: _buildDailySummaryPanel(dailySummary, currency)),
            ],
          );
        }
      },
    );
  }

  Widget _buildCurrentStockPanel(double stockValue, Currency currency) {
    return Card(
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Stock',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Stock Value',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${currency.symbol}${_formatNumber(stockValue)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivableCreditPanel(
      ReceivableCredit receivableCredit, Currency currency) {
    return Card(
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receivable Credit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            _buildReceivableRow(
                'Retail Credit', receivableCredit.retailCredit, currency),
            const Divider(),
            _buildReceivableRow(
                'Wholesale Credit', receivableCredit.wholesaleCredit, currency),
            const Divider(),
            _buildReceivableRow(
                'Unclear Cheque', receivableCredit.unclearCheque, currency),
            const Divider(),
            _buildReceivableRow(
              'Total',
              receivableCredit.total,
              currency,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivableRow(String label, double value, Currency currency,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${currency.symbol}${_formatNumber(value)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummaryPanel(DailySummary dailySummary, Currency currency) {
    return Card(
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Cash Sale', dailySummary.cashSale, currency),
            const Divider(),
            _buildSummaryRow('Recovery', dailySummary.recovery, currency,
                isRed: dailySummary.recovery < 0),
            const Divider(),
            _buildSummaryRow('Total', dailySummary.total, currency,
                isBold: true),
            const Divider(),
            _buildSummaryRow('Expense', dailySummary.expense, currency,
                isRed: true),
            const Divider(),
            _buildSummaryRow(
                'Payment to Party', dailySummary.paymentToParty, currency,
                isRed: true),
            const Divider(),
            _buildSummaryRow(
              'Net Balance',
              dailySummary.netBalance,
              currency,
              isBold: true,
              isGreen: dailySummary.netBalance >= 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value,
    Currency currency, {
    bool isBold = false,
    bool isRed = false,
    bool isGreen = false,
  }) {
    final isNegative = value < 0;
    final absValue = value.abs();
    final formattedValue = _formatNumber(absValue);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          isNegative
              ? RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '-',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              isBold ? FontWeight.bold : FontWeight.normal,
                          color: isRed
                              ? Colors.red[700]
                              : isGreen
                                  ? Colors.green[700]
                                  : null,
                        ),
                      ),
                      TextSpan(
                        text: '${currency.symbol}$formattedValue',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isBold ? FontWeight.bold : FontWeight.normal,
                          color: isRed
                              ? Colors.red[700]
                              : isGreen
                                  ? Colors.green[700]
                                  : null,
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  '${currency.symbol}$formattedValue',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: isRed
                        ? Colors.red[700]
                        : isGreen
                            ? Colors.green[700]
                            : null,
                  ),
                ),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    return NumberFormat('#,##0.00').format(number);
  }

  // ==================== SALES ANALYTICS REPORT ====================
  Widget _buildSalesAnalyticsReport() {
    final salesAsync = ref.watch(salesProvider);
    final currency = ref.watch(currentCurrencyProvider);

    return Column(
      children: [
        _buildDatePicker(),
        Expanded(
          child: salesAsync.when(
            data: (sales) {
              final filteredSales = sales.where((sale) {
                return sale.date.isAfter(
                        _startDate.subtract(const Duration(days: 1))) &&
                    sale.date.isBefore(_endDate.add(const Duration(days: 1)));
              }).toList();

              if (filteredSales.isEmpty) {
                return _buildEmptyState('No sales data for selected period');
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Sales Performance Metrics
                    _buildSalesPerformanceSection(filteredSales, currency),
                    const SizedBox(height: 20),

                    // Sales Trends Chart
                    _buildSalesTrendsChart(filteredSales, currency),
                    const SizedBox(height: 20),

                    // Top Products Analysis
                    _buildTopProductsSection(filteredSales, currency),
                    const SizedBox(height: 20),

                    // Customer Analysis
                    _buildCustomerAnalysisSection(filteredSales, currency),
                    const SizedBox(height: 20),

                    // Export Buttons
                    _buildExportButtons(
                        () => _exportSalesAnalyticsToExcel(
                            filteredSales, currency),
                        () => _exportSalesAnalyticsToPDF(
                            filteredSales, currency)),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }

  // ==================== PROFIT ANALYSIS REPORT ====================
  Widget _buildProfitAnalysisReport() {
    final salesAsync = ref.watch(salesProvider);
    final currency = ref.watch(currentCurrencyProvider);
    final expenseSummary = ref.watch(expenseSummaryProvider(DateRangeFilter(
      start: _startDate,
      end: _endDate,
    )));

    return Column(
      children: [
        _buildDatePicker(),
        Expanded(
          child: salesAsync.when(
            data: (sales) {
              final filteredSales = sales.where((sale) {
                return sale.date.isAfter(
                        _startDate.subtract(const Duration(days: 1))) &&
                    sale.date.isBefore(_endDate.add(const Duration(days: 1)));
              }).toList();

              return expenseSummary.when(
                data: (expenseData) {
                  // Calculate profit metrics
                  final totalSales = filteredSales.fold<double>(
                      0.0, (double sum, s) => sum + s.total);
                  final totalCost =
                      filteredSales.fold<double>(0.0, (double sum, s) {
                    return sum +
                        s.items.fold<double>(0.0, (double itemSum, item) {
                          return itemSum +
                              ((item.product?.cost ?? 0) * item.qty);
                        });
                  });
                  final grossProfit = totalSales - totalCost;
                  final totalExpenses = expenseData.totalExpense;
                  final netProfit = grossProfit - totalExpenses;
                  final profitMargin =
                      totalSales > 0 ? (netProfit / totalSales) * 100 : 0.0;
                  final grossMargin =
                      totalSales > 0 ? (grossProfit / totalSales) * 100 : 0.0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Profit Summary Cards
                        _buildProfitSummaryCards(
                          totalSales,
                          totalCost,
                          grossProfit,
                          totalExpenses,
                          netProfit,
                          profitMargin,
                          grossMargin,
                          currency,
                        ),
                        const SizedBox(height: 20),

                        // Profit Trends Chart
                        _buildProfitTrendsChart(filteredSales, currency),
                        const SizedBox(height: 20),

                        // Expense Breakdown
                        _buildExpenseBreakdownSection(expenseData, currency),
                        const SizedBox(height: 20),

                        // Profit by Product Category
                        _buildProfitByCategorySection(filteredSales, currency),
                        const SizedBox(height: 20),

                        // Export Buttons
                        _buildExportButtons(
                            () => _exportProfitAnalysisToExcel(
                                  filteredSales,
                                  totalSales,
                                  totalCost,
                                  grossProfit,
                                  totalExpenses,
                                  netProfit,
                                  currency,
                                ),
                            () => _exportProfitAnalysisToPDF(
                                  filteredSales,
                                  totalSales,
                                  totalCost,
                                  grossProfit,
                                  totalExpenses,
                                  netProfit,
                                  currency,
                                )),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    Center(child: Text('Error loading expenses: $error')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }

  // ==================== ITEM LIST REPORT ====================
  Widget _buildItemListReport() {
    final productsAsync = ref.watch(productNotifierProvider);
    final currency = ref.watch(currentCurrencyProvider);

    return productsAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return _buildEmptyState('No items found');
        }

        // Calculate totals
        final totalItems = products.length;
        final totalStock =
            products.fold<double>(0.0, (double sum, p) => sum + p.stock);
        final totalValue = products.fold<double>(
            0.0, (double sum, p) => sum + (p.stock * p.cost));
        final totalSaleValue = products.fold<double>(
            0.0, (double sum, p) => sum + (p.stock * p.price));

        return Column(
          children: [
            // Summary Cards
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Items',
                          totalItems.toString(),
                          Icons.inventory_2,
                          const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Stock',
                          totalStock.toStringAsFixed(0),
                          Icons.warehouse,
                          const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Cost Value',
                          '${currency.symbol}${totalValue.toStringAsFixed(2)}',
                          Icons.account_balance_wallet,
                          const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Sale Value',
                          '${currency.symbol}${totalSaleValue.toStringAsFixed(2)}',
                          Icons.trending_up,
                          const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Export Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isExporting
                              ? null
                              : () =>
                                  _exportItemListToExcel(products, currency),
                          icon: const Icon(Icons.file_download),
                          label: Text('reports.export_excel'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isExporting
                              ? null
                              : () => _exportItemListToPDF(products, currency),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text('reports.export_pdf'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Items Table
            Expanded(
              child: _buildCustomTable(
                headers: [
                  'Item Name',
                  'Category',
                  'Barcode',
                  'Stock',
                  'Unit',
                  'Cost Price',
                  'Sale Price',
                  'Total Value',
                ],
                rows: products.map((product) {
                  final totalValue = product.stock * product.cost;
                  return [
                    product.name,
                    product.category,
                    product.barcode ?? 'N/A',
                    product.stock.toStringAsFixed(2),
                    product.unit,
                    '${currency.symbol}${product.cost.toStringAsFixed(2)}',
                    '${currency.symbol}${product.price.toStringAsFixed(2)}',
                    '${currency.symbol}${totalValue.toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  // ==================== LOW STOCK REPORT ====================
  Widget _buildLowStockReport() {
    final productsAsync = ref.watch(productNotifierProvider);
    final currency = ref.watch(currentCurrencyProvider);

    return productsAsync.when(
      data: (products) {
        // Filter products with stock below reorder level or negative
        final lowStockItems =
            products.where((p) => p.stock <= p.reorderLevel).toList();
        final negativeItems = products.where((p) => p.stock < 0).toList();

        return Column(
          children: [
            // Summary Cards
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Low Stock Items',
                          lowStockItems.length.toString(),
                          Icons.trending_down,
                          const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Negative Stock',
                          negativeItems.length.toString(),
                          Icons.error_outline,
                          const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Export Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isExporting
                              ? null
                              : () => _exportLowStockToExcel(
                                  lowStockItems, currency),
                          icon: const Icon(Icons.file_download),
                          label: Text('reports.export_excel'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isExporting
                              ? null
                              : () =>
                                  _exportLowStockToPDF(lowStockItems, currency),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text('reports.export_pdf'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Items List
            Expanded(
              child: lowStockItems.isEmpty
                  ? _buildEmptyState('All items are properly stocked')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: lowStockItems.length,
                      itemBuilder: (context, index) {
                        final product = lowStockItems[index];
                        final isNegative = product.stock < 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isNegative ? Colors.red : Colors.orange,
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isNegative
                                            ? Colors.red.withValues(alpha: 0.1)
                                            : Colors.orange
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isNegative ? 'NEGATIVE' : 'LOW STOCK',
                                        style: TextStyle(
                                          color: isNegative
                                              ? Colors.red
                                              : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Current Stock: ${product.stock.toStringAsFixed(2)} ${product.unit}',
                                            style: TextStyle(
                                              color: isNegative
                                                  ? Colors.red
                                                  : Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Reorder Level: ${product.reorderLevel.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          Text(
                                            'Category: ${product.category}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Sale: ${currency.symbol}${product.price.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Cost: ${currency.symbol}${product.cost.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
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
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  // ==================== DAY END REPORT ====================
  Widget _buildDayEndReport() {
    final salesAsync = ref.watch(salesProvider);
    final currency = ref.watch(currentCurrencyProvider);
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;
    final isAdmin = currentUser?.isAdmin == true;
    final isManager = currentUser?.isManager == true;
    // Use selected date range instead of hard-coded "today"
    final DateTime startBoundary =
        DateTime(_startDate.year, _startDate.month, _startDate.day);
    final DateTime endBoundary =
        DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999);

    final paymentsAsync = ref.watch(
      payment_provider.paymentsByDateRangeProvider(
        payment_provider.DateRange(
          start: startBoundary,
          end: endBoundary,
        ),
      ),
    );

    return Column(
      children: [
        // Date Picker for Day End report (uses global _startDate/_endDate)
        _buildDatePicker(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        const Icon(Icons.today, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Day End Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'From ${DateFormat('dd MMM yyyy').format(startBoundary)} to ${DateFormat('dd MMM yyyy').format(endBoundary)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      'Auto-updated hourly',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(salesProvider);
              ref.invalidate(payment_provider.paymentsByDateRangeProvider(
                payment_provider.DateRange(
                    start: startBoundary, end: endBoundary),
              ));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                salesAsync.when(
                  data: (sales) {
                    // Filter by date range (inclusive)
                    var filteredSales = sales.where((sale) {
                      final saleDate = sale.date;
                      return !saleDate.isBefore(startBoundary) &&
                          !saleDate.isAfter(endBoundary);
                    }).toList()
                      ..sort((a, b) => b.date.compareTo(a.date));

                    // Manager/Cashier should only see their own data
                    if (!isAdmin &&
                        (isManager || currentUser?.isCashier == true)) {
                      final uid = currentUser?.id;
                      if (uid != null) {
                        filteredSales = filteredSales
                            .where((s) => (s.cashierId ?? -1) == uid)
                            .toList();
                      }
                    }

                    return paymentsAsync.when(
                      data: (payments) {
                        var filteredPayments = payments.where((payment) {
                          final paymentDate = payment.date;
                          return !paymentDate.isBefore(startBoundary) &&
                              !paymentDate.isAfter(endBoundary);
                        }).toList()
                          ..sort((a, b) => b.date.compareTo(a.date));
                        if (!isAdmin &&
                            (isManager || currentUser?.isCashier == true)) {
                          final uid = currentUser?.id;
                          if (uid != null) {
                            filteredPayments = filteredPayments
                                .where((p) =>
                                    (p.processedByEmployeeId ?? -1) == uid)
                                .toList();
                          }
                        }

                        if (filteredSales.isEmpty && filteredPayments.isEmpty) {
                          return _buildEmptyState(
                              'No sales or payments found for selected date range');
                        }

                        // Calculate metrics
                        final totalSales = filteredSales.fold<double>(
                            0.0, (double sum, s) => sum + s.total);
                        final totalCost =
                            filteredSales.fold<double>(0.0, (double sum, s) {
                          return sum +
                              s.items.fold<double>(0.0, (double itemSum, item) {
                                return itemSum +
                                    ((item.product?.cost ?? 0) * item.qty);
                              });
                        });
                        final totalProfit = totalSales - totalCost;
                        final totalDiscount = filteredSales.fold<double>(
                            0.0, (double sum, s) => sum + s.discount);
                        final totalTransactions = filteredSales.length;
                        double profitMarginPercent = 0.0;
                        if (totalSales > 0) {
                          final margin = (totalProfit / totalSales) * 100;
                          if (margin.isFinite) {
                            profitMarginPercent = margin;
                          }
                        }

                        // Sales counts and amounts
                        final cashSales = filteredSales
                            .where((s) =>
                                s.paymentType.toString().contains('cash'))
                            .toList();
                        final cardSales = filteredSales
                            .where((s) =>
                                s.paymentType.toString().contains('card'))
                            .toList();
                        final creditSales = filteredSales
                            .where((s) =>
                                s.paymentType.toString().contains('credit'))
                            .toList();
                        final cashSalesCount = cashSales.length;
                        final cardSalesCount = cardSales.length;
                        final creditSalesCount = creditSales.length;
                        final cashSalesAmount = cashSales.fold<double>(
                            0.0, (sum, s) => sum + s.total);
                        final cardSalesAmount = cardSales.fold<double>(
                            0.0, (sum, s) => sum + s.total);
                        final creditSalesAmount = creditSales.fold<double>(
                            0.0, (sum, s) => sum + s.total);

                        // Payment metrics
                        final totalPaymentsAmount = filteredPayments
                            .fold<double>(0.0, (sum, p) => sum + p.amount);
                        final cashPayments = filteredPayments
                            .where((p) => p.paymentMethod == PaymentMethod.cash)
                            .toList();
                        final cardPayments = filteredPayments
                            .where((p) => p.paymentMethod == PaymentMethod.card)
                            .toList();
                        final bankPayments = filteredPayments
                            .where((p) =>
                                p.paymentMethod == PaymentMethod.bankTransfer)
                            .toList();
                        final chequePayments = filteredPayments
                            .where(
                                (p) => p.paymentMethod == PaymentMethod.cheque)
                            .toList();

                        final cashPaymentsAmount = cashPayments.fold<double>(
                            0.0, (sum, p) => sum + p.amount);
                        final cardPaymentsAmount = cardPayments.fold<double>(
                            0.0, (sum, p) => sum + p.amount);
                        final bankPaymentsAmount = bankPayments.fold<double>(
                            0.0, (sum, p) => sum + p.amount);
                        final chequePaymentsAmount = chequePayments
                            .fold<double>(0.0, (sum, p) => sum + p.amount);

                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Profit and Sales Boxes
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildColoredMetricCard(
                                      'Total Profit',
                                      '${currency.symbol}${totalProfit.toStringAsFixed(2)}',
                                      Icons.trending_up,
                                      Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildColoredMetricCard(
                                      'Total Sales',
                                      '${currency.symbol}${totalSales.toStringAsFixed(2)}',
                                      Icons.monetization_on,
                                      Colors.yellow.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildColoredMetricCard(
                                      'Total Cost',
                                      '${currency.symbol}${totalCost.toStringAsFixed(2)}',
                                      Icons.money_off,
                                      Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildColoredMetricCard(
                                      'Discount Given',
                                      '${currency.symbol}${totalDiscount.toStringAsFixed(2)}',
                                      Icons.discount,
                                      Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Transaction Summary
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Transaction Summary',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildSummaryRowText('Total Transactions',
                                          totalTransactions.toString()),
                                      const SizedBox(height: 8),
                                      _buildSummaryRowText('Cash Sales (Count)',
                                          '${cashSalesCount} (${currency.symbol}${cashSalesAmount.toStringAsFixed(2)})'),
                                      _buildSummaryRowText('Card Sales (Count)',
                                          '${cardSalesCount} (${currency.symbol}${cardSalesAmount.toStringAsFixed(2)})'),
                                      _buildSummaryRowText(
                                          'Credit Sales (Count)',
                                          '${creditSalesCount} (${currency.symbol}${creditSalesAmount.toStringAsFixed(2)})'),
                                      const SizedBox(height: 8),
                                      _buildSummaryRowText(
                                        'Customer Payments (${isAdmin ? 'All users' : 'You'})',
                                        '${filteredPayments.length} (${currency.symbol}${totalPaymentsAmount.toStringAsFixed(2)})',
                                      ),
                                      const Divider(),
                                      _buildSummaryRowText(
                                        'Profit Margin',
                                        '${profitMarginPercent.toStringAsFixed(2)}%',
                                        isBold: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Sales List
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Sales Details',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      if (filteredSales.isNotEmpty)
                                        _buildCustomTable(
                                          headers: [
                                            'Sale ID',
                                            'Date',
                                            'Amount',
                                            'Discount',
                                            'Payment',
                                            'Status',
                                            'Cashier',
                                          ],
                                          rows: filteredSales
                                              .take(50)
                                              .map((sale) {
                                            return [
                                              'Sale #${sale.id}',
                                              DateFormat('dd/MM/yyyy hh:mm a')
                                                  .format(sale.date),
                                              '${currency.symbol}${sale.total.toStringAsFixed(2)}',
                                              '${currency.symbol}${sale.discount.toStringAsFixed(2)}',
                                              sale.paymentType
                                                  .toString()
                                                  .split('.')
                                                  .last
                                                  .toUpperCase(),
                                              sale.status
                                                  .toString()
                                                  .split('.')
                                                  .last
                                                  .toUpperCase(),
                                              sale.cashier?.name ?? 'Unknown',
                                            ];
                                          }).toList(),
                                          onRowTap: (index) {
                                            final salesList =
                                                filteredSales.take(50).toList();
                                            if (index < salesList.length) {
                                              _showSaleDetails(context,
                                                  salesList[index], currency);
                                            }
                                          },
                                        )
                                      else
                                        const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(32.0),
                                            child: Text('No sales found'),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (filteredPayments.isNotEmpty)
                                Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Payments Recorded',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildCustomTable(
                                          headers: [
                                            'Payment ID',
                                            'Date',
                                            'Customer',
                                            'Amount',
                                            'Method',
                                            'Recorded By',
                                          ],
                                          rows: filteredPayments
                                              .take(50)
                                              .map((payment) {
                                            return [
                                              payment.id != null
                                                  ? 'PAY-${payment.id}'
                                                  : 'N/A',
                                              DateFormat('dd/MM/yyyy hh:mm a')
                                                  .format(payment.date),
                                              payment.customer?.name ??
                                                  'Unknown',
                                              '${currency.symbol}${payment.amount.toStringAsFixed(2)}',
                                              payment.paymentMethod.name
                                                  .toUpperCase(),
                                              payment.processedBy?.name ??
                                                  'Unknown',
                                            ];
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              // Payment Method Summary
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Payment Method Summary',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildCustomTable(
                                        headers: ['Method', 'Count', 'Amount'],
                                        rows: [
                                          [
                                            'CASH',
                                            cashPayments.length.toString(),
                                            '${currency.symbol}${cashPaymentsAmount.toStringAsFixed(2)}'
                                          ],
                                          [
                                            'CARD',
                                            cardPayments.length.toString(),
                                            '${currency.symbol}${cardPaymentsAmount.toStringAsFixed(2)}'
                                          ],
                                          [
                                            'BANK',
                                            bankPayments.length.toString(),
                                            '${currency.symbol}${bankPaymentsAmount.toStringAsFixed(2)}'
                                          ],
                                          [
                                            'CHEQUE',
                                            chequePayments.length.toString(),
                                            '${currency.symbol}${chequePaymentsAmount.toStringAsFixed(2)}'
                                          ],
                                          [
                                            'TOTAL',
                                            filteredPayments.length.toString(),
                                            '${currency.symbol}${totalPaymentsAmount.toStringAsFixed(2)}'
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // KPIs
                              Builder(
                                builder: (_) {
                                  final int billCount = filteredSales.length;
                                  final double avgBill = billCount == 0
                                      ? 0
                                      : (totalSales / billCount);
                                  final double totalItems =
                                      filteredSales.fold<double>(
                                          0,
                                          (s, sale) =>
                                              s +
                                              sale.items.fold<double>(
                                                  0, (ss, it) => ss + it.qty));
                                  final double itemsPerBill = billCount == 0
                                      ? 0
                                      : (totalItems / billCount);
                                  return Row(
                                    children: [
                                      Expanded(
                                          child: _buildMetricBox(
                                              'Average Bill Value',
                                              '${currency.symbol}${avgBill.toStringAsFixed(2)}')),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: _buildMetricBox(
                                              'Items Per Bill',
                                              itemsPerBill.toStringAsFixed(2))),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              // Hourly Sales Breakdown
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Hourly Sales Breakdown',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildCustomTable(
                                        headers: ['Hour', 'Bills', 'Amount'],
                                        rows: () {
                                          final Map<int, List<dynamic>> byHour =
                                              {};
                                          for (final s in filteredSales) {
                                            final h = s.date.hour;
                                            byHour.putIfAbsent(
                                                h, () => [0, 0.0]);
                                            byHour[h]![0] =
                                                (byHour[h]![0] as int) + 1;
                                            byHour[h]![1] =
                                                (byHour[h]![1] as double) +
                                                    s.total;
                                          }
                                          final hours = byHour.keys.toList()
                                            ..sort();
                                          return hours.map((h) {
                                            final bills = byHour[h]![0] as int;
                                            final amt = byHour[h]![1] as double;
                                            return [
                                              '${h.toString().padLeft(2, '0')}:00',
                                              bills.toString(),
                                              '${currency.symbol}${amt.toStringAsFixed(2)}'
                                            ];
                                          }).toList();
                                        }(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Top Items
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Top Selling Items',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildCustomTable(
                                        headers: ['Item', 'Qty', 'Amount'],
                                        rows: () {
                                          final Map<String, List<double>>
                                              byItem = {};
                                          for (final s in filteredSales) {
                                            for (final it in s.items) {
                                              final name =
                                                  it.product?.name ?? 'Unknown';
                                              // Calculate subtotal using current price: (price * qty) - discount
                                              final amt = (it.price * it.qty) -
                                                  (it.discount);
                                              final list = byItem.putIfAbsent(
                                                  name, () => [0.0, 0.0]);
                                              list[0] = list[0] + it.qty;
                                              list[1] = list[1] + amt;
                                            }
                                          }
                                          final entries = byItem.entries
                                              .toList()
                                            ..sort((a, b) => b.value[1]
                                                .compareTo(a.value[1]));
                                          return entries.take(10).map((e) {
                                            return [
                                              e.key,
                                              e.value[0].toStringAsFixed(0),
                                              '${currency.symbol}${e.value[1].toStringAsFixed(2)}'
                                            ];
                                          }).toList();
                                        }(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Category-wise Sales
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Category-wise Sales',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildCustomTable(
                                        headers: ['Category', 'Qty', 'Amount'],
                                        rows: () {
                                          final Map<String, List<double>>
                                              byCat = {};
                                          for (final s in filteredSales) {
                                            for (final it in s.items) {
                                              final cat =
                                                  (it.product?.category ??
                                                          'Uncategorized')
                                                      .toString();
                                              // Calculate subtotal using current price: (price * qty) - discount
                                              final amt = (it.price * it.qty) -
                                                  (it.discount);
                                              final list = byCat.putIfAbsent(
                                                  cat, () => [0.0, 0.0]);
                                              list[0] = list[0] + it.qty;
                                              list[1] = list[1] + amt;
                                            }
                                          }
                                          final entries = byCat.entries.toList()
                                            ..sort((a, b) => b.value[1]
                                                .compareTo(a.value[1]));
                                          return entries.map((e) {
                                            return [
                                              e.key,
                                              e.value[0].toStringAsFixed(0),
                                              '${currency.symbol}${e.value[1].toStringAsFixed(2)}'
                                            ];
                                          }).toList();
                                        }(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Export Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isExporting
                                          ? null
                                          : () => _exportDayEndToExcel(
                                                filteredSales,
                                                filteredPayments,
                                                totalSales,
                                                totalCost,
                                                totalProfit,
                                                totalDiscount,
                                                cashSalesAmount,
                                                cardSalesAmount,
                                                creditSalesAmount,
                                                currency,
                                              ),
                                      icon: const Icon(Icons.file_download),
                                      label: Text('reports.export_excel'.tr()),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isExporting
                                          ? null
                                          : () => _exportDayEndToPDF(
                                                filteredSales,
                                                filteredPayments,
                                                totalSales,
                                                totalCost,
                                                totalProfit,
                                                totalDiscount,
                                                cashSalesAmount,
                                                cardSalesAmount,
                                                creditSalesAmount,
                                                currency,
                                              ),
                                      icon: const Icon(Icons.picture_as_pdf),
                                      label: Text('reports.export_pdf'.tr()),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFEF4444),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () =>
                          _buildEmptyState('Loading daily payments...'),
                      error: (error, stack) =>
                          _buildEmptyState('Error loading payments'),
                    );
                  },
                  loading: () => _buildEmptyState('Loading daily sales...'),
                  error: (error, stack) =>
                      _buildEmptyState('Error loading sales'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== PAYMENT DETAIL REPORT ====================
  Widget _buildPaymentReport() {
    final DateTime startBoundary =
        DateTime(_startDate.year, _startDate.month, _startDate.day);
    final DateTime endBoundary =
        DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999);

    final paymentsAsync = ref.watch(
      payment_provider.paymentsByDateRangeProvider(
        payment_provider.DateRange(
          start: startBoundary,
          end: endBoundary,
        ),
      ),
    );
    final currency = ref.watch(currentCurrencyProvider);

    return Column(
      children: [
        _buildDatePicker(),
        Expanded(
          child: paymentsAsync.when(
            data: (paymentList) {
              final filteredPayments = paymentList.where((payment) {
                final paymentDate = payment.date;
                return !paymentDate.isBefore(startBoundary) &&
                    !paymentDate.isAfter(endBoundary);
              }).toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              if (filteredPayments.isEmpty) {
                return _buildEmptyState(
                    'No payments found for selected date range');
              }

              final cashPayments = filteredPayments
                  .where((p) => p.paymentMethod == PaymentMethod.cash)
                  .toList();
              final cardPayments = filteredPayments
                  .where((p) => p.paymentMethod == PaymentMethod.card)
                  .toList();
              final bankPayments = filteredPayments
                  .where((p) => p.paymentMethod == PaymentMethod.bankTransfer)
                  .toList();
              final chequePayments = filteredPayments
                  .where((p) => p.paymentMethod == PaymentMethod.cheque)
                  .toList();

              final cashAmount =
                  cashPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
              final cardAmount =
                  cardPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
              final bankAmount =
                  bankPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
              final chequeAmount =
                  chequePayments.fold<double>(0.0, (sum, p) => sum + p.amount);
              final totalAmount = filteredPayments.fold<double>(
                  0.0, (sum, p) => sum + p.amount);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildColoredMetricCard(
                      'Total Payments',
                      '${currency.symbol}${totalAmount.toStringAsFixed(2)}',
                      Icons.payments,
                      Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentTypeCard(
                            'Cash',
                            '${currency.symbol}${cashAmount.toStringAsFixed(2)}',
                            cashPayments.length.toString(),
                            Icons.money,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPaymentTypeCard(
                            'Card',
                            '${currency.symbol}${cardAmount.toStringAsFixed(2)}',
                            cardPayments.length.toString(),
                            Icons.credit_card,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentTypeCard(
                            'Bank Transfer',
                            '${currency.symbol}${bankAmount.toStringAsFixed(2)}',
                            bankPayments.length.toString(),
                            Icons.account_balance,
                            Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPaymentTypeCard(
                            'Cheque',
                            '${currency.symbol}${chequeAmount.toStringAsFixed(2)}',
                            chequePayments.length.toString(),
                            Icons.receipt_long,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildCustomTable(
                              headers: [
                                'Payment ID',
                                'Date',
                                'Customer',
                                'Amount',
                                'Method',
                                'Recorded By',
                              ],
                              rows: filteredPayments.take(100).map((payment) {
                                return [
                                  payment.id != null
                                      ? 'PAY-${payment.id}'
                                      : 'N/A',
                                  DateFormat('dd/MM/yyyy hh:mm a')
                                      .format(payment.date),
                                  payment.customer?.name ?? 'Unknown',
                                  '${currency.symbol}${payment.amount.toStringAsFixed(2)}',
                                  payment.paymentMethod.name.toUpperCase(),
                                  payment.processedBy?.name ?? 'Unknown',
                                ];
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isExporting
                                ? null
                                : () => _exportPaymentReportToExcel(
                                      cashPayments,
                                      cardPayments,
                                      bankPayments,
                                      chequePayments,
                                      currency,
                                    ),
                            icon: const Icon(Icons.file_download),
                            label: Text('reports.export_excel'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isExporting
                                ? null
                                : () => _exportPaymentReportToPDF(
                                      cashPayments,
                                      cardPayments,
                                      bankPayments,
                                      chequePayments,
                                      currency,
                                    ),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: Text('reports.export_pdf'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }

  // ==================== CASH REPORT ====================
  Widget _buildCashReport() {
    final salesAsync = ref.watch(salesProvider);
    final currency = ref.watch(currentCurrencyProvider);
    final DateTime startBoundary =
        DateTime(_startDate.year, _startDate.month, _startDate.day);
    final DateTime endBoundary =
        DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999);

    final customerPaymentsAsync = ref.watch(
        payment_provider.paymentsByDateRangeProvider(payment_provider.DateRange(
      start: startBoundary,
      end: endBoundary,
    )));
    final expenseSummaryAsync =
        ref.watch(expenseSummaryProvider(DateRangeFilter(
      start: startBoundary,
      end: endBoundary,
    )));
    final supplierPaymentsAsync =
        ref.watch(_allSupplierPaymentsProvider(DateRangeFilter(
      start: startBoundary,
      end: endBoundary,
    )));

    return Column(
      children: [
        _buildDatePicker(),
        Expanded(
          child: salesAsync.when(
            data: (sales) => customerPaymentsAsync.when(
              data: (payments) => expenseSummaryAsync.when(
                data: (expenseSummary) => supplierPaymentsAsync.when(
                  data: (supplierPayments) {
                    final filteredSales = sales.where((sale) {
                      final isInDateRange = sale.date.isAfter(
                              _startDate.subtract(const Duration(days: 1))) &&
                          sale.date
                              .isBefore(_endDate.add(const Duration(days: 1)));
                      final isCash =
                          sale.paymentType.toString().contains('cash');
                      return isInDateRange && isCash;
                    }).toList();

                    final totalCashSales = filteredSales.fold<double>(
                        0.0, (double sum, s) => sum + s.total);
                    final totalCashProfit =
                        filteredSales.fold<double>(0.0, (double sum, s) {
                      final saleCost =
                          s.items.fold<double>(0.0, (double itemSum, item) {
                        return itemSum + ((item.product?.cost ?? 0) * item.qty);
                      });
                      return sum + (s.total - saleCost - s.discount);
                    });
                    final totalTransactions = filteredSales.length;
                    final totalDiscount = filteredSales.fold<double>(
                        0.0, (double sum, s) => sum + s.discount);
                    // Include all amounts (positive and negative) for proper recovery tracking
                    final recoveryAmount = payments.fold<double>(
                        0.0,
                        (sum, payment) =>
                            sum +
                            (payment.amount.isNaN || payment.amount.isInfinite
                                ? 0.0
                                : payment.amount));
                    final expenseAmount = expenseSummary.totalExpense;
                    // Exclude cancelled cheques from supplier payments
                    // Include all amounts (positive and negative) except cancelled cheques
                    final paymentToParty =
                        supplierPayments.fold<double>(0.0, (sum, payment) {
                      final isCheque = payment.paymentMethod == 'cheque';
                      final isCancelled = payment.status == 'cancelled';
                      final isCancelledCheque = isCheque && isCancelled;
                      // Exclude cancelled cheques and invalid amounts
                      if (isCancelledCheque) return sum;
                      return sum +
                          (payment.amount.isNaN || payment.amount.isInfinite
                              ? 0.0
                              : payment.amount);
                    });
                    final totalAmount = totalCashSales + recoveryAmount;

                    final Map<String, List<dynamic>> salesByDate = {};
                    for (final sale in filteredSales) {
                      final dateKey =
                          DateFormat('yyyy-MM-dd').format(sale.date);
                      salesByDate.putIfAbsent(dateKey, () => []).add(sale);
                    }

                    final Map<int, Map<String, dynamic>> productStats = {};
                    for (final sale in filteredSales) {
                      for (final item in sale.items) {
                        if (item.product?.id != null) {
                          final productId = item.product!.id!;
                          if (!productStats.containsKey(productId)) {
                            productStats[productId] = {
                              'name': item.product?.name ?? 'Unknown',
                              'unit': item.product?.unit ?? '',
                              'quantity': 0.0,
                              'revenue': 0.0,
                            };
                          }
                          productStats[productId]!['quantity'] =
                              (productStats[productId]!['quantity'] as double) +
                                  item.qty;
                          // Calculate subtotal using current price: (price * qty) - discount
                          final itemSubtotal =
                              (item.price * item.qty) - (item.discount);
                          productStats[productId]!['revenue'] =
                              (productStats[productId]!['revenue'] as double) +
                                  itemSubtotal;
                        }
                      }
                    }
                    final topProducts = productStats.entries.toList()
                      ..sort((a, b) => (b.value['revenue'] as double)
                          .compareTo(a.value['revenue'] as double));
                    final top10Products = topProducts.take(10).toList();
                    final hasSalesData = filteredSales.isNotEmpty;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildColoredMetricCard(
                                  'Total Cash Sales',
                                  _formatCurrencyValue(
                                      currency, totalCashSales),
                                  Icons.money,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildColoredMetricCard(
                                  'Cash Profit',
                                  _formatCurrencyValue(
                                      currency, totalCashProfit),
                                  Icons.trending_up,
                                  Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildColoredMetricCard(
                                  'Transactions',
                                  totalTransactions.toString(),
                                  Icons.receipt_long,
                                  Colors.purple,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildColoredMetricCard(
                                  'Total Discount',
                                  _formatCurrencyValue(currency, totalDiscount),
                                  Icons.discount,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildCashSummaryPanel(
                            currency: currency,
                            cashSale: totalCashSales,
                            recovery: recoveryAmount,
                            total: totalAmount,
                            expense: expenseAmount,
                            paymentToParty: paymentToParty,
                          ),
                          if (!hasSalesData) ...[
                            const SizedBox(height: 24),
                            _buildEmptyState(
                                'No cash sales found for selected date range'),
                          ] else ...[
                            const SizedBox(height: 24),
                            Text(
                              'Daily Cash Sales Breakdown',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: (() {
                                    final sorted = salesByDate.entries.toList()
                                      ..sort((a, b) => b.key.compareTo(a.key));
                                    return sorted.take(15).map((entry) {
                                      final date = DateTime.parse(entry.key);
                                      final daySales = entry.value;
                                      final dayTotal = daySales.fold<double>(
                                          0.0, (sum, s) => sum + s.total);
                                      final dayCount = daySales.length;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    DateFormat('dd MMM yyyy')
                                                        .format(date),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    '$dayCount transaction${dayCount > 1 ? 's' : ''}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              _formatCurrencyValue(
                                                  currency, dayTotal),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList();
                                  })(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Top Products Sold (Cash)',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: top10Products
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final productData = entry.value.value;
                                    final productName =
                                        productData['name'] as String;
                                    final quantity =
                                        productData['quantity'] as double;
                                    final revenue =
                                        productData['revenue'] as double;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.green
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  productName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  'Qty: ${QuantityFormatter.withUnit(quantity, productData['unit'] as String?)}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            _formatCurrencyValue(
                                                currency, revenue),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isExporting
                                        ? null
                                        : () => _exportCashReportToExcel(
                                              filteredSales,
                                              salesByDate,
                                              top10Products,
                                              currency,
                                            ),
                                    icon: const Icon(Icons.file_download),
                                    label: Text('reports.export_excel'.tr()),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isExporting
                                        ? null
                                        : () => _exportCashReportToPDF(
                                              filteredSales,
                                              salesByDate,
                                              top10Products,
                                              currency,
                                              totalCashSales,
                                              totalCashProfit,
                                              totalTransactions,
                                            ),
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: Text('reports.export_pdf'.tr()),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => _buildErrorWidget(error),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _buildErrorWidget(error),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorWidget(error),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _buildErrorWidget(error),
          ),
        ),
      ],
    );
  }

  // ==================== CREDIT REPORT ====================
  Widget _buildCreditReport() {
    final salesAsync = ref.watch(salesProvider);
    final currency = ref.watch(currentCurrencyProvider);
    final DateTime startBoundary =
        DateTime(_startDate.year, _startDate.month, _startDate.day);
    final DateTime endBoundary =
        DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999);

    final customerPaymentsAsync = ref.watch(
        payment_provider.paymentsByDateRangeProvider(payment_provider.DateRange(
      start: startBoundary,
      end: endBoundary,
    )));
    final supplierPaymentsAsync =
        ref.watch(_allSupplierPaymentsProvider(DateRangeFilter(
      start: startBoundary,
      end: endBoundary,
    )));
    final bankPaymentsAsync =
        ref.watch(bank_provider.bankPaymentsByDateRangeProvider((
      start: startBoundary,
      end: endBoundary,
    )));

    return Column(
      children: [
        _buildDatePicker(),
        Expanded(
          child: salesAsync.when(
            data: (sales) {
              return customerPaymentsAsync.when(
                data: (customerPayments) {
                  return supplierPaymentsAsync.when(
                    data: (supplierPayments) {
                      return bankPaymentsAsync.when(
                        data: (bankPayments) {
                          final creditSales = sales.where((sale) {
                            final paymentType =
                                sale.paymentType.toString().toLowerCase();
                            final saleDate = sale.date;
                            return paymentType.contains('credit') &&
                                !saleDate.isBefore(startBoundary) &&
                                !saleDate.isAfter(endBoundary);
                          }).toList()
                            ..sort((a, b) => b.date.compareTo(a.date));

                          // Calculate metrics
                          final totalCredit = creditSales.fold<double>(
                              0.0, (sum, s) => sum + s.total);
                          final totalPaid = creditSales.fold<double>(
                              0.0, (sum, s) => sum + s.paid);
                          final totalDue = creditSales.fold<double>(
                              0.0, (sum, s) => sum + s.due);
                          final totalTransactions = creditSales.length;

                          // Calculate party payments
                          final totalSupplierPayments = supplierPayments
                              .fold<double>(0.0, (sum, p) => sum + p.amount);
                          final totalBankPayments = bankPayments
                              .where((p) =>
                                  p.paymentType == 'transfer' ||
                                  p.paymentType == 'withdrawal')
                              .fold<double>(0.0, (sum, p) => sum + p.amount);
                          final totalPartyPayments =
                              totalSupplierPayments + totalBankPayments;

                          // Calculate customer payments (recovery)
                          // Include all amounts (positive and negative) for proper recovery tracking
                          final totalRecovery = customerPayments.fold<double>(
                              0.0,
                              (sum, p) =>
                                  sum +
                                  (p.amount.isNaN || p.amount.isInfinite
                                      ? 0.0
                                      : p.amount));

                          final retailCreditSales = creditSales
                              .where((sale) => !sale.isWholesale)
                              .toList();
                          final wholesaleCreditSales = creditSales
                              .where((sale) => sale.isWholesale)
                              .toList();

                          double _sumTotal(List<SaleModel> sales) => sales
                              .fold<double>(0.0, (sum, s) => sum + s.total);
                          double _sumPaid(List<SaleModel> sales) =>
                              sales.fold<double>(0.0, (sum, s) => sum + s.paid);
                          double _sumDue(List<SaleModel> sales) =>
                              sales.fold<double>(0.0, (sum, s) => sum + s.due);

                          if (creditSales.isEmpty &&
                              totalPartyPayments == 0 &&
                              totalRecovery == 0) {
                            return _buildEmptyState(
                                'No credit sales or party payments found for selected date range');
                          }

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Credit Summary Cards
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildColoredMetricCard(
                                        'Total Credit',
                                        '${currency.symbol}${totalCredit.toStringAsFixed(2)}',
                                        Icons.credit_card,
                                        Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildColoredMetricCard(
                                        'Total Paid',
                                        '${currency.symbol}${totalPaid.toStringAsFixed(2)}',
                                        Icons.check_circle,
                                        Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildColoredMetricCard(
                                        'Total Due',
                                        '${currency.symbol}${totalDue.toStringAsFixed(2)}',
                                        Icons.warning,
                                        Colors.red,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildColoredMetricCard(
                                        'Transactions',
                                        totalTransactions.toString(),
                                        Icons.receipt_long,
                                        Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildCreditTypeBreakdown(
                                  currency: currency,
                                  retailCount: retailCreditSales.length,
                                  retailTotal: _sumTotal(retailCreditSales),
                                  retailPaid: _sumPaid(retailCreditSales),
                                  retailDue: _sumDue(retailCreditSales),
                                  wholesaleCount: wholesaleCreditSales.length,
                                  wholesaleTotal:
                                      _sumTotal(wholesaleCreditSales),
                                  wholesalePaid: _sumPaid(wholesaleCreditSales),
                                  wholesaleDue: _sumDue(wholesaleCreditSales),
                                ),
                                const SizedBox(height: 16),
                                // Party Payments Summary
                                // Show if there are any party payments or recovery (including negative recovery)
                                if (totalPartyPayments != 0 ||
                                    totalRecovery != 0) ...[
                                  Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Party Payments & Recovery',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildColoredMetricCard(
                                                  'Recovery (Customer Payments)',
                                                  '${currency.symbol}${totalRecovery.toStringAsFixed(2)}',
                                                  totalRecovery >= 0
                                                      ? Icons.arrow_downward
                                                      : Icons.arrow_upward,
                                                  totalRecovery >= 0
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _buildColoredMetricCard(
                                                  'Party Payments',
                                                  '${currency.symbol}${totalPartyPayments.toStringAsFixed(2)}',
                                                  Icons.arrow_upward,
                                                  Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                // Credit Sales List
                                Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Credit Sales Details',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildCustomTable(
                                          headers: [
                                            'Sale ID',
                                            'Type',
                                            'Date',
                                            'Customer',
                                            'Total',
                                            'Paid',
                                            'Due',
                                            'Status',
                                            'Cashier',
                                          ],
                                          rows: creditSales.map((sale) {
                                            return [
                                              'Sale #${sale.id}',
                                              sale.isWholesale
                                                  ? 'Wholesale'
                                                  : 'Retail',
                                              DateFormat('dd/MM/yyyy hh:mm a')
                                                  .format(sale.date),
                                              sale.customer?.name ?? 'Walk-in',
                                              '${currency.symbol}${sale.total.toStringAsFixed(2)}',
                                              '${currency.symbol}${sale.paid.toStringAsFixed(2)}',
                                              '${currency.symbol}${sale.due.toStringAsFixed(2)}',
                                              sale.status
                                                  .toString()
                                                  .split('.')
                                                  .last
                                                  .toUpperCase(),
                                              sale.cashier?.name ?? 'Unknown',
                                            ];
                                          }).toList(),
                                          maxHeight: 400,
                                          onRowTap: (index) {
                                            if (index < creditSales.length) {
                                              _showSaleDetails(context,
                                                  creditSales[index], currency);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(
                            child: Text('Error loading bank payments: $error')),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                        child: Text('Error loading supplier payments: $error')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                    child: Text('Error loading customer payments: $error')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }

  Widget _buildCreditTypeBreakdown({
    required Currency currency,
    required int retailCount,
    required double retailTotal,
    required double retailPaid,
    required double retailDue,
    required int wholesaleCount,
    required double wholesaleTotal,
    required double wholesalePaid,
    required double wholesaleDue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildCreditCategoryCard(
            title: 'Retail Credit',
            icon: Icons.storefront,
            color: const Color(0xFF2563EB),
            count: retailCount,
            total: retailTotal,
            paid: retailPaid,
            due: retailDue,
            currency: currency,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCreditCategoryCard(
            title: 'Wholesale Credit',
            icon: Icons.warehouse,
            color: const Color(0xFF7C3AED),
            count: wholesaleCount,
            total: wholesaleTotal,
            paid: wholesalePaid,
            due: wholesaleDue,
            currency: currency,
          ),
        ),
      ],
    );
  }

  Widget _buildCreditCategoryCard({
    required String title,
    required IconData icon,
    required Color color,
    required int count,
    required double total,
    required double paid,
    required double due,
    required Currency currency,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count credit sale${count == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: color.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            _buildCreditStatRow(
              label: 'Total Credit',
              value: '${currency.symbol}${total.toStringAsFixed(2)}',
              valueColor: color,
            ),
            const SizedBox(height: 8),
            _buildCreditStatRow(
              label: 'Paid Amount',
              value: '${currency.symbol}${paid.toStringAsFixed(2)}',
              valueColor: const Color(0xFF16A34A),
            ),
            const SizedBox(height: 8),
            _buildCreditStatRow(
              label: 'Due Amount',
              value: '${currency.symbol}${due.toStringAsFixed(2)}',
              valueColor:
                  due > 0 ? const Color(0xFFDC2626) : const Color(0xFF047857),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditStatRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  // ==================== STOCK MOVEMENT REPORT ====================
  Widget _buildStockMovementReport() {
    final movementsAsync = ref.watch(stockMovementsProvider);
    final currency = ref.watch(currentCurrencyProvider);

    return Column(
      children: [
        // Date Picker
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
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
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 20, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy').format(_startDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child:
                    Text('to', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, false),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 20, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy').format(_endDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: movementsAsync.when(
            data: (movements) {
              // Filter by date range - StockMovementWithProduct has movement.date
              final filteredMovements = movements.where((m) {
                try {
                  final quantity = m.movement.quantity;
                  if (quantity == 0) {
                    // Skip entries where no stock change occurred
                    return false;
                  }

                  final reason = m.movement.reason.trim().toLowerCase();
                  final isManualMovement = reason == 'stock movement';
                  if (!isManualMovement) {
                    return false;
                  }

                  // StockMovementWithProduct has a movement property of type StockAdjustment
                  final dateStr = m.movement.date;
                  final date = DateTime.parse(dateStr);
                  final isWithinRange = date.isAfter(
                        _startDate.subtract(const Duration(days: 1)),
                      ) &&
                      date.isBefore(_endDate.add(const Duration(days: 1)));

                  // Only include manual movements with actual quantity change within range
                  return isWithinRange;
                } catch (e) {
                  debugPrint('Error parsing date in stock movement: $e');
                  return false; // Skip items we can't parse
                }
              }).toList();

              if (filteredMovements.isEmpty) {
                return _buildEmptyState(
                    'No stock movements for selected date range');
              }

              // Calculate stats
              final totalIn = filteredMovements.where((m) {
                return m.movement.quantity > 0;
              }).fold<double>(0.0, (double sum, m) {
                return sum + m.movement.quantity;
              });

              final totalOut = filteredMovements.where((m) {
                return m.movement.quantity < 0;
              }).fold<double>(0.0, (double sum, m) {
                return sum + m.movement.quantity.abs();
              });

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                'Total In',
                                totalIn.toStringAsFixed(2),
                                Icons.arrow_downward,
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                'Total Out',
                                totalOut.toStringAsFixed(2),
                                Icons.arrow_upward,
                                Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Export Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isExporting
                                    ? null
                                    : () => _exportStockMovementToExcel(
                                        filteredMovements, currency),
                                icon: const Icon(Icons.file_download),
                                label: Text('reports.export_excel'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isExporting
                                    ? null
                                    : () => _exportStockMovementToPDF(
                                        filteredMovements, currency),
                                icon: const Icon(Icons.picture_as_pdf),
                                label: Text('reports.export_pdf'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredMovements.length,
                      itemBuilder: (context, index) {
                        final movementWithProduct = filteredMovements[index];

                        // Get quantity - StockMovementWithProduct has movement.quantity
                        final quantity = movementWithProduct.movement.quantity;
                        final isIn = quantity > 0;

                        // Get product name
                        final productName = movementWithProduct.product.name ??
                            'Unknown Product';

                        // Get reason, reference, and date
                        final reason = movementWithProduct.movement.reason;
                        final reference =
                            movementWithProduct.movement.reference;

                        DateTime date;
                        try {
                          date =
                              DateTime.parse(movementWithProduct.movement.date);
                        } catch (e) {
                          debugPrint('Error parsing date: $e');
                          date = DateTime.now();
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            onTap: () =>
                                _showStockMovementDetails(movementWithProduct),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isIn
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isIn
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: isIn ? Colors.green : Colors.red,
                              ),
                            ),
                            title: Text(
                              productName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Product: $productName',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text('Reason: $reason'),
                                if (movementWithProduct.employee != null)
                                  Text(
                                    'User: ${movementWithProduct.employee!.name}',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (reference != null && reference.isNotEmpty)
                                  Text('Ref: $reference'),
                                Text(
                                    'Date: ${DateFormat('dd/MM/yyyy hh:mm a').format(date)}'),
                              ],
                            ),
                            trailing: Text(
                              '${isIn ? '+' : '-'}${quantity.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isIn ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }

  void _showStockMovementDetails(StockMovementWithProduct movement) {
    if (!mounted) return;

    DateTime displayDate;
    try {
      displayDate = DateTime.parse(movement.movement.date);
    } catch (_) {
      displayDate = DateTime.now();
    }

    final isIncrease = movement.movement.quantity > 0;
    final quantityText =
        '${isIncrease ? '+' : '-'}${movement.movement.quantity.abs().toStringAsFixed(2)} ${movement.product.unit}';
    final reference = movement.movement.reference;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isIncrease ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncrease ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(isIncrease ? 'Stock Increased' : 'Stock Decreased'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Product', movement.product.name ?? 'Unknown'),
            if (movement.product.barcode != null &&
                movement.product.barcode!.isNotEmpty)
              _buildDetailRow('Barcode', movement.product.barcode!),
            _buildDetailRow('Quantity Change', quantityText),
            _buildDetailRow('Reason', movement.movement.reason),
            if (movement.employee != null)
              _buildDetailRow(
                'User/Employee',
                movement.employee!.name,
                valueColor: const Color(0xFF2563EB),
              )
            else if (movement.movement.employeeId != null)
              _buildDetailRow(
                'User/Employee',
                'Employee ID: ${movement.movement.employeeId} (Not Found)',
                valueColor: Colors.orange,
              ),
            if (reference != null && reference.isNotEmpty)
              _buildDetailRow('Reference', reference),
            _buildDetailRow(
              'Date',
              DateFormat('dd MMM yyyy, hh:mm a').format(displayDate),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  // ==================== MONTHLY REPORT ====================
  Widget _buildMonthlyReport() {
    final salesAsync = ref.watch(salesProvider);
    final productsAsync = ref.watch(productNotifierProvider);
    final currency = ref.watch(currentCurrencyProvider);
    final expenseSummary = ref.watch(expenseSummaryProvider(DateRangeFilter(
      start: _startDate,
      end: _endDate,
    )));

    return Column(
      children: [
        // Month Selector
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
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
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month,
                            size: 20, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMMM yyyy').format(_startDate),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    final now = DateTime.now();
                    _startDate = DateTime(now.year, now.month, 1);
                    _endDate = DateTime(now.year, now.month + 1, 0);
                  });
                },
                icon: const Icon(Icons.today, size: 18),
                label: Text('reports.this_month'.tr()),
              ),
            ],
          ),
        ),
        Expanded(
          child: salesAsync.when(
            data: (sales) {
              return productsAsync.when(
                data: (products) {
                  return expenseSummary.when(
                    data: (expenseData) {
                      // Filter sales for the selected month
                      final filteredSales = sales.where((sale) {
                        return sale.date.year == _startDate.year &&
                            sale.date.month == _startDate.month;
                      }).toList();

                      if (filteredSales.isEmpty) {
                        return _buildEmptyState(
                            'No sales data for selected month');
                      }

                      // Calculate monthly metrics
                      final totalSales = filteredSales.fold<double>(
                          0.0, (double sum, s) => sum + s.total);
                      final totalCost =
                          filteredSales.fold<double>(0.0, (double sum, s) {
                        return sum +
                            s.items.fold<double>(0.0, (double itemSum, item) {
                              return itemSum +
                                  ((item.product?.cost ?? 0) * item.qty);
                            });
                      });
                      final totalProfit = totalSales - totalCost;
                      final totalExpenses = expenseData.totalExpense;
                      final netProfit = totalProfit - totalExpenses;
                      final totalTransactions = filteredSales.length;
                      final avgDailySales = totalSales /
                          DateTime(_startDate.year, _startDate.month + 1, 0)
                              .day;
                      final avgTransactionValue =
                          totalSales / totalTransactions;

                      // Calculate daily breakdown
                      final dailyBreakdown = <String, double>{};
                      for (var sale in filteredSales) {
                        final dayKey = DateFormat('dd').format(sale.date);
                        dailyBreakdown[dayKey] =
                            (dailyBreakdown[dayKey] ?? 0) + sale.total;
                      }

                      // Top products
                      final productSales = <String, double>{};
                      for (var sale in filteredSales) {
                        for (var item in sale.items) {
                          final productName = item.product?.name ?? 'Unknown';
                          productSales[productName] =
                              (productSales[productName] ?? 0) +
                                  (item.qty * item.price);
                        }
                      }
                      final topProducts = productSales.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));

                      // Payment method breakdown
                      final cashTotal = filteredSales
                          .where(
                              (s) => s.paymentType.toString().contains('cash'))
                          .fold<double>(0.0, (sum, s) => sum + s.total);
                      final cardTotal = filteredSales
                          .where(
                              (s) => s.paymentType.toString().contains('card'))
                          .fold<double>(0.0, (sum, s) => sum + s.total);
                      final creditTotal = filteredSales
                          .where((s) =>
                              s.paymentType.toString().contains('credit'))
                          .fold<double>(0.0, (sum, s) => sum + s.total);

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Monthly Summary Card
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.summarize,
                                            size: 28, color: Color(0xFF3B82F6)),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Monthly Summary - ${DateFormat('MMMM yyyy').format(_startDate)}',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildMetricCard(
                                            'Total Sales',
                                            '${currency.symbol}${totalSales.toStringAsFixed(2)}',
                                            Icons.trending_up,
                                            Colors.green,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildMetricCard(
                                            'Gross Profit',
                                            '${currency.symbol}${totalProfit.toStringAsFixed(2)}',
                                            Icons.account_balance_wallet,
                                            Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildMetricCard(
                                            'Net Profit',
                                            '${currency.symbol}${netProfit.toStringAsFixed(2)}',
                                            Icons.savings,
                                            Colors.purple,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildMetricCard(
                                            'Transactions',
                                            totalTransactions.toString(),
                                            Icons.receipt_long,
                                            Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildMetricCard(
                                            'Avg Daily Sales',
                                            '${currency.symbol}${avgDailySales.toStringAsFixed(2)}',
                                            Icons.calendar_today,
                                            Colors.teal,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildMetricCard(
                                            'Avg Transaction',
                                            '${currency.symbol}${avgTransactionValue.toStringAsFixed(2)}',
                                            Icons.shopping_cart,
                                            Colors.indigo,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Daily Sales Breakdown
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Daily Sales Breakdown',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 200,
                                      child: BarChart(
                                        BarChartData(
                                          alignment:
                                              BarChartAlignment.spaceAround,
                                          maxY: dailyBreakdown.values.isEmpty
                                              ? 1
                                              : dailyBreakdown.values.reduce(
                                                      (a, b) => a > b ? a : b) *
                                                  1.2,
                                          barTouchData:
                                              BarTouchData(enabled: true),
                                          barGroups: dailyBreakdown.entries
                                              .map((entry) {
                                            return BarChartGroupData(
                                              x: int.parse(entry.key),
                                              barRods: [
                                                BarChartRodData(
                                                  toY: entry.value,
                                                  color:
                                                      const Color(0xFF3B82F6),
                                                  width: 16,
                                                  borderRadius:
                                                      const BorderRadius
                                                          .vertical(
                                                          top: Radius.circular(
                                                              4)),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                          titlesData: FlTitlesData(
                                            show: true,
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (value, meta) {
                                                  return Text(
                                                    value.toInt().toString(),
                                                    style: const TextStyle(
                                                        fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (value, meta) {
                                                  return Text(
                                                    '${currency.symbol}${value.toInt()}',
                                                    style: const TextStyle(
                                                        fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            topTitles: const AxisTitles(
                                              sideTitles:
                                                  SideTitles(showTitles: false),
                                            ),
                                            rightTitles: const AxisTitles(
                                              sideTitles:
                                                  SideTitles(showTitles: false),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Payment Methods Breakdown
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Payment Methods',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildPaymentMethodRow('Cash', cashTotal,
                                        Colors.green, totalSales),
                                    const SizedBox(height: 12),
                                    _buildPaymentMethodRow('Card', cardTotal,
                                        Colors.blue, totalSales),
                                    const SizedBox(height: 12),
                                    _buildPaymentMethodRow('Credit',
                                        creditTotal, Colors.orange, totalSales),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Top Products
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Top 10 Products',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ...topProducts.take(10).map((entry) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                entry.key,
                                                style: const TextStyle(
                                                    fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                '${currency.symbol}${entry.value.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Export Buttons
                            _buildExportButtons(
                              () => _exportMonthlyReportToExcel(
                                filteredSales,
                                products,
                                currency,
                                totalSales,
                                totalProfit,
                                netProfit,
                                totalTransactions,
                                dailyBreakdown,
                                topProducts,
                                cashTotal,
                                cardTotal,
                                creditTotal,
                              ),
                              () => _exportMonthlyReportToPDF(
                                filteredSales,
                                products,
                                currency,
                                totalSales,
                                totalProfit,
                                netProfit,
                                totalTransactions,
                                dailyBreakdown,
                                topProducts,
                                cashTotal,
                                cardTotal,
                                creditTotal,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        Center(child: Text('Error: $error')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }

  // ==================== MONTHLY PROFIT & LOSS REPORT ====================
  Widget _buildMonthlyProfitLossReport() {
    final salesAsync = ref.watch(salesProvider);
    final currency = ref.watch(currentCurrencyProvider);
    final expenseSummary = ref.watch(expenseSummaryProvider(DateRangeFilter(
      start: _startDate,
      end: _endDate,
    )));

    return Column(
      children: [
        // Month Selector
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
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
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month,
                            size: 20, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMMM yyyy').format(_startDate),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    final now = DateTime.now();
                    _startDate = DateTime(now.year, now.month, 1);
                    _endDate = DateTime(now.year, now.month + 1, 0);
                  });
                },
                icon: const Icon(Icons.today, size: 18),
                label: Text('reports.this_month'.tr()),
              ),
            ],
          ),
        ),
        Expanded(
          child: salesAsync.when(
            data: (sales) {
              return expenseSummary.when(
                data: (expenseData) {
                  // Filter sales for the selected month
                  final filteredSales = sales.where((sale) {
                    return sale.date.year == _startDate.year &&
                        sale.date.month == _startDate.month;
                  }).toList();

                  if (filteredSales.isEmpty) {
                    return _buildEmptyState(
                        'No data available for selected month');
                  }

                  // Calculate P&L metrics
                  final totalRevenue = filteredSales.fold<double>(
                      0.0, (double sum, s) => sum + s.total);
                  final totalCost =
                      filteredSales.fold<double>(0.0, (double sum, s) {
                    return sum +
                        s.items.fold<double>(0.0, (double itemSum, item) {
                          return itemSum +
                              ((item.product?.cost ?? 0) * item.qty);
                        });
                  });
                  final grossProfit = totalRevenue - totalCost;
                  final totalExpenses = expenseData.totalExpense;
                  final netProfit = grossProfit - totalExpenses;

                  final grossMargin = totalRevenue > 0
                      ? (grossProfit / totalRevenue) * 100
                      : 0.0;
                  final netMargin =
                      totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // P&L Header
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.account_balance,
                                        size: 28, color: Color(0xFF3B82F6)),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Profit & Loss Report - ${DateFormat('MMMM yyyy').format(_startDate)}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Revenue Section
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Revenue',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildPLRow(
                                    'Total Sales',
                                    '${currency.symbol}${totalRevenue.toStringAsFixed(2)}',
                                    Colors.green),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Cost of Goods Sold
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cost of Goods Sold (COGS)',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildPLRow(
                                    'Product Cost',
                                    '${currency.symbol}${totalCost.toStringAsFixed(2)}',
                                    Colors.red),
                                const Divider(height: 32),
                                _buildPLRow(
                                    'Gross Profit',
                                    '${currency.symbol}${grossProfit.toStringAsFixed(2)}',
                                    grossProfit >= 0
                                        ? Colors.green
                                        : Colors.red,
                                    isBold: true),
                                _buildPLRow(
                                    'Gross Margin',
                                    '${grossMargin.toStringAsFixed(2)}%',
                                    const Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Operating Expenses
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Operating Expenses',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildPLRow(
                                    'Total Expenses',
                                    '${currency.symbol}${totalExpenses.toStringAsFixed(2)}',
                                    Colors.orange),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Net Profit/Loss
                        Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          color: netProfit >= 0
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      netProfit >= 0
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      size: 28,
                                      color: netProfit >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      netProfit >= 0
                                          ? 'Net Profit'
                                          : 'Net Loss',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: netProfit >= 0
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '${currency.symbol}${netProfit.abs().toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: netProfit >= 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Net Margin: ${netMargin.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: netProfit >= 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Export Buttons
                        _buildExportButtons(
                          () => _exportMonthlyPLToExcel(
                            filteredSales,
                            currency,
                            totalRevenue,
                            totalCost,
                            grossProfit,
                            totalExpenses,
                            netProfit,
                            grossMargin,
                            netMargin,
                          ),
                          () => _exportMonthlyPLToPDF(
                            filteredSales,
                            currency,
                            totalRevenue,
                            totalCost,
                            grossProfit,
                            totalExpenses,
                            netProfit,
                            grossMargin,
                            netMargin,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }

  Widget _buildPLRow(String label, String value, Color color,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 20 : 18,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportMonthlyPLToExcel(
    List<dynamic> sales,
    Currency currency,
    double totalRevenue,
    double totalCost,
    double grossProfit,
    double totalExpenses,
    double netProfit,
    double grossMargin,
    double netMargin,
  ) async {
    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Monthly P&L Report'];

      // Header
      sheetObject.appendRow([
        TextCellValue(
            'Monthly Profit & Loss Report - ${DateFormat('MMMM yyyy').format(_startDate)}')
      ]);
      sheetObject.appendRow([]);

      // Revenue
      sheetObject.appendRow([TextCellValue('REVENUE')]);
      sheetObject.appendRow([
        TextCellValue('Total Sales'),
        TextCellValue('${currency.symbol}${totalRevenue.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([]);

      // COGS
      sheetObject.appendRow([TextCellValue('COST OF GOODS SOLD')]);
      sheetObject.appendRow([
        TextCellValue('Product Cost'),
        TextCellValue('${currency.symbol}${totalCost.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([]);
      sheetObject.appendRow([
        TextCellValue('Gross Profit'),
        TextCellValue('${currency.symbol}${grossProfit.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Gross Margin'),
        TextCellValue('${grossMargin.toStringAsFixed(2)}%')
      ]);
      sheetObject.appendRow([]);

      // Operating Expenses
      sheetObject.appendRow([TextCellValue('OPERATING EXPENSES')]);
      sheetObject.appendRow([
        TextCellValue('Total Expenses'),
        TextCellValue('${currency.symbol}${totalExpenses.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([]);

      // Net Profit/Loss
      sheetObject.appendRow(
          [TextCellValue(netProfit >= 0 ? 'NET PROFIT' : 'NET LOSS')]);
      sheetObject.appendRow([
        TextCellValue('Amount'),
        TextCellValue('${currency.symbol}${netProfit.abs().toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Net Margin'),
        TextCellValue('${netMargin.toStringAsFixed(2)}%')
      ]);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/MonthlyPL_$timestamp.xlsx';
      final fileBytes = excel.save();
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(filePath)], text: 'Monthly P&L Report');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('Excel file exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportMonthlyPLToPDF(
    List<dynamic> sales,
    Currency currency,
    double totalRevenue,
    double totalCost,
    double grossProfit,
    double totalExpenses,
    double netProfit,
    double grossMargin,
    double netMargin,
  ) async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Monthly Profit & Loss Report',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text(
              'Period: ${DateFormat('MMMM yyyy').format(_startDate)}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 30),

            // Revenue
            pw.Text('REVENUE',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Sales:'),
                pw.Text(
                  '${currency.symbol}${totalRevenue.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // COGS
            pw.Text('COST OF GOODS SOLD',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Product Cost:'),
                pw.Text('${currency.symbol}${totalCost.toStringAsFixed(2)}'),
              ],
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Gross Profit:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '${currency.symbol}${grossProfit.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: grossProfit >= 0 ? PdfColors.green : PdfColors.red,
                  ),
                ),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Gross Margin:'),
                pw.Text('${grossMargin.toStringAsFixed(2)}%'),
              ],
            ),
            pw.SizedBox(height: 20),

            // Operating Expenses
            pw.Text('OPERATING EXPENSES',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Expenses:'),
                pw.Text(
                    '${currency.symbol}${totalExpenses.toStringAsFixed(2)}'),
              ],
            ),
            pw.SizedBox(height: 20),

            // Net Profit/Loss
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    netProfit >= 0 ? 'NET PROFIT' : 'NET LOSS',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Amount:'),
                      pw.Text(
                        '${currency.symbol}${netProfit.abs().toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color:
                              netProfit >= 0 ? PdfColors.green : PdfColors.red,
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Net Margin:'),
                      pw.Text(
                        '${netMargin.toStringAsFixed(2)}%',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'MonthlyPL_${DateFormat('yyyyMM').format(_startDate)}.pdf',
      );

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('PDF exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow(
      String method, double amount, Color color, double totalSales) {
    final percentageLabel =
        _formatPercentage(amount, totalSales, fractionDigits: 1);
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                method,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_getCurrencySymbol()}${amount.toStringAsFixed(2)} ($percentageLabel)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getCurrencySymbol() {
    return ref.read(currentCurrencyProvider).symbol;
  }

  String _formatPercentage(double numerator, double denominator,
      {int fractionDigits = 1}) {
    final safeDenominator = denominator == 0 ? 0.0 : denominator;
    if (safeDenominator == 0) {
      return '${0.0.toStringAsFixed(fractionDigits)}%';
    }
    final value = (numerator / safeDenominator) * 100;
    final safeValue = value.isFinite ? value : 0.0;
    return '${safeValue.toStringAsFixed(fractionDigits)}%';
  }

  String _formatAverage(double total, int count, {int fractionDigits = 2}) {
    if (count <= 0) {
      return 0.0.toStringAsFixed(fractionDigits);
    }
    final value = total / count;
    final safeValue = value.isFinite ? value : 0.0;
    return safeValue.toStringAsFixed(fractionDigits);
  }

  // ==================== NEW HELPER WIDGETS ====================
  Widget _buildDatePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
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
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 20, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_startDate),
                      style: const TextStyle(fontSize: 14),
                    ),
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
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 20, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_endDate),
                      style: const TextStyle(fontSize: 14),
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

  Widget _buildKPISection(
    double totalSales,
    double totalProfit,
    double netProfit,
    int totalTransactions,
    double salesGrowth,
    Currency currency,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Key Performance Indicators',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildModernMetricCard(
                    'Total Sales',
                    '${currency.symbol}${totalSales.toStringAsFixed(2)}',
                    Icons.trending_up,
                    const Color(0xFF3B82F6),
                    '${salesGrowth >= 0 ? '+' : ''}${salesGrowth.toStringAsFixed(1)}%',
                    salesGrowth >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernMetricCard(
                    'Gross Profit',
                    '${currency.symbol}${totalProfit.toStringAsFixed(2)}',
                    Icons.account_balance_wallet,
                    const Color(0xFF10B981),
                    _formatPercentage(totalProfit, totalSales,
                        fractionDigits: 1),
                    const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModernMetricCard(
                    'Net Profit',
                    '${currency.symbol}${netProfit.toStringAsFixed(2)}',
                    Icons.monetization_on,
                    const Color(0xFF8B5CF6),
                    _formatPercentage(netProfit, totalSales, fractionDigits: 1),
                    netProfit >= 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernMetricCard(
                    'Transactions',
                    totalTransactions.toString(),
                    Icons.receipt_long,
                    const Color(0xFFF59E0B),
                    'Avg: ${currency.symbol}${_formatAverage(totalSales, totalTransactions)}',
                    const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
    Color subtitleColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: subtitleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessHealthSection(
    int totalItems,
    int lowStockItems,
    int outOfStockItems,
    double totalExpenses,
    Currency currency,
  ) {
    final stockHealthPercentage = totalItems > 0
        ? ((totalItems - lowStockItems) / totalItems) * 100
        : 100.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business Health Metrics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildHealthMetricCard(
                    'Inventory Health',
                    '${stockHealthPercentage.toStringAsFixed(1)}%',
                    Icons.inventory,
                    stockHealthPercentage >= 80
                        ? const Color(0xFF10B981)
                        : stockHealthPercentage >= 60
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFEF4444),
                    '${totalItems - lowStockItems} of $totalItems items',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildHealthMetricCard(
                    'Stock Alerts',
                    lowStockItems.toString(),
                    Icons.warning,
                    lowStockItems == 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    '${outOfStockItems} out of stock',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildHealthMetricCard(
              'Total Expenses',
              '${currency.symbol}${totalExpenses.toStringAsFixed(2)}',
              Icons.money_off,
              const Color(0xFFEF4444),
              'Operating costs',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChartsSection(List<dynamic> sales, Currency currency) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildSalesChart(sales, currency),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart(List<dynamic> sales, Currency currency) {
    if (sales.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 16),
            Text('No sales data available',
                style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    // Group sales by date
    final Map<String, double> dailySales = {};
    for (final sale in sales) {
      final dateKey = DateFormat('dd/MM').format(sale.date);
      dailySales[dateKey] = (dailySales[dateKey] ?? 0) + sale.total;
    }

    final sortedDates = dailySales.keys.toList()..sort();
    final maxValue = dailySales.values.isNotEmpty
        ? dailySales.values.reduce((a, b) => a > b ? a : b)
        : 0.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < sortedDates.length) {
                  return Text(
                    sortedDates[value.toInt()],
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${currency.symbol}${value.toInt()}',
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(sortedDates.length, (index) {
          final date = sortedDates[index];
          final amount = dailySales[date] ?? 0.0;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: amount,
                color: const Color(0xFF3B82F6),
                width: 20,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildExportButtons(VoidCallback onExcel, VoidCallback onPDF) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isExporting ? null : onExcel,
            icon: const Icon(Icons.file_download),
            label: Text('reports.export_excel'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isExporting ? null : onPDF,
            icon: const Icon(Icons.picture_as_pdf),
            label: Text('reports.export_pdf'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // Additional helper methods for new report sections
  Widget _buildSalesPerformanceSection(List<dynamic> sales, Currency currency) {
    final totalSales =
        sales.fold<double>(0.0, (double sum, s) => sum + s.total);
    final avgTransactionValue =
        sales.isNotEmpty ? totalSales / sales.length : 0.0;
    final peakHour = _getPeakHour(sales);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Performance',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildModernMetricCard(
                    'Total Revenue',
                    '${currency.symbol}${totalSales.toStringAsFixed(2)}',
                    Icons.trending_up,
                    const Color(0xFF3B82F6),
                    '${sales.length} transactions',
                    const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernMetricCard(
                    'Avg Transaction',
                    '${currency.symbol}${avgTransactionValue.toStringAsFixed(2)}',
                    Icons.receipt,
                    const Color(0xFF10B981),
                    'Peak: $peakHour',
                    const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTrendsChart(List<dynamic> sales, Currency currency) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Trends',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _buildSalesChart(sales, currency),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsSection(List<dynamic> sales, Currency currency) {
    // Calculate top products
    final Map<String, double> productSales = {};
    final Map<String, double> productCount = {};

    for (final sale in sales) {
      for (final item in sale.items) {
        final productName = item.product?.name ?? 'Unknown';
        // Calculate subtotal using current price: (price * qty) - discount
        final itemSubtotal = (item.price * item.qty) - (item.discount);
        productSales[productName] =
            (productSales[productName] ?? 0) + itemSubtotal;
        productCount[productName] = (productCount[productName] ?? 0) + item.qty;
      }
    }

    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Products',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            ...sortedProducts.take(5).map((entry) {
              final percentage = productSales.values.isNotEmpty
                  ? (entry.value /
                          productSales.values.reduce((a, b) => a + b)) *
                      100
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${currency.symbol}${entry.value.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerAnalysisSection(List<dynamic> sales, Currency currency) {
    final customerSales = <String, double>{};
    final customerCount = <String, int>{};

    for (final sale in sales) {
      final customerName = sale.customer?.name ?? 'Walk-in';
      customerSales[customerName] =
          (customerSales[customerName] ?? 0) + sale.total;
      customerCount[customerName] = (customerCount[customerName] ?? 0) + 1;
    }

    final totalCustomers = customerSales.length;
    final repeatCustomers =
        customerCount.values.where((count) => count > 1).length;
    final newCustomers = totalCustomers - repeatCustomers;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Analysis',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildHealthMetricCard(
                    'Total Customers',
                    totalCustomers.toString(),
                    Icons.people,
                    const Color(0xFF3B82F6),
                    'Active customers',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildHealthMetricCard(
                    'Repeat Customers',
                    repeatCustomers.toString(),
                    Icons.repeat,
                    const Color(0xFF10B981),
                    '${((repeatCustomers / totalCustomers) * 100).toStringAsFixed(1)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildHealthMetricCard(
              'New Customers',
              newCustomers.toString(),
              Icons.person_add,
              const Color(0xFF8B5CF6),
              'First-time buyers',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitSummaryCards(
    double totalSales,
    double totalCost,
    double grossProfit,
    double totalExpenses,
    double netProfit,
    double profitMargin,
    double grossMargin,
    Currency currency,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildModernMetricCard(
                'Gross Profit',
                '${currency.symbol}${grossProfit.toStringAsFixed(2)}',
                Icons.trending_up,
                const Color(0xFF10B981),
                '${grossMargin.toStringAsFixed(1)}% margin',
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernMetricCard(
                'Net Profit',
                '${currency.symbol}${netProfit.toStringAsFixed(2)}',
                Icons.account_balance_wallet,
                netProfit >= 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                '${profitMargin.toStringAsFixed(1)}% margin',
                netProfit >= 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModernMetricCard(
                'Total Cost',
                '${currency.symbol}${totalCost.toStringAsFixed(2)}',
                Icons.money_off,
                const Color(0xFFEF4444),
                'Product costs',
                const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernMetricCard(
                'Expenses',
                '${currency.symbol}${totalExpenses.toStringAsFixed(2)}',
                Icons.receipt_long,
                const Color(0xFFF59E0B),
                'Operating costs',
                const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfitTrendsChart(List<dynamic> sales, Currency currency) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profit Trends',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _buildProfitChart(sales, currency),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitChart(List<dynamic> sales, Currency currency) {
    if (sales.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 16),
            Text('No profit data available',
                style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    // Group sales by date and calculate profit
    final Map<String, double> dailyProfit = {};
    for (final sale in sales) {
      final dateKey = DateFormat('dd/MM').format(sale.date);
      final cost = sale.items.fold<double>(0.0, (double sum, item) {
        return sum + ((item.product?.cost ?? 0) * item.qty);
      });
      final profit = sale.total - cost;
      dailyProfit[dateKey] = (dailyProfit[dateKey] ?? 0) + profit;
    }

    final sortedDates = dailyProfit.keys.toList()..sort();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < sortedDates.length) {
                  return Text(
                    sortedDates[value.toInt()],
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${currency.symbol}${value.toInt()}',
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(sortedDates.length, (index) {
              final date = sortedDates[index];
              final profit = dailyProfit[date] ?? 0.0;
              return FlSpot(index.toDouble(), profit);
            }),
            isCurved: true,
            color: const Color(0xFF10B981),
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseBreakdownSection(dynamic expenseData, Currency currency) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expense Breakdown',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            _buildHealthMetricCard(
              'Total Expenses',
              '${currency.symbol}${expenseData.totalExpense.toStringAsFixed(2)}',
              Icons.money_off,
              const Color(0xFFEF4444),
              'Operating costs',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitByCategorySection(List<dynamic> sales, Currency currency) {
    final categoryProfit = <String, double>{};

    for (final sale in sales) {
      for (final item in sale.items) {
        final category = item.product?.category ?? 'Unknown';
        final cost = (item.product?.cost ?? 0) * item.qty;
        // Calculate subtotal using current price: (price * qty) - discount
        final itemSubtotal = (item.price * item.qty) - (item.discount);
        final profit = itemSubtotal - cost;
        categoryProfit[category] = (categoryProfit[category] ?? 0) + profit;
      }
    }

    final sortedCategories = categoryProfit.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profit by Category',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            ...sortedCategories.take(5).map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${currency.symbol}${entry.value.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: entry.value >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  String _getPeakHour(List<dynamic> sales) {
    final hourCount = <int, int>{};
    for (final sale in sales) {
      final hour = sale.date.hour;
      hourCount[hour] = (hourCount[hour] ?? 0) + 1;
    }

    if (hourCount.isEmpty) return 'N/A';

    final peakHour =
        hourCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return '${peakHour.toString().padLeft(2, '0')}:00';
  }

  // ==================== HELPER WIDGETS ====================
  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColoredMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Simple neutral metric box used in Daily Comprehensive report for total amounts
  Widget _buildMetricBox(String title, String value) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashSummaryPanel({
    required Currency currency,
    required double cashSale,
    required double recovery,
    required double total,
    required double expense,
    required double paymentToParty,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        children: [
          _buildCashSummaryRow(
              'Cash Sale', _formatCurrencyValue(currency, cashSale)),
          const SizedBox(height: 4),
          _buildCashSummaryRow(
              'Recovery', _formatCurrencyValue(currency, recovery)),
          const SizedBox(height: 12),
          const Divider(),
          _buildCashSummaryRow(
            'Total',
            _formatCurrencyValue(currency, total),
            emphasize: true,
          ),
          const Divider(),
          _buildCashSummaryRow(
            'Expense',
            _formatCurrencyValue(currency, expense),
            emphasize: true,
            valueColor: const Color(0xFFDC2626),
          ),
          const Divider(),
          _buildCashSummaryRow(
            'Payment to Party',
            _formatCurrencyValue(currency, paymentToParty),
            emphasize: true,
            valueColor: const Color(0xFFDC2626),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToPaymentDetail(),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: Text('misc.payment_detail'.tr()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashSummaryRow(
    String label,
    String value, {
    bool emphasize = false,
    Color valueColor = const Color(0xFF0F172A),
  }) {
    // Check if value is negative
    // NumberFormat formats negatives as "-123.45", and we add currency symbol: "$-123.45"
    final isNegative = value.contains('-');
    String displayValue = value;

    // Extract the minus sign and the rest of the value
    if (isNegative) {
      // Remove the minus sign from the string
      displayValue = value.replaceFirst('-', '');
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
            color: const Color(0xFF475569),
          ),
        ),
        isNegative
            ? RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '-',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: valueColor,
                      ),
                    ),
                    TextSpan(
                      text: displayValue,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: valueColor,
                      ),
                    ),
                  ],
                ),
              )
            : Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
      ],
    );
  }

  String _formatCurrencyValue(Currency currency, double amount) {
    final formatter = NumberFormat('#,##0.00');
    return '${currency.symbol}${formatter.format(amount)}';
  }

  Widget _buildPaymentTypeCard(
    String type,
    String amount,
    String count,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              type,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count transactions',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRowText(String label, String value,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==================== PAYMENT DETAIL ====================
  void _navigateToPaymentDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentDetailScreen(
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
    );
  }

  // ==================== DATE PICKER ====================
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

        // Invalidate providers to refresh data with new date range
        final startBoundary =
            DateTime(_startDate.year, _startDate.month, _startDate.day);
        final endBoundary = DateTime(
            _endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999);

        ref.invalidate(salesProvider);
        ref.invalidate(payment_provider.paymentsByDateRangeProvider(
          payment_provider.DateRange(start: startBoundary, end: endBoundary),
        ));
        ref.invalidate(_allSupplierPaymentsProvider(
          DateRangeFilter(start: startBoundary, end: endBoundary),
        ));
        ref.invalidate(bank_provider.bankPaymentsByDateRangeProvider(
          (start: startBoundary, end: endBoundary),
        ));
        ref.invalidate(expenseSummaryProvider(
          DateRangeFilter(start: startBoundary, end: endBoundary),
        ));
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

  // ==================== EXCEL EXPORT FUNCTIONS ====================
  Future<void> _exportItemListToExcel(
      List<dynamic> products, Currency currency) async {
    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Item List Report'];

      // Add headers
      sheetObject.appendRow([
        TextCellValue('Item Name'),
        TextCellValue('Category'),
        TextCellValue('Barcode'),
        TextCellValue('Stock'),
        TextCellValue('Unit'),
        TextCellValue('Cost Price'),
        TextCellValue('Sale Price'),
        TextCellValue('Total Value'),
      ]);

      // Add data
      for (var product in products) {
        final totalValue = product.stock * product.cost;
        sheetObject.appendRow([
          TextCellValue(product.name),
          TextCellValue(product.category),
          TextCellValue(product.barcode ?? 'N/A'),
          TextCellValue(product.stock.toStringAsFixed(2)),
          TextCellValue(product.unit),
          TextCellValue('${currency.symbol}${product.cost.toStringAsFixed(2)}'),
          TextCellValue(
              '${currency.symbol}${product.price.toStringAsFixed(2)}'),
          TextCellValue('${currency.symbol}${totalValue.toStringAsFixed(2)}'),
        ]);
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/ItemList_$timestamp.xlsx';
      final fileBytes = excel.save();
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      // Share file
      await Share.shareXFiles([XFile(filePath)], text: 'Item List Report');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Excel file exported successfully'),
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
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportLowStockToExcel(
      List<dynamic> products, Currency currency) async {
    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Low Stock Report'];

      sheetObject.appendRow([
        TextCellValue('Item Name'),
        TextCellValue('Category'),
        TextCellValue('Current Stock'),
        TextCellValue('Reorder Level'),
        TextCellValue('Status'),
        TextCellValue('Sale Price'),
        TextCellValue('Cost Price'),
      ]);

      for (var product in products) {
        final status = product.stock < 0 ? 'NEGATIVE' : 'LOW STOCK';
        sheetObject.appendRow([
          TextCellValue(product.name),
          TextCellValue(product.category),
          TextCellValue(product.stock.toStringAsFixed(2)),
          TextCellValue(product.reorderLevel.toStringAsFixed(2)),
          TextCellValue(status),
          TextCellValue(
              '${currency.symbol}${product.price.toStringAsFixed(2)}'),
          TextCellValue('${currency.symbol}${product.cost.toStringAsFixed(2)}'),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/LowStock_$timestamp.xlsx';
      final fileBytes = excel.save();
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(filePath)], text: 'Low Stock Report');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Excel file exported successfully'),
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
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportDayEndToExcel(
    List<dynamic> sales,
    List<PaymentModel> payments,
    double totalSales,
    double totalCost,
    double totalProfit,
    double totalDiscount,
    double cashSalesAmount,
    double cardSalesAmount,
    double creditSalesAmount,
    Currency currency,
  ) async {
    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Day End Report'];

      final totalPaymentsAmount =
          payments.fold<double>(0.0, (sum, p) => sum + p.amount);
      final cashPayments =
          payments.where((p) => p.paymentMethod == PaymentMethod.cash).toList();
      final cardPayments =
          payments.where((p) => p.paymentMethod == PaymentMethod.card).toList();
      final bankPayments = payments
          .where((p) => p.paymentMethod == PaymentMethod.bankTransfer)
          .toList();
      final chequePayments = payments
          .where((p) => p.paymentMethod == PaymentMethod.cheque)
          .toList();
      final cashPaymentsAmount =
          cashPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
      final cardPaymentsAmount =
          cardPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
      final bankPaymentsAmount =
          bankPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
      final chequePaymentsAmount =
          chequePayments.fold<double>(0.0, (sum, p) => sum + p.amount);

      // Summary
      sheetObject.appendRow([TextCellValue('Day End Report')]);
      sheetObject.appendRow([
        TextCellValue('Date Range'),
        TextCellValue(
            '${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}')
      ]);
      sheetObject.appendRow([]);
      sheetObject.appendRow([
        TextCellValue('Total Sales'),
        TextCellValue('${currency.symbol}${totalSales.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Total Cost'),
        TextCellValue('${currency.symbol}${totalCost.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Total Profit'),
        TextCellValue('${currency.symbol}${totalProfit.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Total Discount'),
        TextCellValue('${currency.symbol}${totalDiscount.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Total Payments Recorded'),
        TextCellValue(
            '${currency.symbol}${totalPaymentsAmount.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Payments Count'),
        TextCellValue(payments.length.toString())
      ]);
      sheetObject.appendRow([]);
      sheetObject.appendRow([TextCellValue('Payment Method Breakdown')]);
      sheetObject.appendRow([
        TextCellValue('Cash Sales'),
        TextCellValue('${currency.symbol}${cashSalesAmount.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Card Sales'),
        TextCellValue('${currency.symbol}${cardSalesAmount.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Credit Sales'),
        TextCellValue(
            '${currency.symbol}${creditSalesAmount.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Cash Payments'),
        TextCellValue(
            '${currency.symbol}${cashPaymentsAmount.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Card Payments'),
        TextCellValue(
            '${currency.symbol}${cardPaymentsAmount.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Bank Transfers'),
        TextCellValue(
            '${currency.symbol}${bankPaymentsAmount.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Cheque Payments'),
        TextCellValue(
            '${currency.symbol}${chequePaymentsAmount.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([]);

      // Details
      sheetObject.appendRow([
        TextCellValue('Sale ID'),
        TextCellValue('Date'),
        TextCellValue('Amount'),
        TextCellValue('Discount'),
        TextCellValue('Payment'),
        TextCellValue('Status'),
        TextCellValue('Cashier')
      ]);
      for (var sale in sales) {
        sheetObject.appendRow([
          TextCellValue('Sale #${sale.id}'),
          TextCellValue(DateFormat('dd/MM/yyyy hh:mm a').format(sale.date)),
          TextCellValue('${currency.symbol}${sale.total.toStringAsFixed(2)}'),
          TextCellValue(
              '${currency.symbol}${sale.discount.toStringAsFixed(2)}'),
          TextCellValue(sale.paymentType.toString().split('.').last),
          TextCellValue(sale.status.toString().split('.').last),
          TextCellValue(sale.cashier?.name ?? 'Unknown'),
        ]);
      }

      sheetObject.appendRow([]);
      sheetObject.appendRow([TextCellValue('Payments Recorded')]);
      sheetObject.appendRow([
        TextCellValue('Payment ID'),
        TextCellValue('Date'),
        TextCellValue('Customer'),
        TextCellValue('Amount'),
        TextCellValue('Method'),
        TextCellValue('Recorded By'),
      ]);
      for (final payment in payments) {
        sheetObject.appendRow([
          TextCellValue(payment.id != null ? 'PAY-${payment.id}' : 'N/A'),
          TextCellValue(DateFormat('dd/MM/yyyy hh:mm a').format(payment.date)),
          TextCellValue(payment.customer?.name ?? 'Unknown'),
          TextCellValue(
              '${currency.symbol}${payment.amount.toStringAsFixed(2)}'),
          TextCellValue(payment.paymentMethod.name.toUpperCase()),
          TextCellValue(payment.processedBy?.name ?? 'Unknown'),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/DayEnd_$timestamp.xlsx';
      final fileBytes = excel.save();
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(filePath)], text: 'Day End Report');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('Excel file exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPaymentReportToExcel(
    List<PaymentModel> cashPayments,
    List<PaymentModel> cardPayments,
    List<PaymentModel> bankPayments,
    List<PaymentModel> chequePayments,
    Currency currency,
  ) async {
    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();

      Sheet cashSheet = excel['Cash Payments'];
      cashSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Payment ID'),
        TextCellValue('Customer'),
        TextCellValue('Amount'),
        TextCellValue('Method'),
        TextCellValue('Recorded By'),
      ]);
      for (final payment in cashPayments) {
        cashSheet.appendRow([
          TextCellValue(DateFormat('dd/MM/yyyy hh:mm a').format(payment.date)),
          TextCellValue(payment.id != null ? 'PAY-${payment.id}' : 'N/A'),
          TextCellValue(payment.customer?.name ?? 'Unknown'),
          TextCellValue(
              '${currency.symbol}${payment.amount.toStringAsFixed(2)}'),
          TextCellValue(payment.paymentMethod.name.toUpperCase()),
          TextCellValue(payment.processedBy?.name ?? 'Unknown'),
        ]);
      }

      Sheet cardSheet = excel['Card Payments'];
      cardSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Payment ID'),
        TextCellValue('Customer'),
        TextCellValue('Amount'),
        TextCellValue('Method'),
        TextCellValue('Recorded By'),
      ]);
      for (final payment in cardPayments) {
        cardSheet.appendRow([
          TextCellValue(DateFormat('dd/MM/yyyy hh:mm a').format(payment.date)),
          TextCellValue(payment.id != null ? 'PAY-${payment.id}' : 'N/A'),
          TextCellValue(payment.customer?.name ?? 'Unknown'),
          TextCellValue(
              '${currency.symbol}${payment.amount.toStringAsFixed(2)}'),
          TextCellValue(payment.paymentMethod.name.toUpperCase()),
          TextCellValue(payment.processedBy?.name ?? 'Unknown'),
        ]);
      }

      Sheet bankSheet = excel['Bank Transfers'];
      bankSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Payment ID'),
        TextCellValue('Customer'),
        TextCellValue('Amount'),
        TextCellValue('Method'),
        TextCellValue('Recorded By'),
      ]);
      for (final payment in bankPayments) {
        bankSheet.appendRow([
          TextCellValue(DateFormat('dd/MM/yyyy hh:mm a').format(payment.date)),
          TextCellValue(payment.id != null ? 'PAY-${payment.id}' : 'N/A'),
          TextCellValue(payment.customer?.name ?? 'Unknown'),
          TextCellValue(
              '${currency.symbol}${payment.amount.toStringAsFixed(2)}'),
          TextCellValue(payment.paymentMethod.name.toUpperCase()),
          TextCellValue(payment.processedBy?.name ?? 'Unknown'),
        ]);
      }

      Sheet chequeSheet = excel['Cheque Payments'];
      chequeSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Payment ID'),
        TextCellValue('Customer'),
        TextCellValue('Amount'),
        TextCellValue('Method'),
        TextCellValue('Recorded By'),
      ]);
      for (final payment in chequePayments) {
        chequeSheet.appendRow([
          TextCellValue(DateFormat('dd/MM/yyyy hh:mm a').format(payment.date)),
          TextCellValue(payment.id != null ? 'PAY-${payment.id}' : 'N/A'),
          TextCellValue(payment.customer?.name ?? 'Unknown'),
          TextCellValue(
              '${currency.symbol}${payment.amount.toStringAsFixed(2)}'),
          TextCellValue(payment.paymentMethod.name.toUpperCase()),
          TextCellValue(payment.processedBy?.name ?? 'Unknown'),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/PaymentReport_$timestamp.xlsx';
      final fileBytes = excel.save();
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(filePath)], text: 'Payment Report');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('Excel file exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportStockMovementToExcel(
      List<StockMovementWithProduct> movements, Currency currency) async {
    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Stock Movement Report'];

      sheetObject.appendRow([
        TextCellValue('Date'),
        TextCellValue('Product'),
        TextCellValue('Quantity'),
        TextCellValue('Type'),
        TextCellValue('Reason'),
        TextCellValue('Reference')
      ]);

      for (final movementWithProduct in movements) {
        // Get product name
        final productName = movementWithProduct.product.name ?? 'Unknown';

        // Get date, quantity, reason, reference
        DateTime date;
        try {
          date = DateTime.parse(movementWithProduct.movement.date);
        } catch (e) {
          debugPrint('Error parsing date in Excel export: $e');
          date = DateTime.now();
        }

        final quantity = movementWithProduct.movement.quantity;
        final reason = movementWithProduct.movement.reason;
        final reference = movementWithProduct.movement.reference ?? 'N/A';

        sheetObject.appendRow([
          TextCellValue(DateFormat('dd/MM/yyyy hh:mm a').format(date)),
          TextCellValue(productName),
          TextCellValue(quantity.toStringAsFixed(2)),
          TextCellValue(quantity > 0 ? 'IN' : 'OUT'),
          TextCellValue(reason),
          TextCellValue(reference),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/StockMovement_$timestamp.xlsx';
      final fileBytes = excel.save();
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(filePath)], text: 'Stock Movement Report');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('Excel file exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // ==================== PDF EXPORT FUNCTIONS ====================
  Future<void> _exportItemListToPDF(
      List<dynamic> products, Currency currency) async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Item List Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: [
                'Item Name',
                'Category',
                'Stock',
                'Unit',
                'Cost',
                'Sale Price'
              ],
              data: products
                  .map((p) => [
                        p.name,
                        p.category,
                        p.stock.toStringAsFixed(2),
                        p.unit,
                        '${currency.symbol}${p.cost.toStringAsFixed(2)}',
                        '${currency.symbol}${p.price.toStringAsFixed(2)}',
                      ])
                  .toList(),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename:
              'ItemList_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('PDF exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportLowStockToPDF(
      List<dynamic> products, Currency currency) async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Low Stock Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Item', 'Category', 'Stock', 'Reorder Level', 'Status'],
              data: products
                  .map((p) => [
                        p.name,
                        p.category,
                        p.stock.toStringAsFixed(2),
                        p.reorderLevel.toStringAsFixed(2),
                        p.stock < 0 ? 'NEGATIVE' : 'LOW',
                      ])
                  .toList(),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename:
              'LowStock_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('PDF exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportDayEndToPDF(
    List<dynamic> sales,
    List<PaymentModel> payments,
    double totalSales,
    double totalCost,
    double totalProfit,
    double totalDiscount,
    double cashSalesAmount,
    double cardSalesAmount,
    double creditSalesAmount,
    Currency currency,
  ) async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      final totalPaymentsAmount =
          payments.fold<double>(0.0, (sum, p) => sum + p.amount);
      final cashPayments =
          payments.where((p) => p.paymentMethod == PaymentMethod.cash).toList();
      final cardPayments =
          payments.where((p) => p.paymentMethod == PaymentMethod.card).toList();
      final bankPayments = payments
          .where((p) => p.paymentMethod == PaymentMethod.bankTransfer)
          .toList();
      final chequePayments = payments
          .where((p) => p.paymentMethod == PaymentMethod.cheque)
          .toList();
      final cashPaymentsAmount =
          cashPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
      final cardPaymentsAmount =
          cardPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
      final bankPaymentsAmount =
          bankPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
      final chequePaymentsAmount =
          chequePayments.fold<double>(0.0, (sum, p) => sum + p.amount);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Day End Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text(
                'Period: ${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
            pw.SizedBox(height: 20),
            pw.Text(
                'Total Sales: ${currency.symbol}${totalSales.toStringAsFixed(2)}',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Total Cost: ${currency.symbol}${totalCost.toStringAsFixed(2)}'),
            pw.Text(
                'Total Profit: ${currency.symbol}${totalProfit.toStringAsFixed(2)}',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green)),
            pw.Text(
                'Total Discount: ${currency.symbol}${totalDiscount.toStringAsFixed(2)}'),
            pw.SizedBox(height: 10),
            pw.Text('Payment Method Breakdown:',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Cash Sales: ${currency.symbol}${cashSalesAmount.toStringAsFixed(2)}'),
            pw.Text(
                'Card Sales: ${currency.symbol}${cardSalesAmount.toStringAsFixed(2)}'),
            pw.Text(
                'Credit Sales: ${currency.symbol}${creditSalesAmount.toStringAsFixed(2)}'),
            pw.SizedBox(height: 10),
            pw.Text('Customer Payments Recorded:',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Total Payments: ${currency.symbol}${totalPaymentsAmount.toStringAsFixed(2)} (${payments.length} transactions)'),
            pw.Text(
                'Cash Payments: ${currency.symbol}${cashPaymentsAmount.toStringAsFixed(2)} (${cashPayments.length})'),
            pw.Text(
                'Card Payments: ${currency.symbol}${cardPaymentsAmount.toStringAsFixed(2)} (${cardPayments.length})'),
            pw.Text(
                'Bank Transfers: ${currency.symbol}${bankPaymentsAmount.toStringAsFixed(2)} (${bankPayments.length})'),
            pw.Text(
                'Cheques: ${currency.symbol}${chequePaymentsAmount.toStringAsFixed(2)} (${chequePayments.length})'),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Sale ID', 'Date', 'Amount', 'Payment', 'Cashier'],
              data: sales
                  .take(50)
                  .map((s) => [
                        'Sale #${s.id}',
                        DateFormat('dd/MM/yyyy').format(s.date),
                        '${currency.symbol}${s.total.toStringAsFixed(2)}',
                        s.paymentType.toString().split('.').last,
                        s.cashier?.name ?? 'Unknown',
                      ])
                  .toList(),
            ),
            if (payments.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Payment ID',
                  'Date',
                  'Customer',
                  'Amount',
                  'Method',
                  'Recorded By'
                ],
                data: payments
                    .take(50)
                    .map((p) => [
                          p.id != null ? 'PAY-${p.id}' : 'N/A',
                          DateFormat('dd/MM/yyyy').format(p.date),
                          p.customer?.name ?? 'Unknown',
                          '${currency.symbol}${p.amount.toStringAsFixed(2)}',
                          p.paymentMethod.name.toUpperCase(),
                          p.processedBy?.name ?? 'Unknown',
                        ])
                    .toList(),
              ),
            ],
          ],
        ),
      );

      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename:
              'DayEnd_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('PDF exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPaymentReportToPDF(
    List<PaymentModel> cashPayments,
    List<PaymentModel> cardPayments,
    List<PaymentModel> bankPayments,
    List<PaymentModel> chequePayments,
    Currency currency,
  ) async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      final cashTotal =
          cashPayments.fold<double>(0.0, (double sum, p) => sum + p.amount);
      final cardTotal =
          cardPayments.fold<double>(0.0, (double sum, p) => sum + p.amount);
      final bankTotal =
          bankPayments.fold<double>(0.0, (double sum, p) => sum + p.amount);
      final chequeTotal =
          chequePayments.fold<double>(0.0, (double sum, p) => sum + p.amount);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Payment Detail Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text(
                'Period: ${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
            pw.SizedBox(height: 20),
            pw.Text(
                'Cash: ${currency.symbol}${cashTotal.toStringAsFixed(2)} (${cashPayments.length} transactions)'),
            pw.Text(
                'Card: ${currency.symbol}${cardTotal.toStringAsFixed(2)} (${cardPayments.length} transactions)'),
            pw.Text(
                'Bank Transfer: ${currency.symbol}${bankTotal.toStringAsFixed(2)} (${bankPayments.length} transactions)'),
            pw.Text(
                'Cheque: ${currency.symbol}${chequeTotal.toStringAsFixed(2)} (${chequePayments.length} transactions)'),
            pw.SizedBox(height: 20),
            pw.Text(
                'Total: ${currency.symbol}${(cashTotal + cardTotal + bankTotal + chequeTotal).toStringAsFixed(2)}',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            if (cashPayments.isNotEmpty ||
                cardPayments.isNotEmpty ||
                bankPayments.isNotEmpty ||
                chequePayments.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Payment ID',
                  'Date',
                  'Customer',
                  'Amount',
                  'Method',
                  'Recorded By'
                ],
                data: [
                  ...cashPayments,
                  ...cardPayments,
                  ...bankPayments,
                  ...chequePayments,
                ].take(100).map((payment) {
                  return [
                    payment.id != null ? 'PAY-${payment.id}' : 'N/A',
                    DateFormat('dd/MM/yyyy').format(payment.date),
                    payment.customer?.name ?? 'Unknown',
                    '${currency.symbol}${payment.amount.toStringAsFixed(2)}',
                    payment.paymentMethod.name.toUpperCase(),
                    payment.processedBy?.name ?? 'Unknown',
                  ];
                }).toList(),
              ),
            ],
          ],
        ),
      );

      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename:
              'PaymentReport_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('PDF exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // ==================== CASH REPORT EXPORT ====================
  Future<void> _exportCashReportToExcel(
    List<dynamic> cashSales,
    Map<String, List<dynamic>> salesByDate,
    List<MapEntry<int, Map<String, dynamic>>> topProducts,
    Currency currency,
  ) async {
    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();

      // Cash Sales Sheet
      Sheet cashSheet = excel['Cash Sales'];
      cashSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Sale ID'),
        TextCellValue('Customer'),
        TextCellValue('Amount'),
        TextCellValue('Discount'),
        TextCellValue('Profit'),
        TextCellValue('Cashier'),
      ]);

      for (var sale in cashSales) {
        final saleCost = sale.items.fold<double>(
            0.0, (sum, item) => sum + ((item.product?.cost ?? 0) * item.qty));
        final saleProfit = sale.total - saleCost - sale.discount;

        cashSheet.appendRow([
          TextCellValue(DateFormat('dd/MM/yyyy hh:mm a').format(sale.date)),
          TextCellValue('Sale #${sale.id}'),
          TextCellValue(sale.customer?.name ?? 'Walk-in'),
          TextCellValue('${currency.symbol}${sale.total.toStringAsFixed(2)}'),
          TextCellValue(
              '${currency.symbol}${sale.discount.toStringAsFixed(2)}'),
          TextCellValue('${currency.symbol}${saleProfit.toStringAsFixed(2)}'),
          TextCellValue(sale.cashier?.name ?? 'Unknown'),
        ]);
      }

      // Daily Summary Sheet
      Sheet dailySheet = excel['Daily Summary'];
      dailySheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Transactions'),
        TextCellValue('Total Amount'),
      ]);

      final sortedDates = salesByDate.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));

      for (var entry in sortedDates) {
        final date = DateTime.parse(entry.key);
        final daySales = entry.value;
        final dayTotal = daySales.fold<double>(0.0, (sum, s) => sum + s.total);
        dailySheet.appendRow([
          TextCellValue(DateFormat('dd/MM/yyyy').format(date)),
          TextCellValue(daySales.length.toString()),
          TextCellValue('${currency.symbol}${dayTotal.toStringAsFixed(2)}'),
        ]);
      }

      // Top Products Sheet
      Sheet productsSheet = excel['Top Products'];
      productsSheet.appendRow([
        TextCellValue('Rank'),
        TextCellValue('Product Name'),
        TextCellValue('Quantity'),
        TextCellValue('Revenue'),
      ]);

      for (var entry in topProducts) {
        final productData = entry.value;
        productsSheet.appendRow([
          TextCellValue('${topProducts.indexOf(entry) + 1}'),
          TextCellValue(productData['name'] as String),
          TextCellValue(QuantityFormatter.withUnit(
              productData['quantity'] as double,
              productData['unit'] as String?)),
          TextCellValue(
              '${currency.symbol}${(productData['revenue'] as double).toStringAsFixed(2)}'),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/CashReport_$timestamp.xlsx';
      final fileBytes = excel.save();
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(filePath)], text: 'Cash Report');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('Excel file exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportCashReportToPDF(
    List<dynamic> cashSales,
    Map<String, List<dynamic>> salesByDate,
    List<MapEntry<int, Map<String, dynamic>>> topProducts,
    Currency currency,
    double totalCashSales,
    double totalCashProfit,
    int totalTransactions,
  ) async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('CASH SALES REPORT',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
                'Period: ${DateFormat('dd MMM yyyy').format(_startDate)} to ${DateFormat('dd MMM yyyy').format(_endDate)}'),
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Summary',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Cash Sales:'),
                      pw.Text(
                        '${currency.symbol}${totalCashSales.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Cash Profit:'),
                      pw.Text(
                        '${currency.symbol}${totalCashProfit.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Transactions:'),
                      pw.Text(
                        totalTransactions.toString(),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Daily Breakdown
            pw.Text('Daily Breakdown',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Transactions', 'Amount'],
              data: (() {
                final sorted = salesByDate.entries.toList()
                  ..sort((a, b) => b.key.compareTo(a.key));
                return sorted.take(15).map((entry) {
                  final date = DateTime.parse(entry.key);
                  final daySales = entry.value;
                  final dayTotal =
                      daySales.fold<double>(0.0, (sum, s) => sum + s.total);
                  return [
                    DateFormat('dd MMM yyyy').format(date),
                    daySales.length.toString(),
                    '${currency.symbol}${dayTotal.toStringAsFixed(2)}',
                  ];
                }).toList();
              })(),
            ),
            pw.SizedBox(height: 20),

            // Top Products
            pw.Text('Top Products (Cash Sales)',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Rank', 'Product', 'Quantity', 'Revenue'],
              data: topProducts.take(10).map((entry) {
                final productData = entry.value;
                return [
                  '${topProducts.indexOf(entry) + 1}',
                  productData['name'] as String,
                  QuantityFormatter.withUnit(productData['quantity'] as double,
                      productData['unit'] as String?),
                  '${currency.symbol}${(productData['revenue'] as double).toStringAsFixed(2)}',
                ];
              }).toList(),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename:
              'CashReport_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('PDF exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportStockMovementToPDF(
      List<StockMovementWithProduct> movements, Currency currency) async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Stock Movement Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text(
                'Period: ${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Product', 'Quantity', 'Type', 'Reason'],
              data: movements.map((movementWithProduct) {
                // Get product name
                final productName =
                    movementWithProduct.product.name ?? 'Unknown';

                // Get date, quantity, reason
                DateTime date;
                try {
                  date = DateTime.parse(movementWithProduct.movement.date);
                } catch (e) {
                  debugPrint('Error parsing date in PDF export: $e');
                  date = DateTime.now();
                }

                final quantity = movementWithProduct.movement.quantity;
                final reason = movementWithProduct.movement.reason;

                return [
                  DateFormat('dd/MM/yyyy').format(date),
                  productName,
                  quantity.toStringAsFixed(2),
                  quantity > 0 ? 'IN' : 'OUT',
                  reason,
                ];
              }).toList(),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename:
              'StockMovement_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('PDF exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // ==================== NEW EXPORT FUNCTIONS ====================
  Future<void> _exportOverviewToExcel(
    List<dynamic> sales,
    List<dynamic> products,
    double totalSales,
    double totalProfit,
    double netProfit,
    double totalExpenses,
    Currency currency,
  ) async {
    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Business Overview'];

      // Summary section
      sheetObject.appendRow([TextCellValue('Business Overview Report')]);
      sheetObject.appendRow([
        TextCellValue('Date Range'),
        TextCellValue(
            '${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}')
      ]);
      sheetObject.appendRow([]);
      sheetObject.appendRow([
        TextCellValue('Total Sales'),
        TextCellValue('${currency.symbol}${totalSales.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Gross Profit'),
        TextCellValue('${currency.symbol}${totalProfit.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Net Profit'),
        TextCellValue('${currency.symbol}${netProfit.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Total Expenses'),
        TextCellValue('${currency.symbol}${totalExpenses.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Total Products'),
        TextCellValue(products.length.toString())
      ]);
      sheetObject.appendRow([
        TextCellValue('Total Transactions'),
        TextCellValue(sales.length.toString())
      ]);
      sheetObject.appendRow([]);

      // Sales details
      sheetObject.appendRow([
        TextCellValue('Sale ID'),
        TextCellValue('Date'),
        TextCellValue('Amount'),
        TextCellValue('Payment Type'),
        TextCellValue('Cashier')
      ]);
      for (var sale in sales.take(100)) {
        sheetObject.appendRow([
          TextCellValue('Sale #${sale.id}'),
          TextCellValue(DateFormat('dd/MM/yyyy hh:mm a').format(sale.date)),
          TextCellValue('${currency.symbol}${sale.total.toStringAsFixed(2)}'),
          TextCellValue(sale.paymentType.toString().split('.').last),
          TextCellValue(sale.cashier?.name ?? 'Unknown'),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/BusinessOverview_$timestamp.xlsx';
      final fileBytes = excel.save();
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(filePath)],
          text: 'Business Overview Report');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('Excel file exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportOverviewToPDF(
    List<dynamic> sales,
    List<dynamic> products,
    double totalSales,
    double totalProfit,
    double netProfit,
    double totalExpenses,
    Currency currency,
  ) async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Business Overview Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text(
                'Period: ${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
            pw.SizedBox(height: 20),
            pw.Text(
                'Total Sales: ${currency.symbol}${totalSales.toStringAsFixed(2)}',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Gross Profit: ${currency.symbol}${totalProfit.toStringAsFixed(2)}'),
            pw.Text(
                'Net Profit: ${currency.symbol}${netProfit.toStringAsFixed(2)}',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: netProfit >= 0 ? PdfColors.green : PdfColors.red)),
            pw.Text(
                'Total Expenses: ${currency.symbol}${totalExpenses.toStringAsFixed(2)}'),
            pw.Text('Total Products: ${products.length}'),
            pw.Text('Total Transactions: ${sales.length}'),
            pw.SizedBox(height: 20),
            pw.Text('Recent Sales:',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.TableHelper.fromTextArray(
              headers: ['Sale ID', 'Date', 'Amount', 'Payment'],
              data: sales
                  .take(20)
                  .map((s) => [
                        'Sale #${s.id}',
                        DateFormat('dd/MM/yyyy').format(s.date),
                        '${currency.symbol}${s.total.toStringAsFixed(2)}',
                        s.paymentType.toString().split('.').last,
                      ])
                  .toList(),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename:
              'BusinessOverview_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('PDF exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportSalesAnalyticsToExcel(
      List<dynamic> sales, Currency currency) async {
    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sales Analytics'];

      // Calculate analytics
      final totalSales =
          sales.fold<double>(0.0, (double sum, s) => sum + s.total);
      final avgTransactionValue =
          sales.isNotEmpty ? totalSales / sales.length : 0.0;

      // Top products analysis
      final Map<String, double> productSales = {};
      for (final sale in sales) {
        for (final item in sale.items) {
          final productName = item.product?.name ?? 'Unknown';
          // Calculate subtotal using current price: (price * qty) - discount
          final itemSubtotal = (item.price * item.qty) - (item.discount);
          productSales[productName] =
              (productSales[productName] ?? 0) + itemSubtotal;
        }
      }

      final sortedProducts = productSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Summary
      sheetObject.appendRow([TextCellValue('Sales Analytics Report')]);
      sheetObject.appendRow([
        TextCellValue('Date Range'),
        TextCellValue(
            '${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}')
      ]);
      sheetObject.appendRow([]);
      sheetObject.appendRow([
        TextCellValue('Total Revenue'),
        TextCellValue('${currency.symbol}${totalSales.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Total Transactions'),
        TextCellValue(sales.length.toString())
      ]);
      sheetObject.appendRow([
        TextCellValue('Average Transaction Value'),
        TextCellValue(
            '${currency.symbol}${avgTransactionValue.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([]);

      // Top products
      sheetObject.appendRow([TextCellValue('Top Products Analysis')]);
      sheetObject.appendRow([
        TextCellValue('Product Name'),
        TextCellValue('Revenue'),
        TextCellValue('Percentage')
      ]);
      for (var entry in sortedProducts.take(10)) {
        final percentage = productSales.values.isNotEmpty
            ? (entry.value / productSales.values.reduce((a, b) => a + b)) * 100
            : 0.0;
        sheetObject.appendRow([
          TextCellValue(entry.key),
          TextCellValue('${currency.symbol}${entry.value.toStringAsFixed(2)}'),
          TextCellValue('${percentage.toStringAsFixed(1)}%'),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/SalesAnalytics_$timestamp.xlsx';
      final fileBytes = excel.save();
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(filePath)],
          text: 'Sales Analytics Report');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('Excel file exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportSalesAnalyticsToPDF(
      List<dynamic> sales, Currency currency) async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      final totalSales =
          sales.fold<double>(0.0, (double sum, s) => sum + s.total);
      final avgTransactionValue =
          sales.isNotEmpty ? totalSales / sales.length : 0.0;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Sales Analytics Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text(
                'Period: ${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
            pw.SizedBox(height: 20),
            pw.Text(
                'Total Revenue: ${currency.symbol}${totalSales.toStringAsFixed(2)}',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Total Transactions: ${sales.length}'),
            pw.Text(
                'Average Transaction Value: ${currency.symbol}${avgTransactionValue.toStringAsFixed(2)}'),
            pw.SizedBox(height: 20),
            pw.Text('Sales Summary:',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.TableHelper.fromTextArray(
              headers: ['Sale ID', 'Date', 'Amount', 'Payment Type'],
              data: sales
                  .take(30)
                  .map((s) => [
                        'Sale #${s.id}',
                        DateFormat('dd/MM/yyyy').format(s.date),
                        '${currency.symbol}${s.total.toStringAsFixed(2)}',
                        s.paymentType.toString().split('.').last,
                      ])
                  .toList(),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename:
              'SalesAnalytics_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('PDF exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportProfitAnalysisToExcel(
    List<dynamic> sales,
    double totalSales,
    double totalCost,
    double grossProfit,
    double totalExpenses,
    double netProfit,
    Currency currency,
  ) async {
    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Profit Analysis'];

      final profitMargin =
          totalSales > 0 ? (netProfit / totalSales) * 100 : 0.0;
      final grossMargin =
          totalSales > 0 ? (grossProfit / totalSales) * 100 : 0.0;

      // Summary
      sheetObject.appendRow([TextCellValue('Profit Analysis Report')]);
      sheetObject.appendRow([
        TextCellValue('Date Range'),
        TextCellValue(
            '${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}')
      ]);
      sheetObject.appendRow([]);
      sheetObject.appendRow([
        TextCellValue('Total Sales'),
        TextCellValue('${currency.symbol}${totalSales.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Total Cost'),
        TextCellValue('${currency.symbol}${totalCost.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Gross Profit'),
        TextCellValue('${currency.symbol}${grossProfit.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Total Expenses'),
        TextCellValue('${currency.symbol}${totalExpenses.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Net Profit'),
        TextCellValue('${currency.symbol}${netProfit.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Gross Margin'),
        TextCellValue('${grossMargin.toStringAsFixed(2)}%')
      ]);
      sheetObject.appendRow([
        TextCellValue('Net Margin'),
        TextCellValue('${profitMargin.toStringAsFixed(2)}%')
      ]);
      sheetObject.appendRow([]);

      // Profit by product category
      final categoryProfit = <String, double>{};
      for (final sale in sales) {
        for (final item in sale.items) {
          final category = item.product?.category ?? 'Unknown';
          final cost = (item.product?.cost ?? 0) * item.qty;
          // Calculate subtotal using current price: (price * qty) - discount
          final itemSubtotal = (item.price * item.qty) - (item.discount);
          final profit = itemSubtotal - cost;
          categoryProfit[category] = (categoryProfit[category] ?? 0) + profit;
        }
      }

      final sortedCategories = categoryProfit.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      sheetObject.appendRow([TextCellValue('Profit by Category')]);
      sheetObject.appendRow([
        TextCellValue('Category'),
        TextCellValue('Profit'),
        TextCellValue('Percentage')
      ]);
      for (var entry in sortedCategories.take(10)) {
        final percentage = categoryProfit.values.isNotEmpty
            ? (entry.value / categoryProfit.values.reduce((a, b) => a + b)) *
                100
            : 0.0;
        sheetObject.appendRow([
          TextCellValue(entry.key),
          TextCellValue('${currency.symbol}${entry.value.toStringAsFixed(2)}'),
          TextCellValue('${percentage.toStringAsFixed(1)}%'),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/ProfitAnalysis_$timestamp.xlsx';
      final fileBytes = excel.save();
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(filePath)],
          text: 'Profit Analysis Report');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('Excel file exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportProfitAnalysisToPDF(
    List<dynamic> sales,
    double totalSales,
    double totalCost,
    double grossProfit,
    double totalExpenses,
    double netProfit,
    Currency currency,
  ) async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      final profitMargin =
          totalSales > 0 ? (netProfit / totalSales) * 100 : 0.0;
      final grossMargin =
          totalSales > 0 ? (grossProfit / totalSales) * 100 : 0.0;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Profit Analysis Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text(
                'Period: ${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
            pw.SizedBox(height: 20),
            pw.Text(
                'Total Sales: ${currency.symbol}${totalSales.toStringAsFixed(2)}',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Total Cost: ${currency.symbol}${totalCost.toStringAsFixed(2)}'),
            pw.Text(
                'Gross Profit: ${currency.symbol}${grossProfit.toStringAsFixed(2)}',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green)),
            pw.Text(
                'Total Expenses: ${currency.symbol}${totalExpenses.toStringAsFixed(2)}'),
            pw.Text(
                'Net Profit: ${currency.symbol}${netProfit.toStringAsFixed(2)}',
                style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: netProfit >= 0 ? PdfColors.green : PdfColors.red)),
            pw.Text('Gross Margin: ${grossMargin.toStringAsFixed(2)}%'),
            pw.Text('Net Margin: ${profitMargin.toStringAsFixed(2)}%',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename:
              'ProfitAnalysis_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('PDF exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportMonthlyReportToExcel(
    List<dynamic> sales,
    List<dynamic> products,
    Currency currency,
    double totalSales,
    double totalProfit,
    double netProfit,
    int totalTransactions,
    Map<String, double> dailyBreakdown,
    List<MapEntry<String, double>> topProducts,
    double cashTotal,
    double cardTotal,
    double creditTotal,
  ) async {
    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Monthly Report'];

      // Header
      sheetObject.appendRow([
        TextCellValue(
            'Monthly Report - ${DateFormat('MMMM yyyy').format(_startDate)}')
      ]);
      sheetObject.appendRow([]);

      // Summary
      sheetObject.appendRow([TextCellValue('Summary')]);
      sheetObject.appendRow([
        TextCellValue('Total Sales'),
        TextCellValue('${currency.symbol}${totalSales.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Gross Profit'),
        TextCellValue('${currency.symbol}${totalProfit.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Net Profit'),
        TextCellValue('${currency.symbol}${netProfit.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Total Transactions'),
        TextCellValue(totalTransactions.toString())
      ]);
      sheetObject.appendRow([]);

      // Payment Methods
      sheetObject.appendRow([TextCellValue('Payment Methods')]);
      sheetObject.appendRow([
        TextCellValue('Cash'),
        TextCellValue('${currency.symbol}${cashTotal.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Card'),
        TextCellValue('${currency.symbol}${cardTotal.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([
        TextCellValue('Credit'),
        TextCellValue('${currency.symbol}${creditTotal.toStringAsFixed(2)}')
      ]);
      sheetObject.appendRow([]);

      // Top Products
      sheetObject.appendRow([TextCellValue('Top Products')]);
      sheetObject.appendRow([TextCellValue('Product'), TextCellValue('Sales')]);
      for (var product in topProducts.take(10)) {
        sheetObject.appendRow([
          TextCellValue(product.key),
          TextCellValue(
              '${currency.symbol}${product.value.toStringAsFixed(2)}'),
        ]);
      }
      sheetObject.appendRow([]);

      // Daily Breakdown
      sheetObject.appendRow([TextCellValue('Daily Sales Breakdown')]);
      sheetObject.appendRow([TextCellValue('Day'), TextCellValue('Sales')]);
      final sortedDays = dailyBreakdown.entries.toList()
        ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
      for (var entry in sortedDays) {
        sheetObject.appendRow([
          TextCellValue(entry.key),
          TextCellValue('${currency.symbol}${entry.value.toStringAsFixed(2)}'),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/MonthlyReport_$timestamp.xlsx';
      final fileBytes = excel.save();
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(filePath)], text: 'Monthly Report');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('Excel file exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportMonthlyReportToPDF(
    List<dynamic> sales,
    List<dynamic> products,
    Currency currency,
    double totalSales,
    double totalProfit,
    double netProfit,
    int totalTransactions,
    Map<String, double> dailyBreakdown,
    List<MapEntry<String, double>> topProducts,
    double cashTotal,
    double cardTotal,
    double creditTotal,
  ) async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                  'Monthly Report - ${DateFormat('MMMM yyyy').format(_startDate)}',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),

            // Summary
            pw.Text('Summary',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text(
                'Total Sales: ${currency.symbol}${totalSales.toStringAsFixed(2)}',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Gross Profit: ${currency.symbol}${totalProfit.toStringAsFixed(2)}'),
            pw.Text(
                'Net Profit: ${currency.symbol}${netProfit.toStringAsFixed(2)}',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: netProfit >= 0 ? PdfColors.green : PdfColors.red)),
            pw.Text('Total Transactions: $totalTransactions'),
            pw.SizedBox(height: 20),

            // Payment Methods
            pw.Text('Payment Methods',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Cash: ${currency.symbol}${cashTotal.toStringAsFixed(2)}'),
            pw.Text('Card: ${currency.symbol}${cardTotal.toStringAsFixed(2)}'),
            pw.Text(
                'Credit: ${currency.symbol}${creditTotal.toStringAsFixed(2)}'),
            pw.SizedBox(height: 20),

            // Top Products
            pw.Text('Top Products',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              children: [
                pw.TableRow(
                  children: [
                    pw.Text('Product',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Sales',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                ...topProducts.take(10).map((product) => pw.TableRow(
                      children: [
                        pw.Text(product.key),
                        pw.Text(
                            '${currency.symbol}${product.value.toStringAsFixed(2)}'),
                      ],
                    )),
              ],
            ),
          ],
        ),
      );

      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename:
              'MonthlyReport_${DateFormat('yyyyMM').format(_startDate)}.pdf');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('PDF exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // ==================== CUSTOM TABLE WIDGET ====================
  Widget _buildCustomTable({
    required List<String> headers,
    required List<List<String>> rows,
    double? maxHeight,
    Function(int)? onRowTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: headers
                  .map((header) => Expanded(
                        child: Text(
                          header,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF374151),
                            fontSize: 12,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Table Body
          maxHeight != null
              ? SizedBox(
                  height: maxHeight,
                  child: _buildTableBody(rows, onRowTap),
                )
              : Expanded(
                  child: _buildTableBody(rows, onRowTap),
                ),
        ],
      ),
    );
  }

  Widget _buildTableBody(List<List<String>> rows, Function(int)? onRowTap) {
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final isEven = index % 2 == 0;

        Widget rowWidget = Container(
          decoration: BoxDecoration(
            color: isEven ? Colors.white : const Color(0xFFF9FAFB),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFFE5E7EB),
                width: 0.5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: row
                  .map((cell) => Expanded(
                        child: Text(
                          cell,
                          style: const TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
            ),
          ),
        );

        if (onRowTap != null) {
          return InkWell(
            onTap: () => onRowTap(index),
            child: rowWidget,
          );
        }

        return rowWidget;
      },
    );
  }

  void _showSaleDetails(
      BuildContext context, SaleModel sale, Currency currency) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sale #${sale.id} Details'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Customer', sale.customer?.name ?? 'Walk-in'),
                _buildDetailRow('Cashier', sale.cashier?.name ?? 'Unknown'),
                _buildDetailRow(
                    'Date', DateFormat('dd/MM/yyyy hh:mm a').format(sale.date)),
                _buildDetailRow('Status',
                    sale.status.toString().split('.').last.toUpperCase()),
                _buildDetailRow('Payment Type',
                    sale.paymentType.toString().split('.').last.toUpperCase()),
                _buildDetailRow(
                    'Type', sale.isWholesale ? 'Wholesale' : 'Retail'),
                if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow('Remarks', sale.notes!,
                      valueColor: const Color(0xFF64748B)),
                ],
                if (sale.profit != null) ...[
                  _buildDetailRow('Profit',
                      '${currency.symbol}${sale.profit!.toStringAsFixed(2)}'),
                  if (sale.profitMargin != null)
                    _buildDetailRow('Profit Margin',
                        '${sale.profitMargin!.toStringAsFixed(1)}%'),
                ],
                if (sale.paymentType == PaymentType.credit) ...[
                  _buildDetailRow('Total',
                      '${currency.symbol}${sale.total.toStringAsFixed(2)}'),
                  _buildDetailRow('Paid',
                      '${currency.symbol}${sale.paid.toStringAsFixed(2)}'),
                  _buildDetailRow('Due',
                      '${currency.symbol}${sale.due.toStringAsFixed(2)}'),
                ],
                const Divider(),
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...sale.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.product?.name ?? 'Unknown Product'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Qty: ${item.qty} × ${currency.symbol}${item.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (item.discount > 0)
                                  Text(
                                    'Discount: ${currency.symbol}${item.discount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${currency.symbol}${((item.price * item.qty) - item.discount).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('reports.subtotal'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        '${currency.symbol}${(sale.total + sale.discount).toStringAsFixed(2)}'),
                  ],
                ),
                if (sale.discount > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('reports.discount'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                          '-${currency.symbol}${sale.discount.toStringAsFixed(2)}'),
                    ],
                  ),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('reports.total'.tr(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      '${currency.symbol}${sale.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
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

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueColor != null
                  ? TextStyle(color: valueColor, fontWeight: FontWeight.w500)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(Object error, [VoidCallback? onRetry]) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              'Error: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text('common.retry'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== EXPENSE REPORT ====================
  Widget _buildExpenseReport() {
    final currency = ref.watch(currentCurrencyProvider);
    final expenseHeadsAsync = ref.watch(expenseHeadNotifierProvider);
    final expenseAsync = ref.watch(expenseNotifierProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final double expenseTableHeight = math.max(
      320.0,
      math.min(screenHeight * 0.45, 520.0),
    );

    return Column(
      children: [
        _buildDatePicker(),
        _buildExpenseFilterControls(expenseHeadsAsync, currency),
        Expanded(
          child: expenseAsync.when(
            data: (expenses) {
              final filteredExpenses = _applyExpenseFilters(expenses);
              final totalExpense = filteredExpenses.fold<double>(
                  0, (sum, exp) => sum + exp.amount);
              final averageExpense = filteredExpenses.isEmpty
                  ? 0
                  : totalExpense / filteredExpenses.length;

              final categoryExpenses = <String, double>{};
              final paymentMethodExpenses = <String, double>{};
              final employeeExpenses = <String, double>{};

              for (final expense in filteredExpenses) {
                categoryExpenses[expense.category] =
                    (categoryExpenses[expense.category] ?? 0) + expense.amount;
                paymentMethodExpenses[expense.paymentMethod] =
                    (paymentMethodExpenses[expense.paymentMethod] ?? 0) +
                        expense.amount;
                if (expense.createdBy != null &&
                    expense.createdBy!.isNotEmpty) {
                  employeeExpenses[expense.createdBy!] =
                      (employeeExpenses[expense.createdBy!] ?? 0) +
                          expense.amount;
                }
              }

              final sortedCategories = categoryExpenses.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final topEmployees = employeeExpenses.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return Column(
                children: [
                  _buildExpenseExportBar(filteredExpenses, currency),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredExpenses.isEmpty
                        ? _buildEmptyState(
                            'No expenses found for selected filters')
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricCard(
                                        'Total Expenses',
                                        '${currency.symbol}${totalExpense.toStringAsFixed(2)}',
                                        Icons.money_off,
                                        Colors.red,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildMetricCard(
                                        'Count',
                                        filteredExpenses.length.toString(),
                                        Icons.receipt_long,
                                        Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricCard(
                                        'Avg per Expense',
                                        '${currency.symbol}${averageExpense.toStringAsFixed(2)}',
                                        Icons.calculate,
                                        Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildMetricCard(
                                        'Categories',
                                        categoryExpenses.length.toString(),
                                        Icons.category,
                                        Colors.purple,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _buildSectionTitle('Expenses by Category'),
                                const SizedBox(height: 12),
                                Card(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: sortedCategories.length,
                                    itemBuilder: (context, index) {
                                      final entry = sortedCategories[index];
                                      final percentage = totalExpense == 0
                                          ? 0
                                          : (entry.value / totalExpense) * 100;
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.red.shade100,
                                          child: Icon(Icons.category,
                                              color: Colors.red.shade700),
                                        ),
                                        title: Text(entry.key),
                                        subtitle: Text(
                                            '${percentage.toStringAsFixed(1)}%'),
                                        trailing: Text(
                                          '${currency.symbol}${entry.value.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildSectionTitle(
                                    'Expenses by Payment Method'),
                                const SizedBox(height: 12),
                                Card(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: paymentMethodExpenses.length,
                                    itemBuilder: (context, index) {
                                      final entry = paymentMethodExpenses
                                          .entries
                                          .toList()[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.blue.shade100,
                                          child: Icon(Icons.payment,
                                              color: Colors.blue.shade700),
                                        ),
                                        title: Text(entry.key),
                                        trailing: Text(
                                          '${currency.symbol}${entry.value.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildSectionTitle(
                                    'Top Employees / Created By'),
                                const SizedBox(height: 12),
                                Card(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: topEmployees.length,
                                    itemBuilder: (context, index) {
                                      final entry = topEmployees[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              Colors.green.shade100,
                                          child: Icon(Icons.person,
                                              color: Colors.green.shade700),
                                        ),
                                        title: Text(entry.key),
                                        trailing: Text(
                                          '${currency.symbol}${entry.value.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildSectionTitle('Expense Details'),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: expenseTableHeight,
                                  child: _buildCustomTable(
                                    headers: const [
                                      'Date',
                                      'Title',
                                      'Category',
                                      'Amount',
                                      'Created By'
                                    ],
                                    rows: filteredExpenses.map((exp) {
                                      return [
                                        DateFormat('dd/MM/yyyy')
                                            .format(exp.date),
                                        exp.title,
                                        exp.category,
                                        '${currency.symbol}${exp.amount.toStringAsFixed(2)}',
                                        exp.createdBy ?? 'N/A',
                                      ];
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _buildErrorWidget(error),
          ),
        ),
      ],
    );
  }

  void _exportExpenseToExcel(
      List<ExpenseModel> expenses, Currency currency) async {
    if (expenses.isEmpty) return;
    setState(() => _isExporting = true);

    try {
      final totalExpenses =
          expenses.fold<double>(0, (sum, e) => sum + e.amount);
      final excel = Excel.createExcel();
      final sheet = excel['Expense Report'];
      sheet.appendRow([TextCellValue('Expense Report')]);
      sheet.appendRow([
        TextCellValue(
            'Period: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}')
      ]);
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue('Total Expenses'),
        TextCellValue('${currency.symbol}${totalExpenses.toStringAsFixed(2)}')
      ]);
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Title'),
        TextCellValue('Category'),
        TextCellValue('Amount'),
        TextCellValue('Created By'),
      ]);

      for (final exp in expenses) {
        sheet.appendRow([
          TextCellValue(DateFormat('dd/MM/yyyy').format(exp.date)),
          TextCellValue(exp.title),
          TextCellValue(exp.category),
          TextCellValue('${currency.symbol}${exp.amount.toStringAsFixed(2)}'),
          TextCellValue(exp.createdBy ?? 'N/A'),
        ]);
      }

      final fileName =
          'expense_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Expense Report');
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
                content: Text('Expense report exported'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
              content: Text('Error exporting: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportExpenseToPDF(
      List<ExpenseModel> expenses, Currency currency) async {
    if (expenses.isEmpty) return;
    setState(() => _isExporting = true);

    try {
      final totalExpense =
          expenses.fold<double>(0, (sum, exp) => sum + exp.amount);
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'EXPENSE REPORT',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Period: ${DateFormat('dd MMM yyyy').format(_startDate)} to ${DateFormat('dd MMM yyyy').format(_endDate)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Date',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Title',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Category',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Amount',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Employee',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...expenses.map(
                  (e) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(DateFormat('dd/MM/yyyy').format(e.date),
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(e.title,
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(e.category,
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '${currency.symbol}${e.amount.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(e.createdBy ?? 'N/A',
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Expenses:',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '${currency.symbol}${totalExpense.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/expense_report_$timestamp.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Expense Report');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
              content: Text('Expense report exported'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
              content: Text('Error exporting: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Widget _buildWholesaleReport() {
    final salesAsync = ref.watch(salesProvider);
    final currency = ref.watch(currentCurrencyProvider);

    return Column(
      children: [
        // Date Picker
        _buildDatePicker(),
        // Export Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: _isExporting
                    ? null
                    : () async {
                        salesAsync.whenData((sales) {
                          _exportWholesaleToPDF(sales, currency);
                        });
                      },
                tooltip: 'Export to PDF',
              ),
            ],
          ),
        ),
        Expanded(
          child: salesAsync.when(
            data: (sales) {
              // Filter wholesale sales
              final wholesaleSales =
                  sales.where((sale) => sale.isWholesale).toList();

              // Filter by date range
              final filteredSales = wholesaleSales.where((sale) {
                return sale.date.isAfter(
                        _startDate.subtract(const Duration(days: 1))) &&
                    sale.date.isBefore(_endDate.add(const Duration(days: 1)));
              }).toList();

              if (filteredSales.isEmpty) {
                return _buildEmptyState(
                    'No wholesale sales found for selected period');
              }

              // Calculate metrics
              final totalWholesaleSales =
                  filteredSales.fold<double>(0.0, (sum, s) => sum + s.total);
              final totalTransactions = filteredSales.length;
              final avgTransactionValue =
                  totalWholesaleSales / totalTransactions;

              // Sales by payment type
              final cashSales = filteredSales
                  .where((s) => s.paymentType.name == 'cash')
                  .fold<double>(0.0, (sum, s) => sum + s.total);
              final creditSales = filteredSales
                  .where((s) => s.paymentType.name == 'credit')
                  .fold<double>(0.0, (sum, s) => sum + s.total);
              final cardSales = filteredSales
                  .where((s) => s.paymentType.name == 'card')
                  .fold<double>(0.0, (sum, s) => sum + s.total);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Total Wholesale Sales',
                            '${currency.symbol}${totalWholesaleSales.toStringAsFixed(2)}',
                            Icons.store,
                            const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Total Transactions',
                            totalTransactions.toString(),
                            Icons.receipt_long,
                            const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Avg Transaction Value',
                            '${currency.symbol}${avgTransactionValue.toStringAsFixed(2)}',
                            Icons.calculate,
                            const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Sales by Payment Type
                    _buildSectionTitle('Sales by Payment Type'),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF10B981)
                                  .withValues(alpha: 0.1),
                              child: const Icon(Icons.money,
                                  color: Color(0xFF10B981)),
                            ),
                            title: Text('reports.cash_sales'.tr()),
                            trailing: Text(
                              '${currency.symbol}${cashSales.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF3B82F6)
                                  .withValues(alpha: 0.1),
                              child: const Icon(Icons.credit_card,
                                  color: Color(0xFF3B82F6)),
                            ),
                            title: Text('reports.card_sales'.tr()),
                            trailing: Text(
                              '${currency.symbol}${cardSales.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.1),
                              child: const Icon(Icons.receipt_long,
                                  color: Color(0xFFF59E0B)),
                            ),
                            title: Text('reports.credit_sales'.tr()),
                            trailing: Text(
                              '${currency.symbol}${creditSales.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Recent Wholesale Sales
                    _buildSectionTitle('Recent Wholesale Sales'),
                    const SizedBox(height: 12),
                    Card(
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredSales.take(10).length,
                        itemBuilder: (context, index) {
                          final sale = filteredSales[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF10B981)
                                  .withValues(alpha: 0.1),
                              child: const Icon(Icons.store,
                                  color: Color(0xFF10B981)),
                            ),
                            title: Text('Sale #${sale.id}'),
                            subtitle: Text(
                              '${sale.customer?.name ?? 'Walk-in'} • ${DateFormat('dd/MM/yyyy').format(sale.date)}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${currency.symbol}${sale.total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  sale.paymentType.name.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }

  Future<void> _exportWholesaleToPDF(
      List<dynamic> sales, Currency currency) async {
    setState(() => _isExporting = true);

    try {
      final wholesaleSales = sales.where((sale) => sale.isWholesale).toList();
      final filteredSales = wholesaleSales.where((sale) {
        return sale.date
                .isAfter(_startDate.subtract(const Duration(days: 1))) &&
            sale.date.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      if (filteredSales.isEmpty) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('No wholesale sales to export'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final totalWholesaleSales =
          filteredSales.fold<double>(0.0, (sum, s) => sum + s.total);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'WHOLESALE SALES REPORT',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Period: ${DateFormat('dd MMM yyyy').format(_startDate)} to ${DateFormat('dd MMM yyyy').format(_endDate)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Summary',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Wholesale Sales:'),
                      pw.Text(
                        '${currency.symbol}${totalWholesaleSales.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Transactions:'),
                      pw.Text(
                        filteredSales.length.toString(),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Avg Transaction Value:'),
                      pw.Text(
                        '${currency.symbol}${(totalWholesaleSales / filteredSales.length).toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Sales table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Date',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Sale #',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Customer',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Payment',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Total',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                ...filteredSales.map((s) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            DateFormat('dd/MM/yyyy').format(s.date),
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            s.id.toString(),
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            s.customer?.name ?? 'Walk-in',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            s.paymentType.name.toUpperCase(),
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${currency.symbol}${s.total.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 10),
                            textAlign: pw.TextAlign.right,
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
                border: pw.Border.all(color: PdfColors.black),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Grand Total:',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '${currency.symbol}${totalWholesaleSales.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/wholesale_report_$timestamp.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)],
          text: 'Wholesale Sales Report');

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Wholesale report exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // ==================== ITEM-WISE SALES REPORT ====================
  Widget _buildItemWiseSalesReport() {
    return const ItemWiseSalesReportScreen();
  }
}
