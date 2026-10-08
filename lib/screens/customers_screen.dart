import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/customer_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../models/customer.dart';
import '../models/currency.dart';
import '../theme/app_theme.dart';
import '../services/excel_export_service.dart';
import '../services/bulk_import_service.dart';
import '../services/database_service.dart';
import '../utils/navigation_helper.dart';
import '../utils/modern_dialog_builder.dart';
import '../utils/haptic_feedback_util.dart';
import 'customer_payment_screen.dart';
import '../widgets/app_snack_bar.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerNotifierProvider);
    final customerNotifier = ref.read(customerNotifierProvider.notifier);
    final currency = ref.watch(currentCurrencyProvider);
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('nav.customers'.tr()),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            tooltip: 'Import (.xlsx)',
            icon: const Icon(Icons.upload_file),
            onPressed: _handleImportCustomers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          _buildSearchAndFilterBar(isDarkMode),
          // Customers Data
          Expanded(
            child: customersAsync.when(
              data: (customers) {
                final filteredCustomers = _filterCustomers(customers);
                return _buildCustomersTable(
                    context, filteredCustomers, customerNotifier, currency);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading customers: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => customerNotifier.refresh(),
                      child: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer(
        builder: (context, ref, child) {
          final authState = ref.watch(authProvider);
          final currentUser = authState.currentUser;
          final canAdd = currentUser?.canAddCustomer() ?? false;
          
          if (!canAdd) return const SizedBox.shrink();
          
          return FloatingActionButton(
        onPressed: () => context.go('/add-customer'),
        backgroundColor: AppColors.primaryColor,
        heroTag: "customers_fab",
        child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilterBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode
                ? AppColors.borderColor.withValues(alpha: 0.3)
                : AppColors.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or address...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primaryColor, width: 2),
                ),
                filled: true,
                fillColor:
                    isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _selectedFilter == 'all'
                  ? AppColors.primaryColor
                  : (isDarkMode ? AppColors.surfaceDark : AppColors.hoverColor),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderColor, width: 1),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                isDense: true,
                style: TextStyle(
                  color: _selectedFilter == 'all'
                      ? Colors.white
                      : (isDarkMode
                          ? AppColors.textPrimary
                          : AppColors.textPrimary),
                  fontSize: 14,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Customers')),
                  DropdownMenuItem(
                      value: 'active', child: Text('Active Customers')),
                  DropdownMenuItem(
                      value: 'inactive', child: Text('Inactive Customers')),
                  DropdownMenuItem(
                      value: 'outstanding', child: Text('Outstanding Balance')),
                  DropdownMenuItem(
                      value: 'paid', child: Text('No Outstanding')),
                  DropdownMenuItem(
                      value: 'credit', child: Text('Credit Balance')),
                  DropdownMenuItem(
                      value: 'retail', child: Text('Retail Customers')),
                  DropdownMenuItem(
                      value: 'wholesale', child: Text('Wholesale Customers')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value ?? 'all';
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<CustomerModel> _filterCustomers(List<CustomerModel> customers) {
    return customers.where((customer) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final matchesSearch = customer.name
                .toLowerCase()
                .contains(searchLower) ||
            customer.phone.toLowerCase().contains(searchLower) ||
            (customer.address?.toLowerCase().contains(searchLower) ?? false);
        if (!matchesSearch) return false;
      }

      // Status filter
      // Active/Inactive filters
      if (_selectedFilter == 'active' && !customer.isActive) return false;
      if (_selectedFilter == 'inactive' && customer.isActive) return false;
      
      // Other filters
      if (_selectedFilter == 'outstanding' && !customer.hasOutstandingBalance)
        return false;
      if (_selectedFilter == 'paid' && customer.totalDue.abs() > 0.0001)
        return false;
      if (_selectedFilter == 'credit' && !customer.hasCredit) return false;
      if (_selectedFilter == 'retail' && !customer.isRetailCustomer)
        return false;
      if (_selectedFilter == 'wholesale' && !customer.isWholesaleCustomer)
        return false;

      return true;
    }).toList();
  }

  Widget _buildCustomersTable(
      BuildContext context,
      List<CustomerModel> customers,
      CustomerNotifier customerNotifier,
      Currency currency) {
    if (customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people, size: 64, color: Color(0xFF64748B)),
            const SizedBox(height: 16),
            const Text(
              'No customers found',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first customer to get started',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 24),
            Consumer(
              builder: (context, ref, child) {
                final authState = ref.watch(authProvider);
                final currentUser = authState.currentUser;
                final canAdd = currentUser?.canAddCustomer() ?? false;
                
                if (!canAdd) return const SizedBox.shrink();
                
                return ElevatedButton.icon(
              onPressed: () => context.go('/add-customer'),
              icon: const Icon(Icons.add),
              label: Text('customers.add_customer'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                minimumSize: const Size(160, 44), // 44px minimum touch target
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
                );
              },
            ),
          ],
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;

    return RefreshIndicator(
      onRefresh: () async => customerNotifier.refresh(),
      child: isMobile
          ? _buildCustomersCardView(
              context, customers, customerNotifier, currency)
          : _buildCustomersCustomTable(
              context, customers, customerNotifier, currency),
    );
  }

  Widget _buildCustomersCardView(
      BuildContext context,
      List<CustomerModel> customers,
      CustomerNotifier customerNotifier,
      Currency currency) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        final bool isOutstanding = customer.hasOutstandingBalance;
        final bool hasCredit = customer.hasCredit;
        final Color statusColor = isOutstanding
            ? AppColors.khata
            : (hasCredit ? const Color(0xFF2563EB) : const Color(0xFF10B981));
        final String statusLabel =
            isOutstanding ? 'Outstanding' : (hasCredit ? 'Credit' : 'Settled');
        final Color borderColor = (isOutstanding || hasCredit)
            ? statusColor.withValues(alpha: 0.3)
            : const Color(0xFFE5E7EB);
        final double borderWidth = (isOutstanding || hasCredit) ? 2 : 1;
        final String balanceTitle = isOutstanding
            ? 'Outstanding Balance'
            : (hasCredit ? 'Credit Balance' : 'Balance');
        final double balanceAmount = customer.totalDue.abs();
        final String balanceDisplay =
            '${currency.symbol}${balanceAmount.toStringAsFixed(2)}';
        
        // Check permissions for swipe actions
        final authState = ref.read(authProvider);
        final currentUser = authState.currentUser;
        final canDelete = currentUser?.canDeleteCustomer() ?? false;
        final canEdit = currentUser?.canEditCustomer() ?? false;
        
        Widget cardWidget = Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: borderColor,
              width: borderWidth,
            ),
          ),
          child: InkWell(
            onTap: () => context.go('/customer-ledger?id=${customer.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: statusColor,
                        child: Text(
                          customer.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    customer.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: customer.isActive 
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFF94A3B8),
                                      decoration: customer.isActive 
                                          ? null 
                                          : TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                                if (!customer.isActive) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF94A3B8).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF94A3B8), width: 1),
                                    ),
                                    child: const Text(
                                      'Inactive',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (customer.phone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone,
                                      size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    customer.phone,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (customer.address?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            customer.address!,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (customer.isRetailCustomer ||
                      customer.isWholesaleCustomer) ...[
                    const SizedBox(height: 12),
                    _buildCustomerTypeBadges(customer),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            balanceTitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            balanceDisplay,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.go('/customer-ledger?id=${customer.id}'),
                        icon: const Icon(Icons.receipt_long, size: 18),
                        label: Text('ledger.view_ledger'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize:
                              const Size(120, 44), // 44px minimum touch target
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        
        // Wrap with Dismissible if user has delete permission
        if (canDelete) {
          return Dismissible(
            key: Key('customer_${customer.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
                size: 28,
              ),
            ),
            secondaryBackground: canEdit
                ? Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 28,
                    ),
                  )
                : null,
            confirmDismiss: (direction) async {
              HapticFeedbackUtil.medium();
              if (direction == DismissDirection.endToStart) {
                // Delete action
                return await _confirmDeleteCustomer(context, customer, customerNotifier);
              } else if (direction == DismissDirection.startToEnd && canEdit) {
                // Edit action
                HapticFeedbackUtil.light();
                context.go('/edit-customer?id=${customer.id}');
                return false; // Don't dismiss, just navigate
              }
              return false;
            },
            onDismissed: (direction) {
              if (direction == DismissDirection.endToStart) {
                HapticFeedbackUtil.success();
              }
            },
            child: cardWidget,
          );
        }
        
        return cardWidget;
      },
    );
  }

  Future<bool> _confirmDeleteCustomer(
      BuildContext context, CustomerModel customer, CustomerNotifier customerNotifier) async {
    final result = await ModernDialogBuilder.showConfirmDialog(
      context: context,
      title: 'Delete Customer',
      message:
          'Are you sure you want to delete "${customer.name}"?\n\nThis will permanently delete:\n• All associated sales\n• All associated payments\n• The customer record\n\nStock will be restored for all sold items.\n\nThis action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      icon: Icons.delete_outline,
    );

    if (result == true) {
      try {
        await customerNotifier.deleteCustomer(customer.id!);
        ref.invalidate(customersProvider);
        ref.invalidate(customersWithDueProvider);
        ref.invalidate(customerByIdProvider(customer.id!));
        
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Customer deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return true;
      } catch (e) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Error deleting customer: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return false;
      }
    }
    return false;
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.people_outline,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No customers found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first customer to get started',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 24),
          Consumer(
            builder: (context, ref, child) {
              final authState = ref.watch(authProvider);
              final currentUser = authState.currentUser;
              final canAdd = currentUser?.canAddCustomer() ?? false;
              
              if (!canAdd) return const SizedBox.shrink();
              
              return ElevatedButton.icon(
            onPressed: () => context.go('/add-customer'),
            icon: const Icon(Icons.add),
            label: Text('customers.add_customer'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportCustomers(List<CustomerModel> customers) async {
    try {
      // Show export options dialog
      final exportOption = await _showExportOptionsDialog();
      if (exportOption == null) return;

      // Get sales data for analysis
      final databaseService = ref.read(databaseServiceProvider);
      final allSales = await databaseService.getAllSales();

      // Show loading dialog
      if (mounted) {
        ModernDialogBuilder.showLoadingDialog(
          context: context,
          message: 'Generating export...',
        );
      }

      String filePath;
      String filename =
          'customer_data_${DateTime.now().millisecondsSinceEpoch}';

      switch (exportOption) {
        case 'excel':
          filePath = await ExcelExportService.exportCustomerDataToExcel(
            customers,
            allSales,
            filename,
            currencySymbol: ref.read(currentCurrencyProvider).symbol,
          );
          break;
        case 'pdf':
          filePath = await ExcelExportService.exportCustomerDataToPDF(
            customers,
            allSales,
            filename,
          );
          break;
        default:
          throw Exception('Invalid export option');
      }

      if (mounted) {
        // Use safe navigation to close the dialog
        NavigationHelper.safeCloseDialog(context);

        // Show success dialog with options
        await _showExportSuccessDialog(filePath, exportOption);
      }
    } catch (e) {
      if (mounted) {
        // Use safe navigation to close the dialog
        NavigationHelper.safeCloseDialog(context);

        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleImportCustomers() async {
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
            context: context, message: 'Importing customers...');
      }

      final databaseService = ref.read(databaseServiceProvider);
      final result = await BulkImportService.importCustomersFromExcel(
          databaseService, file);

      if (mounted) {
        NavigationHelper.safeCloseDialog(context);
        await ModernDialogBuilder.showInfoDialog(
          context: context,
          title: 'Import Completed',
          message:
              'Inserted: ${result.inserted}\nUpdated: ${result.updated}\nSkipped: ${result.skipped}' +
                  (result.errors.isNotEmpty
                      ? '\n\nErrors (first 3):\n${result.errors.take(3).join('\n')}'
                      : ''),
          icon: Icons.cloud_done_outlined,
          iconColor: const Color(0xFF10B981),
          buttonText: 'OK',
        );
      }

      ref.read(customerNotifierProvider.notifier).refresh();
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

  Future<String?> _showExportOptionsDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('customers.export_data'.tr()),
        content: Text('customers.export_prompt'.tr()),
        actions: [
          TextButton(
            onPressed: () => NavigationHelper.safePop(context),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => NavigationHelper.safePop(context, 'excel'),
            child: Text('customers.excel_file'.tr()),
          ),
          TextButton(
            onPressed: () => NavigationHelper.safePop(context, 'pdf'),
            child: Text('customers.pdf_file'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _showExportSuccessDialog(String filePath, String format) async {
    await ModernDialogBuilder.showInfoDialog(
      context: context,
      title: 'Export Successful',
      message:
          'Customer data exported to $format format\n\nFile: ${filePath.split('/').last}',
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF10B981),
      buttonText: 'Close',
    );

    // Trigger share/print actions after dialog
    await Future.delayed(const Duration(milliseconds: 300));

    // Show action options
    final action = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'What would you like to do?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, 'share'),
                      icon: const Icon(Icons.share),
                      label: Text('common.share'.tr()),
                    ),
                  ),
                  if (format == 'pdf') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, 'print'),
                        icon: const Icon(Icons.print),
                        label: Text('common.print'.tr()),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (action == 'share') {
      await ExcelExportService.shareFile(filePath);
    } else if (action == 'print') {
      await ExcelExportService.printFile(filePath);
    }
  }

  void _navigateToPaymentScreen(BuildContext context, CustomerModel customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerPaymentScreen(customerId: customer.id!),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, CustomerModel customer,
      CustomerNotifier customerNotifier) async {
    final result = await ModernDialogBuilder.showConfirmDialog(
      context: context,
      title: 'Delete Customer',
      message:
          'Are you sure you want to delete "${customer.name}"?\n\nThis will permanently delete:\n• All associated sales\n• All associated payments\n• The customer record\n\nStock will be restored for all sold items.\n\nThis action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      icon: Icons.delete_outline,
    );

    if (result == true) {
      try {
        // Delete the customer - this will automatically refresh the notifier's state via _loadCustomers()
        await customerNotifier.deleteCustomer(customer.id!);
        
        // Invalidate related providers to ensure all dependent widgets refresh
        // Note: We don't invalidate customerNotifierProvider itself because it already refreshed internally
        ref.invalidate(customersProvider);
        ref.invalidate(customersWithDueProvider);
        ref.invalidate(customerByIdProvider(customer.id!));
        
        // The state should already be updated by _loadCustomers() in deleteCustomer()
        // The screen is watching customerNotifierProvider, so it will automatically rebuild

        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Customer deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Error deleting customer: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  // ==================== CUSTOM CUSTOMERS TABLE WIDGET ====================
  Widget _buildCustomersCustomTable(
      BuildContext context,
      List<CustomerModel> customers,
      CustomerNotifier customerNotifier,
      Currency currency) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDarkMode ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05),
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
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2A2F36) : const Color(0xFFF3F4F6),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('Customer'),
                ),
                Expanded(
                  child: _buildHeaderCell('Phone'),
                ),
                Expanded(
                  child: _buildHeaderCell('Address'),
                ),
                Expanded(
                  child: _buildHeaderCell('Type'),
                ),
                Expanded(
                  child: _buildHeaderCell('Balance'),
                ),
                Expanded(
                  child: _buildHeaderCell('Status'),
                ),
                Expanded(
                  child: _buildHeaderCell('Actions'),
                ),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: customers.length,
              itemBuilder: (context, index) {
                final customer = customers[index];
                final isEven = index % 2 == 0;
                final bool isOutstanding = customer.hasOutstandingBalance;
                final bool hasCredit = customer.hasCredit;
                final Color statusColor = isOutstanding
                    ? AppColors.khata
                    : (hasCredit
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF10B981));
                final String statusLabel = isOutstanding
                    ? 'Outstanding'
                    : (hasCredit ? 'Credit' : 'Settled');
                final String balanceValue =
                    '${currency.symbol}${customer.totalDue.toStringAsFixed(2)}';

                return Container(
                    decoration: BoxDecoration(
                      color: isEven 
                          ? (isDarkMode ? AppColors.surfaceDark : Colors.white)
                          : (isDarkMode ? const Color(0xFF2A2F36) : const Color(0xFFF9FAFB)),
                      border: Border(
                        bottom: BorderSide(
                          color: isDarkMode ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: InkWell(
                      onTap: () =>
                          context.go('/customer-ledger?id=${customer.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Customer Column
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: statusColor,
                                    child: Text(
                                      customer.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            customer.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: customer.isActive 
                                                  ? (isDarkMode ? Colors.white : const Color(0xFF1E293B))
                                                  : (isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                              fontSize: 12,
                                              decoration: customer.isActive 
                                                  ? null 
                                                  : TextDecoration.lineThrough,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!customer.isActive) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF94A3B8).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFF94A3B8), width: 1),
                                            ),
                                            child: const Text(
                                              'Inactive',
                                              style: TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Phone Column
                            Expanded(
                              child: Text(
                                customer.phone.isNotEmpty
                                    ? customer.phone
                                    : 'N/A',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Address Column
                            Expanded(
                              child: Text(
                                (customer.address?.isNotEmpty ?? false)
                                    ? customer.address!
                                    : 'N/A',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildCustomerTypeBadges(customer,
                                    compact: true),
                              ),
                            ),
                            // Outstanding Column
                            Expanded(
                              child: Text(
                                balanceValue,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            // Status Column
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  if (!customer.isActive) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF94A3B8).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFF94A3B8), width: 1),
                                      ),
                                      child: const Text(
                                        'Inactive',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Actions Column
                            Expanded(
                              child: Consumer(
                                builder: (context, ref, child) {
                                  final authState = ref.watch(authProvider);
                                  final currentUser = authState.currentUser;
                                  final canEdit = currentUser?.canEditCustomer() ?? false;
                                  final canDelete = currentUser?.canDeleteCustomer() ?? false;
                                  
                                  return Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.receipt_long,
                                      size: 18,
                                      color: AppColors.primaryColor,
                                    ),
                                    onPressed: () => context.go(
                                        '/customer-ledger?id=${customer.id}'),
                                    tooltip: 'View Ledger',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      if (canEdit)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: Color(0xFF3B82F6),
                                          ),
                                          onPressed: () => context.go(
                                              '/edit-customer?id=${customer.id}'),
                                          tooltip: 'Edit Customer',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      if (canDelete)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 18,
                                            color: Color(0xFFEF4444),
                                          ),
                                          onPressed: () => _showDeleteDialog(
                                              context, customer, customerNotifier),
                                          tooltip: 'Delete Customer',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerTypeBadges(CustomerModel customer,
      {bool compact = false}) {
    final badges = <Widget>[];

    if (customer.isRetailCustomer) {
      badges.add(
          _buildTypeChip('Retail', const Color(0xFF2563EB), compact: compact));
    }
    if (customer.isWholesaleCustomer) {
      badges.add(_buildTypeChip('Wholesale', const Color(0xFFF97316),
          compact: compact));
    }

    if (badges.isEmpty) {
      return Text(
        'N/A',
        style: TextStyle(
          fontSize: compact ? 10 : 12,
          color: const Color(0xFF94A3B8),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: badges,
    );
  }

  Widget _buildTypeChip(String label, Color color, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFF374151),
        fontSize: 12,
      ),
    );
  }
}
