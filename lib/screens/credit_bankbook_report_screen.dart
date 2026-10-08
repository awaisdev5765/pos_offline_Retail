import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../providers/sale_provider.dart' as sale_provider;
import '../providers/payment_provider.dart' as payment_provider;
import '../providers/supplier_provider.dart';
import '../providers/bank_provider.dart';
import '../providers/currency_provider.dart';
import '../models/sale.dart';
import '../models/payment.dart';
import '../models/currency.dart';
import '../models/bank.dart';
import '../services/database_service.dart';

class CreditBankBookReportScreen extends ConsumerStatefulWidget {
  const CreditBankBookReportScreen({super.key});

  @override
  ConsumerState<CreditBankBookReportScreen> createState() =>
      _CreditBankBookReportScreenState();
}

class _CreditBankBookReportScreenState
    extends ConsumerState<CreditBankBookReportScreen> {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('common.date_range_to'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final banksAsync = ref.watch(banksProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('misc.credit_bank_book_title'.tr()),
        backgroundColor: const Color(0xFF8B5CF6),
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
                data: (payments) => banksAsync.when(
                  data: (banks) => _buildCreditBankContent(
                    sales,
                    payments,
                    banks,
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

  Widget _buildCreditBankContent(
    List<SaleModel> sales,
    List<PaymentModel> payments,
    List<BankModel> banks,
    Currency currency,
  ) {
    // Filter credit and bank transactions (sales are already filtered by date range)
    final creditSales = sales.where((sale) {
      return sale.paymentType.toString().toLowerCase().contains('credit');
    }).toList();

    final bankSales = sales.where((sale) {
      return sale.paymentType.toString().toLowerCase().contains('card') ||
          sale.paymentType.toString().toLowerCase().contains('bank');
    }).toList();

    // Payments are already filtered by date range
    final bankPayments = payments.where((payment) {
      return payment.paymentMethod.toString().toLowerCase().contains('bank') ||
          payment.paymentMethod.toString().toLowerCase().contains('transfer') ||
          payment.paymentMethod.toString().toLowerCase().contains('card') ||
          payment.paymentMethod.toString().toLowerCase().contains('cheque');
    }).toList();

    // Get bank transactions - we'll load them asynchronously
    final databaseService = ref.read(databaseServiceProvider);

    // Calculate totals
    final totalCredit =
        creditSales.fold<double>(0.0, (sum, s) => sum + s.total);
    final totalBankSales =
        bankSales.fold<double>(0.0, (sum, s) => sum + s.total);
    final totalBankPayments =
        bankPayments.fold<double>(0.0, (sum, p) => sum + p.amount);

    // Combine transactions
    final transactions = <BankTransaction>[];

    // Add credit sales
    for (final sale in creditSales) {
      transactions.add(BankTransaction(
        date: sale.date,
        description: 'Credit Sale - ${sale.customer?.name ?? 'Walk-in'}',
        type: TransactionType.credit,
        amount: sale.total,
        reference: 'SINVO-${sale.id}',
        bankName: 'Credit',
        enteredBy: sale.cashier?.name ?? 'Unknown',
      ));
    }

    // Add bank sales
    for (final sale in bankSales) {
      transactions.add(BankTransaction(
        date: sale.date,
        description: 'Bank/Card Sale - ${sale.customer?.name ?? 'Walk-in'}',
        type: TransactionType.credit,
        amount: sale.total,
        reference: 'SINVO-${sale.id}',
        bankName: 'Bank',
        enteredBy: sale.cashier?.name ?? 'Unknown',
      ));
    }

    // Add bank payments
    for (final payment in bankPayments) {
      transactions.add(BankTransaction(
        date: payment.date,
        description: 'Bank Payment - Customer',
        type: TransactionType.credit,
        amount: payment.amount,
        reference: 'PAY-${payment.id}',
        bankName: 'Bank',
        enteredBy: payment.processedBy?.name ?? 'Unknown',
      ));
    }

    // Note: Bank transactions would be added here if needed
    // For now, we focus on credit sales and bank/card payments

    // Sort by date
    transactions.sort((a, b) => b.date.compareTo(a.date));

    final totalCreditAmount = totalCredit + totalBankSales + totalBankPayments;

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
                  'Credit Sales',
                  '${currency.symbol}${totalCredit.toStringAsFixed(2)}',
                  Colors.blue,
                  Icons.credit_card,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Bank Sales',
                  '${currency.symbol}${totalBankSales.toStringAsFixed(2)}',
                  Colors.purple,
                  Icons.account_balance,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            'Total Credit/Bank',
            '${currency.symbol}${totalCreditAmount.toStringAsFixed(2)}',
            Colors.indigo,
            Icons.book,
          ),
          const SizedBox(height: 24),

          // Transactions List
          Text(
            'Credit/Bank Transactions',
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
                    'No credit/bank transactions found for selected date range',
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

  Widget _buildTransactionCard(BankTransaction transaction, Currency currency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: transaction.type == TransactionType.credit
              ? Colors.blue.shade100
              : Colors.red.shade100,
          child: Icon(
            transaction.type == TransactionType.credit
                ? Icons.arrow_downward
                : Icons.arrow_upward,
            color: transaction.type == TransactionType.credit
                ? Colors.blue
                : Colors.red,
          ),
        ),
        title: Text(transaction.description),
        subtitle: Text(
          '${DateFormat('dd MMM yyyy hh:mm a').format(transaction.date)}\n${transaction.reference} - ${transaction.bankName}'
          '${transaction.enteredBy != null ? '\nEntered by: ${transaction.enteredBy}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '${currency.symbol}${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: transaction.type == TransactionType.credit
                ? Colors.blue
                : Colors.red,
          ),
        ),
      ),
    );
  }
}

class BankTransaction {
  final DateTime date;
  final String description;
  final TransactionType type;
  final double amount;
  final String reference;
  final String bankName;
  final String? enteredBy;

  BankTransaction({
    required this.date,
    required this.description,
    required this.type,
    required this.amount,
    required this.reference,
    required this.bankName,
    this.enteredBy,
  });
}

enum TransactionType {
  credit,
  debit,
}
