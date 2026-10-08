import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/expense_head_provider.dart';
import '../providers/currency_provider.dart';
import '../models/expense.dart';
import '../models/currency.dart';
import '../database/database.dart';

class ExpenseReportScreen extends ConsumerStatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  ConsumerState<ExpenseReportScreen> createState() =>
      _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends ConsumerState<ExpenseReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  ExpenseHead? _selectedExpenseHead;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _endDate = DateTime.now();
  }

  List<ExpenseModel> _filterExpenses(List<ExpenseModel> expenses) {
    var filtered = expenses;

    // Filter by date range
    if (_startDate != null) {
      filtered = filtered
          .where((e) =>
              e.date.isAfter(_startDate!.subtract(const Duration(days: 1))))
          .toList();
    }
    if (_endDate != null) {
      filtered = filtered
          .where((e) => e.date.isBefore(_endDate!.add(const Duration(days: 1))))
          .toList();
    }

    // Filter by expense head
    if (_selectedExpenseHead != null) {
      filtered = filtered
          .where((e) => e.category == _selectedExpenseHead!.name)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((e) {
        return e.title.toLowerCase().contains(query) ||
            (e.description?.toLowerCase().contains(query) ?? false) ||
            (e.vendor?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expenseNotifierProvider);
    final expenseHeadsAsync = ref.watch(expenseHeadNotifierProvider);
    final currency = ref.watch(currentCurrencyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'expense.report_title'.tr(),
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
      body: Column(
        children: [
          _buildFilterSection(expenseHeadsAsync, currency),
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                final filtered = _filterExpenses(expenses);
                final totalAmount =
                    filtered.fold<double>(0.0, (sum, e) => sum + e.amount);

                return Column(
                  children: [
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No expenses found',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            )
                          : _buildExpenseTable(filtered, currency),
                    ),
                    _buildSummarySection(
                        totalAmount, filtered.length, currency),
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
                      onPressed: () => ref.refresh(expenseNotifierProvider),
                      child: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(
      AsyncValue<List<ExpenseHead>> expenseHeadsAsync, Currency currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _startDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'From Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      prefixIcon: const Icon(Icons.calendar_today,
                          color: Color(0xFF64748B)),
                    ),
                    child: Text(
                      _startDate != null
                          ? DateFormat('dd-MMM-yyyy').format(_startDate!)
                          : 'Select date',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _endDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'To Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      prefixIcon: const Icon(Icons.calendar_today,
                          color: Color(0xFF64748B)),
                    ),
                    child: Text(
                      _endDate != null
                          ? DateFormat('dd-MMM-yyyy').format(_endDate!)
                          : 'Select date',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: expenseHeadsAsync.when(
                  data: (expenseHeads) => DropdownButtonFormField<ExpenseHead>(
                    value: _selectedExpenseHead,
                    decoration: InputDecoration(
                      labelText: 'Expense Head',
                      hintText: 'All',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    items: [
                      const DropdownMenuItem<ExpenseHead>(
                        value: null,
                        child: Text('All'),
                      ),
                      ...expenseHeads.map((head) {
                        return DropdownMenuItem<ExpenseHead>(
                          value: head,
                          child: Text(head.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedExpenseHead = value);
                    },
                  ),
                  loading: () => const SizedBox(
                    height: 56,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const SizedBox(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search expenses...',
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
        ],
      ),
    );
  }

  Widget _buildExpenseTable(List<ExpenseModel> expenses, Currency currency) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(const Color(0xFFFFF9C4)),
          headingRowHeight: 48,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 64,
          columnSpacing: 24,
          horizontalMargin: 16,
          columns: const [
            DataColumn(
              label: Text(
                'Date',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Expense Head',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Amount',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                ),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                'Reason',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
          rows: expenses.asMap().entries.map((entry) {
            final index = entry.key;
            final expense = entry.value;
            final isEven = index % 2 == 0;

            return DataRow(
              color: MaterialStateProperty.all(
                isEven ? Colors.white : const Color(0xFFF8FAFC),
              ),
              cells: [
                DataCell(Text(
                  DateFormat('dd-MMM-yyyy').format(expense.date),
                  style: const TextStyle(fontSize: 13),
                )),
                DataCell(Text(
                  expense.category,
                  style: const TextStyle(fontSize: 13),
                )),
                DataCell(Text(
                  '${currency.symbol}${expense.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: expense.amount < 0 ? Colors.red : null,
                  ),
                  textAlign: TextAlign.right,
                )),
                DataCell(Text(
                  expense.description ?? '-',
                  style: const TextStyle(fontSize: 13),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummarySection(
      double totalAmount, int count, Currency currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3B82F6), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text(
                'Total Expenses',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: const Color(0xFFE2E8F0),
          ),
          Column(
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${currency.symbol}${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
