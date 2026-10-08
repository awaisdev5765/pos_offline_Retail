import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../providers/supplier_payment_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/bank_provider.dart';
import '../models/supplier_payment.dart';
import '../models/payment.dart';
import '../models/bank_payment.dart';
import '../models/bank.dart';
import '../models/supplier.dart';
import '../providers/currency_provider.dart';
import '../models/currency.dart';
import '../providers/auth_provider.dart';
import '../utils/input_formatters.dart';
import '../providers/payment_provider.dart';
import '../widgets/app_snack_bar.dart';

class SupplierPaymentScreen extends ConsumerStatefulWidget {
  final int supplierId;

  const SupplierPaymentScreen({super.key, required this.supplierId});

  @override
  ConsumerState<SupplierPaymentScreen> createState() =>
      _SupplierPaymentScreenState();
}

class _SupplierPaymentScreenState extends ConsumerState<SupplierPaymentScreen>
    with TickerProviderStateMixin {
  static const bool _cashOnlyPayments = true; // Toggle to re-enable other methods
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _otherNameController = TextEditingController();
  final _chequeNumberController = TextEditingController();

  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  BankModel? _selectedBank;
  DateTime? _chequeDate;
  bool _isLoading = false;
  _PaymentReceiptData? _lastReceipt;
  bool _canPrint = false;
  double _enteredAmount = 0.0;
  bool get _isBalanceAdditionMode => _enteredAmount < 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _otherNameController.dispose();
    _chequeNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;
    final currency = ref.watch(currentCurrencyProvider);
    final supplierAsync = ref.watch(supplierByIdProvider(widget.supplierId));
    final banksAsync = ref.watch(activeBanksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('misc.record_supplier_payment'.tr()),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: supplierAsync.when(
          data: (supplier) {
            if (supplier == null) {
              return const Center(child: Text('Supplier not found'));
            }
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildSupplierInfo(supplier, currency),
                      const SizedBox(height: 24),
                      _buildPaymentForm(currency, banksAsync),
                    ]),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading supplier: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: Text('roles.go_back'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierInfo(SupplierModel supplier, Currency currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business, color: Color(0xFF3B82F6)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(supplier.currentBalance - supplier.unclearCheque) < 0 ? 'Credit' : 'Balance'}: ${currency.symbol}${(supplier.currentBalance - supplier.unclearCheque).abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: (supplier.currentBalance - supplier.unclearCheque) > 0
                            ? Colors.red
                            : ((supplier.currentBalance - supplier.unclearCheque) < 0
                                ? const Color(0xFF2563EB)
                                : Colors.green),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (supplier.unclearCheque > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Unclear Cheque: ${currency.symbol}${supplier.unclearCheque.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Add Ledger Report button
              OutlinedButton.icon(
                onPressed: () => context.go('/supplier-ledger?id=${supplier.id}'),
                icon: const Icon(Icons.receipt_long, size: 18),
                label: Text('ledger.view_ledger'.tr()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  side: const BorderSide(color: Color(0xFF3B82F6)),
                  foregroundColor: const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm(
      Currency currency, AsyncValue<List<BankModel>> banksAsync) {
    if (_cashOnlyPayments && _selectedPaymentMethod != PaymentMethod.cash) {
      _selectedPaymentMethod = PaymentMethod.cash;
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 24),

            if (_cashOnlyPayments) ...[
              // Cash is the only available option for now (other methods hidden)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF8FAFC),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.payments, color: Color(0xFF3B82F6)),
                    SizedBox(width: 12),
                    Text(
                      'Payment Method: CASH',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              DropdownButtonFormField<PaymentMethod>(
                initialValue: _selectedPaymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  prefixIcon: Icon(Icons.payment),
                  border: OutlineInputBorder(),
                ),
                items: PaymentMethod.values.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(method.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPaymentMethod = value;
                      if (value != PaymentMethod.cheque) {
                        _chequeNumberController.clear();
                        _chequeDate = null;
                      }
                    });
                  }
                },
              ),
            ],

            const SizedBox(height: 16),

            if (!_cashOnlyPayments &&
                (_selectedPaymentMethod == PaymentMethod.bankTransfer ||
                    _selectedPaymentMethod == PaymentMethod.cheque)) ...[
              banksAsync.when(
                data: (banks) => DropdownButtonFormField<BankModel>(
                  initialValue: _selectedBank,
                  decoration: const InputDecoration(
                    labelText: 'Select Bank',
                    prefixIcon: Icon(Icons.account_balance),
                    border: OutlineInputBorder(),
                  ),
                  items: banks.map((bank) {
                    return DropdownMenuItem(
                      value: bank,
                      child: Text(bank.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBank = value;
                    });
                  },
                  validator: (value) {
                    if ((_selectedPaymentMethod == PaymentMethod.bankTransfer ||
                            _selectedPaymentMethod == PaymentMethod.cheque) &&
                        value == null) {
                      return 'Please select a bank';
                    }
                    return null;
                  },
                ),
                loading: () => const CircularProgressIndicator(),
                error: (error, stack) => Text('Error loading banks: $error'),
              ),
              const SizedBox(height: 16),
            ],

            // Cheque Details (only show when cheque is selected)
            if (!_cashOnlyPayments &&
                _selectedPaymentMethod == PaymentMethod.cheque) ...[
              _buildChequeDetails(),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'-?\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount *',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
                helperText: 'Use negative value (-100) to add balance',
              ),
              onChanged: (value) {
                final parsed = double.tryParse(value);
                setState(() {
                  _enteredAmount = parsed ?? 0.0;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount == 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _otherNameController,
              decoration: const InputDecoration(
                labelText: 'Other Name (optional)',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            // Submit Button
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _recordPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Record Payment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        (!_canPrint || _lastReceipt == null || _isLoading)
                            ? null
                            : () => _handlePrint(currency),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: _canPrint
                            ? const Color(0xFF3B82F6)
                            : Colors.grey.shade400,
                      ),
                      foregroundColor:
                          _canPrint ? const Color(0xFF3B82F6) : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text(
                      'Print',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChequeDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cheque Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _chequeNumberController,
          decoration: const InputDecoration(
            labelText: 'Cheque Number *',
            prefixIcon: Icon(Icons.description),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (_selectedPaymentMethod == PaymentMethod.cheque &&
                (value == null || value.trim().isEmpty)) {
              return 'Please enter cheque number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: _chequeDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              helpText: 'Select Cheque Date',
            );
            if (pickedDate != null) {
              setState(() {
                _chequeDate = pickedDate;
              });
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Cheque Date *',
              prefixIcon: Icon(Icons.calendar_today),
              border: OutlineInputBorder(),
            ),
            child: Text(
              _chequeDate == null
                  ? 'Select Cheque Date'
                  : '${_chequeDate!.day}-${_chequeDate!.month}-${_chequeDate!.year}',
              style: TextStyle(
                color:
                    _chequeDate == null ? Colors.grey.shade600 : Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _paymentMethodToString(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.card:
        return 'card';
      case PaymentMethod.bankTransfer:
        return 'bank_transfer';
      case PaymentMethod.cheque:
        return 'cheque';
    }
  }

  Future<void> _recordPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate bank selection for bank transfers and cheques
    final requiresBankAccount = !_isBalanceAdditionMode &&
        (_selectedPaymentMethod == PaymentMethod.bankTransfer ||
            _selectedPaymentMethod == PaymentMethod.cheque);

    if (requiresBankAccount && _selectedBank == null) {
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text(_selectedPaymentMethod == PaymentMethod.cheque
              ? 'Please select a bank account for cheque payment'
              : 'Please select a bank account for bank transfer'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Validate cheque details
    if (!_isBalanceAdditionMode &&
        _selectedPaymentMethod == PaymentMethod.cheque) {
      if (_chequeNumberController.text.trim().isEmpty) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Please enter cheque number'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
      if (_chequeDate == null) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Please select cheque date'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final amountText = _amountController.text.trim();
      if (amountText.isEmpty) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Please enter payment amount'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      double? amountValue = double.tryParse(amountText);
      if (amountValue == null ||
          amountValue.isNaN ||
          amountValue.isInfinite ||
          amountValue == 0) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Invalid payment amount'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
      final isBalanceAddition = amountValue < 0;
      final amount = amountValue.abs();

      final supplierBefore =
          await ref.read(supplierByIdProvider(widget.supplierId).future);
      if (supplierBefore == null) {
        throw Exception('Supplier not found');
      }

      int? paymentId;
      final baseNoteText = _noteController.text.trim();
      final paymentNote = _selectedPaymentMethod == PaymentMethod.cheque
          ? 'Cheque #${_chequeNumberController.text.trim()} - ${baseNoteText.isEmpty ? 'Pending' : baseNoteText}'
          : (baseNoteText.isEmpty ? null : baseNoteText);
      final otherName = _otherNameController.text.trim();
      String? storedNote = paymentNote;
      if (otherName.isNotEmpty) {
        final noteParts = <String>[];
        if (storedNote != null && storedNote.trim().isNotEmpty) {
          noteParts.add(storedNote.trim());
        }
        noteParts.add('Other Name: $otherName');
        storedNote = noteParts.join(' | ');
      }

      final effectiveMethod = _paymentMethodToString(
        isBalanceAddition ? PaymentMethod.cash : _selectedPaymentMethod,
      );

      // Get current user for createdBy field
      final currentUser = ref.read(authProvider).currentUser;
      final createdByName = currentUser?.name ?? 'Unknown';

      final payment = SupplierPaymentModel(
        supplierId: widget.supplierId,
        amount: isBalanceAddition ? -amount : amount,
        paymentMethod: effectiveMethod,
        paymentType: 'payment',
        date: DateTime.now(),
        reference: _selectedPaymentMethod == PaymentMethod.cheque
            ? _chequeNumberController.text.trim()
            : null,
        chequeDate:
            _selectedPaymentMethod == PaymentMethod.cheque ? _chequeDate : null,
        issueDate: DateTime.now(),
        note: storedNote,
        otherName: otherName.isEmpty ? null : otherName,
        createdBy: createdByName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final paymentNotifier =
          ref.read(supplierPaymentsProvider(widget.supplierId).notifier);
      try {
        paymentId = await paymentNotifier.addPayment(payment);
        if (paymentId <= 0) {
          throw Exception('Failed to create payment record');
        }
      } catch (e) {
        setState(() => _isLoading = false);
        rethrow;
      }

      // If it's a bank transfer or cheque, also record it in the banking system
      if (!isBalanceAddition &&
          (_selectedPaymentMethod == PaymentMethod.bankTransfer ||
              _selectedPaymentMethod == PaymentMethod.cheque) &&
          _selectedBank != null) {
        try {
          final bankCheck =
              await ref.read(bankByIdProvider(_selectedBank!.id!).future);
          if (bankCheck == null) {
            throw Exception('Bank account not found');
          }

          final bankPayment = BankPaymentModel(
            bankId: bankCheck.id!,
            partyName: supplierBefore.name,
            otherName: otherName.isNotEmpty ? otherName : supplierBefore.phone,
            amount: amount,
            paymentType: _selectedPaymentMethod == PaymentMethod.cheque
                ? 'cheque'
                : 'deposit',
            chequeNumber: _selectedPaymentMethod == PaymentMethod.cheque
                ? _chequeNumberController.text.trim()
                : null,
            chequeDate: _selectedPaymentMethod == PaymentMethod.cheque
                ? _chequeDate
                : null,
            issueDate: DateTime.now(),
            paidDate: _selectedPaymentMethod == PaymentMethod.cheque
                ? (_chequeDate ?? DateTime.now())
                : DateTime.now(),
            previousBalance: bankCheck.currentBalance,
            newBalance: bankCheck.currentBalance + amount,
            notes: _selectedPaymentMethod == PaymentMethod.cheque
                ? 'Supplier cheque payment (${_chequeNumberController.text.trim()}): ${baseNoteText.isEmpty ? 'No notes' : baseNoteText}'
                : 'Supplier payment: ${baseNoteText.isEmpty ? 'No notes' : baseNoteText}',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await ref
              .read(bankPaymentsProvider(bankCheck.id!).notifier)
              .addPayment(bankPayment);

          // Update bank balance for bank transfers and cheques
          if (_selectedPaymentMethod == PaymentMethod.bankTransfer ||
              _selectedPaymentMethod == PaymentMethod.cheque) {
            final bankBeforeUpdate =
                await ref.read(bankByIdProvider(bankCheck.id!).future);
            if (bankBeforeUpdate != null) {
              final updatedBank = bankBeforeUpdate.copyWith(
                currentBalance: bankBeforeUpdate.currentBalance + amount,
                updatedAt: DateTime.now(),
              );
              await ref
                  .read(bankNotifierProvider.notifier)
                  .updateBank(updatedBank);
            }
          }

          // For cheques: add amount to unclearCheque to track pending cheque
          if (_selectedPaymentMethod == PaymentMethod.cheque) {
            final currentSupplier =
                await ref.read(supplierByIdProvider(widget.supplierId).future);
            if (currentSupplier != null) {
              final updatedSupplier = currentSupplier.copyWith(
                unclearCheque: currentSupplier.unclearCheque + amount,
                updatedAt: DateTime.now(),
              );
              await ref
                  .read(supplierNotifierProvider.notifier)
                  .updateSupplier(updatedSupplier);
              ref.invalidate(supplierByIdProvider(widget.supplierId));
            }
          }

          ref.invalidate(allBankPaymentsProvider);
        } catch (e) {
          debugPrint('Warning: Bank payment record failed: $e');
        }
      }

      // Invalidate providers to refresh data
      ref.invalidate(supplierNotifierProvider);
      ref.invalidate(supplierNotifierProvider);
      ref.invalidate(supplierByIdProvider(widget.supplierId));
      ref.invalidate(supplierPaymentsProvider(widget.supplierId));
      // Trigger overview payments refresh so Party Payment / Party Balance updates instantly
      ref.read(paymentsRefreshTickProvider.notifier).state++;

      final currency = ref.read(currentCurrencyProvider);
      if (mounted) {
        final effectiveMethod =
            isBalanceAddition ? PaymentMethod.cash : _selectedPaymentMethod;
        final receiptData = _PaymentReceiptData(
          supplierName: supplierBefore.name,
          otherName: otherName.isEmpty ? null : otherName,
          amount: amount,
          method: effectiveMethod,
          date: DateTime.now(),
          note: baseNoteText.isEmpty ? null : baseNoteText,
          isBalanceAddition: isBalanceAddition,
        );

        setState(() {
          _lastReceipt = receiptData;
          _canPrint = true;
          _enteredAmount = 0.0;
          _amountController.clear();
          _noteController.clear();
          _otherNameController.clear();
          _chequeNumberController.clear();
          _chequeDate = null;
          _selectedBank = null;
          _selectedPaymentMethod = PaymentMethod.cash;
        });

        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              isBalanceAddition
                  ? 'Balance increased by ${currency.symbol}${amount.toStringAsFixed(2)}'
                  : 'Payment of ${currency.symbol}${amount.toStringAsFixed(2)} recorded successfully!',
            ),
            backgroundColor: isBalanceAddition ? Colors.blue : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error recording payment: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handlePrint(Currency currency) async {
    final receipt = _lastReceipt;
    if (receipt == null) {
      AppSnackBar.show(
        context,
        const SnackBar(
          content: Text('Record a payment before printing.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    await _printPaymentReceipt(receipt, currency);
  }

  Future<void> _printPaymentReceipt(
    _PaymentReceiptData receipt,
    Currency currency,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Supplier Payment Receipt',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            _buildReceiptRow('Supplier Name', receipt.supplierName),
            if (receipt.otherName != null && receipt.otherName!.isNotEmpty)
              _buildReceiptRow('Other Name', receipt.otherName!),
            _buildReceiptRow('Type',
                receipt.isBalanceAddition ? 'Balance Addition' : 'Payment'),
            _buildReceiptRow('Amount',
                '${currency.symbol}${receipt.amount.toStringAsFixed(2)}'),
            _buildReceiptRow(
                'Date', DateFormat('dd/MM/yyyy • hh:mm a').format(receipt.date)),
            _buildReceiptRow(
                'Payment Method', receipt.method.name.toUpperCase()),
            if (receipt.note != null && receipt.note!.isNotEmpty)
              _buildReceiptRow('Notes', receipt.note!),
            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Thank you!',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _buildReceiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }
}

class _PaymentReceiptData {
  final String supplierName;
  final String? otherName;
  final double amount;
  final PaymentMethod method;
  final DateTime date;
  final String? note;
  final bool isBalanceAddition;

  const _PaymentReceiptData({
    required this.supplierName,
    required this.otherName,
    required this.amount,
    required this.method,
    required this.date,
    this.note,
    this.isBalanceAddition = false,
  });
}
