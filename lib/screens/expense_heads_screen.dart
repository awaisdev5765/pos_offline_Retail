import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../providers/expense_head_provider.dart';
import '../database/database.dart';
import '../widgets/app_snack_bar.dart';

class ExpenseHeadsScreen extends ConsumerStatefulWidget {
  const ExpenseHeadsScreen({super.key});

  @override
  ConsumerState<ExpenseHeadsScreen> createState() => _ExpenseHeadsScreenState();
}

class _ExpenseHeadsScreenState extends ConsumerState<ExpenseHeadsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _jobTypeController = TextEditingController();
  final _searchController = TextEditingController();

  ExpenseHead? _selectedExpenseHead;
  bool _isEditing = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _jobTypeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _jobTypeController.clear();
    _selectedExpenseHead = null;
    _isEditing = false;
  }

  void _loadExpenseHead(ExpenseHead expenseHead) {
    _nameController.text = expenseHead.name;
    _descriptionController.text = expenseHead.description ?? '';
    _jobTypeController.text = expenseHead.jobType ?? '';
    _selectedExpenseHead = expenseHead;
    _isEditing = true;
  }

  Future<void> _saveExpenseHead() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (_isEditing && _selectedExpenseHead != null) {
        final updated = _selectedExpenseHead!.copyWith(
          name: _nameController.text.trim(),
          description: drift.Value(_descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim()),
          jobType: drift.Value(_jobTypeController.text.trim().isEmpty
              ? null
              : _jobTypeController.text.trim()),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await ref
            .read(expenseHeadNotifierProvider.notifier)
            .updateExpenseHead(updated);
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Expense Head updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await ref.read(expenseHeadNotifierProvider.notifier).addExpenseHead(
              _nameController.text.trim(),
              _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              _jobTypeController.text.trim().isEmpty
                  ? null
                  : _jobTypeController.text.trim(),
            );
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Expense Head added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _clearForm();
    } catch (e) {
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteExpenseHead(ExpenseHead expenseHead) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('expense.delete_head_title'.tr()),
        content: Text('Are you sure you want to delete "${expenseHead.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(expenseHeadNotifierProvider.notifier)
            .deleteExpenseHead(expenseHead.id);
        if (_selectedExpenseHead?.id == expenseHead.id) {
          _clearForm();
        }
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Expense Head deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
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

  Widget _buildButton(String label, VoidCallback onPressed,
      {Color? backgroundColor, Color? textColor}) {
    return SizedBox(
      width: 120,
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? const Color(0xFF3B82F6),
          foregroundColor: textColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseHeadsAsync = ref.watch(expenseHeadNotifierProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'expense.heads_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
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
      ),
      body: expenseHeadsAsync.when(
        data: (expenseHeads) {
          final filteredHeads = _searchQuery.isEmpty
              ? expenseHeads
              : expenseHeads.where((head) {
                  final query = _searchQuery.toLowerCase();
                  return head.name.toLowerCase().contains(query) ||
                      (head.description?.toLowerCase().contains(query) ??
                          false) ||
                      (head.jobType?.toLowerCase().contains(query) ?? false);
                }).toList();

          if (isMobile) {
            return Column(
              children: [
                _buildFormSection(),
                const Divider(),
                Expanded(child: _buildTableSection(filteredHeads)),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 400,
                child: _buildFormSection(),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _buildTableSection(filteredHeads),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(expenseHeadNotifierProvider),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expense Head Form',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name *',
                  hintText: 'Enter expense head name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF3B82F6), width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF3B82F6), width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _jobTypeController,
                decoration: InputDecoration(
                  labelText: 'Job Type',
                  hintText: 'Enter job type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF3B82F6), width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildButton('NEW', () => _clearForm(),
                      backgroundColor: Colors.green),
                  _buildButton('SAVE', _saveExpenseHead),
                  _buildButton('EDIT', () {
                    if (_selectedExpenseHead == null) {
                      AppSnackBar.show(
                        context,
                        const SnackBar(
                            content:
                                Text('Please select an expense head to edit')),
                      );
                    }
                  }, backgroundColor: Colors.orange),
                  _buildButton('DELETE', () {
                    if (_selectedExpenseHead != null) {
                      _deleteExpenseHead(_selectedExpenseHead!);
                    } else {
                      AppSnackBar.show(
                        context,
                        const SnackBar(
                            content: Text(
                                'Please select an expense head to delete')),
                      );
                    }
                  }, backgroundColor: Colors.red),
                  _buildButton('CANCEL', () => _clearForm(),
                      backgroundColor: Colors.grey),
                  _buildButton('FIND', () {
                    // FIND functionality - show search dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('expense.find_head_title'.tr()),
                        content: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Enter search query',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Text('common.close'.tr()),
                          ),
                        ],
                      ),
                    );
                  }, backgroundColor: Colors.blue),
                  _buildButton('EXIT', () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  }, backgroundColor: Colors.grey[800]!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableSection(List<ExpenseHead> expenseHeads) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search expense heads...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: expenseHeads.isEmpty
              ? const Center(
                  child: Text(
                    'No expense heads found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        MaterialStateProperty.all(const Color(0xFFFFF9C4)),
                    headingRowHeight: 48,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 64,
                    columnSpacing: 24,
                    horizontalMargin: 16,
                    columns: const [
                      DataColumn(
                        label: Text(
                          'ID',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Name',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Description',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Job Type',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Created At',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Actions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                    rows: expenseHeads.asMap().entries.map((entry) {
                      final index = entry.key;
                      final head = entry.value;
                      final isEven = index % 2 == 0;
                      final isSelected = _selectedExpenseHead?.id == head.id;

                      return DataRow(
                        color: MaterialStateProperty.all(
                          isSelected
                              ? const Color(0xFFE3F2FD)
                              : (isEven
                                  ? Colors.white
                                  : const Color(0xFFF8FAFC)),
                        ),
                        cells: [
                          DataCell(Text('${head.id}',
                              style: const TextStyle(fontSize: 13))),
                          DataCell(Text(head.name,
                              style: const TextStyle(fontSize: 13))),
                          DataCell(Text(
                            head.description ?? '-',
                            style: const TextStyle(fontSize: 13),
                          )),
                          DataCell(Text(
                            head.jobType ?? '-',
                            style: const TextStyle(fontSize: 13),
                          )),
                          DataCell(Text(
                            DateFormat('dd-MMM-yyyy')
                                .format(DateTime.parse(head.createdAt)),
                            style: const TextStyle(fontSize: 13),
                          )),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      size: 18, color: Color(0xFF3B82F6)),
                                  onPressed: () => _loadExpenseHead(head),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  onPressed: () => _deleteExpenseHead(head),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelectChanged: (selected) {
                          if (selected == true) {
                            _loadExpenseHead(head);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}
