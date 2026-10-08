import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/customer_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../models/customer.dart';
import '../utils/input_formatters.dart';
import '../utils/mobile_optimization.dart';
import '../utils/touch_optimization.dart';
import '../widgets/app_snack_bar.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  final int? customerId;

  const AddCustomerScreen({super.key, this.customerId});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _creditDaysController = TextEditingController();

  // FocusNodes for Enter key navigation (Windows-style)
  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  final _creditLimitFocusNode = FocusNode();
  final _creditDaysFocusNode = FocusNode();

  bool _isLoading = false;
  CustomerModel? _existingCustomer;
  bool _isRetailCustomer = true;
  bool _isWholesaleCustomer = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();

    if (widget.customerId != null) {
      _loadCustomer();
    }
  }

  Future<void> _loadCustomer() async {
    final customer =
        await ref.read(customerByIdProvider(widget.customerId!).future);
    if (customer != null) {
      if (mounted) {
        setState(() {
          _existingCustomer = customer;
          _nameController.text = customer.name;
          _phoneController.text = customer.phone;
          _addressController.text = customer.address ?? '';
          _creditLimitController.text = customer.creditLimit.toStringAsFixed(2);
          _creditDaysController.text = customer.creditDays.toString();
          _isRetailCustomer = customer.isRetailCustomer;
          _isWholesaleCustomer = customer.isWholesaleCustomer;
          _isActive = customer.isActive;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _creditLimitController.dispose();
    _creditDaysController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    _creditLimitFocusNode.dispose();
    _creditDaysFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobileDevice = MobileOptimization.isMobile(context);
    
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.customerId == null ? 'Add Customer' : 'Edit Customer'),
        leading: MobileOptimization.mobileIconButton(
          icon: Icons.arrow_back,
          onPressed: () {
            if (mounted) {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/customers');
              }
            }
          },
        ),
        actions: [
          if (widget.customerId != null)
            MobileOptimization.mobileIconButton(
              icon: Icons.delete,
              onPressed: _showDeleteDialog,
              tooltip: 'add_customer_scr.delete_tooltip'.tr(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : MobileOptimization.keyboardAwareForm(
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: MobileOptimization.getResponsivePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBasicInfoSection(),
                      SizedBox(
                        height: MobileOptimization.getFormFieldSpacing(context),
                      ),
                    _buildActionButtons(),
                  ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBasicInfoSection() {
    final isMobileDevice = MobileOptimization.isMobile(context);
    final fieldSpacing = MobileOptimization.getFormFieldSpacing(context);
    
    return Card(
      child: Padding(
        padding: MobileOptimization.getCardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: MobileOptimization.getResponsiveFontSize(
                  context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
              ),
            ),
            SizedBox(height: fieldSpacing),
            TextFormField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              decoration: InputDecoration(
                labelText: 'Customer Name',
                hintText: 'Enter customer name',
                contentPadding: MobileOptimization.getTextFieldPadding(context),
              ),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(),
            ),
            SizedBox(height: fieldSpacing),
            TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter phone number',
                contentPadding: MobileOptimization.getTextFieldPadding(context),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _addressFocusNode.requestFocus(),
              inputFormatters: [
                NumericPhoneInputFormatter(),
                LengthLimitingTextInputFormatter(15), // Limit to 15 digits
              ],
            ),
            SizedBox(height: fieldSpacing),
            TextFormField(
              controller: _addressController,
              focusNode: _addressFocusNode,
              decoration: InputDecoration(
                labelText: 'Address (Optional)',
                hintText: 'Enter customer address',
                contentPadding: MobileOptimization.getTextFieldPadding(context),
              ),
              maxLines: isMobileDevice ? 3 : 2,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _creditLimitFocusNode.requestFocus(),
            ),
            SizedBox(height: fieldSpacing),
            isMobileDevice
                ? Column(
                    children: [
                      TextFormField(
                        controller: _creditLimitController,
                        focusNode: _creditLimitFocusNode,
                        decoration: InputDecoration(
                          labelText: 'Credit Limit',
                          hintText: 'Enter credit limit',
                          prefixText: ref.watch(currentCurrencyProvider).symbol,
                          helperText: 'Maximum amount',
                          contentPadding:
                              MobileOptimization.getTextFieldPadding(context),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            _creditDaysFocusNode.requestFocus(),
                        inputFormatters: [
                          DecimalInputFormatter(maxDecimalPlaces: 2),
                        ],
                      ),
                      SizedBox(height: fieldSpacing),
                      TextFormField(
                        controller: _creditDaysController,
                        focusNode: _creditDaysFocusNode,
                        decoration: InputDecoration(
                          labelText: 'Credit Days',
                          hintText: 'Enter credit days',
                          helperText: 'Payment period',
                          prefixIcon: const Icon(Icons.calendar_today),
                          contentPadding:
                              MobileOptimization.getTextFieldPadding(context),
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).unfocus(),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ],
                  )
                : Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _creditLimitController,
                    focusNode: _creditLimitFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Credit Limit',
                      hintText: 'Enter credit limit',
                      prefixText: ref.watch(currentCurrencyProvider).symbol,
                      helperText: 'Maximum amount',
                            contentPadding:
                                MobileOptimization.getTextFieldPadding(context),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _creditDaysFocusNode.requestFocus(),
                    inputFormatters: [
                      DecimalInputFormatter(maxDecimalPlaces: 2),
                    ],
                  ),
                ),
                      SizedBox(
                        width: MobileOptimization.getResponsiveSpacing(
                          context,
                          mobile: 12,
                          tablet: 16,
                          desktop: 16,
                        ),
                      ),
                Expanded(
                  child: TextFormField(
                    controller: _creditDaysController,
                    focusNode: _creditDaysFocusNode,
                          decoration: InputDecoration(
                      labelText: 'Credit Days',
                      hintText: 'Enter credit days',
                      helperText: 'Payment period',
                            prefixIcon: const Icon(Icons.calendar_today),
                            contentPadding:
                                MobileOptimization.getTextFieldPadding(context),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) =>
                              FocusScope.of(context).unfocus(),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: fieldSpacing),
            Text(
              'Customer Type',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('add_customer_scr.retail'.tr()),
                    value: _isRetailCustomer,
                    onChanged: (value) {
                      setState(() {
                        _isRetailCustomer = value ?? false;
                        if (!_isRetailCustomer && !_isWholesaleCustomer) {
                          _isWholesaleCustomer = true;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('add_customer_scr.wholesale'.tr()),
                    value: _isWholesaleCustomer,
                    onChanged: (value) {
                      setState(() {
                        _isWholesaleCustomer = value ?? false;
                        if (!_isWholesaleCustomer && !_isRetailCustomer) {
                          _isRetailCustomer = true;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_existingCustomer != null &&
                _existingCustomer!.totalDue != 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _existingCustomer!.totalDue < 0
                      ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                      : Colors.orange.shade50,
                  border: Border.all(
                    color: _existingCustomer!.totalDue < 0
                        ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                        : Colors.orange.shade200,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: _existingCustomer!.totalDue < 0
                          ? const Color(0xFF2563EB)
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_existingCustomer!.totalDue < 0 ? 'Credit Balance' : 'Outstanding Balance'}: ${ref.read(currentCurrencyProvider).symbol}${_existingCustomer!.totalDue.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          color: _existingCustomer!.totalDue < 0
                              ? const Color(0xFF2563EB)
                              : Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('add_customer_scr.active'.tr()),
              subtitle: const Text(
                  'Inactive customers are hidden from customer lists.'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isMobileDevice = MobileOptimization.isMobile(context);
    
    return isMobileDevice
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MobileOptimization.mobileButton(
                onPressed: _isLoading ? null : _saveCustomer,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.customerId == null
                            ? 'Add Customer'
                            : 'Update Customer',
                      ),
                isFullWidth: true,
              ),
              SizedBox(
                height: MobileOptimization.getFormFieldSpacing(context),
              ),
              OutlinedButton(
                onPressed: _handleCancel,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(
                    double.infinity,
                    MobileOptimization.isMobile(context)
                        ? TouchOptimization.recommendedTouchTarget
                        : 40,
                  ),
                  padding: MobileOptimization.isMobile(context)
                      ? TouchOptimization.getTouchPadding()
                      : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text('common.cancel'.tr()),
              ),
            ],
          )
        : Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _handleCancel,
            child: Text('common.cancel'.tr()),
          ),
        ),
              SizedBox(
                width: MobileOptimization.getResponsiveSpacing(
                  context,
                  mobile: 12,
                  tablet: 16,
                  desktop: 16,
                ),
              ),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveCustomer,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.customerId == null
                    ? 'Add Customer'
                    : 'Update Customer'),
          ),
        ),
      ],
    );
  }

  void _handleCancel() {
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/customers');
      }
    }
  }

  Future<void> _saveCustomer() async {
    // Check permissions
    final authState = ref.read(authProvider);
    final currentUser = authState.currentUser;
    
    if (widget.customerId == null) {
      // Adding new customer
      if (currentUser?.canAddCustomer() != true) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('You do not have permission to add customers.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } else {
      // Editing existing customer
      if (currentUser?.canEditCustomer() != true) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('You do not have permission to edit customers.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    // Remove validation check to prevent errors
    // Basic check for empty name/phone
    if (_nameController.text.trim().isEmpty &&
        _phoneController.text.trim().isEmpty) {
      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Please enter at least name or phone number'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!_isRetailCustomer && !_isWholesaleCustomer) {
      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text(
                'Select at least one customer type (retail or wholesale).'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (widget.customerId == null) {
      // Prevent duplicate customer names when adding a new customer
      final enteredName = _nameController.text.trim();
      if (enteredName.isNotEmpty) {
        try {
          final existingCustomers = await ref.read(customersProvider.future);
          final hasDuplicate = existingCustomers.any(
            (c) => c.name.trim().toLowerCase() == enteredName.toLowerCase(),
          );
          if (hasDuplicate) {
            if (mounted) {
              AppSnackBar.show(
                context,
                const SnackBar(
                  content: Text(
                      'A customer with this name already exists. Please use a different name.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
        } catch (_) {
          // If there is an error loading customers, fall through and let save continue
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final creditLimit =
          double.tryParse(_creditLimitController.text.trim()) ?? 0.0;
      final creditDays = int.tryParse(_creditDaysController.text.trim()) ?? 0;

      final customer = CustomerModel(
        id: _existingCustomer?.id,
        name: _nameController.text.trim().isEmpty
            ? 'Unknown'
            : _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? '0000000'
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        totalDue: _existingCustomer?.totalDue ?? 0,
        creditLimit: creditLimit,
        creditDays: creditDays,
        isRetailCustomer: _isRetailCustomer,
        isWholesaleCustomer: _isWholesaleCustomer,
        isActive: _isActive,
        createdAt: _existingCustomer?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final customerNotifier = ref.read(customerNotifierProvider.notifier);

      if (widget.customerId == null) {
        await customerNotifier.addCustomer(customer);
        // Invalidate all customer-related providers to refresh the UI
        ref.invalidate(customersProvider);
        ref.invalidate(customersWithDueProvider);
        ref.invalidate(customerNotifierProvider);
        if (mounted) {
          // Show immediate toast message
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Customer added successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          );
        }
      } else {
        await customerNotifier.updateCustomer(customer);
        // Invalidate all customer-related providers to refresh the UI
        ref.invalidate(customersProvider);
        ref.invalidate(customersWithDueProvider);
        ref.invalidate(customerNotifierProvider);
        ref.invalidate(customerByIdProvider(widget.customerId!));
        if (mounted) {
          // Show immediate toast message
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Customer updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          );
        }
      }

      // Navigate back after a short delay to show the toast
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/customers');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDeleteDialog() {
    final isMobileDevice = MobileOptimization.isMobile(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('add_customer_scr.delete_title'.tr()),
        content: SingleChildScrollView(
          child: Text(
            'add_customer_scr.delete_confirm_body'.tr(namedArgs: {
              'name': _nameController.text,
            }),
          ),
        ),
        contentPadding: MobileOptimization.getDialogPadding(context),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(
              minimumSize: Size(
                0,
                isMobileDevice
                    ? TouchOptimization.recommendedTouchTarget
                    : 40,
              ),
              padding: isMobileDevice
                  ? TouchOptimization.getTouchPadding()
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              if (mounted) {
                Navigator.pop(context);
                setState(() => _isLoading = true);
              }

              try {
                final customerNotifier =
                    ref.read(customerNotifierProvider.notifier);
                await customerNotifier.deleteCustomer(widget.customerId!);

                // Invalidate related providers - notifier already refreshed itself
                ref.invalidate(customersProvider);
                ref.invalidate(customersWithDueProvider);
                ref.invalidate(customerByIdProvider(widget.customerId!));

                if (mounted) {
                  AppSnackBar.show(
                    context,
                    const SnackBar(
                        content: Text('Customer deleted successfully')),
                  );
                  if (mounted) {
                    context.pop();
                  }
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.show(
                    context,
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            style: TextButton.styleFrom(
              minimumSize: Size(
                0,
                isMobileDevice
                    ? TouchOptimization.recommendedTouchTarget
                    : 40,
              ),
              padding: isMobileDevice
                  ? TouchOptimization.getTouchPadding()
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text('common.delete'.tr(),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
        actionsPadding: MobileOptimization.getDialogPadding(context),
      ),
    );
  }
}
