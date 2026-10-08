import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/expense_head_provider.dart';
import '../providers/expense_provider.dart';
import '../database/database.dart';
import '../models/expense.dart';
import '../utils/input_formatters.dart';
import '../utils/mobile_optimization.dart';
import '../utils/touch_optimization.dart';
import '../widgets/app_snack_bar.dart';

class ExpenseEntryScreen extends ConsumerStatefulWidget {
  const ExpenseEntryScreen({super.key});

  @override
  ConsumerState<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends ConsumerState<ExpenseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  ExpenseHead? _selectedExpenseHead;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  int? _editingExpenseId;
  ExpenseModel? _editingExpense;
  List<ExpenseHead> _availableExpenseHeads = [];

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExpenseHead == null) {
      AppSnackBar.show(
        context,
        const SnackBar(
          content: Text('Please select an expense head'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final amount = double.parse(_amountController.text);

      // Normalize date to start of day for consistent date filtering
      final normalizedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      
      final expense = ExpenseModel(
        id: _editingExpenseId,
        title: _selectedExpenseHead!.name,
        category: _selectedExpenseHead!.name,
        amount: amount,
        date: normalizedDate,
        paymentMethod: 'cash',
        description: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
        createdAt: _editingExpense?.createdAt ?? now,
        updatedAt: now,
      );

      if (_isEditing) {
        await ref.read(expenseNotifierProvider.notifier).updateExpense(expense);
      } else {
        await ref.read(expenseNotifierProvider.notifier).addExpense(expense);
      }

      // Invalidate expense summary providers to refresh reports
      // This ensures overview and cash reports update immediately
      final startBoundary = DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
      );
      final endBoundary = DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        23,
        59,
        59,
        999,
      );
      ref.invalidate(expensesByDateRangeProvider(
          DateRangeFilter(start: startBoundary, end: endBoundary)));
      // Invalidate all expense summary providers by invalidating the family
      // This will cause all date range queries to refresh
      ref.invalidate(expenseSummaryProvider);

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(_isEditing
                ? 'Expense updated successfully'
                : 'Expense recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();
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
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    _amountController.clear();
    _reasonController.clear();
    _selectedExpenseHead = null;
    _selectedDate = DateTime.now();
    _editingExpenseId = null;
    _editingExpense = null;
  }

  bool get _isEditing => _editingExpenseId != null;

  ExpenseHead? _matchExpenseHead(String name) {
    for (final head in _availableExpenseHeads) {
      if (head.name.toLowerCase() == name.toLowerCase()) {
        return head;
      }
    }
    return null;
  }

  Future<ExpenseHead?> _showSelectExpenseHeadDialog(
      List<ExpenseHead> expenseHeads) async {
    ExpenseHead? selected;
    String query = '';
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = expenseHeads.where((h) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return h.name.toLowerCase().contains(q) ||
                  (h.description ?? '').toLowerCase().contains(q);
            }).toList()
              ..sort((a, b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()));

            return AlertDialog(
              title: Text('expense.select_head_title'.tr()),
              contentPadding: MobileOptimization.getDialogPadding(context),
              content: SizedBox(
                width: MobileOptimization.isMobile(context)
                    ? MediaQuery.of(context).size.width * 0.9
                    : MediaQuery.of(context).size.width * 0.5,
                height: MobileOptimization.isMobile(context)
                    ? MediaQuery.of(context).size.height * 0.6
                    : MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search expense head...',
                      ),
                      onChanged: (val) => setDialogState(() => query = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, index) {
                          final head = filtered[index];
                          final isActive = selected?.name == head.name;
                          return ListTile(
                            title: Text(
                              head.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: head.description != null
                                ? Text(head.description!)
                                : null,
                            trailing: isActive
                                ? const Icon(Icons.check_circle,
                                    color: Color(0xFF3B82F6))
                                : null,
                            onTap: () => setDialogState(() => selected = head),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: MobileOptimization.getDialogPadding(context),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    minimumSize: Size(
                      0,
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
                ElevatedButton(
                  onPressed: selected == null ? null : () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(
                      0,
                      MobileOptimization.isMobile(context)
                          ? TouchOptimization.recommendedTouchTarget
                          : 40,
                    ),
                    padding: MobileOptimization.isMobile(context)
                        ? TouchOptimization.getTouchPadding()
                        : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text('expense.select_btn'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
    return selected;
  }

  void _loadExpenseForEdit(ExpenseModel expense) {
    final head =
        _matchExpenseHead(expense.category) ?? _matchExpenseHead(expense.title);

    setState(() {
      _editingExpenseId = expense.id;
      _editingExpense = expense;
      _selectedExpenseHead = head ?? _selectedExpenseHead;
      _selectedDate = expense.date;
      _amountController.text = expense.amount.toStringAsFixed(2);
      _reasonController.text = expense.description ?? '';
    });
  }

  Future<void> _showFindExpenseDialog() async {
    // Check if widget is still mounted
    if (!mounted) return;
    
    // Get the current state
    var expensesState = ref.read(expenseNotifierProvider);
    
    // If still loading, refresh the notifier and wait for it to complete
    if (expensesState.isLoading) {
      ref.read(expenseNotifierProvider.notifier).refresh();
      // Wait for refresh to complete
      await Future.delayed(const Duration(milliseconds: 300));
      expensesState = ref.read(expenseNotifierProvider);
      
      // If still loading, wait a bit more
      int attempts = 0;
      while (expensesState.isLoading && mounted && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        expensesState = ref.read(expenseNotifierProvider);
        attempts++;
      }
    }
    
    // Check if widget is still mounted before proceeding
    if (!mounted) return;
    
    // Extract expenses from the state
    final expenses = expensesState.maybeWhen(
      data: (data) => data,
      orElse: () => <ExpenseModel>[],
    );

    if (expenses.isEmpty) {
      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('No expense entries found'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Ensure we have a valid context before showing dialog
    if (!mounted) return;
    
    ExpenseModel? selectedExpense;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = expenses.where((expense) {
              if (searchQuery.isEmpty) return true;
              final query = searchQuery.toLowerCase();
              return expense.title.toLowerCase().contains(query) ||
                  expense.category.toLowerCase().contains(query) ||
                  (expense.description ?? '').toLowerCase().contains(query);
            }).toList()
              ..sort((a, b) => b.date.compareTo(a.date));

            return AlertDialog(
              title: Text('expense.find_expense_title'.tr()),
              contentPadding: MobileOptimization.getDialogPadding(context),
              content: SizedBox(
                width: MobileOptimization.isMobile(context)
                    ? MediaQuery.of(context).size.width * 0.9
                    : MediaQuery.of(context).size.width * 0.6,
                height: MobileOptimization.isMobile(context)
                    ? MediaQuery.of(context).size.height * 0.6
                    : MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search expense...',
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Expense Head',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569)),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Expense Date',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569)),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Amount',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 0),
                          itemBuilder: (context, index) {
                            final expense = filtered[index];
                            final isSelected =
                                selectedExpense?.id == expense.id;
                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedExpense = expense;
                                });
                              },
                              child: Container(
                                color: isSelected
                                    ? const Color(0xFFE0F2FE)
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        expense.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(DateFormat('dd-MMM-yyyy')
                                          .format(expense.date)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        expense.amount.toStringAsFixed(2),
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: expense.amount < 0
                                                ? Colors.red
                                                : null),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: MobileOptimization.getDialogPadding(context),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    minimumSize: Size(
                      0,
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
                ElevatedButton(
                  onPressed: selectedExpense == null
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _loadExpenseForEdit(selectedExpense!);
                        },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(
                      0,
                      MobileOptimization.isMobile(context)
                          ? TouchOptimization.recommendedTouchTarget
                          : 40,
                    ),
                    padding: MobileOptimization.isMobile(context)
                        ? TouchOptimization.getTouchPadding()
                        : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text('common.ok'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseHeadsAsync = ref.watch(expenseHeadNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'expense.entry_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        leading: MobileOptimization.mobileIconButton(
          icon: Icons.arrow_back,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          color: const Color(0xFF1E293B),
        ),
      ),
      body: MobileOptimization.keyboardAwareForm(
        child: SingleChildScrollView(
          padding: MobileOptimization.getResponsivePadding(context),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: MobileOptimization.getCardPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expense Entry Form',
                        style: TextStyle(
                          fontSize: MobileOptimization.getResponsiveFontSize(
                            context,
                            mobile: 20,
                            tablet: 22,
                            desktop: 24,
                          ),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(
                        height: MobileOptimization.getFormFieldSpacing(context),
                      ),
                      expenseHeadsAsync.when(
                        data: (expenseHeads) {
                          _availableExpenseHeads = expenseHeads;
                          if (expenseHeads.isEmpty) {
                            return const Column(
                              children: [
                                Icon(Icons.warning,
                                    color: Colors.orange, size: 48),
                                SizedBox(height: 16),
                                Text(
                                  'No expense heads found. Please create expense heads first.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final selected =
                                      await _showSelectExpenseHeadDialog(
                                          expenseHeads);
                                  if (selected != null) {
                                    setState(() {
                                      _selectedExpenseHead = selected;
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: '',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF3B82F6), width: 2),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    prefixIcon: const Icon(Icons.category,
                                        color: Color(0xFF64748B)),
                                    contentPadding: MobileOptimization.getTextFieldPadding(context),
                                  ),
                                  isEmpty: _selectedExpenseHead == null,
                                  child: _selectedExpenseHead == null
                                      ? const Text(
                                          'Select expense head',
                                          style: TextStyle(
                                              color: Color(0xFF94A3B8)),
                                        )
                                      : Text(
                                          _selectedExpenseHead!.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Color(0xFF1E293B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (_selectedExpenseHead == null)
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 12),
                                    child: Text('Required',
                                        style: TextStyle(
                                            color: Colors.red, fontSize: 12)),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) {
                                    setState(() => _selectedDate = date);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Date *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF3B82F6), width: 2),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    prefixIcon: const Icon(Icons.calendar_today,
                                        color: Color(0xFF64748B)),
                                  ),
                                  child: Text(
                                    DateFormat('dd-MMM-yyyy')
                                        .format(_selectedDate),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: MobileOptimization.getFormFieldSpacing(context),
                              ),
                              TextFormField(
                                controller: _amountController,
                                decoration: InputDecoration(
                                  labelText: 'Amount *',
                                  hintText: 'Enter amount (use - for returns)',
                                  helperText: 'Use negative value (-5000) for returns/refunds',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF3B82F6), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  prefixIcon: const Icon(Icons.monetization_on,
                                      color: Color(0xFF64748B)),
                                  contentPadding: MobileOptimization.getTextFieldPadding(context),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true, signed: true),
                                inputFormatters: [
                                  DecimalInputFormatter(
                                      maxDecimalPlaces: 2, allowNegative: true),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty)
                                    return 'Required';
                                  if (double.tryParse(value) == null)
                                    return 'Invalid amount';
                                  if (double.parse(value) == 0)
                                    return 'Amount cannot be zero';
                                  return null;
                                },
                              ),
                              SizedBox(
                                height: MobileOptimization.getFormFieldSpacing(context),
                              ),
                              TextFormField(
                                controller: _reasonController,
                                decoration: InputDecoration(
                                  labelText: 'Reason',
                                  hintText: 'Enter reason for expense',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF3B82F6), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  prefixIcon: const Icon(Icons.description,
                                      color: Color(0xFF64748B)),
                                  contentPadding: MobileOptimization.getTextFieldPadding(context),
                                ),
                                maxLines: MobileOptimization.isMobile(context) ? 4 : 3,
                              ),
                              SizedBox(
                                height: MobileOptimization.getFormFieldSpacing(context) * 1.5,
                              ),
                              MobileOptimization.isMobile(context)
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        MobileOptimization.mobileButton(
                                          onPressed:
                                              _isLoading ? null : _saveExpense,
                                          child: _isLoading
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Text(
                                                  _isEditing ? 'UPDATE' : 'SAVE',
                                                ),
                                          backgroundColor:
                                              const Color(0xFF3B82F6),
                                          isFullWidth: true,
                                        ),
                                        SizedBox(
                                          height: MobileOptimization
                                              .getFormFieldSpacing(context),
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: _isLoading
                                                    ? null
                                                    : _showFindExpenseDialog,
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                      color: Color(0xFFE2E8F0)),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  minimumSize: Size(
                                                    0,
                                                    MobileOptimization.isMobile(
                                                            context)
                                                        ? TouchOptimization
                                                            .recommendedTouchTarget
                                                        : 40,
                                                  ),
                                                  padding:
                                                      MobileOptimization.isMobile(
                                                              context)
                                                          ? TouchOptimization
                                                              .getTouchPadding()
                                                          : const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 16,
                                                              vertical: 8),
                                                ),
                                                icon: const Icon(Icons.search),
                                                label: const Text(
                                                  'FIND',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: MobileOptimization
                                                  .getResponsiveSpacing(
                                                context,
                                                mobile: 12,
                                                tablet: 16,
                                                desktop: 16,
                                              ),
                                            ),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed:
                                                    _isLoading ? null : _clearForm,
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                      color: Color(0xFFE2E8F0)),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  minimumSize: Size(
                                                    0,
                                                    MobileOptimization.isMobile(
                                                            context)
                                                        ? TouchOptimization
                                                            .recommendedTouchTarget
                                                        : 40,
                                                  ),
                                                  padding:
                                                      MobileOptimization.isMobile(
                                                              context)
                                                          ? TouchOptimization
                                                              .getTouchPadding()
                                                          : const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 16,
                                                              vertical: 8),
                                                ),
                                                child: Text(
                                                  'CLEAR',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: _isEditing
                                                        ? const Color(0xFFEF4444)
                                                        : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : _showFindExpenseDialog,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        side: const BorderSide(
                                            color: Color(0xFFE2E8F0)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      icon: const Icon(Icons.search),
                                      label: const Text(
                                        'FIND',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ),
                                        SizedBox(
                                          width: MobileOptimization
                                              .getResponsiveSpacing(
                                            context,
                                            mobile: 12,
                                            tablet: 16,
                                            desktop: 16,
                                          ),
                                        ),
                                  Expanded(
                                    child: OutlinedButton(
                                            onPressed:
                                                _isLoading ? null : _clearForm,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        side: const BorderSide(
                                            color: Color(0xFFE2E8F0)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        'CLEAR',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: _isEditing
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                        SizedBox(
                                          width: MobileOptimization
                                              .getResponsiveSpacing(
                                            context,
                                            mobile: 12,
                                            tablet: 16,
                                            desktop: 16,
                                          ),
                                        ),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading ? null : _saveExpense,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF3B82F6),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            )
                                          : Text(
                                              _isEditing ? 'UPDATE' : 'SAVE',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(
                          child: Column(
                            children: [
                              const Icon(Icons.error,
                                  color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text('Error: $error'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () =>
                                    ref.refresh(expenseHeadNotifierProvider),
                                child: Text('common.retry'.tr()),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

