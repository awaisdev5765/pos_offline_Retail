import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/supplier_payment.dart';
import '../models/bank_payment.dart';
import '../models/supplier.dart';
import '../models/employee.dart';
import '../models/currency.dart';
import '../providers/payment_provider.dart' as payment_provider;
import '../providers/bank_provider.dart' as bank_provider;
import '../providers/currency_provider.dart';
import '../services/database_service.dart';
import '../widgets/app_snack_bar.dart';
import 'comprehensive_reports_screen.dart' show _allSupplierPaymentsProvider;
import '../providers/supplier_payment_provider.dart';

class PaymentDetailScreen extends ConsumerStatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const PaymentDetailScreen({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  ConsumerState<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends ConsumerState<PaymentDetailScreen> {
  bool _isExporting = false;

  /// Helper function to get full employee name from createdBy field
  /// This ensures we always display the full employee name, not abbreviations
  Future<String> _getFullEmployeeName(
    String? createdBy,
    DatabaseService databaseService,
  ) async {
    if (createdBy == null || createdBy.isEmpty) {
      return 'Unknown';
    }

    try {
      final allEmployees = await databaseService.getAllEmployees();
      if (allEmployees.isEmpty) {
        return createdBy; // Return as-is if no employees found
      }

      // First, try to match by exact name (case-insensitive)
      try {
        final emp = allEmployees.firstWhere(
          (e) => e.name.toLowerCase().trim() == createdBy.toLowerCase().trim(),
        );
        return emp.name; // Return full name
      } catch (_) {
        // If not found by name, try username
        try {
          final emp = allEmployees.firstWhere(
            (e) => e.username != null &&
                e.username!.toLowerCase().trim() == createdBy.toLowerCase().trim(),
          );
          return emp.name; // Return full name
        } catch (_) {
          // Try partial match - sometimes createdBy might be an abbreviation
          // Check if createdBy is contained in any employee name or vice versa
          final matchingEmployees = allEmployees.where((e) {
            final nameLower = e.name.toLowerCase().trim();
            final createdByLower = createdBy.toLowerCase().trim();
            final usernameLower = (e.username ?? '').toLowerCase().trim();
            
            // Check if createdBy matches start of name (e.g., "US MA" matches "USAMA" or similar)
            return nameLower.contains(createdByLower) ||
                createdByLower.contains(nameLower) ||
                usernameLower.contains(createdByLower) ||
                createdByLower.contains(usernameLower);
          }).toList();

          if (matchingEmployees.isNotEmpty) {
            // Return the first matching employee's full name
            return matchingEmployees.first.name;
          }

          // If still not found, return the original value
          return createdBy;
        }
      }
    } catch (e) {
      // If any error occurs, return the original value
      return createdBy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currentCurrencyProvider);
    final DateTime startBoundary =
        DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
    final DateTime endBoundary =
        DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day, 23, 59, 59, 999);

    final customerPaymentsAsync = ref.watch(
        payment_provider.paymentsByDateRangeProvider(payment_provider.DateRange(
      start: startBoundary,
      end: endBoundary,
    )));
    final supplierPaymentsAsync = ref.watch(
        allSupplierPaymentsByDateRangeProvider((
      start: startBoundary,
      end: endBoundary,
    )));
    final bankPaymentsAsync = ref.watch(
        bank_provider.bankPaymentsByDateRangeProvider((
      start: startBoundary,
      end: endBoundary,
    )));

    return Scaffold(
      appBar: AppBar(
        title: Text('misc.received_payment_detail'.tr()),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _exportToPDF(
                customerPaymentsAsync,
                supplierPaymentsAsync,
                bankPaymentsAsync,
                currency,
              ),
              tooltip: 'Export to PDF',
            ),
        ],
      ),
      body: customerPaymentsAsync.when(
        data: (customerPayments) => supplierPaymentsAsync.when(
          data: (supplierPayments) => bankPaymentsAsync.when(
            data: (bankPayments) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Received and Payment Detail',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'From Date : ${DateFormat('dd-MMM-yy').format(widget.startDate)} To ${DateFormat('dd-MMM-yy').format(widget.endDate)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // CREDIT CASH RECEIVED (customer cash payments)
                    _buildSection(
                      title: 'CREDIT CASH RECEIVED',
                      data: _buildCreditCashReceived(customerPayments),
                    ),
                    const SizedBox(height: 24),
                    // CUSTOMER CHECQUE CLEARED (customer cheques cleared via bank)
                    _buildSection(
                      title: 'CUSTOMER CHECQUE CLEARED',
                      data: _buildCustomerChequeCleared(
                        customerPayments,
                        bankPayments,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // PARTY BANK PAYMENT (supplier bank transfers/withdrawals)
                    _buildSection(
                      title: 'PARTY BANK PAYMENT',
                      data: _buildPartyBankPayment(supplierPayments, bankPayments),
                    ),
                    const SizedBox(height: 24),
                    // PARTY CASH PAYMENT (supplier cash payments)
                    _buildSection(
                      title: 'PARTY CASH PAYMENT',
                      data: _buildPartyCashPayment(supplierPayments),
                    ),
                    const SizedBox(height: 24),
                    // PARTY CHECQUE CLEARED (only supplier cheques)
                    _buildSection(
                      title: 'PARTY CHECQUE CLEARED',
                      data: _buildPartyChequeCleared(
                        supplierPayments,
                        bankPayments,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget data}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        data,
      ],
    );
  }

  Widget _buildCreditCashReceived(List<PaymentModel> payments) {
    // Filter for ALL cash payments - Credit Cash Received shows customer cash payments (recovery)
    // Credit Cash Received = All customer payments made with cash method
    // Include both positive amounts (recovery payments) and negative amounts (balance additions)
    
    // Filter cash payments - ensure we catch all cash payments
    final cashPayments = payments
        .where((p) => p.paymentMethod == PaymentMethod.cash)
        .toList();

    if (cashPayments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No data available', style: TextStyle(color: Colors.grey)),
      );
    }

    final databaseService = ref.read(databaseServiceProvider);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait(
        cashPayments.map((payment) async {
          // Load customer data if not already loaded
          CustomerModel? customer = payment.customer;
          if (customer == null) {
            try {
              customer = await databaseService.getCustomerById(payment.customerId);
            } catch (e) {
              debugPrint('Error loading customer ${payment.customerId} for payment ${payment.id}: $e');
            }
          }
          
          // Use customer balance if available, otherwise 0
          final currentBalance = customer?.totalDue ?? 0.0;
          // Previous balance = current balance + payment amount (payment reduces balance)
          // Works correctly for both positive (payment received) and negative (balance addition) amounts
          final previousBalance = currentBalance + payment.amount;
          final paidAmount = payment.amount;
          final balance = currentBalance;

          String employeeName = 'Unknown';
          if (payment.processedBy != null) {
            employeeName = payment.processedBy!.name;
          } else if (payment.processedByEmployeeId != null) {
            try {
              final employee = await databaseService.getEmployeeById(payment.processedByEmployeeId!);
              employeeName = employee?.name ?? 'Unknown';
            } catch (e) {
              debugPrint('Error loading employee for payment ${payment.id}: $e');
            }
          }

          return {
            'name': customer?.name ?? 'Unknown Customer',
            'date': payment.date,
            'previousBalance': previousBalance,
            'paidAmount': paidAmount,
            'balance': balance,
            'cashBank': '',
            'user': employeeName,
            'dateTime': payment.date,
          };
        }),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No data available', style: TextStyle(color: Colors.grey)),
          );
        }
        return _buildTable(snapshot.data!);
      },
    );
  }

  /// PARTY BANK PAYMENT:
  /// - Shows cheques GIVEN to suppliers (from banking system) that are still
  ///   pending/unclear in the bank.
  Widget _buildPartyBankPayment(
    List<SupplierPaymentModel> supplierPayments,
    List<BankPaymentModel> bankPayments,
  ) {
    final databaseService = ref.read(databaseServiceProvider);

    // Pending/unclear supplier cheques in bank payments
    final pendingSupplierCheques = bankPayments
        .where((bp) =>
            bp.paymentType == 'cheque' &&
            (bp.status.toLowerCase() == 'pending' ||
                bp.status.toLowerCase() == 'unclear'))
        .toList();

    if (pendingSupplierCheques.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No data available', style: TextStyle(color: Colors.grey)),
      );
    }

    // We need suppliers and employees to map names and balances
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: () async {
        final allSuppliers = await databaseService.getAllSuppliers();
        final allEmployees = await databaseService.getAllEmployees();
        final rows = <Map<String, dynamic>>[];

        for (final payment in pendingSupplierCheques) {
          // Only include cheques where partyName matches a supplier
          SupplierModel? supplierModel;
          try {
            final supplierRow = allSuppliers.firstWhere(
              (s) => s.name == payment.partyName,
              orElse: () => throw Exception('Not a supplier'),
            );
            supplierModel = SupplierModel.fromSupplier(supplierRow);
          } catch (_) {
            continue; // not a supplier, skip
          }

          // Find matching supplier payment (cheque) to get createdBy/user
          SupplierPaymentModel? matchingSupplierPayment;
          try {
            matchingSupplierPayment = supplierPayments.firstWhere(
              (sp) =>
                  sp.supplierId == supplierModel?.id &&
                  sp.paymentMethod == 'cheque' &&
                  (sp.amount - payment.amount).abs() < 0.01 &&
                  (sp.date.difference(payment.issueDate).inDays.abs() <= 7),
            );
          } catch (_) {
            matchingSupplierPayment = null;
          }

          final employeeName = await _getFullEmployeeName(
            matchingSupplierPayment?.createdBy,
            databaseService,
          );

          // Bank name
          final bank = await databaseService.getBankById(payment.bankId);
          final bankName = bank?.name ?? 'BANK';

          // Previous/Current balance from supplier ledger
          final currentBalance = supplierModel.currentBalance;
          final previousBalance = currentBalance + payment.amount;

          rows.add({
            'name': supplierModel.name,
            'date': payment.issueDate,
            'previousBalance': previousBalance,
            'paidAmount': payment.amount,
            'balance': currentBalance,
            'cashBank': bankName,
            'user': employeeName,
            'dateTime': payment.issueDate,
          });
        }

        return rows;
      }(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildTable(snapshot.data!);
      },
    );
  }

  Widget _buildPartyCashPayment(List<SupplierPaymentModel> payments) {
    final cashPayments = payments
        .where((p) => p.paymentMethod == 'cash' && p.paymentType == 'payment')
        .toList();

    if (cashPayments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No data available', style: TextStyle(color: Colors.grey)),
      );
    }

    final databaseService = ref.read(databaseServiceProvider);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait(
        cashPayments.map((payment) async {
          final supplierDb = await databaseService.getSupplierById(payment.supplierId);
          if (supplierDb == null) return null;
          final supplier = SupplierModel.fromSupplier(supplierDb);
          
          final employeeName = await _getFullEmployeeName(
            payment.createdBy,
            databaseService,
          );
          
          final previousBalance = supplier.currentBalance + payment.amount;
          final paidAmount = payment.amount;
          final balance = supplier.currentBalance;

          return {
            'name': supplier.name,
            'date': payment.date,
            'previousBalance': previousBalance,
            'paidAmount': paidAmount,
            'balance': balance,
            'cashBank': 'PARTY CASH PAYMENT',
            'user': employeeName,
            'dateTime': payment.date,
          };
        }),
      ).then((results) => results.whereType<Map<String, dynamic>>().toList()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildTable(snapshot.data!);
      },
    );
  }

  /// Customer cheque payments (credit payments) that have been cleared in bank.
  /// Shown separately from PARTY CHECQUE CLEARED (supplier-only).
  Widget _buildCustomerChequeCleared(
    List<PaymentModel> customerPayments,
    List<BankPaymentModel> bankPayments,
  ) {
    // All cleared cheque bank payments in the selected date range
    final clearedCheques = bankPayments
        .where((p) => p.status == 'cleared' && p.paymentType == 'cheque')
        .toList();

    // Build a set of customer names from the customer payments in range
    final customerNames = customerPayments
        .map((p) => p.customer?.name)
        .whereType<String>()
        .toSet();

    // Only keep cheques whose partyName matches a known customer
    final customerCheques = clearedCheques
        .where((bp) => customerNames.contains(bp.partyName))
        .toList();

    if (customerCheques.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No data available', style: TextStyle(color: Colors.grey)),
      );
    }

    final databaseService = ref.read(databaseServiceProvider);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait(
        customerCheques.map((payment) async {
          final bank = await databaseService.getBankById(payment.bankId);

          // Try to find matching customer payment (cheque) to get balances and user
          PaymentModel? matchingPayment;
          try {
            matchingPayment = customerPayments.firstWhere(
              (cp) =>
                  cp.paymentMethod == PaymentMethod.cheque &&
                  cp.customer?.name == payment.partyName &&
                  (cp.amount - payment.amount).abs() < 0.01 &&
                  (cp.date.difference(payment.issueDate).inDays.abs() <= 7 ||
                      cp.date.difference(payment.paidDate).inDays.abs() <= 7),
            );
          } catch (_) {
            matchingPayment = null;
          }

          CustomerModel? customer = matchingPayment?.customer;
          if (customer == null && matchingPayment != null) {
            try {
              customer =
                  await databaseService.getCustomerById(matchingPayment.customerId);
            } catch (_) {
              customer = null;
            }
          }

          double previousBalance = 0;
          double balance = 0;

          if (matchingPayment != null) {
            final currentBalance = customer?.totalDue ?? 0.0;
            // Previous balance = current balance + cheque amount (payment reduces balance)
            previousBalance = currentBalance + matchingPayment.amount;
            balance = currentBalance;
          } else {
            // Fallback to bank-side balances if we can't resolve customer balance
            previousBalance = payment.previousBalance;
            balance = payment.newBalance;
          }

          String employeeName = 'Unknown';
          if (matchingPayment != null) {
            if (matchingPayment.processedBy != null) {
              employeeName = matchingPayment.processedBy!.name;
            } else if (matchingPayment.processedByEmployeeId != null) {
              try {
                final emp = await databaseService
                    .getEmployeeById(matchingPayment.processedByEmployeeId!);
                employeeName = emp?.name ?? 'Unknown';
              } catch (_) {
                employeeName = 'Unknown';
              }
            }
          }

          return {
            'name': customer?.name ?? payment.partyName,
            'date': payment.paidDate,
            'previousBalance': previousBalance,
            'paidAmount': payment.amount,
            'balance': balance,
            'cashBank': bank?.name ?? 'Unknown Bank',
            'user': employeeName,
            'dateTime': payment.paidDate,
          };
        }),
      ).then((results) => results.whereType<Map<String, dynamic>>().toList()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No data available', style: TextStyle(color: Colors.grey)),
          );
        }
        return _buildTable(snapshot.data!);
      },
    );
  }

  Widget _buildPartyChequeCleared(
    List<SupplierPaymentModel> supplierPayments,
    List<BankPaymentModel> payments,
  ) {
    final clearedCheques = payments
        .where((p) => p.status == 'cleared' && p.paymentType == 'cheque')
        .toList();

    if (clearedCheques.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No data available', style: TextStyle(color: Colors.grey)),
      );
    }

    final databaseService = ref.read(databaseServiceProvider);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait(
        clearedCheques.map((payment) async {
          final bank = await databaseService.getBankById(payment.bankId);

          // Only include cheques that belong to suppliers (partyName matches a supplier
          // and there is a matching supplier payment). Customer cheques will be shown
          // separately in the CUSTOMER CHECQUE CLEARED section.
          SupplierModel? supplierModel;
          try {
            final allSuppliers = await databaseService.getAllSuppliers();
            final supplier = allSuppliers.firstWhere(
              (s) => s.name == payment.partyName,
              orElse: () => throw Exception('Not a supplier'),
            );
            supplierModel = SupplierModel.fromSupplier(supplier);
          } catch (_) {
            // Not a supplier -> skip this cheque (it will be handled as customer cheque)
            return null;
          }

          // Find matching supplier payment to infer who created/cleared it
          SupplierPaymentModel? matchingPayment;
          try {
            final supplierPaymentList =
                await databaseService.getSupplierPayments(supplierModel.id!);
            matchingPayment = supplierPaymentList.firstWhere(
              (sp) =>
                  (sp.amount - payment.amount).abs() < 0.01 &&
                  (sp.date.difference(payment.issueDate).inDays.abs() <= 1),
              orElse: () => supplierPaymentList.isNotEmpty
                  ? supplierPaymentList.first
                  : throw Exception('No supplier payment'),
            );
          } catch (_) {
            matchingPayment = null;
          }

          final employeeName = await _getFullEmployeeName(
            matchingPayment?.createdBy,
            databaseService,
          );

          return {
            'name': payment.partyName,
            'date': payment.paidDate,
            'previousBalance': payment.previousBalance,
            'paidAmount': payment.amount,
            'balance': payment.newBalance,
            'cashBank': bank?.name ?? 'Unknown Bank',
            'user': employeeName,
            'dateTime': payment.paidDate,
          };
        }),
      ).then((results) => results.whereType<Map<String, dynamic>>().toList()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildTable(snapshot.data!);
      },
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No data available', style: TextStyle(color: Colors.grey)),
      );
    }

    final total = rows.fold<double>(
      0.0,
      (sum, row) => sum + (row['paidAmount'] as double),
    );

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[300],
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: Row(
            children: [
              _buildHeaderCell('Name', flex: 2),
              _buildHeaderCell('Date'),
              _buildHeaderCell('Previous Balance'),
              _buildHeaderCell('Paid Amount'),
              _buildHeaderCell('Balance'),
              _buildHeaderCell('CASH / BANK'),
              _buildHeaderCell('Br'),
              _buildHeaderCell('Date'),
              _buildHeaderCell('Time', isLast: true),
            ],
          ),
        ),
        ...rows.map((row) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  left: BorderSide(color: Colors.grey[300]!),
                  right: BorderSide(color: Colors.grey[300]!),
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  _buildDataCell(row['name'] as String, flex: 2),
                  _buildDataCell(DateFormat('dd-MMM-yy').format(row['date'] as DateTime)),
                  _buildDataCell(_formatNumber(row['previousBalance'] as double)),
                  _buildDataCell(_formatNumber(row['paidAmount'] as double)),
                  _buildDataCell(_formatNumber(row['balance'] as double)),
                  _buildDataCell(row['cashBank'] as String),
                  _buildDataCell(row['user'] as String),
                  _buildDataCell(DateFormat('dd-MMM-yy').format(row['dateTime'] as DateTime)),
                  _buildDataCell(DateFormat('hh:mm').format(row['dateTime'] as DateTime), isLast: true),
                ],
              ),
            )),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Container()),
              Expanded(child: Container()),
              Expanded(
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
                  _formatNumber(total),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey[900],
                  ),
                ),
              ),
              Expanded(child: Container()),
              Expanded(child: Container()),
              Expanded(child: Container()),
              Expanded(child: Container()),
              Expanded(child: Container()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1, bool isLast = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(right: BorderSide(color: Colors.grey[400]!)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, {int flex = 1, bool isLast = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(right: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(2);
  }

  Future<void> _exportToPDF(
    AsyncValue<List<PaymentModel>> customerPaymentsAsync,
    AsyncValue<List<SupplierPaymentModel>> supplierPaymentsAsync,
    AsyncValue<List<BankPaymentModel>> bankPaymentsAsync,
    Currency currency,
  ) async {
    setState(() => _isExporting = true);

    try {
      final customerPayments = customerPaymentsAsync.valueOrNull ?? [];
      final supplierPayments = supplierPaymentsAsync.valueOrNull ?? [];
      final bankPayments = bankPaymentsAsync.valueOrNull ?? [];

      final databaseService = ref.read(databaseServiceProvider);
      final allBankPaymentsAsync = ref.read(bank_provider.allBankPaymentsProvider);

      // Prepare data for PDF
      final creditCashReceived = await _prepareCreditCashReceived(customerPayments, databaseService);
      final customerChequeCleared = await _prepareCustomerChequeCleared(
        bankPayments,
        databaseService,
        customerPayments,
      );
      final partyBankPayment = await _preparePartyBankPayment(
        supplierPayments, 
        databaseService, 
        allBankPaymentsAsync.valueOrNull ?? [],
        dateFilteredBankPayments: bankPayments, // Pass date-filtered bank payments for transfers/withdrawals
      );
      final partyCashPayment = await _preparePartyCashPayment(supplierPayments, databaseService);
      final partyChequeCleared = await _preparePartyChequeCleared(bankPayments, databaseService);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Received and Payment Detail',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              'From Date : ${DateFormat('dd-MMM-yy').format(widget.startDate)} To ${DateFormat('dd-MMM-yy').format(widget.endDate)}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 20),
            // CREDIT CASH RECEIVED
            _buildPDFSection('CREDIT CASH RECEIVED', creditCashReceived, currency),
            pw.SizedBox(height: 20),
            // CUSTOMER CHECQUE CLEARED
            _buildPDFSection('CUSTOMER CHECQUE CLEARED', customerChequeCleared, currency),
            pw.SizedBox(height: 20),
            // PARTY BANK PAYMENT
            _buildPDFSection('PARTY BANK PAYMENT', partyBankPayment, currency),
            pw.SizedBox(height: 20),
            // PARTY CASH PAYMENT
            _buildPDFSection('PARTY CASH PAYMENT', partyCashPayment, currency),
            pw.SizedBox(height: 20),
            // PARTY CHECQUE CLEARED
            _buildPDFSection('PARTY CHECQUE CLEARED', partyChequeCleared, currency),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'PaymentDetail_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('PDF exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error exporting PDF: $e'),
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

  Future<List<Map<String, dynamic>>> _prepareCreditCashReceived(
    List<PaymentModel> payments,
    DatabaseService databaseService,
  ) async {
    // Include ALL cash payments - both positive (recovery) and negative (balance additions)
    // Credit Cash Received should show ALL customer cash payments received
    final cashPayments = payments.where((p) => p.paymentMethod == PaymentMethod.cash).toList();
    final List<Map<String, dynamic>> rows = [];

    for (final payment in cashPayments) {
      // Load customer data if not already loaded
      CustomerModel? customer = payment.customer;
      if (customer == null && payment.customerId != null) {
        try {
          customer = await databaseService.getCustomerById(payment.customerId!);
        } catch (e) {
          debugPrint('Error loading customer for payment ${payment.id}: $e');
        }
      }
      
      final currentBalance = customer?.totalDue ?? 0.0;
      // Previous balance = current balance + payment amount (payment reduces balance)
      // Works correctly for both positive (payment received) and negative (balance addition) amounts
      final previousBalance = currentBalance + payment.amount;

      String employeeName = 'Unknown';
      if (payment.processedBy != null) {
        employeeName = payment.processedBy!.name;
      } else if (payment.processedByEmployeeId != null) {
        try {
          final employee = await databaseService.getEmployeeById(payment.processedByEmployeeId!);
          employeeName = employee?.name ?? 'Unknown';
        } catch (e) {
          debugPrint('Error loading employee for payment ${payment.id}: $e');
        }
      }

      rows.add({
        'name': customer?.name ?? 'Unknown Customer',
        'date': payment.date,
        'previousBalance': previousBalance,
        'paidAmount': payment.amount,
        'balance': currentBalance,
        'cashBank': '',
        'user': employeeName,
        'dateTime': payment.date,
      });
    }

    return rows;
  }

  Future<List<Map<String, dynamic>>> _preparePartyBankPayment(
    List<SupplierPaymentModel> supplierPayments,
    DatabaseService databaseService,
    List<BankPaymentModel> allBankPayments, {
    List<BankPaymentModel>? dateFilteredBankPayments,
  }) async {
    final List<Map<String, dynamic>> rows = [];

    // Pending/unclear supplier cheques across all bank payments
    final bankPaymentsToFilter = dateFilteredBankPayments ?? allBankPayments;
    final pendingSupplierCheques = bankPaymentsToFilter
        .where((bp) =>
            bp.paymentType == 'cheque' &&
            (bp.status.toLowerCase() == 'pending' ||
                bp.status.toLowerCase() == 'unclear'))
        .toList();

    final allSuppliers = await databaseService.getAllSuppliers();
    final allEmployees = await databaseService.getAllEmployees();

    for (final payment in pendingSupplierCheques) {
      // Supplier by party name
      SupplierModel? supplierModel;
      try {
        final supplierRow = allSuppliers.firstWhere(
          (s) => s.name == payment.partyName,
          orElse: () => throw Exception('Not a supplier'),
        );
        supplierModel = SupplierModel.fromSupplier(supplierRow);
      } catch (_) {
        continue;
      }

      // Match supplier payment (cheque) for createdBy/user
      SupplierPaymentModel? matchingSupplierPayment;
      try {
        matchingSupplierPayment = supplierPayments.firstWhere(
          (sp) =>
              sp.supplierId == supplierModel?.id &&
              sp.paymentMethod == 'cheque' &&
              (sp.amount - payment.amount).abs() < 0.01 &&
              (sp.date.difference(payment.issueDate).inDays.abs() <= 7),
        );
      } catch (_) {
        matchingSupplierPayment = null;
      }

      final employeeName = await _getFullEmployeeName(
        matchingSupplierPayment?.createdBy,
        databaseService,
      );

      final bank = await databaseService.getBankById(payment.bankId);
      final bankName = bank?.name ?? 'BANK';

      final currentBalance = supplierModel.currentBalance;
      final previousBalance = currentBalance + payment.amount;

      rows.add({
        'name': supplierModel.name,
        'date': payment.issueDate,
        'previousBalance': previousBalance,
        'paidAmount': payment.amount,
        'balance': currentBalance,
        'cashBank': bankName,
        'user': employeeName,
        'dateTime': payment.issueDate,
      });
    }

    return rows;
  }

  Future<List<Map<String, dynamic>>> _preparePartyCashPayment(
    List<SupplierPaymentModel> payments,
    DatabaseService databaseService,
  ) async {
    final cashPayments = payments
        .where((p) => p.paymentMethod == 'cash' && p.paymentType == 'payment')
        .toList();
    final List<Map<String, dynamic>> rows = [];

    for (final payment in cashPayments) {
      final supplierDb = await databaseService.getSupplierById(payment.supplierId);
      if (supplierDb == null) continue;
      final supplier = SupplierModel.fromSupplier(supplierDb);

      final employeeName = await _getFullEmployeeName(
        payment.createdBy,
        databaseService,
      );

      rows.add({
        'name': supplier.name,
        'date': payment.date,
        'previousBalance': supplier.currentBalance + payment.amount,
        'paidAmount': payment.amount,
        'balance': supplier.currentBalance,
        'cashBank': 'PARTY CASH PAYMENT',
        'user': employeeName,
        'dateTime': payment.date,
      });
    }

    return rows;
  }

  Future<List<Map<String, dynamic>>> _preparePartyChequeCleared(
    List<BankPaymentModel> payments,
    DatabaseService databaseService,
  ) async {
    final clearedCheques = payments
        .where((p) => p.status == 'cleared' && p.paymentType == 'cheque')
        .toList();
    final List<Map<String, dynamic>> rows = [];

    // Only include supplier cheques here. Customer cheques are prepared
    // separately in _prepareCustomerChequeCleared.
    for (final payment in clearedCheques) {
      final bank = await databaseService.getBankById(payment.bankId);

      SupplierModel? matchingSupplierModel;
      try {
        final allSuppliers = await databaseService.getAllSuppliers();
        final supplier = allSuppliers.firstWhere(
          (s) => s.name == payment.partyName,
          orElse: () => throw Exception('Not a supplier'),
        );
        matchingSupplierModel = SupplierModel.fromSupplier(supplier);
      } catch (_) {
        // Not a supplier -> skip; this will be handled as customer cheque
        continue;
      }

      String employeeName = 'Unknown';
      try {
        final supplierPayments = await databaseService
            .getSupplierPayments(matchingSupplierModel.id!);
        SupplierPaymentModel? matchingPayment;
        try {
          matchingPayment = supplierPayments.firstWhere(
            (sp) =>
                (sp.amount - payment.amount).abs() < 0.01 &&
                (sp.date.difference(payment.issueDate).inDays.abs() <= 1),
          );
        } catch (_) {
          matchingPayment =
              supplierPayments.isNotEmpty ? supplierPayments.first : null;
        }
        employeeName = await _getFullEmployeeName(
          matchingPayment?.createdBy,
          databaseService,
        );
      } catch (_) {
        // Keep Unknown
      }

      rows.add({
        'name': payment.partyName,
        'date': payment.paidDate,
        'previousBalance': payment.previousBalance,
        'paidAmount': payment.amount,
        'balance': payment.newBalance,
        'cashBank': bank?.name ?? 'Unknown Bank',
        'user': employeeName,
        'dateTime': payment.paidDate,
      });
    }

    return rows;
  }

  Future<List<Map<String, dynamic>>> _prepareCustomerChequeCleared(
    List<BankPaymentModel> payments,
    DatabaseService databaseService,
    List<PaymentModel> customerPayments,
  ) async {
    final clearedCheques = payments
        .where((p) => p.status == 'cleared' && p.paymentType == 'cheque')
        .toList();
    final List<Map<String, dynamic>> rows = [];

    // Build a set of customer names from the customer payments in range
    final customerNames = customerPayments
        .map((p) => p.customer?.name)
        .whereType<String>()
        .toSet();

    for (final payment in clearedCheques) {
      // Only keep cheques whose partyName matches a known customer
      if (!customerNames.contains(payment.partyName)) continue;

      final bank = await databaseService.getBankById(payment.bankId);

      // Try to find matching customer payment (cheque)
      PaymentModel? matchingPayment;
      try {
        matchingPayment = customerPayments.firstWhere(
          (cp) =>
              cp.paymentMethod == PaymentMethod.cheque &&
              cp.customer?.name == payment.partyName &&
              (cp.amount - payment.amount).abs() < 0.01 &&
              (cp.date.difference(payment.issueDate).inDays.abs() <= 7 ||
                  cp.date.difference(payment.paidDate).inDays.abs() <= 7),
        );
      } catch (_) {
        matchingPayment = null;
      }

      CustomerModel? customer = matchingPayment?.customer;
      if (customer == null && matchingPayment != null) {
        try {
          customer =
              await databaseService.getCustomerById(matchingPayment.customerId);
        } catch (_) {
          customer = null;
        }
      }

      double previousBalance = 0;
      double balance = 0;

      if (matchingPayment != null) {
        final currentBalance = customer?.totalDue ?? 0.0;
        previousBalance = currentBalance + matchingPayment.amount;
        balance = currentBalance;
      } else {
        previousBalance = payment.previousBalance;
        balance = payment.newBalance;
      }

      String employeeName = 'Unknown';
      if (matchingPayment != null) {
        if (matchingPayment.processedBy != null) {
          employeeName = matchingPayment.processedBy!.name;
        } else if (matchingPayment.processedByEmployeeId != null) {
          try {
            final emp = await databaseService
                .getEmployeeById(matchingPayment.processedByEmployeeId!);
            employeeName = emp?.name ?? 'Unknown';
          } catch (_) {
            employeeName = 'Unknown';
          }
        }
      }

      rows.add({
        'name': customer?.name ?? payment.partyName,
        'date': payment.paidDate,
        'previousBalance': previousBalance,
        'paidAmount': payment.amount,
        'balance': balance,
        'cashBank': bank?.name ?? 'Unknown Bank',
        'user': employeeName,
        'dateTime': payment.paidDate,
      });
    }

    return rows;
  }

  pw.Widget _buildPDFSection(String title, List<Map<String, dynamic>> rows, Currency currency) {
    if (rows.isEmpty) {
      return pw.Text('$title: No data available');
    }

    final total = rows.fold<double>(0.0, (sum, row) => sum + (row['paidAmount'] as double));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue,
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Name', 'Date', 'Previous Balance', 'Paid Amount', 'Balance', 'CASH / BANK', 'Br', 'Date', 'Time'],
          data: rows.map((row) => [
            row['name'] as String,
            DateFormat('dd-MMM-yy').format(row['date'] as DateTime),
            _formatNumber(row['previousBalance'] as double),
            _formatNumber(row['paidAmount'] as double),
            _formatNumber(row['balance'] as double),
            row['cashBank'] as String,
            row['user'] as String,
            DateFormat('dd-MMM-yy').format(row['dateTime'] as DateTime),
            DateFormat('hh:mm').format(row['dateTime'] as DateTime),
          ]).toList(),
          headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.lightBlue,
            border: pw.Border.all(color: PdfColors.grey),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                _formatNumber(total),
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

