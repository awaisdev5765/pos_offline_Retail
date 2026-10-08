import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/bank_provider.dart';
import '../models/bank.dart';
import '../models/bank_payment.dart';
import '../providers/currency_provider.dart';
import '../models/currency.dart';
import '../providers/payment_provider.dart';
import '../widgets/app_snack_bar.dart';

class BankPaymentScreen extends ConsumerStatefulWidget {
  final int? bankId;

  const BankPaymentScreen({super.key, this.bankId});

  @override
  ConsumerState<BankPaymentScreen> createState() => _BankPaymentScreenState();
}

class _BankPaymentScreenState extends ConsumerState<BankPaymentScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _partyNameController = TextEditingController();
  final _otherNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _chequeNumberController = TextEditingController();
  final _notesController = TextEditingController();

  // Form state
  BankModel? _selectedBank;
  String _selectedPaymentType = 'cheque';
  DateTime _issueDate = DateTime.now();
  DateTime _paidDate = DateTime.now();
  DateTime? _chequeDate;
  double _previousBalance = 0.0;
  double _newBalance = 0.0;
  bool _isLoading = false;

  @override
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

    // Load bank after frame is built
    if (widget.bankId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final bank = await ref.read(bankByIdProvider(widget.bankId!).future);
        if (bank != null && mounted) {
          setState(() {
            _selectedBank = bank;
            _previousBalance = bank.currentBalance;
            _newBalance = bank.currentBalance;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _partyNameController.dispose();
    _otherNameController.dispose();
    _amountController.dispose();
    _chequeNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadBank() async {
    if (widget.bankId == null) return;

    final bank = await ref.read(bankByIdProvider(widget.bankId!).future);
    if (bank != null) {
      if (mounted) {
        setState(() {
          _selectedBank = bank;
          _previousBalance = bank.currentBalance;
          _newBalance = bank.currentBalance;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;
    final currency = ref.watch(currentCurrencyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildPaymentForm(isMobile, currency),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          if (mounted) {
            context.pop();
          }
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.payment,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PARTY BANK PAYMENT',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Roboto',
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Record bank payment and cheques',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentForm(bool isMobile, Currency currency) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 24),

            // Two column layout
            Row(
              children: [
                // Left Column
                Expanded(
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _partyNameController,
                        label: 'Party Name',
                        hint: 'Enter party name',
                        icon: Icons.business,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Party name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _otherNameController,
                        label: 'Other Name',
                        hint: 'Enter other name',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 16),
                      _buildBankDropdown(),
                      const SizedBox(height: 16),
                      if (_selectedPaymentType == 'cheque') ...[
                        _buildTextField(
                          controller: _chequeNumberController,
                          label: 'Cheq No',
                          hint: 'Enter cheque number',
                          icon: Icons.receipt,
                        ),
                        const SizedBox(height: 16),
                        _buildDateField(
                          label: 'Cheq Date',
                          value: _chequeDate,
                          onChanged: (date) {
                            if (mounted) {
                              setState(() {
                                _chequeDate = date;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Right Column
                Expanded(
                  child: Column(
                    children: [
                      _buildDateField(
                        label: 'Paid Date',
                        value: _paidDate,
                        onChanged: (date) {
                          if (date != null) {
                            if (mounted) {
                              setState(() {
                                _paidDate = date;
                              });
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: TextEditingController(
                            text: _previousBalance.toStringAsFixed(2)),
                        label: 'Previous Balance',
                        hint: 'Previous balance',
                        icon: Icons.account_balance_wallet,
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _amountController,
                        label: _selectedPaymentType == 'cheque'
                            ? 'Cheq Amount'
                            : 'Amount',
                        hint: 'Enter amount',
                        icon: Icons.monetization_on,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Amount is required';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          final amount = double.tryParse(value) ?? 0.0;
                          if (mounted) {
                            setState(() {
                              _newBalance = _previousBalance + amount;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: TextEditingController(
                            text: _newBalance.toStringAsFixed(2)),
                        label: 'New Balance',
                        hint: 'New balance',
                        icon: Icons.account_balance,
                        enabled: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Payment Type Selection
            _buildPaymentTypeSelection(),
            const SizedBox(height: 24),

            // Issue Date
            _buildDateField(
              label: 'Issue Date',
              value: _issueDate,
              onChanged: (date) {
                if (date != null) {
                  if (mounted) {
                    setState(() {
                      _issueDate = date;
                    });
                  }
                }
              },
            ),
            const SizedBox(height: 16),

            // Notes
            _buildTextField(
              controller: _notesController,
              label: 'Notes',
              hint: 'Enter any additional notes',
              icon: Icons.note,
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _savePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
                            'SAVE',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    int maxLines = 1,
    bool enabled = true,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          maxLines: maxLines,
          enabled: enabled,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            filled: true,
            fillColor:
                enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
          ),
        ),
      ],
    );
  }

  Widget _buildBankDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bank',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<BankModel>(
          value: _selectedBank,
          items: ref.watch(activeBanksProvider).when(
                data: (banks) => banks
                    .map((bank) => DropdownMenuItem(
                          value: bank,
                          child: Text(bank.name),
                        ))
                    .toList(),
                loading: () =>
                    [const DropdownMenuItem(child: Text('Loading...'))],
                error: (error, stack) => [
                  const DropdownMenuItem(child: Text('Error loading banks'))
                ],
              ),
          onChanged: (bank) {
            if (mounted) {
              setState(() {
                _selectedBank = bank;
                if (bank != null) {
                  _previousBalance = bank.currentBalance;
                  _newBalance = bank.currentBalance;
                }
              });
            }
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              onChanged(date);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFF8FAFC),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    color: const Color(0xFF3B82F6), size: 18),
                const SizedBox(width: 8),
                Text(
                  value != null
                      ? '${value.day}-${value.month}-${value.year}'
                      : 'Select date',
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: Text('banking.payment_type_cheque'.tr()),
                value: 'cheque',
                groupValue: _selectedPaymentType,
                onChanged: (value) {
                  if (mounted) {
                    setState(() {
                      _selectedPaymentType = value!;
                    });
                  }
                },
                activeColor: const Color(0xFF3B82F6),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: Text('banking.payment_type_transfer'.tr()),
                value: 'transfer',
                groupValue: _selectedPaymentType,
                onChanged: (value) {
                  if (mounted) {
                    setState(() {
                      _selectedPaymentType = value!;
                    });
                  }
                },
                activeColor: const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleCancel() {
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/banking-system');
      }
    }
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBank == null) {
      AppSnackBar.show(
        context,
        const SnackBar(
          content: Text('Please select a bank'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final payment = BankPaymentModel(
        bankId: _selectedBank!.id!,
        partyName: _partyNameController.text.trim(),
        otherName: _otherNameController.text.trim().isEmpty
            ? null
            : _otherNameController.text.trim(),
        amount: double.parse(_amountController.text),
        paymentType: _selectedPaymentType,
        chequeNumber: _chequeNumberController.text.trim().isEmpty
            ? null
            : _chequeNumberController.text.trim(),
        chequeDate: _chequeDate,
        issueDate: _issueDate,
        paidDate: _paidDate,
        previousBalance: _previousBalance,
        newBalance: _newBalance,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref
          .read(bankPaymentsProvider(_selectedBank!.id!).notifier)
          .addPayment(payment);

      // Refresh the all bank payments provider to update the banking system screen
      ref.invalidate(allBankPaymentsProvider);
      // Trigger overview payments refresh so Party Payment updates instantly
      ref.read(paymentsRefreshTickProvider.notifier).state++;

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Bank payment recorded successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/banking-system');
          }
        }
      }
    } catch (error) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error recording payment: $error'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
