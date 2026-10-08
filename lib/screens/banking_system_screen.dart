import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/bank.dart';
import '../models/bank_payment.dart';
import '../providers/currency_provider.dart';
import '../providers/bank_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/supplier_payment_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/customer_provider.dart';
import '../models/currency.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import '../models/payment.dart';
import '../widgets/app_snack_bar.dart';

class BankingSystemScreen extends ConsumerStatefulWidget {
  const BankingSystemScreen({super.key});

  @override
  ConsumerState<BankingSystemScreen> createState() =>
      _BankingSystemScreenState();
}

class _BankingSystemScreenState extends ConsumerState<BankingSystemScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Search and filter controllers
  final _dateController = TextEditingController();
  final _partyController = TextEditingController();
  final _chequeNumberController = TextEditingController();

  DateTime? _selectedDate;
  String _selectedBank = 'All Banks';
  List<BankModel> _banks = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Refresh banks when screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBanks();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _dateController.dispose();
    _partyController.dispose();
    _chequeNumberController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data when app comes to foreground
      _refreshBanks();
    }
  }

  void _refreshBanks() {
    if (mounted) {
      // Invalidate all bank-related providers for real-time updates
      ref.invalidate(bankNotifierProvider);
      ref.invalidate(bankNotifierProvider);
      ref.invalidate(allBankPaymentsProvider);
      ref.invalidate(activeBanksProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;
    final currency = ref.watch(currentCurrencyProvider);
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;
    final canEditBanking = currentUser?.canManageBanks() ?? false;

    // Watch providers for data
    final banksAsync = ref.watch(banksProvider);
    final allPaymentsAsync = ref.watch(allBankPaymentsProvider);

    final isDarkMode = ref.watch(isDarkModeProvider);
    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildBanksList(banksAsync, currency, canEditBanking),
                  const SizedBox(height: 24),
                  _buildSearchAndFilterSection(),
                  const SizedBox(height: 24),
                  _buildBankingTable(currency, banksAsync, allPaymentsAsync),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(isMobile),
    );
  }

  Widget _buildAppBar() {
    final isDarkMode = ref.watch(isDarkModeProvider);
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor:
          isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [
                      AppColors.surfaceDark,
                      AppColors.backgroundDark,
                      AppColors.surfaceDark
                    ]
                  : [
                      AppColors.primaryColor,
                      AppColors.primaryDark,
                      AppColors.primaryColor.withValues(alpha: 0.8)
                    ],
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
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'banking.system_title'.tr(),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Roboto',
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'banking.subtitle'.tr(),
                              style: const TextStyle(
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

  Widget _buildBanksList(AsyncValue<List<BankModel>> banksAsync,
      Currency currency, bool canEditBanking) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    return banksAsync.when(
      data: (banks) {
        if (banks.isEmpty) {
          return const SizedBox.shrink();
        }

        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 500),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.95 + (0.05 * value),
              child: Opacity(
                opacity: value,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDarkMode ? 0.1 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Banks',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          Text(
                            '${banks.length} ${banks.length == 1 ? 'Bank' : 'Banks'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: banks
                            .map((bank) => _buildBankCard(
                                bank, currency, isDarkMode, canEditBanking))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildBankCard(
      BankModel bank, Currency currency, bool isDarkMode, bool canEditBanking) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppColors.backgroundDark.withValues(alpha: 0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bank.isActive
              ? AppColors.successColor.withValues(alpha: 0.3)
              : AppColors.errorColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: bank.isActive
                            ? AppColors.successColor.withValues(alpha: 0.1)
                            : AppColors.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.account_balance,
                        color: bank.isActive
                            ? AppColors.successColor
                            : AppColors.errorColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bank.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (bank.code.isNotEmpty)
                            Text(
                              'Code: ${bank.code}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    if (canEditBanking) {
                      context.go('/edit-bank?id=${bank.id}');
                    } else {
                      AppSnackBar.show(
                        context,
                        const SnackBar(
                          content: Text(
                              'You do not have permission to edit banking.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } else if (value == 'ledger') {
                    context.go('/bank-ledger?id=${bank.id}');
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    enabled: canEditBanking,
                    child: Row(
                      children: [
                        Icon(Icons.edit,
                            size: 18,
                            color: canEditBanking
                                ? AppColors.primaryColor
                                : Colors.grey),
                        const SizedBox(width: 8),
                        Text('Edit Bank',
                            style: TextStyle(
                                color: canEditBanking ? null : Colors.grey)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'ledger',
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long,
                            size: 18, color: AppColors.primaryColor),
                        SizedBox(width: 8),
                        Text('View Ledger'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (bank.accountNumber!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Account: ${bank.accountNumber}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bank.isActive
                    ? AppColors.successColor.withValues(alpha: 0.1)
                    : AppColors.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                bank.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: bank.isActive
                      ? AppColors.successColor
                      : AppColors.errorColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    final isDarkMode = ref.watch(isDarkModeProvider);
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Opacity(
                opacity: value,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDarkMode ? 0.1 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search & Filter',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              isDarkMode ? Colors.white : AppColors.textPrimary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // Date Search
                          Expanded(
                            child: _buildSearchField(
                              controller: _dateController,
                              label: 'Date:',
                              hint: 'Select date',
                              icon: Icons.calendar_today,
                              onTap: () => _selectDate(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Party Search
                          Expanded(
                            child: _buildSearchField(
                              controller: _partyController,
                              label: 'Party:',
                              hint: 'Enter party name',
                              icon: Icons.person,
                              onChanged: (value) => _searchPayments(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Cheque Number Search
                          Expanded(
                            child: _buildSearchField(
                              controller: _chequeNumberController,
                              label: 'Cheque No:',
                              hint: 'Enter cheque number',
                              icon: Icons.receipt,
                              onChanged: (value) => _searchPayments(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // Bank Filter
                          Expanded(
                            child: _buildBankFilter(),
                          ),
                          const SizedBox(width: 16),
                          // Search Button
                          ElevatedButton.icon(
                            onPressed: _searchPayments,
                            icon: const Icon(Icons.search, size: 18),
                            label: Text('common.search'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )));
      },
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
  }) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color:
                isDarkMode ? AppColors.textSecondary : AppColors.textSecondary,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderColor),
              borderRadius: BorderRadius.circular(8),
              color:
                  isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    onChanged: onChanged,
                    enabled: onTap == null,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: isDarkMode
                            ? AppColors.textTertiary
                            : AppColors.textTertiary,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.arrow_drop_down, color: AppColors.primaryColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBankFilter() {
    final isDarkMode = ref.watch(isDarkModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bank:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color:
                isDarkMode ? AppColors.textSecondary : AppColors.textSecondary,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedBank,
          items: [
            const DropdownMenuItem(
                value: 'All Banks', child: Text('All Banks')),
            ..._banks.map((bank) => DropdownMenuItem(
                  value: bank.name,
                  child: Text(bank.name),
                )),
          ],
          onChanged: (value) {
            if (mounted) {
              setState(() {
                _selectedBank = value!;
              });
            }
            _searchPayments();
          },
          dropdownColor:
              isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
          style: TextStyle(
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
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
        ),
      ],
    );
  }

  Widget _buildBankingTable(
      Currency currency,
      AsyncValue<List<BankModel>> banksAsync,
      AsyncValue<List<BankPaymentModel>> allPaymentsAsync) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: Opacity(
              opacity: value,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.surfaceDark
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDarkMode ? 0.1 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Banking Transactions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            // Invalidate all bank-related providers for complete refresh
                            ref.invalidate(bankNotifierProvider);
                            ref.invalidate(bankNotifierProvider);
                            ref.invalidate(allBankPaymentsProvider);
                            ref.invalidate(activeBanksProvider);
                          },
                          icon: Icon(Icons.refresh,
                              color: AppColors.primaryColor),
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 768;
                        return isMobile
                            ? _buildTransactionsCardView(currency, banksAsync,
                                allPaymentsAsync, isDarkMode)
                            : _buildTransactionsTable(currency, banksAsync,
                                allPaymentsAsync, isDarkMode);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }

// Fix for BankingSystemScreen
// Replace the _buildTransactionsTable method with this updated version:

  Widget _buildTransactionsTable(
      Currency currency,
      AsyncValue<List<BankModel>> banksAsync,
      AsyncValue<List<BankPaymentModel>> allPaymentsAsync,
      bool isDarkMode) {
    // Handle loading state
    if (allPaymentsAsync.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
        ),
      );
    }

    // Handle error state
    if (allPaymentsAsync.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.error, color: AppColors.errorColor, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading transactions: ${allPaymentsAsync.error}',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.errorColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(allBankPaymentsProvider);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                ),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    // Get payments data
    final payments = allPaymentsAsync.value ?? [];
    final banks = banksAsync.value ?? [];

    // Update banks list in real-time whenever it changes
    if (banks.isNotEmpty) {
      // Use a post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _banks.length != banks.length) {
          setState(() {
            _banks = banks;
          });
        }
      });
    }

    // Filter out cancelled and completed (cleared) cheques - only show pending and unclear cheques
    // Non-cheque payments remain visible
    List<BankPaymentModel> filteredPayments = payments.where((payment) {
      // If it's a cheque, only show if status is 'pending' or 'unclear'
      if (payment.paymentType == 'cheque') {
        return payment.status == 'pending' || payment.status == 'unclear';
      }
      // For non-cheque payments, show all
      return true;
    }).toList();

    // Calculate cheque summary (count and total amount) for currently visible rows
    final int totalCheques = filteredPayments
        .where((p) => p.paymentType == 'cheque')
        .length;
    final double totalChequeAmount = filteredPayments
        .where((p) => p.paymentType == 'cheque')
        .fold(0.0, (sum, p) => sum + p.amount);

    // Apply additional filters

    if (_isSearching) {
      if (_partyController.text.isNotEmpty) {
        filteredPayments = filteredPayments
            .where((p) => p.partyName
                .toLowerCase()
                .contains(_partyController.text.toLowerCase()))
            .toList();
      }

      if (_chequeNumberController.text.isNotEmpty) {
        filteredPayments = filteredPayments
            .where((p) =>
                p.chequeNumber
                    ?.toLowerCase()
                    .contains(_chequeNumberController.text.toLowerCase()) ??
                false)
            .toList();
      }

      if (_selectedDate != null) {
        filteredPayments = filteredPayments
            .where((p) =>
                p.issueDate.year == _selectedDate!.year &&
                p.issueDate.month == _selectedDate!.month &&
                p.issueDate.day == _selectedDate!.day)
            .toList();
      }

      if (_selectedBank != 'All Banks' && banks.isNotEmpty) {
        final selectedBank = banks.firstWhere(
          (b) => b.name == _selectedBank,
          orElse: () => banks.first,
        );
        filteredPayments =
            filteredPayments.where((p) => p.bankId == selectedBank.id).toList();
      }
    }

    // Rest of the method remains the same...
    if (filteredPayments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.receipt_long,
                  color: AppColors.textSecondary, size: 48),
              const SizedBox(height: 16),
              Text(
                _isSearching
                    ? 'No transactions found matching your criteria'
                    : 'No bank payments found',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode
                      ? AppColors.textTertiary
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (!_isSearching) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.push('/bank-payment'),
                  icon: const Icon(Icons.add),
                  label: Text('banking.add_bank_payment'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cheque summary row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long, size: 16, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    'Cheques: $totalCheques',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.attach_money,
                      size: 16, color: Colors.indigo),
                  const SizedBox(width: 6),
                  Text(
                    'Cheque Amount: ${currency.symbol}${totalChequeAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Transactions table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Actions')),
              DataColumn(label: Text('Party Name')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Issue Date')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Bank')),
              DataColumn(label: Text('Cheque No')),
              DataColumn(label: Text('Cheque Date')),
              DataColumn(label: Text('Status')),
            ],
        rows: filteredPayments.map((payment) {
          return DataRow(
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (payment.status == 'pending') ...[
                      IconButton(
                        onPressed: () => _acceptPayment(payment.id!),
                        icon: const Icon(Icons.check_circle, size: 18),
                        color: AppColors.successColor,
                        tooltip: 'Mark as Cleared',
                      ),
                      if (payment.paymentType == 'cheque')
                        IconButton(
                          onPressed: () => _markAsUnclear(payment.id!),
                          icon:
                              const Icon(Icons.warning_amber_rounded, size: 18),
                          color: Colors.orange,
                          tooltip: 'Mark as Unclear',
                        ),
                      IconButton(
                        onPressed: () => _cancelPayment(payment.id!),
                        icon: const Icon(Icons.cancel, size: 18),
                        color: AppColors.errorColor,
                        tooltip: 'Cancel Payment',
                      ),
                    ] else if (payment.status == 'cleared') ...[
                      IconButton(
                        onPressed: () => _viewPaymentDetails(payment),
                        icon: const Icon(Icons.visibility, size: 18),
                        color: AppColors.primaryColor,
                        tooltip: 'View Details',
                      ),
                      if (payment.paymentType == 'cheque')
                        IconButton(
                          onPressed: () => _markAsUnclear(payment.id!),
                          icon:
                              const Icon(Icons.warning_amber_rounded, size: 18),
                          color: Colors.orange,
                          tooltip: 'Mark as Unclear',
                        ),
                    ] else if (payment.status == 'unclear') ...[
                      IconButton(
                        onPressed: () => _acceptPayment(payment.id!),
                        icon: const Icon(Icons.check_circle, size: 18),
                        color: AppColors.successColor,
                        tooltip: 'Mark as Cleared',
                      ),
                      IconButton(
                        onPressed: () => _viewPaymentDetails(payment),
                        icon: const Icon(Icons.visibility, size: 18),
                        color: AppColors.primaryColor,
                        tooltip: 'View Details',
                      ),
                    ] else if (payment.status == 'cancelled') ...[
                      IconButton(
                        onPressed: () => _viewPaymentDetails(payment),
                        icon: const Icon(Icons.visibility, size: 18),
                        color: AppColors.textSecondary,
                        tooltip: 'View Details',
                      ),
                    ],
                    IconButton(
                      onPressed: () => _viewPaymentDetails(payment),
                      icon: const Icon(Icons.info_outline, size: 18),
                      color: AppColors.primaryColor,
                      tooltip: 'View Details',
                    ),
                  ],
                ),
              ),
              DataCell(Text(payment.partyName)),
              DataCell(
                FutureBuilder<String>(
                  future: _getPartyType(payment.partyName),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    final partyType = snapshot.data ?? 'Unknown';
                    final isSupplier = partyType == 'Supplier';
                    final isCustomer = partyType == 'Customer';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSupplier
                            ? Colors.blue.shade50
                            : isCustomer
                                ? Colors.green.shade50
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSupplier
                              ? Colors.blue.shade300
                              : isCustomer
                                  ? Colors.green.shade300
                                  : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        partyType,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSupplier
                              ? Colors.blue.shade700
                              : isCustomer
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
                        ),
                      ),
                    );
                  },
                ),
              ),
              DataCell(Text(
                  '${payment.issueDate.day}-${payment.issueDate.month}-${payment.issueDate.year}')),
              DataCell(Text(
                  '${currency.symbol}${payment.amount.toStringAsFixed(2)}')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () =>
                          context.go('/bank-ledger?id=${payment.bankId}'),
                      child: Text(
                        _getBankName(payment.bankId, banks),
                        style: TextStyle(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.receipt_long, size: 16),
                      color: AppColors.primaryColor,
                      onPressed: () =>
                          context.go('/bank-ledger?id=${payment.bankId}'),
                      tooltip: 'View Ledger',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              DataCell(Text(payment.chequeNumber ?? '-')),
              DataCell(Text(payment.chequeDate != null
                  ? '${payment.chequeDate!.day}-${payment.chequeDate!.month}-${payment.chequeDate!.year}'
                  : '-')),
              DataCell(
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        _getStatusColor(payment.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(payment.status)),
                  ),
                  child: Text(
                    payment.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(payment.status),
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    )]);
  }

  Widget _buildTransactionsCardView(
      Currency currency,
      AsyncValue<List<BankModel>> banksAsync,
      AsyncValue<List<BankPaymentModel>> allPaymentsAsync,
      bool isDarkMode) {
    if (allPaymentsAsync.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (allPaymentsAsync.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.error, color: AppColors.errorColor, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading transactions: ${allPaymentsAsync.error}',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.errorColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(allBankPaymentsProvider);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  minimumSize: const Size(120, 44),
                ),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    final payments = allPaymentsAsync.value ?? [];
    final banks = banksAsync.value ?? [];

    // Filter out cancelled and completed (cleared) cheques - only show pending and unclear cheques
    // Non-cheque payments remain visible
    List<BankPaymentModel> filteredPayments = payments.where((payment) {
      // If it's a cheque, only show if status is 'pending' or 'unclear'
      if (payment.paymentType == 'cheque') {
        return payment.status == 'pending' || payment.status == 'unclear';
      }
      // For non-cheque payments, show all
      return true;
    }).toList();

    if (_isSearching) {
      if (_partyController.text.isNotEmpty) {
        filteredPayments = filteredPayments
            .where((p) => p.partyName
                .toLowerCase()
                .contains(_partyController.text.toLowerCase()))
            .toList();
      }
      if (_chequeNumberController.text.isNotEmpty) {
        filteredPayments = filteredPayments
            .where((p) =>
                p.chequeNumber
                    ?.toLowerCase()
                    .contains(_chequeNumberController.text.toLowerCase()) ??
                false)
            .toList();
      }
      if (_selectedDate != null) {
        filteredPayments = filteredPayments
            .where((p) =>
                p.issueDate.year == _selectedDate!.year &&
                p.issueDate.month == _selectedDate!.month &&
                p.issueDate.day == _selectedDate!.day)
            .toList();
      }
      if (_selectedBank != 'All Banks' && banks.isNotEmpty) {
        final selectedBank = banks.firstWhere(
          (b) => b.name == _selectedBank,
          orElse: () => banks.first,
        );
        filteredPayments =
            filteredPayments.where((p) => p.bankId == selectedBank.id).toList();
      }
    }

    if (filteredPayments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.receipt_long,
                  color: AppColors.textSecondary, size: 48),
              const SizedBox(height: 16),
              Text(
                _isSearching
                    ? 'No transactions found matching your criteria'
                    : 'No bank payments found',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode
                      ? AppColors.textTertiary
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (!_isSearching) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.push('/bank-payment'),
                  icon: const Icon(Icons.add),
                  label: Text('banking.add_bank_payment'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    minimumSize: const Size(180, 44),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredPayments.length,
      itemBuilder: (context, index) {
        final payment = filteredPayments[index];
        final statusColor = _getStatusColor(payment.status);
        final bankName = _getBankName(payment.bankId, banks);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: statusColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        payment.paymentType == 'cheque'
                            ? Icons.account_balance_wallet
                            : Icons.money,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment.partyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bankName,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        payment.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Amount',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${currency.symbol}${payment.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Type',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FutureBuilder<String>(
                            future: _getPartyType(payment.partyName),
                            builder: (context, snapshot) {
                              final partyType = snapshot.data ?? 'Unknown';
                              final isSupplier = partyType == 'Supplier';
                              final isCustomer = partyType == 'Customer';

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSupplier
                                      ? Colors.blue.shade50
                                      : isCustomer
                                          ? Colors.green.shade50
                                          : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSupplier
                                        ? Colors.blue.shade300
                                        : isCustomer
                                            ? Colors.green.shade300
                                            : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  partyType,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSupplier
                                        ? Colors.blue.shade700
                                        : isCustomer
                                            ? Colors.green.shade700
                                            : Colors.grey.shade700,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${payment.issueDate.day}-${payment.issueDate.month}-${payment.issueDate.year}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (payment.paymentType == 'cheque' &&
                    payment.chequeNumber != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cheque No',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              payment.chequeNumber!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (payment.chequeDate != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cheque Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${payment.chequeDate!.day}-${payment.chequeDate!.month}-${payment.chequeDate!.year}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (payment.status == 'pending') ...[
                      ElevatedButton.icon(
                        onPressed: () => _acceptPayment(payment.id!),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: Text('banking.accept'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(100, 44),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (payment.paymentType == 'cheque')
                        OutlinedButton.icon(
                          onPressed: () => _markAsUnclear(payment.id!),
                          icon:
                              const Icon(Icons.warning_amber_rounded, size: 18),
                          label: Text('common.unclear'.tr()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            minimumSize: const Size(100, 44),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _cancelPayment(payment.id!),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: Text('common.cancel'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.errorColor,
                          minimumSize: const Size(100, 44),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ] else if (payment.status == 'cleared') ...[
                      ElevatedButton.icon(
                        onPressed: () => _viewPaymentDetails(payment),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: Text('common.view'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(100, 44),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                      if (payment.paymentType == 'cheque') ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _markAsUnclear(payment.id!),
                          icon:
                              const Icon(Icons.warning_amber_rounded, size: 18),
                          label: Text('common.unclear'.tr()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            minimumSize: const Size(100, 44),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ] else if (payment.status == 'unclear') ...[
                      ElevatedButton.icon(
                        onPressed: () => _acceptPayment(payment.id!),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: Text('banking.accept'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(100, 44),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _viewPaymentDetails(payment),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: Text('common.view'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(100, 44),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: () => _viewPaymentDetails(payment),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: Text('common.view'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(100, 44),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to determine if party is Supplier or Customer
  Future<String> _getPartyType(String partyName) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);

      // Try supplier first
      try {
        final suppliers = await databaseService.getAllSuppliers();
        final supplier = suppliers.firstWhere(
          (s) => s.name.toLowerCase() == partyName.toLowerCase(),
        );
        return 'Supplier';
      } catch (e) {
        // Not a supplier, try customer
      }

      // Try customer
      try {
        final customers = await databaseService.getAllCustomers();
        final customer = customers.firstWhere(
          (c) => c.name.toLowerCase() == partyName.toLowerCase(),
        );
        return 'Customer';
      } catch (e) {
        // Not found
      }

      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'cleared':
        return AppColors.successColor;
      case 'pending':
        return AppColors.warningColor;
      case 'unclear':
        return Colors.orange;
      case 'cancelled':
        return AppColors.errorColor;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getBankName(int bankId, List<BankModel> banks) {
    final bank = banks.firstWhere(
      (b) => b.id == bankId,
      orElse: () => BankModel(
        name: 'Unknown Bank',
        code: 'UNK',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return bank.name;
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      if (mounted) {
        setState(() {
          _selectedDate = date;
          _dateController.text = '${date.day}-${date.month}-${date.year}';
        });
      }
      _searchPayments();
    }
  }

  Future<void> _searchPayments() async {
    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }
  }

  void _acceptPayment(int paymentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('banking.accept_payment_title'.tr()),
        content: const Text(
            'Are you sure you want to accept this payment? This will mark it as cleared.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successColor,
              foregroundColor: Colors.white,
            ),
            child: Text('banking.accept'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading dialog and store its navigator
      NavigatorState? dialogNavigator;
      bool dialogShown = false;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          dialogNavigator = Navigator.of(dialogContext);
          dialogShown = true;
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Accepting payment...'),
              ],
            ),
          );
        },
      );

      try {
        // Find the bank ID for this payment (with timeout safety)
        final allPayments = await ref
            .read(allBankPaymentsProvider.future)
            .timeout(const Duration(seconds: 10));
        final payment = allPayments.firstWhere(
          (p) => p.id == paymentId,
          orElse: () => throw Exception('Payment not found'),
        );

        final oldStatus = payment.status;

        // Update payment status to cleared
        await ref
            .read(bankPaymentsProvider(payment.bankId).notifier)
            .updatePaymentStatus(paymentId, 'cleared')
            .timeout(const Duration(seconds: 10));

        // If this is a cheque payment, update supplier/customer balance and unclearCheque
        if (payment.paymentType == 'cheque') {
          await _updatePartyUnclearCheque(
              payment.partyName, payment.amount, oldStatus, 'cleared');
          await _updatePartyBalance(
              payment.partyName, payment.amount, oldStatus, 'cleared',
              bankPayment: payment);

          // CRITICAL: Invalidate bank payments by cheque number so customer ledger FutureBuilder refreshes
          if (payment.chequeNumber != null &&
              payment.chequeNumber!.isNotEmpty) {
            ref.invalidate(
                bankPaymentsByChequeNumberProvider(payment.chequeNumber!));
          }
        }

        // Refresh all bank payments and bank data
        ref.invalidate(allBankPaymentsProvider);
        ref.invalidate(bankByIdProvider(payment.bankId));

        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('banking.accept_payment_done'.tr()),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Error accepting payment: $e'),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      } finally {
        // Always close loading dialog if it was shown
        if (dialogShown &&
            dialogNavigator != null &&
            dialogNavigator!.canPop()) {
          dialogNavigator!.pop();
        }
      }
    }
  }

  void _cancelPayment(int paymentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('banking.cancel_payment_title'.tr()),
        content: const Text(
            'Are you sure you want to cancel this payment? This will mark it as cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.no'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text('banking.cancel_payment_btn'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Show loading dialog and store its navigator
      NavigatorState? dialogNavigator;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          dialogNavigator = Navigator.of(dialogContext);
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Cancelling payment...'),
              ],
            ),
          );
        },
      );

      try {
        // Find the bank ID for this payment
        final allPayments = await ref.read(allBankPaymentsProvider.future);
        final payment = allPayments.firstWhere(
          (p) => p.id == paymentId,
          orElse: () => throw Exception('Payment not found'),
        );

        final oldStatus = payment.status;

        // Update payment status to cancelled
        await ref
            .read(bankPaymentsProvider(payment.bankId).notifier)
            .updatePaymentStatus(paymentId, 'cancelled');

        // CRITICAL: If this is a cheque payment, reverse all changes
        final paymentType = payment.paymentType.toLowerCase().trim();
        if (paymentType == 'cheque') {
          // CRITICAL: Reverse the bank balance - cheques always add balance when created
          // So we need to reverse it regardless of status (pending, unclear, or cleared)
          final bankNotifier = ref.read(bankNotifierProvider.notifier);
          final bank = await ref.read(bankByIdProvider(payment.bankId).future);
          if (bank != null) {
            // CRITICAL: Get fresh bank balance before reversing
            final bankBeforeUpdate =
                await ref.read(bankByIdProvider(payment.bankId).future);
            if (bankBeforeUpdate != null) {
              final updatedBank = bankBeforeUpdate.copyWith(
                currentBalance:
                    bankBeforeUpdate.currentBalance - payment.amount,
                updatedAt: DateTime.now(),
              );
              await bankNotifier.updateBank(updatedBank);
            }
          }

          // CRITICAL: Update supplier/customer unclearCheque (reduce it)
          await _updatePartyUnclearCheque(
              payment.partyName, payment.amount, oldStatus, 'cancelled');

          // CRITICAL: Reverse supplier/customer payment - add amount back to their balance
          // This ensures supplier/customer balance returns to what it was before cheque
          await _reversePartyPayment(payment);
        }

        // Refresh the all bank payments provider and bank data
        ref.invalidate(allBankPaymentsProvider);
        ref.invalidate(bankByIdProvider(payment.bankId));

        // Hide loading dialog using the stored navigator
        if (mounted && dialogNavigator != null && dialogNavigator!.canPop()) {
          dialogNavigator!.pop();
        }

        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('banking.cancel_payment_done'.tr()),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      } catch (error) {
        // Hide loading dialog using the stored navigator
        if (mounted && dialogNavigator != null && dialogNavigator!.canPop()) {
          dialogNavigator!.pop();
        }

        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Failed to cancel payment: $error'),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      }
    }
  }

  void _markAsUnclear(int paymentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('banking.mark_unclear_title'.tr()),
        content: const Text(
            'Are you sure you want to mark this cheque as unclear? This will add it to the supplier\'s unclear cheque balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('banking.mark_unclear_btn'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Show loading dialog and store its navigator
      NavigatorState? dialogNavigator;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          dialogNavigator = Navigator.of(dialogContext);
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Marking cheque as unclear...'),
              ],
            ),
          );
        },
      );

      try {
        // Find the bank ID for this payment
        final allPayments = await ref.read(allBankPaymentsProvider.future);
        final payment = allPayments.firstWhere(
          (p) => p.id == paymentId,
          orElse: () => throw Exception('Payment not found'),
        );

        final oldStatus = payment.status;

        // CRITICAL: Update payment status to unclear
        await ref
            .read(bankPaymentsProvider(payment.bankId).notifier)
            .updatePaymentStatus(paymentId, 'unclear');

        // CRITICAL: If this is a cheque payment, update supplier/customer unclearCheque
        // Note: Bank balance stays the same (already added when cheque was created)
        // unclearCheque increases to track the unclear amount
        // Supplier/customer balance should already be reduced (if supplier payment exists)
        if (payment.paymentType == 'cheque') {
          await _updatePartyUnclearCheque(
              payment.partyName, payment.amount, oldStatus, 'unclear');
          // CRITICAL: For unclear cheques, supplier/customer balance should already be reduced
          // (reduced when cheque was created), so we don't change it here

          // CRITICAL: Invalidate bank payments by cheque number so customer ledger FutureBuilder refreshes
          if (payment.chequeNumber != null &&
              payment.chequeNumber!.isNotEmpty) {
            ref.invalidate(
                bankPaymentsByChequeNumberProvider(payment.chequeNumber!));
          }
        }

        // Refresh all bank payments
        ref.invalidate(allBankPaymentsProvider);

        // Close loading dialog using the stored navigator
        if (mounted && dialogNavigator != null && dialogNavigator!.canPop()) {
          dialogNavigator!.pop();
        }

        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('banking.cheque_unclear_done'.tr()),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        // Close loading dialog using the stored navigator
        if (mounted && dialogNavigator != null && dialogNavigator!.canPop()) {
          dialogNavigator!.pop();
        }

        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Error marking cheque as unclear: $e'),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      }
    }
  }

  // Update supplier or customer unclearCheque when cheque status changes
  Future<void> _updatePartyUnclearCheque(
    String partyName,
    double amount,
    String oldStatus,
    String newStatus,
  ) async {
    final databaseService = ref.read(databaseServiceProvider);

    double unclearChequeChange = 0.0;

    final normalizedOldStatus = oldStatus.trim().toLowerCase();
    final normalizedNewStatus = newStatus.trim().toLowerCase();

    // Calculate change based on status transition
    if (normalizedNewStatus == 'cleared') {
      // When clearing: subtract amount if it was unclear/pending
      if (normalizedOldStatus == 'unclear' ||
          normalizedOldStatus == 'pending') {
        unclearChequeChange = -amount;
      }
    } else if (normalizedNewStatus == 'unclear') {
      // When marking as unclear: add amount if it wasn't already unclear
      if (normalizedOldStatus != 'unclear') {
        unclearChequeChange = amount;
      }
    } else if (normalizedNewStatus == 'cancelled') {
      // When cancelling: subtract amount if it was unclear/pending
      if (normalizedOldStatus == 'unclear' ||
          normalizedOldStatus == 'pending') {
        unclearChequeChange = -amount;
      }
    }

    if (unclearChequeChange == 0.0) return; // No change needed

    // Try supplier first
    try {
      final suppliers = await databaseService.getAllSuppliers();
      final supplier = suppliers.firstWhere(
        (s) => s.name.toLowerCase() == partyName.toLowerCase(),
      );

      final newUnclearCheque = (supplier.unclearCheque + unclearChequeChange)
          .clamp(0.0, double.infinity);
      final updatedSupplier = SupplierModel.fromSupplier(supplier).copyWith(
        unclearCheque: newUnclearCheque,
        updatedAt: DateTime.now(),
      );

      await ref
          .read(supplierNotifierProvider.notifier)
          .updateSupplier(updatedSupplier);

      // CRITICAL: Invalidate ALL supplier-related providers to refresh UI in real-time
      ref.invalidate(supplierByIdProvider(supplier.id!));
      ref.invalidate(suppliersProvider);
      ref.invalidate(supplierPaymentsProvider(supplier.id!));
      ref.invalidate(supplierPaymentsByDateRangeProvider((
        supplierId: supplier.id!,
        start: DateTime(2020),
        end: DateTime.now()
      )));

      return; // Successfully updated supplier unclearCheque
    } catch (e) {
      // Not a supplier, try customer
    }

    // Try customer
    try {
      final customers = await databaseService.getAllCustomers();
      final customer = customers.firstWhere(
        (c) => c.name.toLowerCase() == partyName.toLowerCase(),
      );

      final newUnclearCheque = (customer.unclearCheque + unclearChequeChange)
          .clamp(0.0, double.infinity);
      final updatedCustomer = customer.copyWith(
        unclearCheque: newUnclearCheque,
        updatedAt: DateTime.now(),
      );

      await ref
          .read(customerNotifierProvider.notifier)
          .updateCustomer(updatedCustomer);

      // CRITICAL: Invalidate ALL customer-related providers to refresh UI in real-time
      ref.invalidate(customerByIdProvider(customer.id!));
      ref.invalidate(customersProvider);
      ref.invalidate(customersWithDueProvider);
      ref.invalidate(customerPaymentsProvider(customer.id!));
      ref.invalidate(paymentsByCustomerProvider(customer.id!));
      ref.invalidate(paymentNotifierProvider);

      return; // Successfully updated customer unclearCheque
    } catch (e) {
      // Not a customer either - this is fine
      debugPrint(
          'Could not update party unclear cheque (not supplier or customer): $e');
    }
  }

  // Keep the old method name for backward compatibility
  @Deprecated('Use _updatePartyUnclearCheque instead')
  Future<void> _updateSupplierUnclearCheque(
    String partyName,
    double amount,
    String oldStatus,
    String newStatus,
  ) async {
    await _updatePartyUnclearCheque(partyName, amount, oldStatus, newStatus);
  }

  // Update supplier or customer balance when cheque status changes
  // CRITICAL: This handles balance updates correctly based on cheque lifecycle
  Future<void> _updatePartyBalance(
    String partyName,
    double amount,
    String oldStatus,
    String newStatus, {
    BankPaymentModel? bankPayment,
  }) async {
    final databaseService = ref.read(databaseServiceProvider);
    final normalizedOldStatus = oldStatus.trim().toLowerCase();
    final normalizedNewStatus = newStatus.trim().toLowerCase();

    // CRITICAL: When accepting (clearing) a cheque
    // If supplier payment exists, balance is already reduced - don't reduce again
    // If supplier payment doesn't exist (cheque created directly), reduce balance now
    if (normalizedNewStatus == 'cleared' &&
        (normalizedOldStatus == 'pending' ||
            normalizedOldStatus == 'unclear')) {
      // Try supplier first
      try {
        final suppliers = await databaseService.getAllSuppliers();
        final supplier = suppliers.firstWhere(
          (s) => s.name.toLowerCase() == partyName.toLowerCase(),
        );

        // CRITICAL: Find and update existing supplier payment record for this cheque
        // Payment record should already exist (created when cheque was received)
        // Just update the status/note to show "Cleared" status
        final supplierPayments =
            await databaseService.getSupplierPayments(supplier.id!);
        final paymentDate = bankPayment?.issueDate ?? DateTime.now();
        final chequeNumber = bankPayment?.chequeNumber ?? '';

        // Find matching payment by amount, date, and cheque number
        SupplierPaymentModel? matchingPayment;
        try {
          if (chequeNumber.isNotEmpty) {
            // Try to find by cheque number
            matchingPayment = supplierPayments.firstWhere((p) =>
                p.paymentMethod == 'cheque' &&
                p.reference == chequeNumber &&
                p.amount == amount &&
                p.status != 'cancelled' &&
                (p.date.difference(paymentDate).inDays.abs() <= 1));
          } else {
            // Try to find by amount and date
            matchingPayment = supplierPayments.firstWhere((p) =>
                p.paymentMethod == 'cheque' &&
                p.amount == amount &&
                p.status != 'cancelled' &&
                (p.date.difference(paymentDate).inDays.abs() <= 1));
          }
        } catch (e) {
          // Payment not found by exact match
        }

        if (matchingPayment != null && matchingPayment.id != null) {
          // Update existing supplier payment note/status to show "Cleared" status
          // Note: Supplier payment status is 'completed' or 'pending', we'll update note
          // CRITICAL: Preserve the existing status to ensure balance is not recalculated
          final updatedNote = matchingPayment.note?.contains('Cancelled') ==
                  true
              ? matchingPayment.note // Keep cancelled note if already cancelled
              : (matchingPayment.note?.contains('Cleared') == true
                  ? matchingPayment.note
                  : '${matchingPayment.note ?? 'Cheque'} - Cleared');

          final updatedPayment = matchingPayment.copyWith(
            note: updatedNote!.contains('Cleared')
                ? updatedNote
                : '$updatedNote - Cleared',
            status: matchingPayment
                .status, // CRITICAL: Explicitly preserve status to prevent recalculation
            updatedAt: DateTime.now(),
          );

          // CRITICAL: Update supplier payment note WITHOUT triggering balance recalculation
          // The balance was already correctly reduced when cheque was received
          // We just need to update the note to show "Cleared" status
          // The updateSupplierPayment method will NOT recalculate balance since only note changed
          await databaseService.updateSupplierPayment(updatedPayment);

          // CRITICAL: Verify supplier balance is still correct (should remain reduced)
          // Double-check by getting fresh supplier data and ensuring balance hasn't changed incorrectly
          final currentSupplier =
              await ref.read(supplierByIdProvider(supplier.id!).future);
          if (currentSupplier != null) {
            // Verify balance is still correctly reduced (should be less than before payment)
            // If somehow balance was increased, we need to recalculate it correctly
            final recalculatedBalance =
                await databaseService.recalculateSupplierBalance(supplier.id!);
            // Only update if there's a significant discrepancy (more than 0.01 difference)
            if ((currentSupplier.currentBalance - recalculatedBalance).abs() >
                0.01) {
              // Balance was incorrectly changed, correct it
              final correctedSupplier = currentSupplier.copyWith(
                currentBalance: recalculatedBalance,
                updatedAt: DateTime.now(),
              );
              await ref
                  .read(supplierNotifierProvider.notifier)
                  .updateSupplier(correctedSupplier);
            }
          }

          // CRITICAL: Invalidate ALL supplier-related providers to refresh UI in real-time
          ref.invalidate(supplierByIdProvider(supplier.id!));
          ref.invalidate(supplierNotifierProvider);
          ref.invalidate(supplierPaymentsProvider(supplier.id!));
          ref.invalidate(supplierPaymentsByDateRangeProvider((
            supplierId: supplier.id!,
            start: DateTime(2020),
            end: DateTime.now()
          )));

          // CRITICAL: Invalidate bank payments by cheque number so supplier ledger FutureBuilder refreshes
          if (chequeNumber.isNotEmpty) {
            ref.invalidate(bankPaymentsByChequeNumberProvider(chequeNumber));
          }
        } else {
          // CRITICAL: No matching supplier payment found - this is a standalone bank cheque
          // Balance was never reduced, so we don't need to reduce it now
          // unclearCheque was increased when cheque was created, it will be reduced now
          // This means amount moves from unclearCheque to bank (which is correct)

          // Still invalidate providers to refresh UI
          ref.invalidate(supplierByIdProvider(supplier.id!));
          ref.invalidate(supplierNotifierProvider);
          ref.invalidate(supplierPaymentsProvider(supplier.id!));
        }

        // Balance was already reduced when cheque was received, unclearCheque will be reduced
        // No need to create new payment or modify balance
        return; // Successfully handled supplier balance
      } catch (e) {
        // Not a supplier, try customer
      }

      // Try customer
      try {
        final customers = await databaseService.getAllCustomers();
        final customerModel = customers.firstWhere(
          (c) => c.name.toLowerCase() == partyName.toLowerCase(),
        );

        // CRITICAL: Find and update existing customer payment record for this cheque
        // Payment record should already exist (created when cheque was received)
        // Just update the note to show "Cleared" status
        final customerPayments =
            await databaseService.getPaymentsByCustomer(customerModel.id!);
        final paymentDate = bankPayment?.issueDate ?? DateTime.now();
        final chequeNumber = bankPayment?.chequeNumber ?? '';

        // Find matching payment by amount, date, and cheque number in note
        PaymentModel? matchingPayment;
        try {
          matchingPayment = customerPayments.firstWhere((p) =>
              p.paymentMethod == PaymentMethod.cheque &&
              p.amount == amount &&
              (p.date.difference(paymentDate).inDays.abs() <= 1) &&
              (chequeNumber.isEmpty ||
                  (p.note?.contains(chequeNumber) ?? false)));
        } catch (e) {
          // Payment not found by exact match
        }

        if (matchingPayment != null && matchingPayment.id != null) {
          // Update existing payment note to show "Cleared" status
          final updatedNote = matchingPayment.note?.contains('Cancelled') ==
                  true
              ? matchingPayment.note // Keep cancelled note if already cancelled
              : (matchingPayment.note?.replaceAll('Pending', 'Cleared') ??
                  'Cheque #$chequeNumber - Cleared');

          final updatedPayment = matchingPayment.copyWith(
            note: updatedNote!.contains('Cleared')
                ? updatedNote
                : '$updatedNote - Cleared',
          );

          await databaseService.updatePayment(updatedPayment);

          // CRITICAL: Recalculate customer balance to ensure it's up to date
          final recalculatedBalance = await databaseService
              .recalculateCustomerBalance(customerModel.id!);
          final updatedCustomer = customerModel.copyWith(
            totalDue: recalculatedBalance,
            updatedAt: DateTime.now(),
          );
          await ref
              .read(customerNotifierProvider.notifier)
              .updateCustomer(updatedCustomer);

          // Invalidate ALL customer-related providers to refresh UI in real-time
          ref.invalidate(customerByIdProvider(customerModel.id!));
          ref.invalidate(customersProvider);
          ref.invalidate(customersWithDueProvider);
          ref.invalidate(customerPaymentsProvider(customerModel.id!));
          ref.invalidate(paymentsByCustomerProvider(customerModel.id!));
          ref.invalidate(paymentNotifierProvider);

          // CRITICAL: Invalidate bank payments by cheque number so customer ledger FutureBuilder refreshes
          if (chequeNumber.isNotEmpty) {
            ref.invalidate(bankPaymentsByChequeNumberProvider(chequeNumber));
          }
        }

        // Balance was already reduced when cheque was received, unclearCheque will be reduced
        // No need to create new payment or modify balance
        // If payment already exists, balance was already reduced - do nothing
        return; // Successfully handled customer balance
      } catch (e) {
        // Not a customer either - this is fine
        debugPrint(
            'Could not update party balance (not supplier or customer): $e');
      }
    }
  }

  Future<void> _reversePartyPayment(BankPaymentModel bankPayment) async {
    final databaseService = ref.read(databaseServiceProvider);

    // Try supplier first
    try {
      final suppliers = await databaseService.getAllSuppliers();

      // Find supplier by party name
      final supplier = suppliers.firstWhere(
        (s) => s.name.toLowerCase() == bankPayment.partyName.toLowerCase(),
      );

      // Find the supplier payment that matches this bank payment
      final supplierPayments =
          await databaseService.getSupplierPayments(supplier.id!);
      SupplierPaymentModel? matchingPayment;

      if (bankPayment.chequeNumber != null &&
          bankPayment.chequeNumber!.isNotEmpty) {
        // Try to find by cheque number
        try {
          matchingPayment = supplierPayments.firstWhere(
            (p) =>
                p.reference == bankPayment.chequeNumber &&
                p.paymentMethod == 'cheque' &&
                p.amount == bankPayment.amount &&
                p.status == 'completed',
          );
        } catch (e) {
          // Payment not found by cheque number
        }
      }

      if (matchingPayment == null) {
        // If no cheque number match, try to find by amount and date proximity
        final paymentDate = bankPayment.issueDate;
        try {
          matchingPayment = supplierPayments.firstWhere(
            (p) =>
                p.paymentMethod == 'cheque' &&
                p.amount == bankPayment.amount &&
                p.status == 'completed' &&
                (p.date.difference(paymentDate).inDays.abs() <= 1),
          );
        } catch (e) {
          // Payment not found
        }
      }

      // CRITICAL: If payment is found, mark it as cancelled and reverse the balance
      if (matchingPayment != null) {
        // Update the payment status to cancelled
        final cancelledPayment = matchingPayment.copyWith(
          status: 'cancelled',
          updatedAt: DateTime.now(),
        );
        await databaseService.updateSupplierPayment(cancelledPayment);

        // CRITICAL: Recalculate supplier balance - the updateSupplierPayment method already
        // recalculates balance when status changes to cancelled, but we need to ensure it's correct
        // The recalculateSupplierBalance method excludes cancelled cheques, so balance is already correct
        // DO NOT add the amount back - that would cause double-counting!
        final currentSupplier =
            await ref.read(supplierByIdProvider(supplier.id!).future);
        if (currentSupplier != null) {
          // Recalculate supplier balance to ensure accuracy (excludes cancelled cheques)
          final recalculatedBalance =
              await databaseService.recalculateSupplierBalance(supplier.id!);
          // Use the recalculated balance directly - it already excludes the cancelled cheque
          final updatedSupplier = currentSupplier.copyWith(
            currentBalance: recalculatedBalance,
            updatedAt: DateTime.now(),
          );
          await ref
              .read(supplierNotifierProvider.notifier)
              .updateSupplier(updatedSupplier);

          // CRITICAL: Invalidate ALL supplier-related providers to refresh UI in real-time
          ref.invalidate(supplierByIdProvider(supplier.id!));
          ref.invalidate(supplierNotifierProvider);
          ref.invalidate(supplierPaymentsProvider(supplier.id!));
          ref.invalidate(supplierPaymentsByDateRangeProvider((
            supplierId: supplier.id!,
            start: DateTime(2020),
            end: DateTime.now()
          )));

          // CRITICAL: Invalidate bank payments by cheque number so supplier ledger FutureBuilder refreshes
          final chequeNumber = bankPayment.chequeNumber ?? '';
          if (chequeNumber.isNotEmpty) {
            ref.invalidate(bankPaymentsByChequeNumberProvider(chequeNumber));
          }

          return; // Successfully reversed supplier payment
        }
      } else {
        // CRITICAL: No matching supplier payment found
        // This could be a standalone bank cheque payment (created directly in bank screen)
        // If supplier balance was never reduced, we don't need to add it back
        // For safety, we'll still check and update if needed
        final currentSupplier =
            await ref.read(supplierByIdProvider(supplier.id!).future);
        if (currentSupplier != null) {
          // Check if this might be a standalone cheque - if unclearCheque was increased, reduce it
          // But we don't modify currentBalance if no payment record exists
          debugPrint(
              'No matching supplier payment found for bank payment ${bankPayment.id} - may be standalone cheque');
        }
      }
    } catch (e) {
      // Not a supplier payment, try customer
      debugPrint('Not a supplier payment, trying customer: $e');
    }

    // Try customer payment
    try {
      final customers = await databaseService.getAllCustomers();

      // Find customer by party name
      final customer = customers.firstWhere(
        (c) => c.name.toLowerCase() == bankPayment.partyName.toLowerCase(),
      );

      // Find the customer payment that matches this bank payment
      final customerPayments =
          await databaseService.getPaymentsByCustomer(customer.id!);

      // Find matching payment by amount, date, and cheque number in note
      PaymentModel? matchingPayment;
      final paymentDate = bankPayment.issueDate;
      final chequeNumber = bankPayment.chequeNumber ?? '';

      try {
        matchingPayment = customerPayments.firstWhere(
          (p) =>
              p.paymentMethod == PaymentMethod.cheque &&
              p.amount == bankPayment.amount &&
              (p.date.difference(paymentDate).inDays.abs() <= 1) &&
              (chequeNumber.isEmpty ||
                  (p.note?.contains(chequeNumber) ?? false)),
        );
      } catch (e) {
        // Payment not found by amount and date
      }

      // If payment is found, mark it as cancelled (don't delete, keep for history)
      if (matchingPayment != null && matchingPayment.id != null) {
        // Update payment note to show "Cancelled" status
        // Ensure note contains "Cancelled" so it's excluded from balance calculation
        final currentNote = matchingPayment.note ?? '';
        final cancelledNote = currentNote.contains('Cancelled') || currentNote.contains('cancelled')
            ? currentNote // Already cancelled
            : (currentNote.contains('Cleared') || currentNote.contains('cleared')
                ? currentNote.replaceAll(RegExp(r'(?i)Cleared'), 'Cancelled')
                : '${currentNote.isNotEmpty ? currentNote : 'Cheque #$chequeNumber'} - Cancelled');

        final updatedPayment = matchingPayment.copyWith(
          note: cancelledNote,
        );

        // CRITICAL: Determine old status before cancelling
        // Check if payment was unclear, pending, or cleared
        final oldNote = matchingPayment.note?.toLowerCase() ?? '';
        String oldStatus = 'pending'; // Default
        if (oldNote.contains('unclear')) {
          oldStatus = 'unclear';
        } else if (oldNote.contains('cleared')) {
          oldStatus = 'cleared';
        } else if (oldNote.contains('pending')) {
          oldStatus = 'pending';
        }

        // CRITICAL: Update unclearCheque FIRST - reduce it when cancelling
        // If the cheque was unclear or pending, reduce unclearCheque
        // This moves the amount from unclearCheque back to balance
        if (oldStatus == 'unclear' || oldStatus == 'pending') {
          await _updatePartyUnclearCheque(
            customer.name,
            bankPayment.amount,
            oldStatus,
            'cancelled',
          );
        }

        // CRITICAL: Update payment first to mark as cancelled
        // This will trigger balance recalculation which excludes cancelled cheques
        await databaseService.updatePayment(updatedPayment);

        // CRITICAL: Recalculate balance AFTER marking payment as cancelled
        // The recalculateCustomerBalance method will exclude cancelled cheques,
        // which effectively adds the amount back to balance
        final currentCustomer =
            await ref.read(customerByIdProvider(customer.id!).future);
        if (currentCustomer != null) {
          // Recalculate balance (will exclude cancelled payment from calculations)
          // Since the cancelled cheque is excluded, balance will be restored (increased)
          final recalculatedBalance =
              await databaseService.recalculateCustomerBalance(customer.id!);
          
          // Update customer with recalculated balance
          final updatedCustomer = currentCustomer.copyWith(
            totalDue: recalculatedBalance,
            updatedAt: DateTime.now(),
          );
          await ref
              .read(customerNotifierProvider.notifier)
              .updateCustomer(updatedCustomer);

          // CRITICAL: Invalidate ALL customer-related providers to refresh UI in real-time
          ref.invalidate(customerByIdProvider(customer.id!));
          ref.invalidate(customersProvider);
          ref.invalidate(customersWithDueProvider);
          ref.invalidate(customerPaymentsProvider(customer.id!));
          ref.invalidate(paymentsByCustomerProvider(customer.id!));
          ref.invalidate(paymentNotifierProvider);

          // CRITICAL: Invalidate bank payments by cheque number so customer ledger FutureBuilder refreshes
          if (chequeNumber.isNotEmpty) {
            ref.invalidate(bankPaymentsByChequeNumberProvider(chequeNumber));
          }
        }
        return; // Successfully cancelled customer cheque payment
      }

      // CRITICAL: If no customer payment exists, this shouldn't happen for new flow
      // But handle it gracefully - return amount to balance
      final currentCustomer =
          await ref.read(customerByIdProvider(customer.id!).future);
      if (currentCustomer != null) {
        // Increase customer balance because cheque was cancelled - customer still owes the money
        final recalculatedBalance =
            await databaseService.recalculateCustomerBalance(customer.id!);
        final updatedCustomer = currentCustomer.copyWith(
          totalDue: recalculatedBalance,
          updatedAt: DateTime.now(),
        );
        await ref
            .read(customerNotifierProvider.notifier)
            .updateCustomer(updatedCustomer);

        // CRITICAL: Invalidate ALL customer-related providers to refresh UI in real-time
        ref.invalidate(customerByIdProvider(customer.id!));
        ref.invalidate(customersProvider);
        ref.invalidate(customersWithDueProvider);
        ref.invalidate(customerPaymentsProvider(customer.id!));
        ref.invalidate(paymentsByCustomerProvider(customer.id!));
        ref.invalidate(paymentNotifierProvider);

        // CRITICAL: Invalidate bank payments by cheque number so customer ledger FutureBuilder refreshes
        final chequeNumber = bankPayment.chequeNumber ?? '';
        if (chequeNumber.isNotEmpty) {
          ref.invalidate(bankPaymentsByChequeNumberProvider(chequeNumber));
        }
        return; // Successfully reversed customer cheque payment
      }
    } catch (e) {
      // Not a customer payment either - this is fine, just log it
      debugPrint(
          'Could not reverse party payment (not supplier or customer): $e');
    }
  }

  void _showBankDetails(int bankId) {
    // TODO: Navigate to bank details or show bank cheques
    AppSnackBar.show(
      context,
      SnackBar(
        content: Text('Showing cheques for bank ID: $bankId'),
        backgroundColor: AppColors.primaryColor,
      ),
    );
  }

  void _viewPaymentDetails(BankPaymentModel payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('banking.payment_details'.tr()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Party Name', payment.partyName),
              if (payment.otherName != null)
                _buildDetailRow('Other Name', payment.otherName!),
              _buildDetailRow('Amount', payment.amount.toStringAsFixed(2)),
              _buildDetailRow('Payment Type', payment.paymentType),
              if (payment.chequeNumber != null)
                _buildDetailRow('Cheque Number', payment.chequeNumber!),
              if (payment.chequeDate != null)
                _buildDetailRow('Cheque Date',
                    '${payment.chequeDate!.day}-${payment.chequeDate!.month}-${payment.chequeDate!.year}'),
              _buildDetailRow('Issue Date',
                  '${payment.issueDate.day}-${payment.issueDate.month}-${payment.issueDate.year}'),
              _buildDetailRow('Paid Date',
                  '${payment.paidDate.day}-${payment.paidDate.month}-${payment.paidDate.year}'),
              _buildDetailRow('Previous Balance',
                  payment.previousBalance.toStringAsFixed(2)),
              _buildDetailRow(
                  'New Balance', payment.newBalance.toStringAsFixed(2)),
              _buildDetailRow('Status', payment.status),
              if (payment.notes != null)
                _buildDetailRow('Notes', payment.notes!),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons(bool isMobile) {
    if (isMobile) {
      // Mobile: Stacked FABs
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () => context.go('/add-bank'),
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.account_balance),
            label: Text('misc.add_bank'.tr()),
            heroTag: "add_bank",
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            onPressed: () => context.push('/bank-payment'),
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text('banking.add_bank_payment'.tr()),
            heroTag: "add_payment",
          ),
        ],
      );
    } else {
      // Desktop: Single FAB with menu
      return FloatingActionButton(
        onPressed: _showActionMenu,
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        heroTag: "banking_main_fab",
        child: const Icon(Icons.add),
      );
    }
  }

  void _showActionMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('banking.quick_actions'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.account_balance, color: Color(0xFF10B981)),
              title: Text('misc.add_bank'.tr()),
              onTap: () {
                Navigator.pop(context);
                context.go('/add-bank');
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment, color: Color(0xFF6366F1)),
              title: Text('banking.add_bank_payment'.tr()),
              onTap: () {
                Navigator.pop(context);
                context.push('/bank-payment');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          )
        ],
      ),
    );
  }
}
