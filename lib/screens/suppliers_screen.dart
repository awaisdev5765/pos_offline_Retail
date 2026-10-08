import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/supplier_provider.dart';
import '../providers/auth_provider.dart';
import '../models/supplier.dart';
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../models/currency.dart';
import '../theme/app_theme.dart';
import '../utils/modern_dialog_builder.dart';
import '../utils/navigation_helper.dart';
import '../services/bulk_import_service.dart';
import '../services/database_service.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/drag_drop_area.dart';
import 'dart:io';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';

  String _safeLower(String? value) => (value ?? '').toLowerCase();

  void _openSupplierLedger(SupplierModel supplier) {
    final supplierId = supplier.id;
    if (supplierId == null) {
      AppSnackBar.show(
        context,
        const SnackBar(
          content: Text('Unable to open supplier ledger for this record'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    context.go('/supplier-ledger?id=$supplierId');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(supplierNotifierProvider);
    final supplierNotifier = ref.read(supplierNotifierProvider.notifier);
    final currency = ref.watch(currentCurrencyProvider);
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('nav.suppliers'.tr()),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            tooltip: 'Import (.xlsx)',
            icon: const Icon(Icons.upload_file),
            onPressed: _handleImportSuppliers,
          ),
        ],
      ),
      body: DragDropArea(
        onFilesDropped: (files) async {
          // Filter for Excel files only
          final excelFiles = files.where((file) {
            final extension = file.path.split('.').last.toLowerCase();
            return extension == 'xlsx' || extension == 'xls';
          }).toList();

          if (excelFiles.isEmpty) {
            if (mounted) {
              AppSnackBar.show(
                context,
                const SnackBar(
                  content: Text('Please drop an Excel file (.xlsx or .xls)'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          // Use the first Excel file
          await _processImportFile(excelFiles.first);
        },
        allowedExtensions: ['xlsx', 'xls'],
        allowedExtensionsMessage: 'Only Excel files (.xlsx, .xls) are supported',
        child: Column(
          children: [
            // Search and Filter Bar
            _buildSearchAndFilterBar(isDarkMode),
            // Suppliers Data
            Expanded(
              child: suppliersAsync.when(
                data: (suppliers) {
                  final filteredSuppliers = _filterSuppliers(suppliers);
                  return _buildSuppliersTable(
                      context, filteredSuppliers, supplierNotifier, currency);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading suppliers: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => supplierNotifier.refresh(),
                        child: Text('common.retry'.tr()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Consumer(
        builder: (context, ref, child) {
          final authState = ref.watch(authProvider);
          final currentUser = authState.currentUser;
          final canAdd = currentUser?.canAddSupplier() ?? false;
          
          if (!canAdd) return const SizedBox.shrink();
          
          return FloatingActionButton(
        onPressed: () {
          print('SuppliersScreen: navigating to /add-supplier from FAB');
          context.go('/add-supplier');
        },
        backgroundColor: AppColors.primaryColor,
        heroTag: "suppliers_fab",
        child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }


  Future<void> _handleImportSuppliers() async {
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

      await _processImportFile(file);
    } catch (e) {
      if (mounted) {
        NavigationHelper.safePop(context);
        AppSnackBar.show(
          context,
          SnackBar(
              content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _processImportFile(File file) async {
    if (mounted) {
      ModernDialogBuilder.showLoadingDialog(
          context: context, message: 'Importing suppliers...');
    }

    try {
      final databaseService = ref.read(databaseServiceProvider);
      final result = await BulkImportService.importSuppliersFromExcel(
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

      ref.invalidate(supplierNotifierProvider);
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
                hintText: 'Search by name, contact person, or phone...',
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
                  DropdownMenuItem(value: 'all', child: Text('All Suppliers')),
                  DropdownMenuItem(
                      value: 'active', child: Text('Active Suppliers')),
                  DropdownMenuItem(
                      value: 'inactive', child: Text('Inactive Suppliers')),
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

  Widget _buildSuppliersTable(
      BuildContext context,
      List<SupplierModel> suppliers,
      SupplierNotifier supplierNotifier,
      Currency currency) {
    if (suppliers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business, size: 64, color: Color(0xFF64748B)),
            const SizedBox(height: 16),
            const Text(
              'No suppliers found',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first supplier to get started',
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
                final canAdd = currentUser?.canAddSupplier() ?? false;
                
                if (!canAdd) return const SizedBox.shrink();
                
                return ElevatedButton.icon(
              onPressed: () {
                print('SuppliersScreen: navigating to /add-supplier from empty state');
                context.go('/add-supplier');
              },
              icon: const Icon(Icons.add),
              label: Text('misc.add_supplier'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                minimumSize: const Size(160, 44),
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
      onRefresh: () async => supplierNotifier.refresh(),
      child: isMobile
          ? _buildSuppliersCardView(
              context, suppliers, supplierNotifier, currency)
          : _buildSuppliersCustomTable(
              context, suppliers, supplierNotifier, currency),
    );
  }

  List<SupplierModel> _filterSuppliers(List<SupplierModel> suppliers) {
    final filtered = suppliers.where((supplier) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final matchesSearch = _safeLower(supplier.name).contains(searchLower) ||
            _safeLower(supplier.contactPerson).contains(searchLower) ||
            _safeLower(supplier.phone).contains(searchLower);
        if (!matchesSearch) return false;
      }

      // Status filter
      if (_selectedFilter == 'active' && !supplier.isActive) return false;
      if (_selectedFilter == 'inactive' && supplier.isActive) return false;

      return true;
    }).toList();
    
    // Sort by payable amount (currentBalance) in descending order
    // Suppliers with highest payable amount appear first
    filtered.sort((a, b) {
      // Sort by currentBalance descending (highest payable first)
      return b.currentBalance.compareTo(a.currentBalance);
    });
    
    return filtered;
  }

  Widget _buildSuppliersCardView(
      BuildContext context,
      List<SupplierModel> suppliers,
      SupplierNotifier supplierNotifier,
      Currency currency) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suppliers.length,
      itemBuilder: (context, index) {
        final supplier = suppliers[index];
        final bool hasOutstanding = supplier.hasOutstandingBalance;
        final bool hasCredit = supplier.hasCredit;
        final Color statusColor = hasOutstanding
            ? AppColors.warningColor
            : (hasCredit ? const Color(0xFF2563EB) : const Color(0xFF10B981));
        final String statusLabel =
            hasOutstanding ? 'Payable' : (hasCredit ? 'Credit' : 'Settled');
        final Color borderColor = (hasOutstanding || hasCredit)
            ? statusColor.withValues(alpha: 0.3)
            : const Color(0xFFE5E7EB);
        final String balanceValue =
            '${currency.symbol}${supplier.currentBalance.abs().toStringAsFixed(2)}';
        
        final isDarkMode = ref.watch(isDarkModeProvider);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: 1),
          ),
          child: InkWell(
            onTap: () => _openSupplierLedger(supplier),
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
                        child: Icon(
                          Icons.business,
                          color: Colors.white,
                          size: 24,
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
                                    supplier.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: supplier.isActive 
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFF94A3B8),
                                      decoration: supplier.isActive 
                                          ? null 
                                          : TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                                if (!supplier.isActive) ...[
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
                            if (supplier.contactPerson.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                supplier.contactPerson,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.phone,
                                    size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  supplier.phone,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                      if (!supplier.isActive) ...[
                        const SizedBox(width: 6),
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
                      Text(
                        balanceValue,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== CUSTOM SUPPLIERS TABLE WIDGET ====================
  Widget _buildSuppliersCustomTable(
      BuildContext context,
      List<SupplierModel> suppliers,
      SupplierNotifier supplierNotifier,
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
                  child: _buildHeaderCell('Supplier'),
                ),
                Expanded(
                  child: _buildHeaderCell('Contact Person'),
                ),
                Expanded(
                  child: _buildHeaderCell('Phone'),
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
              itemCount: suppliers.length,
              itemBuilder: (context, index) {
                final supplier = suppliers[index];
                final isEven = index % 2 == 0;
                final bool hasOutstanding = supplier.hasOutstandingBalance;
                final bool hasCredit = supplier.hasCredit;
                final Color statusColor = hasOutstanding
                    ? AppColors.warningColor
                    : (hasCredit
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF10B981));
                final String statusLabel = hasOutstanding
                    ? 'Payable'
                    : (hasCredit ? 'Credit' : 'Settled');
                final String balanceValue =
                    '${currency.symbol}${supplier.currentBalance.abs().toStringAsFixed(2)}';

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
                    onTap: () => _openSupplierLedger(supplier),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Supplier Column
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: statusColor,
                                  child: Icon(
                                    Icons.business,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          supplier.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: supplier.isActive
                                                ? const Color(0xFF1E293B)
                                                : const Color(0xFF94A3B8),
                                            fontSize: 12,
                                            decoration: supplier.isActive
                                                ? null
                                                : TextDecoration.lineThrough,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!supplier.isActive) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF94A3B8)
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: const Color(0xFF94A3B8),
                                                width: 1),
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
                          // Contact Person Column
                          Expanded(
                            child: Text(
                              supplier.contactPerson,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Phone Column
                          Expanded(
                            child: Text(
                              supplier.phone.isNotEmpty
                                  ? supplier.phone
                                  : 'N/A',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Balance Column
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
                                    color:
                                        statusColor.withValues(alpha: 0.1),
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
                                if (!supplier.isActive) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF94A3B8)
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: const Color(0xFF94A3B8),
                                          width: 1),
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
                                final canEdit =
                                    currentUser?.canEditSupplier() ?? false;
                                final canDelete =
                                    currentUser?.canDeleteSupplier() ?? false;

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.receipt_long,
                                        size: 18,
                                        color: AppColors.primaryColor,
                                      ),
                                      onPressed: () =>
                                          _openSupplierLedger(supplier),
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
                                            '/edit-supplier?id=${supplier.id}'),
                                        tooltip: 'Edit Supplier',
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
                                            context, supplier, supplierNotifier),
                                        tooltip: 'Delete Supplier',
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
                  ),
                );
              },
            ),
          ),
        ],
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

  Widget _buildEmptyState() {
    final isDarkMode = ref.watch(isDarkModeProvider);
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color:
                    isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDarkMode ? 0.1 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.business_outlined,
                      size: 48,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No suppliers found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first supplier to start managing vendor relationships',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? AppColors.textTertiary
                          : AppColors.textSecondary,
                      fontFamily: 'Roboto',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Consumer(
                    builder: (context, ref, child) {
                      final authState = ref.watch(authProvider);
                      final currentUser = authState.currentUser;
                      final canAdd = currentUser?.canAddSupplier() ?? false;
                      
                      if (!canAdd) return const SizedBox.shrink();
                      
                      return ElevatedButton.icon(
                    onPressed: () {
                      print('SuppliersScreen: navigating to /add-supplier from animated empty state');
                      context.go('/add-supplier');
                    },
                    icon: const Icon(Icons.add),
                    label: Text('misc.add_supplier'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  void _showDeleteDialog(
      BuildContext context, SupplierModel supplier, SupplierNotifier supplierNotifier) async {
    final confirmed = await ModernDialogBuilder.showConfirmDialog(
      context: context,
      title: 'Delete Supplier',
      message:
          'Are you sure you want to delete "${supplier.name}"?\n\nThis will permanently delete:\n• All associated purchase orders\n• All associated supplier payments\n• The supplier record\n\nStock changes from purchase orders will be reversed.\n\nThis action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      icon: Icons.delete_outline,
    );

    if (confirmed == true) {
      try {
        // Delete the supplier - this will automatically refresh the notifier's state via _loadSuppliers()
        await supplierNotifier.deleteSupplier(supplier.id!);
        
        // Invalidate related providers to ensure all dependent widgets refresh
        // Note: We don't invalidate supplierNotifierProvider itself because it already refreshed internally
        ref.invalidate(activeSuppliersProvider);
        ref.invalidate(supplierByIdProvider(supplier.id!));
        
        // The state should already be updated by _loadSuppliers() in deleteSupplier()
        // The screen is watching supplierNotifierProvider, so it will automatically rebuild

        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Supplier deleted successfully'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        // Re-throw to let the UI handle the error (e.g., show a SnackBar)
        // The notifier error handling will still show the error state, but we show snackbar here too
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Error deleting supplier: ${e.toString()}'),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }
}
