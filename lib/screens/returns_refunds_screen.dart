import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/return.dart';
import '../models/sale.dart';
import '../providers/return_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/currency_provider.dart';
import '../models/currency.dart';
import '../utils/input_formatters.dart';
import '../widgets/app_snack_bar.dart';

class ReturnsRefundsScreen extends ConsumerStatefulWidget {
  const ReturnsRefundsScreen({super.key});

  @override
  ConsumerState<ReturnsRefundsScreen> createState() =>
      _ReturnsRefundsScreenState();
}

class _ReturnsRefundsScreenState extends ConsumerState<ReturnsRefundsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currentCurrencyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'returns.title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        foregroundColor: const Color(0xFF1E293B),
        automaticallyImplyLeading: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF3B82F6),
          tabs: const [
            Tab(text: 'All Returns', icon: Icon(Icons.assignment_return)),
            Tab(text: 'Pending', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Statistics', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showCreateReturnDialog(),
            icon: const Icon(Icons.add, color: Color(0xFF3B82F6)),
            tooltip: 'Create Return',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllReturnsTab(currency),
          _buildPendingReturnsTab(currency),
          _buildStatisticsTab(currency),
        ],
      ),
    );
  }

  Widget _buildAllReturnsTab(Currency currency) {
    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search returns...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  DropdownMenuItem(
                      value: 'processed', child: Text('Processed')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value!;
                  });
                },
              ),
            ],
          ),
        ),

        // Returns List
        Expanded(
          child: _buildReturnsList(currency),
        ),
      ],
    );
  }

  Widget _buildPendingReturnsTab(Currency currency) {
    final returnsAsync = ref.watch(returnsByStatusProvider('pending'));

    return returnsAsync.when(
      data: (returns) {
        if (returns.isEmpty) {
          return _buildEmptyState('No pending returns');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: returns.length,
          itemBuilder: (context, index) {
            final returnData = returns[index];
            return _buildReturnCard(returnData, currency, showActions: true);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error'),
      ),
    );
  }

  Widget _buildStatisticsTab(Currency currency) {
    final statsAsync = ref.watch(returnStatsProvider);

    return statsAsync.when(
      data: (stats) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatCard(
                'Total Returns',
                stats.totalReturns.toString(),
                Icons.assignment_return,
                const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Pending',
                stats.pendingReturns.toString(),
                Icons.pending_actions,
                const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Approved',
                stats.approvedReturns.toString(),
                Icons.check_circle,
                const Color(0xFF10B981),
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Rejected',
                stats.rejectedReturns.toString(),
                Icons.cancel,
                const Color(0xFFEF4444),
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Processed',
                stats.processedReturns.toString(),
                Icons.done_all,
                const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Total Refund Amount',
                '${currency.symbol}${stats.totalRefundAmount.toStringAsFixed(2)}',
                Icons.account_balance_wallet,
                const Color(0xFF06B6D4),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error'),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnsList(Currency currency) {
    final returnsAsync = ref.watch(returnsByStatusProvider(_selectedStatus));

    return returnsAsync.when(
      data: (returns) {
        final filteredReturns = returns.where((returnData) {
          if (_searchQuery.isEmpty) return true;

          final query = _searchQuery.toLowerCase();
          return returnData.returnNumber.toLowerCase().contains(query) ||
              (returnData.customer?.name.toLowerCase().contains(query) ??
                  false) ||
              (returnData.originalSale?.id.toString().contains(query) ?? false);
        }).toList();

        if (filteredReturns.isEmpty) {
          return _buildEmptyState('No returns found');
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filteredReturns.length,
          itemBuilder: (context, index) {
            final returnData = filteredReturns[index];
            return _buildReturnCard(returnData, currency,
                showActions: returnData.status == ReturnStatus.pending);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnCard(ReturnModel returnData, Currency currency,
      {bool showActions = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewReturn(returnData, currency),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      returnData.returnNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  _buildStatusBadge(returnData.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Customer: ${returnData.customer?.name ?? 'Unknown'}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Original Sale: #${returnData.originalSale?.id ?? 'N/A'}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Date: ${_formatDate(returnData.returnDate)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reason: ${returnData.reasonDisplayName}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Amount: ${currency.symbol}${returnData.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  Text(
                    'Items: ${returnData.items.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (showActions) ...[
                const SizedBox(height: 12),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _rejectReturn(returnData.id!),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: Text('returns.reject'.tr()),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _approveReturn(returnData.id!),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: Text('returns.approve'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ReturnStatus status) {
    Color color;
    String text;

    switch (status) {
      case ReturnStatus.pending:
        color = const Color(0xFFF59E0B);
        text = 'Pending';
        break;
      case ReturnStatus.approved:
        color = const Color(0xFF10B981);
        text = 'Approved';
        break;
      case ReturnStatus.rejected:
        color = const Color(0xFFEF4444);
        text = 'Rejected';
        break;
      case ReturnStatus.processed:
        color = const Color(0xFF8B5CF6);
        text = 'Processed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_return_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new return to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showCreateReturnDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreateReturnDialog(),
    );
  }

  Future<void> _approveReturn(int returnId) async {
    try {
      await ref.read(returnNotifierProvider.notifier).approveReturn(returnId);

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Return approved and stock updated'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectReturn(int returnId) async {
    // Show dialog to get rejection notes
    final notes = await showDialog<String>(
      context: context,
      builder: (context) {
        final notesController = TextEditingController();
        return AlertDialog(
          title: Text('returns.reject_title'.tr()),
          content: TextField(
            controller: notesController,
            decoration: InputDecoration(
              labelText: 'returns.rejection_reason_label'.tr(),
              hintText: 'returns.rejection_hint'.tr(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, notesController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: Text('returns.reject'.tr()),
            ),
          ],
        );
      },
    );

    if (notes == null) return;

    try {
      await ref
          .read(returnNotifierProvider.notifier)
          .rejectReturn(returnId, notes.isEmpty ? null : notes);

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Return rejected'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewReturn(ReturnModel returnData, Currency currency) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(returnData.returnNumber),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Status', returnData.statusDisplayName),
              _buildDetailRow(
                  'Customer', returnData.customer?.name ?? 'Unknown'),
              _buildDetailRow('Phone', returnData.customer?.phone ?? 'N/A'),
              _buildDetailRow('Date', _formatDate(returnData.returnDate)),
              _buildDetailRow(
                  'Original Sale', '#${returnData.originalSale?.id ?? 'N/A'}'),
              _buildDetailRow('Reason', returnData.reasonDisplayName),
              if (returnData.notes != null)
                _buildDetailRow('Notes', returnData.notes!),
              if (returnData.processedBy != null)
                _buildDetailRow('Processed By', returnData.processedBy!),
              const Divider(),
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...returnData.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.product?.name ?? 'Unknown Product'),
                        Text(
                          'Qty: ${item.quantity} × ${currency.symbol}${item.unitPrice.toStringAsFixed(2)} = ${currency.symbol}${item.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Text(
                          'Condition: ${item.conditionDisplayName}, Action: ${item.actionDisplayName}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${currency.symbol}${returnData.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

// Create Return Dialog
class _CreateReturnDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateReturnDialog> createState() =>
      _CreateReturnDialogState();
}

class _CreateReturnDialogState extends ConsumerState<_CreateReturnDialog> {
  final _formKey = GlobalKey<FormState>();
  SaleModel? _selectedSale;
  ReturnReason _selectedReason = ReturnReason.customerRequest;
  final _notesController = TextEditingController();
  final List<_ReturnItemData> _returnItems = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesProvider);
    final currency = ref.watch(currentCurrencyProvider);

    return AlertDialog(
      title: Text('returns.create_title'.tr()),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sale Selection
                salesAsync.when(
                  data: (sales) {
                    final recentSales = sales.take(50).toList();
                    return DropdownButtonFormField<SaleModel>(
                      value: _selectedSale,
                      decoration: const InputDecoration(
                        labelText: 'Select Original Sale',
                        border: OutlineInputBorder(),
                      ),
                      items: recentSales.map((sale) {
                        return DropdownMenuItem(
                          value: sale,
                          child: Text(
                              'Sale #${sale.id} - ${currency.symbol}${sale.total.toStringAsFixed(2)}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSale = value;
                          _returnItems.clear();
                          // Add all sale items as potential return items
                          if (value != null) {
                            for (final item in value.items) {
                              _returnItems.add(_ReturnItemData(
                                saleItem: item,
                                quantity: 0,
                                condition: ReturnCondition.good,
                                action: ReturnAction.refund,
                              ));
                            }
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null) return 'Please select a sale';
                        return null;
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stack) => Text('Error: $error'),
                ),
                const SizedBox(height: 16),

                // Reason Selection
                DropdownButtonFormField<ReturnReason>(
                  value: _selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'Return Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: ReturnReason.values.map((reason) {
                    return DropdownMenuItem(
                      value: reason,
                      child: Text(_getReasonDisplayName(reason)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedReason = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Return Items
                if (_selectedSale != null) ...[
                  const Text(
                    'Select Items to Return:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._returnItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return _buildReturnItemCard(item, index, currency);
                  }),
                ],

                const SizedBox(height: 16),

                // Notes
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createReturn,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('returns.create_submit'.tr()),
        ),
      ],
    );
  }

  Widget _buildReturnItemCard(
      _ReturnItemData item, int index, Currency currency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.saleItem.product?.name ?? 'Unknown Product',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Available: ${item.saleItem.qty} @ ${currency.symbol}${item.saleItem.price.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Return Qty',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      setState(() {
                        item.quantity = double.tryParse(value) ?? 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<ReturnCondition>(
                    value: item.condition,
                    decoration: const InputDecoration(
                      labelText: 'Condition',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ReturnCondition.values.map((cond) {
                      return DropdownMenuItem(
                        value: cond,
                        child: Text(_getConditionDisplayName(cond)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          item.condition = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ReturnAction>(
              value: item.action,
              decoration: const InputDecoration(
                labelText: 'Action',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: ReturnAction.values.map((action) {
                return DropdownMenuItem(
                  value: action,
                  child: Text(_getActionDisplayName(action)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    item.action = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createReturn() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that at least one item has quantity > 0
    final itemsWithQuantity =
        _returnItems.where((item) => item.quantity > 0).toList();
    if (itemsWithQuantity.isEmpty) {
      AppSnackBar.show(
        context,
        const SnackBar(
          content: Text('Please select at least one item to return'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Calculate total amount
      double totalAmount = 0;
      for (final item in itemsWithQuantity) {
        final saleItem = item.saleItem as SaleItemModel;
        totalAmount += item.quantity * saleItem.price;
      }

      // Create return items
      final returnItems = itemsWithQuantity.map((item) {
        final saleItem = item.saleItem as SaleItemModel;
        return ReturnItemModel(
          returnId: 0, // Will be set by the database
          productId: saleItem.productId,
          quantity: item.quantity,
          unitPrice: saleItem.price,
          subtotal: item.quantity * saleItem.price,
          reason: _selectedReason,
          condition: item.condition,
          action: item.action,
          createdAt: DateTime.now(),
          product: saleItem.product,
        );
      }).toList();

      // Create return
      final returnModel = ReturnModel(
        returnNumber: '', // Will be generated
        originalSaleId: _selectedSale!.id ?? 0,
        customerId: _selectedSale!.customerId ?? 0,
        returnDate: DateTime.now(),
        totalAmount: totalAmount,
        reason: _selectedReason,
        status: ReturnStatus.pending,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: returnItems,
      );

      await ref.read(returnNotifierProvider.notifier).addReturn(returnModel);

      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Return created successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getReasonDisplayName(ReturnReason reason) {
    switch (reason) {
      case ReturnReason.defective:
        return 'Defective';
      case ReturnReason.wrongItem:
        return 'Wrong Item';
      case ReturnReason.customerRequest:
        return 'Customer Request';
      case ReturnReason.qualityIssue:
        return 'Quality Issue';
      case ReturnReason.other:
        return 'Other';
    }
  }

  String _getConditionDisplayName(ReturnCondition condition) {
    switch (condition) {
      case ReturnCondition.good:
        return 'Good';
      case ReturnCondition.damaged:
        return 'Damaged';
      case ReturnCondition.defective:
        return 'Defective';
    }
  }

  String _getActionDisplayName(ReturnAction action) {
    switch (action) {
      case ReturnAction.refund:
        return 'Refund';
      case ReturnAction.exchange:
        return 'Exchange';
      case ReturnAction.credit:
        return 'Store Credit';
    }
  }
}

class _ReturnItemData {
  final dynamic saleItem;
  double quantity;
  ReturnCondition condition;
  ReturnAction action;

  _ReturnItemData({
    required this.saleItem,
    required this.quantity,
    required this.condition,
    required this.action,
  });
}
