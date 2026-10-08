import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../providers/sale_provider.dart' as sale_provider;
import '../providers/payment_provider.dart' as payment_provider;
import '../providers/supplier_provider.dart';
import '../providers/supplier_payment_provider.dart';
import '../providers/currency_provider.dart';
import '../models/sale.dart';
import '../models/payment.dart';
import '../models/currency.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import '../services/database_service.dart';

class CashbookReportScreen extends ConsumerStatefulWidget {
  const CashbookReportScreen({super.key});

  @override
  ConsumerState<CashbookReportScreen> createState() =>
      _CashbookReportScreenState();
}

class _CashbookReportScreenState extends ConsumerState<CashbookReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

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
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null && mounted) {
                  setState(() => _startDate = picked);
                }
              },
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
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null && mounted) {
                  setState(() => _endDate = picked);
                }
              },
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
    final currency = ref.watch(currentCurrencyProvider);
    final salesAsync = ref.watch(sale_provider.salesByDateRangeProvider(
      sale_provider.DateRange(
          start: _startDate, end: _endDate.add(const Duration(days: 1))),
    ));
    final paymentsAsync =
        ref.watch(payment_provider.paymentsByDateRangeProvider(
      payment_provider.DateRange(
          start: _startDate, end: _endDate.add(const Duration(days: 1))),
    ));
    final supplierPaymentsAsync =
        ref.watch(allSupplierPaymentsByDateRangeProvider((
      start: _startDate,
      end: _endDate.add(const Duration(days: 1)),
    )));

    return Scaffold(
      appBar: AppBar(
        title: Text('misc.cashbook'.tr()),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _buildDatePicker(),
          Expanded(
            child: salesAsync.when(
              data: (sales) => paymentsAsync.when(
                data: (payments) => supplierPaymentsAsync.when(
                  data: (supplierPayments) => _buildCashbookContent(
                    sales,
                    payments,
                    supplierPayments,
                    currency,
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashbookContent(
    List<SaleModel> sales,
    List<PaymentModel> payments,
    List<SupplierPaymentModel> supplierPayments,
    Currency currency,
  ) {
    // Filter cash transactions (sales are already filtered by date range)
    final cashSales = sales.where((sale) {
      return sale.paymentType.toString().toLowerCase().contains('cash');
    }).toList();

    // Payments are already filtered by date range
    final cashPayments = payments.where((payment) {
      return payment.paymentMethod.toString().toLowerCase().contains('cash');
    }).toList();

    // Supplier cash payments (party payment via cash) within date range
    final supplierCashPayments = supplierPayments.where((sp) {
      return sp.paymentMethod == 'cash';
    }).toList();

    final supplierCashIn = supplierCashPayments
        .where((sp) => sp.amount < 0)
        .fold<double>(0.0, (sum, sp) => sum + sp.amount.abs());
    final supplierCashOut = supplierCashPayments
        .where((sp) => sp.amount >= 0)
        .fold<double>(0.0, (sum, sp) => sum + sp.amount);

    // Calculate totals
    final totalCashIn = cashSales.fold<double>(0.0, (sum, s) => sum + s.total) +
        cashPayments.fold<double>(
            0.0, (sum, p) => sum + (p.amount > 0 ? p.amount : 0)) +
        supplierCashIn;
    final totalCashOut = supplierCashOut +
        cashPayments.fold<double>(
            0.0, (sum, p) => sum + (p.amount < 0 ? p.amount.abs() : 0));

    // Combine transactions
    final transactions = <CashTransaction>[];

    // Add sales (cash in)
    for (final sale in cashSales) {
      transactions.add(CashTransaction(
        date: sale.date,
        description: 'Cash Sale - ${sale.customer?.name ?? 'Walk-in'}',
        type: TransactionType.cashIn,
        amount: sale.total,
        reference: 'SINVO-${sale.id}',
        enteredBy: sale.cashier?.name ?? 'Unknown',
      ));
    }

    // Add customer payments: positive = cash in; negative (balance addition) = cash out
    for (final payment in cashPayments) {
      if (payment.amount >= 0) {
        transactions.add(CashTransaction(
          date: payment.date,
          description: 'Cash Payment - Customer',
          type: TransactionType.cashIn,
          amount: payment.amount,
          reference: 'PAY-${payment.id}',
          enteredBy: payment.processedBy?.name ?? 'Unknown',
        ));
      } else {
        transactions.add(CashTransaction(
          date: payment.date,
          description: 'Balance Addition - Customer',
          type: TransactionType.cashOut,
          amount: payment.amount.abs(),
          reference: 'PAY-${payment.id}',
          enteredBy: payment.processedBy?.name ?? 'Unknown',
        ));
      }
    }

    // Add supplier cash payments as cash out (party payment)
    for (final sp in supplierCashPayments) {
      final isRefund = sp.amount < 0;
      transactions.add(CashTransaction(
        date: sp.date,
        description: isRefund
            ? 'Supplier Refund - Cash'
            : 'Party Payment - Supplier',
        type: isRefund ? TransactionType.cashIn : TransactionType.cashOut,
        amount: sp.amount.abs(),
        reference: 'SPAY-${sp.id}',
        enteredBy: null,
      ));
    }

    // Sort by date
    transactions.sort((a, b) => b.date.compareTo(a.date));

    final netCash = totalCashIn - totalCashOut;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Cash In',
                  '${currency.symbol}${totalCashIn.toStringAsFixed(2)}',
                  Colors.green,
                  Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Cash Out',
                  '${currency.symbol}${totalCashOut.toStringAsFixed(2)}',
                  Colors.red,
                  Icons.arrow_upward,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            'Net Cash Flow',
            '${currency.symbol}${netCash.toStringAsFixed(2)}',
            netCash >= 0 ? Colors.blue : Colors.orange,
            Icons.account_balance,
          ),
          const SizedBox(height: 24),

          // Transactions List
          Text(
            'Cash Transactions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          if (transactions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No cash transactions found for selected date range',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            )
          else
            ...transactions.map(
                (transaction) => _buildTransactionCard(transaction, currency)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String amount, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(CashTransaction transaction, Currency currency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: transaction.type == TransactionType.cashIn
              ? Colors.green.shade100
              : Colors.red.shade100,
          child: Icon(
            transaction.type == TransactionType.cashIn
                ? Icons.arrow_downward
                : Icons.arrow_upward,
            color: transaction.type == TransactionType.cashIn
                ? Colors.green
                : Colors.red,
          ),
        ),
        title: Text(transaction.description),
        subtitle: Text(
          '${DateFormat('dd MMM yyyy hh:mm a').format(transaction.date)}\n${transaction.reference}'
          '${transaction.enteredBy != null ? '\nEntered by: ${transaction.enteredBy}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '${transaction.type == TransactionType.cashIn ? '+' : '-'}${currency.symbol}${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: transaction.type == TransactionType.cashIn
                ? Colors.green
                : Colors.red,
          ),
        ),
      ),
    );
  }
}

class CashTransaction {
  final DateTime date;
  final String description;
  final TransactionType type;
  final double amount;
  final String reference;
  final String? enteredBy;

  CashTransaction({
    required this.date,
    required this.description,
    required this.type,
    required this.amount,
    required this.reference,
    this.enteredBy,
  });
}

enum TransactionType {
  cashIn,
  cashOut,
}
