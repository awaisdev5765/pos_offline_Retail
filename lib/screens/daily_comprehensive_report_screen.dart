import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/payment_provider.dart' as payment_provider;
import '../providers/supplier_payment_provider.dart';
import '../models/sale.dart';
import '../models/payment.dart';
import '../models/supplier_payment.dart';

class DailyComprehensiveReportScreen extends ConsumerStatefulWidget {
  const DailyComprehensiveReportScreen({super.key});

  @override
  ConsumerState<DailyComprehensiveReportScreen> createState() =>
      _DailyComprehensiveReportScreenState();
}

class _DailyComprehensiveReportScreenState
    extends ConsumerState<DailyComprehensiveReportScreen> {
  DateTime _from =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _to = DateTime(DateTime.now().year, DateTime.now().month,
      DateTime.now().day, 23, 59, 59, 999);

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final currentUser = auth.currentUser;
    final isAdmin = currentUser?.isAdmin == true;
    final isManager = currentUser?.isManager == true;

    if (!(isAdmin || isManager)) {
      return const Scaffold(
        body: Center(child: Text('Access denied')),
      );
    }

    final currency = ref.watch(currentCurrencyProvider);
    final salesAsync =
        ref.watch(salesByDateRangeProvider(DateRange(start: _from, end: _to)));
    final paymentsAsync = ref.watch(
        payment_provider.paymentsByDateRangeProvider(
            payment_provider.DateRange(start: _from, end: _to)));
    final supplierPaymentsAsync = ref.watch(
        allSupplierPaymentsByDateRangeProvider((start: _from, end: _to)));

    return Scaffold(
      appBar: AppBar(
        title: Text('misc.daily_comprehensive'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFilters(),
            const SizedBox(height: 12),
            Expanded(
              child: salesAsync.when(
                data: (sales) {
                  return paymentsAsync.when(
                    data: (customerPayments) {
                      return supplierPaymentsAsync.when(
                        data: (supplierPays) {
                          final grouped = _groupByCashier(sales);
                          return _buildTable(grouped, customerPayments,
                              supplierPays, currency.symbol,
                              showProfit: isAdmin);
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Center(child: Text('Error: $e')),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _from,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _from = DateTime(picked.year, picked.month, picked.day);
                  if (_to.isBefore(_from)) {
                    _to = DateTime(
                        picked.year, picked.month, picked.day, 23, 59, 59, 999);
                  }
                });
              }
            },
            child: _dateField('From', _from),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _to,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _to = DateTime(
                      picked.year, picked.month, picked.day, 23, 59, 59, 999);
                });
              }
            },
            child: _dateField('To', _to),
          ),
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18, color: Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          Text('$label: ${DateFormat('dd/MM/yyyy').format(date)}'),
        ],
      ),
    );
  }

  Map<int, List<SaleModel>> _groupByCashier(List<SaleModel> sales) {
    final map = <int, List<SaleModel>>{};
    for (final s in sales) {
      final id = s.cashierId ?? -1;
      map.putIfAbsent(id, () => []);
      map[id]!.add(s);
    }
    return map;
  }

  Widget _buildTable(
    Map<int, List<SaleModel>> byUser,
    List<PaymentModel> customerPayments,
    List<SupplierPaymentModel> supplierPayments,
    String symbol, {
    required bool showProfit,
  }) {
    // Header columns
    final headers = <String>[
      'User',
      'Retail Cash',
      if (showProfit) 'Cash Profit',
      'Retail Credit',
      if (showProfit) 'Credit Profit',
      'Stock Movement',
      if (showProfit) 'SM Profit',
      'Wholesale Cash',
      if (showProfit) 'W.Cash Profit',
      'Wholesale Credit',
      if (showProfit) 'W.Credit Profit',
      'Credit Cash Received',
      'Party Cash Payment',
      if (showProfit) 'Total Sale',
      if (showProfit) 'Total Profit',
    ];

    final rows = <TableRow>[];
    rows.add(_headerRow(headers));

    double totalSale = 0, totalProfit = 0;
    double totalReceived = 0, totalPartyPay = 0;

    byUser.forEach((userId, sales) {
      final userName = sales.first.cashier?.name ??
          (userId == -1 ? 'Unknown' : 'User $userId');
      // Partition sales by type
      double retailCash = 0, retailCredit = 0, sm = 0, wCash = 0, wCredit = 0;
      double pRetailCash = 0,
          pRetailCredit = 0,
          pSm = 0,
          pWcash = 0,
          pWcredit = 0;

      for (final s in sales) {
        final saleTotal = s.total;
        final saleCost = s.items.fold<double>(
            0.0, (sum, i) => sum + ((i.product?.cost ?? 0) * i.qty));
        final profit = saleTotal - saleCost;
        switch (s.paymentType) {
          case PaymentType.cash:
            retailCash += saleTotal;
            pRetailCash += profit;
            break;
          case PaymentType.credit:
            retailCredit += saleTotal;
            pRetailCredit += profit;
            break;
          case PaymentType.card:
            // Treat card as cash for this summary
            retailCash += saleTotal;
            pRetailCash += profit;
            break;
        }
        // Stock movement and wholesale flags are not explicit in model; placeholder kept zero unless business rules exist
      }

      // Credit cash received by user
      final receivedByUser = customerPayments
          .where((p) =>
              p.processedByEmployeeId == userId &&
              p.paymentMethod == PaymentMethod.cash &&
              (p.amount > 0))
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      // Party cash payment by user (supplier payments with 'cash' have no user ID in current model; sum overall)
      final partyCashByUser = supplierPayments
          .where((sp) => sp.paymentMethod == 'cash')
          .fold<double>(0.0, (sum, sp) => sum + sp.amount);

      totalSale += retailCash + retailCredit + sm + wCash + wCredit;
      totalProfit += pRetailCash + pRetailCredit + pSm + pWcash + pWcredit;
      totalReceived += receivedByUser;
      totalPartyPay += partyCashByUser;

      rows.add(_dataRow([
        userName,
        '$symbol${retailCash.toStringAsFixed(2)}',
        if (showProfit) '$symbol${pRetailCash.toStringAsFixed(2)}',
        '$symbol${retailCredit.toStringAsFixed(2)}',
        if (showProfit) '$symbol${pRetailCredit.toStringAsFixed(2)}',
        '$symbol${sm.toStringAsFixed(2)}',
        if (showProfit) '$symbol${pSm.toStringAsFixed(2)}',
        '$symbol${wCash.toStringAsFixed(2)}',
        if (showProfit) '$symbol${pWcash.toStringAsFixed(2)}',
        '$symbol${wCredit.toStringAsFixed(2)}',
        if (showProfit) '$symbol${pWcredit.toStringAsFixed(2)}',
        '$symbol${receivedByUser.toStringAsFixed(2)}',
        '$symbol${partyCashByUser.toStringAsFixed(2)}',
        if (showProfit)
          '$symbol${(retailCash + retailCredit + sm + wCash + wCredit).toStringAsFixed(2)}',
        if (showProfit)
          '$symbol${(pRetailCash + pRetailCredit + pSm + pWcash + pWcredit).toStringAsFixed(2)}',
      ], showProfit: showProfit));
    });

    // Total row
    rows.add(_totalRow([
      'Total',
      '$symbol${_fmt(totalSale)}',
      if (showProfit) '$symbol${_fmt(totalProfit)}',
      // Keep placeholders aligned with headers
      '', if (showProfit) '', '', if (showProfit) '', '', if (showProfit) '',
      '',
      '$symbol${_fmt(totalReceived)}',
      '$symbol${_fmt(totalPartyPay)}',
      if (showProfit) '$symbol${_fmt(totalSale)}',
      if (showProfit) '$symbol${_fmt(totalProfit)}',
    ], showProfit: showProfit));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {},
          children: rows,
        ),
      ),
    );
  }

  TableRow _headerRow(List<String> headers) {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
      children: headers.map((h) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            h,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF1F2937)),
          ),
        );
      }).toList(),
    );
  }

  TableRow _dataRow(List<String> cells, {required bool showProfit}) {
    return TableRow(
      decoration: const BoxDecoration(color: Colors.white),
      children: cells.map((c) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            c,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF111827)),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  TableRow _totalRow(List<String> cells, {required bool showProfit}) {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
      children: cells.map((c) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            c,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Color(0xFF111827)),
          ),
        );
      }).toList(),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2);
}
