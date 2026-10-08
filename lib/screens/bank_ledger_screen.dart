import 'dart:async';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/bank_provider.dart';
import '../providers/currency_provider.dart';
import '../services/database_service.dart';
import '../models/currency.dart';
import '../models/bank.dart';
import '../models/bank_payment.dart';
import '../services/bulk_import_service.dart';
import '../utils/modern_dialog_builder.dart';
import '../utils/navigation_helper.dart';
import '../widgets/app_snack_bar.dart';

class BankLedgerScreen extends ConsumerStatefulWidget {
  final int bankId;

  const BankLedgerScreen({super.key, required this.bankId});

  @override
  ConsumerState<BankLedgerScreen> createState() => _BankLedgerScreenState();
}

class _BankLedgerScreenState extends ConsumerState<BankLedgerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  DateTime _startDate = DateTime(2020);
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

      ref.invalidate(bankByIdProvider(widget.bankId));
      ref.invalidate(bankPaymentsProvider(widget.bankId));

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _handleImportLedger() async {
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
            context: context, message: 'Importing bank payments...');
      }

      final databaseService = ref.read(databaseServiceProvider);
      final result = await BulkImportService.importBankLedgerFromExcel(
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
    final bankAsync = ref.watch(bankByIdProvider(widget.bankId));
    final paymentsAsync = ref.watch(bankPaymentsProvider(widget.bankId));
    final currency = ref.watch(currentCurrencyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFE8F4FD),
      appBar: AppBar(
        title: Text('ledger.bank'.tr()),
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
              context.go('/banking-system');
            }
          },
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            onPressed: _handleImportLedger,
            icon: const Icon(Icons.upload_file, color: Colors.white),
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
          Builder(
            builder: (context) {
              final bank = bankAsync.valueOrNull;
              if (bank != null) {
                return IconButton(
                  icon: const Icon(Icons.description),
                  onPressed: () =>
                      _generateLedgerReport(bank, currency, paymentsAsync),
                  tooltip: 'Generate Ledger Report',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          bankAsync.when(
            data: (bank) => _buildLedgerContent(bank, paymentsAsync, currency),
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

  Widget _buildLedgerContent(BankModel? bank,
      AsyncValue<List<BankPaymentModel>> paymentsAsync, Currency currency) {
    if (bank == null) {
      return const Center(
        child: Text('Bank not found'),
      );
    }

    return Column(
      children: [
        _buildProfessionalBankInfo(bank, currency, paymentsAsync),
        Expanded(
          child: _buildTransactionsList(paymentsAsync, currency),
        ),
      ],
    );
  }

  Widget _buildProfessionalBankInfo(BankModel bank, Currency currency,
      AsyncValue<List<BankPaymentModel>> paymentsAsync) {
    return Container(
      color: const Color(0xFF4A90E2),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoField('Bank Name:', bank.name, Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoField('Account Number:',
                    bank.accountNumber ?? 'N/A', Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoField(
                    'Branch:', bank.branch ?? 'N/A', Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoField('Code:', bank.code, Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoField(
                    'Current Balance:',
                    '${currency.symbol}${bank.currentBalance.toStringAsFixed(2)}',
                    Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoField('Status:',
                    bank.isActive ? 'Active' : 'Inactive', Colors.white),
              ),
            ],
          ),
          if (bank.address != null || bank.phone != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (bank.address != null)
                  Expanded(
                    child: _buildInfoField(
                        'Address:', bank.address!, Colors.white),
                  ),
                if (bank.phone != null) ...[
                  if (bank.address != null) const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoField('Phone:', bank.phone!, Colors.white),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: Colors.white54, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () =>
                    _generateLedgerReport(bank, currency, paymentsAsync),
                icon: const Icon(Icons.description, color: Colors.white),
                label: Text(
                  'ledger.ledger_report'.tr(),
                  style: const TextStyle(color: Colors.white),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(
      AsyncValue<List<BankPaymentModel>> paymentsAsync, Currency currency) {
    return paymentsAsync.when(
      data: (payments) {
        final filteredPayments = payments
            .where((payment) => _isDateInRange(payment.issueDate))
            .toList();
        filteredPayments.sort((a, b) => b.issueDate.compareTo(a.issueDate));

        if (filteredPayments.isEmpty) {
          return _buildEmptyState('No transactions found');
        }

        final bankAsync = ref.watch(bankByIdProvider(widget.bankId));
        final paymentsWithBalance = <BankPaymentWithBalance>[];

        // Use the stored previousBalance and newBalance from each payment
        for (var payment in filteredPayments) {
          paymentsWithBalance.add(BankPaymentWithBalance(
            payment: payment,
            previousBalance: payment.previousBalance,
            transactionAmount: payment.amount,
            balance: payment.newBalance,
          ));
        }

        // Reverse to show newest first (descending)
        final finalList = paymentsWithBalance.reversed.toList();
        final totalTransactions = filteredPayments.fold<double>(
            0.0, (sum, payment) => sum + payment.amount);

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
                    Expanded(flex: 2, child: _buildTableHeader('Party Name')),
                    Expanded(flex: 1, child: _buildTableHeader('Type')),
                    Expanded(flex: 2, child: _buildTableHeader('Issue Date')),
                    Expanded(
                        flex: 2, child: _buildTableHeader('Previous Balance')),
                    Expanded(flex: 2, child: _buildTableHeader('Amount')),
                    Expanded(flex: 2, child: _buildTableHeader('Balance')),
                    Expanded(flex: 1, child: _buildTableHeader('Status')),
                  ],
                ),
              ),
            ],
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(bankPaymentsProvider(widget.bankId));
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: isMobile
                    ? ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: finalList.length,
                        itemBuilder: (context, index) {
                          final paymentWithBalance = finalList[index];
                          return _buildTransactionCard(
                              paymentWithBalance, currency, index);
                        },
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: finalList.length,
                        itemBuilder: (context, index) {
                          final paymentWithBalance = finalList[index];
                          return _buildTransactionRow(
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
                  const Spacer(),
                  const Text(
                    'Total Transactions:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${currency.symbol}${totalTransactions.toStringAsFixed(2)}',
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

  Widget _buildTransactionCard(
      BankPaymentWithBalance paymentWithBalance, Currency currency, int index) {
    final payment = paymentWithBalance.payment;
    final isDeposit =
        payment.paymentType == 'deposit' || payment.paymentType == 'cheque';
    final statusColor = _getStatusColor(payment.status);

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
                    isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
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
                        payment.partyName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd-MMM-yyyy').format(payment.issueDate),
                        style: const TextStyle(
                          fontSize: 14,
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
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    payment.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
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
                        'Type',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDeposit
                              ? Colors.green.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDeposit
                                ? Colors.green.shade300
                                : Colors.blue.shade300,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          payment.paymentType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDeposit
                                ? Colors.green.shade700
                                : Colors.blue.shade700,
                          ),
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
                        'Previous Balance',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currency.symbol}${paymentWithBalance.previousBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currency.symbol}${paymentWithBalance.transactionAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDeposit ? Colors.green : Colors.blue,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (payment.paymentType == 'cheque' &&
                payment.chequeNumber != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
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
                          payment.chequeNumber!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (payment.chequeDate != null)
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
                                .format(payment.chequeDate!),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'cleared':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'unclear':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return const Color(0xFF4A90E2);
    }
  }

  Widget _buildTransactionRow(
      BankPaymentWithBalance paymentWithBalance, Currency currency, int index) {
    final isEven = index % 2 == 0;
    final payment = paymentWithBalance.payment;
    final isDeposit =
        payment.paymentType == 'deposit' || payment.paymentType == 'cheque';

    return Container(
      color: isEven ? Colors.white : const Color(0xFFF5F5F5),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.partyName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (payment.otherName != null && payment.otherName!.isNotEmpty)
                  Text(
                    payment.otherName!,
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              _getPaymentTypeDisplay(payment.paymentType),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd-MM-yyyy').format(payment.issueDate),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              paymentWithBalance.previousBalance.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              paymentWithBalance.transactionAmount.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDeposit ? Colors.green : Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              paymentWithBalance.balance.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(payment.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getStatusColor(payment.status)),
              ),
              child: Text(
                payment.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(payment.status),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentTypeDisplay(String type) {
    switch (type) {
      case 'cheque':
        return 'CHEQUE';
      case 'transfer':
        return 'TRANSFER';
      case 'deposit':
        return 'DEPOSIT';
      case 'withdrawal':
        return 'WITHDRAWAL';
      default:
        return type.toUpperCase();
    }
  }

  bool _isDateInRange(DateTime date) {
    return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
        date.isBefore(_endDate.add(const Duration(days: 1)));
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
              Icons.account_balance,
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
              ref.invalidate(bankByIdProvider(widget.bankId));
              ref.invalidate(bankPaymentsProvider(widget.bankId));
            },
            child: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _generateLedgerReport(BankModel bank, Currency currency,
      AsyncValue<List<BankPaymentModel>> paymentsAsync) async {
    try {
      await paymentsAsync.when(
        data: (payments) async {
          final filteredPayments =
              payments.where((p) => _isDateInRange(p.issueDate)).toList();
          filteredPayments.sort((a, b) => a.issueDate.compareTo(b.issueDate));

          final transactions = <BankLedgerTransaction>[];
          for (final payment in filteredPayments) {
            final isDeposit = payment.paymentType == 'deposit' ||
                payment.paymentType == 'cheque';
            transactions.add(BankLedgerTransaction(
              type: BankLedgerType.transaction,
              date: payment.issueDate,
              description: payment.otherName?.isNotEmpty == true
                  ? '${payment.partyName} (${payment.otherName})'
                  : payment.partyName,
              debit: isDeposit ? payment.amount : 0,
              credit: isDeposit ? 0 : payment.amount,
              chequeNumber: payment.chequeNumber,
              paymentType: payment.paymentType,
              balance: payment.newBalance,
            ));
          }

          transactions.sort((a, b) => a.date.compareTo(b.date));

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
                        'BANK LEDGER REPORT',
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
                        'Bank Information',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text('Name: ${bank.name}'),
                          ),
                          pw.Expanded(
                            child: pw.Text('Code: ${bank.code}'),
                          ),
                        ],
                      ),
                      if (bank.accountNumber != null &&
                          bank.accountNumber!.isNotEmpty)
                        pw.Text('Account Number: ${bank.accountNumber}'),
                      if (bank.branch != null && bank.branch!.isNotEmpty)
                        pw.Text('Branch: ${bank.branch}'),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Current Balance: ${currency.symbol}${bank.currentBalance.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
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
                            'Cheque No',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Type',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
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
                                transaction.chequeNumber ?? '-',
                                style: pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                transaction.paymentType.toUpperCase(),
                                style: pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                transaction.debit > 0
                                    ? '${currency.symbol}${transaction.debit.toStringAsFixed(2)}'
                                    : '-',
                                style: pw.TextStyle(fontSize: 10),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                transaction.credit > 0
                                    ? '${currency.symbol}${transaction.credit.toStringAsFixed(2)}'
                                    : '-',
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
                                  fontWeight: pw.FontWeight.bold,
                                ),
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
                        'Current Balance:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '${currency.symbol}${bank.currentBalance.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
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

          final bytes = await pdf.save();
          final directory = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final file =
              File('${directory.path}/bank_ledger_${bank.name}_$timestamp.pdf');
          await file.writeAsBytes(bytes);

          await Share.shareXFiles([XFile(file.path)],
              text: 'Bank Ledger Report');

          if (mounted) {
            AppSnackBar.show(
              context,
              const SnackBar(
                content: Text('Ledger report generated successfully'),
                backgroundColor: Colors.green,
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
}

// Helper classes
enum BankLedgerType { transaction }

class BankLedgerTransaction {
  final BankLedgerType type;
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  final String? chequeNumber;
  final String paymentType;
  double balance;

  BankLedgerTransaction({
    required this.type,
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    this.chequeNumber,
    required this.paymentType,
    this.balance = 0.0,
  });
}

class BankPaymentWithBalance {
  final BankPaymentModel payment;
  final double previousBalance;
  final double transactionAmount;
  final double balance;

  BankPaymentWithBalance({
    required this.payment,
    required this.previousBalance,
    required this.transactionAmount,
    required this.balance,
  });
}
