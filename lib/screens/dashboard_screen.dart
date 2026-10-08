import 'dart:io';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../providers/sale_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/product_provider.dart';
import '../providers/wallpaper_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/category_provider.dart';
import '../providers/dashboard_theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../models/currency.dart';
import '../models/employee.dart';
import '../models/sale.dart';
import '../services/global_refresh_service.dart';
import '../widgets/enhanced_stat_card.dart';
import '../theme/app_theme.dart';
import '../providers/network_provider.dart';
import '../services/database_sync_service.dart';
import '../utils/mobile_optimization.dart';
import '../router/app_router.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  // Cache for data to prevent excessive database calls
  List<SaleModel>? _cachedTodaySales;
  List<SaleModel>? _cachedWeekSales;
  DateTime? _lastTodayDataFetch;
  DateTime? _lastWeekDataFetch;

  @override
  void dispose() {
    _animationController.dispose();
    _clockTimer.cancel();
    super.dispose();
  }

  // Method to clear cache when new data is added
  void _clearDataCache() {
    _cachedTodaySales = null;
    _cachedWeekSales = null;
    _lastTodayDataFetch = null;
    _lastWeekDataFetch = null;
  }

  // Check if stats cards should be shown
  bool _shouldShowStatsCards() {
    // This will be checked asynchronously via FutureBuilder
    // For now, return true by default, will be updated via state
    return _showStatsCards;
  }

  bool _showStatsCards = true; // Default to showing stats cards

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

    // Initialize clock timer (reduced frequency to prevent excessive rebuilds)
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });

    // Load stats cards visibility setting
    _loadStatsCardsVisibility();

    // Trigger global refresh when dashboard loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalRefreshService.refreshAllData(ref);
    });
  }

  Future<void> _loadStatsCardsVisibility() async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final hideStatsCards =
          await databaseService.getSetting('hide_stats_cards');
      // If setting is 'true', hide stats cards (don't show them)
      if (mounted) {
        setState(() {
          _showStatsCards = hideStatsCards != 'true';
        });
      }
    } catch (e) {
      // Default to showing stats cards if there's an error
      if (mounted) {
        setState(() {
          _showStatsCards = true;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload stats cards visibility when screen becomes active again
    // This ensures changes from settings are reflected immediately
    _loadStatsCardsVisibility();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;
    final currency = ref.watch(currentCurrencyProvider);
    final currentUser = ref.watch(authProvider).currentUser;
    final canViewDashboard = currentUser != null &&
        (currentUser.isAdmin ||
            (currentUser.isManager &&
                (currentUser.permissions['view_dashboard'] ?? true)));

    if (!canViewDashboard) {
      return _buildDashboardAccessDenied();
    }

    return _buildWindowsClassicDashboard(currency, isMobile: isMobile);
  }

  Widget _buildDashboardAccessDenied() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 56,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              Text(
                'common.access_denied'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'dashboard.access_admin_manager_only'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWindowsClassicDashboard(Currency currency,
      {required bool isMobile}) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          _buildWindowsTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 14 : 24,
                isMobile ? 16 : 22,
                isMobile ? 14 : 24,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'dashboard.title'.tr(),
                              style: TextStyle(
                                fontSize: isMobile ? 24 : 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'A clear view of today’s sales and business activity.',
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isMobile)
                        FilledButton.icon(
                          onPressed: () => context.go('/pos'),
                          icon:
                              const Icon(Icons.point_of_sale_rounded, size: 19),
                          label: const Text('Open POS'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildWindowsQuickTiles(currency),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 1000;
                      if (isNarrow) {
                        return Column(
                          children: [
                            _buildWindowsPanel(
                              title: 'dashboard.sales_chart'.tr(),
                              child: SizedBox(
                                height: isMobile ? 240 : 280,
                                child: _buildInteractiveChart(currency),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildWindowsPanel(
                              title:
                                  'dashboard.top_products_month'.tr(namedArgs: {
                                'month': DateFormat('MMMM yyyy')
                                    .format(_currentTime),
                              }),
                              child: SizedBox(
                                height: isMobile ? 240 : 280,
                                child: _buildWindowsTopProductsList(currency),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildWindowsPanel(
                              title: 'dashboard.sales_chart'.tr(),
                              child: SizedBox(
                                height: 280,
                                child: _buildInteractiveChart(currency),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: _buildWindowsPanel(
                              title:
                                  'dashboard.top_products_month'.tr(namedArgs: {
                                'month': DateFormat('MMMM yyyy')
                                    .format(_currentTime),
                              }),
                              child: SizedBox(
                                height: 280,
                                child: _buildWindowsTopProductsList(currency),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildWindowsKpiStrip(currency),
                  const SizedBox(height: 14),
                  _buildWindowsInsightsSection(currency),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildQuickActionFAB(isMobile),
    );
  }

  Widget _buildWindowsTopBar() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded,
              color: AppColors.primaryColor, size: 21),
          const SizedBox(width: 8),
          Text(
            'dashboard.retail_pos'.tr(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            DateFormat('d MMMM yyyy hh:mm a').format(_currentTime),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 14),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFE8F1FC),
            child: Icon(Icons.person_outline_rounded,
                size: 17, color: AppColors.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowsQuickTiles(Currency currency) {
    final productsAsync = ref.watch(productsProvider);
    final customersAsync = ref.watch(customerNotifierProvider);
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return FutureBuilder<List<SaleModel>>(
      future: _getTodaySales(),
      builder: (context, salesSnapshot) {
        final sales = salesSnapshot.data ?? [];
        final totalSales = sales.fold(0.0, (sum, sale) => sum + sale.total);
        final totalOrders = sales.length;
        final openInvoices = sales
            .where((sale) => sale.due > 0 || sale.status != SaleStatus.paid)
            .length;

        return categoriesAsync.when(
          data: (categories) {
            return customersAsync.when(
              data: (customers) {
                return productsAsync.when(
                  data: (products) {
                    return FutureBuilder<List<EmployeeModel>>(
                      future:
                          ref.read(databaseServiceProvider).getAllEmployees(),
                      builder: (context, employeesSnapshot) {
                        final usersCount = employeesSnapshot.data?.length ?? 0;
                        final tileData = <_WindowsTileData>[
                          _WindowsTileData(
                            title: 'dashboard.tile_pos'.tr(),
                            value: '$totalOrders',
                            color: const Color(0xFFE74C3C),
                            icon: Icons.dashboard,
                            route: '/pos',
                          ),
                          _WindowsTileData(
                            title: 'dashboard.products'.tr(),
                            value: '${products.length}',
                            color: const Color(0xFFD35400),
                            icon: Icons.inventory_2,
                            route: '/products',
                          ),
                          _WindowsTileData(
                            title: 'dashboard.tile_sales'.tr(),
                            value:
                                '${currency.symbol}${totalSales.toStringAsFixed(0)}',
                            color: const Color(0xFFF1C40F),
                            icon: Icons.shopping_cart,
                            route: '/sales',
                          ),
                          _WindowsTileData(
                            title: 'dashboard.tile_open_invoices'.tr(),
                            value: '$openInvoices',
                            color: const Color(0xFF2ECC71),
                            icon: Icons.notifications,
                            route: '/sales',
                          ),
                          _WindowsTileData(
                            title: 'dashboard.tile_categories'.tr(),
                            value: '${categories.length}',
                            color: const Color(0xFF2E86C1),
                            icon: Icons.folder_open,
                            route: '/categories',
                          ),
                          _WindowsTileData(
                            title: 'dashboard.customers'.tr(),
                            value: '${customers.length}',
                            color: const Color(0xFFE74C3C),
                            icon: Icons.group,
                            route: '/customers',
                          ),
                          _WindowsTileData(
                            title: 'dashboard.tile_users'.tr(),
                            value: '$usersCount',
                            color: const Color(0xFF2E6BC6),
                            icon: Icons.groups,
                            route: '/settings',
                          ),
                          _WindowsTileData(
                            title: 'dashboard.tile_reports'.tr(),
                            value: '${sales.length}',
                            color: const Color(0xFF95A5A6),
                            icon: Icons.insert_chart,
                            route: '/reports',
                          ),
                        ];

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final crossAxisCount = width < 600
                                ? 1
                                : width < 900
                                    ? 2
                                    : width < 1200
                                        ? 3
                                        : 4;

                            final childAspectRatio = width < 600
                                ? 2.8
                                : width < 900
                                    ? 2.5
                                    : 2.35;

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: tileData.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: childAspectRatio,
                              ),
                              itemBuilder: (context, index) {
                                return _buildWindowsTileCard(tileData[index]);
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildWindowsTileCard(_WindowsTileData tile) {
    return InkWell(
      onTap: () => context.go(tile.route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderColor),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkNavy.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tile.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    tile.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tile.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tile.icon, color: tile.color, size: 23),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowsPanel({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkNavy.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderColor)),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildWindowsTopProductsList(Currency currency) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getTopProductsData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return Center(
            child: Text(
              'dashboard.no_top_products_data'.tr(),
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: products.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final product = products[index];
            return ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -2),
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFEEF2FF),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                '${product['name']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F2F2F),
                ),
              ),
              trailing: Text(
                '${currency.symbol}${(product['revenue'] ?? 0).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF047857),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWindowsKpiStrip(Currency currency) {
    final productsAsync = ref.watch(productsProvider);
    final customersAsync = ref.watch(customerNotifierProvider);

    return FutureBuilder<List<SaleModel>>(
      future: _getWeekSales(),
      builder: (context, weekSnapshot) {
        final weekSales = weekSnapshot.data ?? [];
        final weekRevenue =
            weekSales.fold<double>(0.0, (sum, sale) => sum + sale.total);
        final avgOrder =
            weekSales.isEmpty ? 0.0 : weekRevenue / weekSales.length;

        return customersAsync.when(
          data: (customers) {
            return productsAsync.when(
              data: (products) {
                final cards = [
                  _buildWindowsMiniKpiCard(
                    title: 'dashboard.weekly_revenue'.tr(),
                    value:
                        '${currency.symbol}${weekRevenue.toStringAsFixed(0)}',
                    icon: Icons.trending_up,
                    color: const Color(0xFF0EA5E9),
                  ),
                  _buildWindowsMiniKpiCard(
                    title: 'dashboard.avg_order'.tr(),
                    value: '${currency.symbol}${avgOrder.toStringAsFixed(1)}',
                    icon: Icons.receipt_long,
                    color: AppColors.successColor,
                  ),
                  _buildWindowsMiniKpiCard(
                    title: 'dashboard.total_customers'.tr(),
                    value: '${customers.length}',
                    icon: Icons.people,
                    color: const Color(0xFF8B5CF6),
                  ),
                  _buildWindowsMiniKpiCard(
                    title: 'dashboard.products'.tr(),
                    value: '${products.length}',
                    icon: Icons.inventory_2,
                    color: const Color(0xFFF59E0B),
                  ),
                ];

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width < 650
                        ? 1
                        : width < 1100
                            ? 2
                            : 4;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cards.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: width < 650 ? 2.6 : 3.0,
                      ),
                      itemBuilder: (context, index) => cards[index],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildWindowsMiniKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowsInsightsSection(Currency currency) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isSingleColumn = width < 1000;

        if (isSingleColumn) {
          return Column(
            children: [
              _buildWindowsPanel(
                title: 'dashboard.customer_insights'.tr(),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    height: 245,
                    child: _buildCustomerInsightsCard(currency, false),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildWindowsPanel(
                title: 'dashboard.inventory_alerts'.tr(),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    height: 245,
                    child: _buildInventoryAlertsCard(false),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildWindowsPanel(
                title: 'dashboard.performance'.tr(),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    height: 245,
                    child: _buildPerformanceMetricsCard(currency, false),
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildWindowsPanel(
                title: 'dashboard.customer_insights'.tr(),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    height: 245,
                    child: _buildCustomerInsightsCard(currency, false),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildWindowsPanel(
                title: 'dashboard.inventory_alerts'.tr(),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    height: 245,
                    child: _buildInventoryAlertsCard(false),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildWindowsPanel(
                title: 'dashboard.performance'.tr(),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    height: 245,
                    child: _buildPerformanceMetricsCard(currency, false),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _hasWallpaper(String? wallpaperPath) {
    if (kIsWeb || wallpaperPath == null) {
      return false;
    }
    final file = File(wallpaperPath);
    return file.existsSync();
  }

  Widget _buildDashboardBackground(String? wallpaperPath, bool isDarkMode,
      DashboardAppearanceSettings appearance) {
    if (_hasWallpaper(wallpaperPath)) {
      final file = File(wallpaperPath!);
      return Stack(
        children: [
          Positioned.fill(
            child: Image.file(
              file,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.35),
            ),
          ),
        ],
      );
    }

    final defaultDarkGradient = const [Color(0xFF1C2128), Color(0xFF1F2732)];
    final defaultLightGradient = const [Color(0xFFF5F7FB), Color(0xFFE9EEF8)];
    final gradientColors = appearance.useCustomGradient
        ? [appearance.gradientStart, appearance.gradientEnd]
        : (isDarkMode ? defaultDarkGradient : defaultLightGradient);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildModernAppBar(
      DashboardAppearanceSettings appearance, bool isMobile) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final defaultDarkGradient = const [
      Color(0xFF23272F),
      Color(0xFF1C2128),
      Color(0xFF23272F)
    ];
    final defaultLightGradient = const [
      AppColors.primaryColor,
      AppColors.primaryDark,
      Color(0xFF1D4E8F)
    ];
    final appBarGradient = appearance.useCustomGradient
        ? [
            appearance.gradientStart,
            appearance.gradientEnd,
          ]
        : (isDarkMode ? defaultDarkGradient : defaultLightGradient);

    // Detect very narrow mobile screens for additional compaction
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrowMobile = isMobile && screenWidth < 380;

    return SliverAppBar(
        // Slightly shorter on mobile handsets to give more room to content
        expandedHeight: isMobile ? 160 : 230,
        floating: false,
        pinned: true,
        backgroundColor: isDarkMode ? const Color(0xFF23272F) : Colors.white,
        elevation: 0,
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: appBarGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                // Tighter padding on phones to reduce header height usage
                padding: EdgeInsets.all(isMobile ? 12 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Business Name at the top - hide on very narrow mobile
                    if (!isNarrowMobile)
                      FutureBuilder<String?>(
                        future: ref
                            .read(databaseServiceProvider)
                            .getSetting('business_name'),
                        builder: (context, snapshot) {
                          final businessName = snapshot.data ?? '';
                          if (businessName.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            margin: EdgeInsets.only(bottom: isMobile ? 8 : 16),
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 10 : 20,
                              vertical: isMobile ? 6 : 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(isMobile ? 10 : 12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: isMobile ? 6 : 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.business,
                                  color: Colors.white,
                                  size: isMobile ? 16 : 24,
                                ),
                                SizedBox(width: isMobile ? 6 : 12),
                                Expanded(
                                  child: Text(
                                    businessName.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: isMobile ? 14 : 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontFamily: 'Roboto',
                                      letterSpacing: isMobile ? 0.8 : 1.2,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.3),
                                          offset: const Offset(0, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    Row(
                      children: [
                        Container(
                          padding:
                              EdgeInsets.all(isMobile ? 10 : AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius:
                                BorderRadius.circular(isMobile ? 12 : 16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: isMobile ? 8 : 10,
                                offset: Offset(0, isMobile ? 2 : 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.dashboard,
                            color: Colors.white,
                            size: isMobile ? 20 : 28,
                          ),
                        ),
                        SizedBox(width: isMobile ? 10 : 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'dashboard.title'.tr(),
                                style: TextStyle(
                                  fontSize: isMobile ? 20 : 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Roboto',
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: isMobile ? 2 : 4),
                              Text(
                                isMobile
                                    ? 'dashboard.overview'.tr()
                                    : 'dashboard.welcome'.tr(),
                                style: TextStyle(
                                  fontSize: isMobile
                                      ? (isNarrowMobile ? 11 : 13)
                                      : 16,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: isMobile ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (!isNarrowMobile) ...[
                          // Clock Widget (hide on very small phones)
                          _buildClockWidget(isMobile),
                          SizedBox(width: isMobile ? 8 : 12),
                        ],
                        // Dark Mode Toggle always visible
                        _buildDarkModeToggle(isMobile),
                        // Show connected clients count if admin server
                        _buildConnectedClientsBadge(isMobile, ref),
                        if (!isNarrowMobile) ...[
                          SizedBox(width: isMobile ? 8 : 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius:
                                  BorderRadius.circular(isMobile ? 10 : 12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              onPressed: () {
                                _clearDataCache();
                                ref.invalidate(salesSummaryProvider);
                              },
                              icon: Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: isMobile ? 20 : 24,
                              ),
                              padding: EdgeInsets.all(isMobile ? 8 : 12),
                              constraints: BoxConstraints(
                                minWidth: isMobile ? 36 : 48,
                                minHeight: isMobile ? 36 : 48,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  Widget _buildStatsLoadingGrid(bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MobileOptimization.getGridCrossAxisCount(
        context,
        mobile: 2,
        tablet: 3,
        desktop: 4,
      ),
      crossAxisSpacing: MobileOptimization.getResponsiveSpacing(
        context,
        mobile: 12,
        tablet: 16,
        desktop: 16,
      ),
      mainAxisSpacing: MobileOptimization.getResponsiveSpacing(
        context,
        mobile: 12,
        tablet: 16,
        desktop: 16,
      ),
      childAspectRatio: isMobile ? 1.2 : 1.4,
      children: List.generate(4, (index) => _buildLoadingCard()),
    );
  }

  Widget _buildErrorStats(Object error) {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'dashboard.error_loading'.tr(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Error: $error',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontFamily: 'Roboto',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () {
              _clearDataCache();
              ref.invalidate(salesSummaryProvider);
            },
            child: Text('dashboard.retry'.tr()),
          ),
        ],
      ),
    );
  }

  // New widget methods for enhanced dashboard
  Widget _buildClockWidget(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('hh:mm a').format(_currentTime),
            style: TextStyle(
              fontSize: isMobile ? 14 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Roboto',
            ),
          ),
          Text(
            '${_currentTime.day}/${_currentTime.month}/${_currentTime.year}',
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              color: Colors.white.withValues(alpha: 0.8),
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkModeToggle(bool isMobile) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: () {
          themeNotifier.toggleTheme();
        },
        icon: Icon(
          isDarkMode ? Icons.light_mode : Icons.dark_mode,
          color: Colors.white,
          size: isMobile ? 20 : 24,
        ),
        padding: EdgeInsets.all(isMobile ? 8 : 12),
        constraints: BoxConstraints(
          minWidth: isMobile ? 36 : 48,
          minHeight: isMobile ? 36 : 48,
        ),
      ),
    );
  }

  Widget _buildConnectedClientsBadge(bool isMobile, WidgetRef ref) {
    final networkStatusAsync = ref.watch(networkStatusProvider);

    return networkStatusAsync.when(
      data: (status) {
        // Only show if running as admin server
        if (status != SyncStatus.serverRunning) {
          return const SizedBox.shrink();
        }

        final clientsCountAsync = ref.watch(connectedClientsCountProvider);
        return clientsCountAsync.when(
          data: (count) {
            if (count == 0) return const SizedBox.shrink();

            return Padding(
              padding: EdgeInsets.only(
                left: isMobile ? 8 : 12,
                right: isMobile ? 0 : 0,
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 10,
                  vertical: isMobile ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.computer,
                      color: Colors.white,
                      size: isMobile ? 16 : 18,
                    ),
                    SizedBox(width: isMobile ? 4 : 6),
                    Text(
                      '$count',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatsCards(Currency currency, bool isMobile) {
    // Use a simpler approach with direct database access
    return FutureBuilder<List<SaleModel>>(
      future: _getTodaySales(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingStats(isMobile);
        } else if (snapshot.hasError) {
          return _buildErrorStats(snapshot.error!);
        } else if (snapshot.hasData) {
          final sales = snapshot.data!;
          return _buildStatsGrid(sales, currency, isMobile);
        } else {
          return _buildLoadingStats(isMobile);
        }
      },
    );
  }

  Future<List<SaleModel>> _getTodaySales() async {
    const cacheDuration = Duration(seconds: 30);

    // Use cache if data is less than 30 seconds old
    if (_cachedTodaySales != null &&
        _lastTodayDataFetch != null &&
        DateTime.now().difference(_lastTodayDataFetch!) < cacheDuration) {
      return _cachedTodaySales!;
    }

    try {
      final databaseService = ref.read(databaseServiceProvider);
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final sales =
          await databaseService.getSalesByDateRange(todayStart, todayEnd);

      // Cache the data
      _cachedTodaySales = sales;
      _lastTodayDataFetch = DateTime.now();

      return sales;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<SaleModel>> _getWeekSales() async {
    const cacheDuration = Duration(seconds: 30);

    // Use cache if data is less than 30 seconds old
    if (_cachedWeekSales != null &&
        _lastWeekDataFetch != null &&
        DateTime.now().difference(_lastWeekDataFetch!) < cacheDuration) {
      return _cachedWeekSales!;
    }

    try {
      final databaseService = ref.read(databaseServiceProvider);
      final today = DateTime.now();
      final weekAgo = today.subtract(const Duration(days: 7));

      final sales = await databaseService.getSalesByDateRange(weekAgo, today);

      // Cache the data
      _cachedWeekSales = sales;
      _lastWeekDataFetch = DateTime.now();

      return sales;
    } catch (e) {
      rethrow;
    }
  }

  Widget _buildStatsGrid(
      List<SaleModel> sales, Currency currency, bool isMobile) {
    // Calculate real statistics from sales data
    final totalSales = sales.fold(0.0, (sum, sale) => sum + sale.total);
    final totalOrders = sales.length;
    final uniqueCustomers =
        sales.map((sale) => sale.customerId).whereType<int>().toSet().length;

    // Get all products and customers (real-time via providers)
    final productsData = ref.watch(productsProvider);
    final customersData = ref.watch(customerNotifierProvider);

    return customersData.when(
      data: (customers) {
        return productsData.when(
          data: (products) {
            final totalCustomers = customers.length;
            final customerChangeLabel = totalCustomers == 0
                ? 'dashboard.no_customers'.tr()
                : 'dashboard.active_week'
                    .tr(namedArgs: {'n': '$uniqueCustomers'});
            final isCustomerPositive = totalCustomers > 0;

            // On very narrow mobile screens, use a single column for better readability
            final screenWidth = MediaQuery.of(context).size.width;
            final isNarrowMobile = isMobile && screenWidth < 380;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MobileOptimization.getGridCrossAxisCount(
                context,
                mobile: isNarrowMobile ? 1 : 2,
                tablet: 3,
                desktop: 4,
              ),
              crossAxisSpacing: MobileOptimization.getResponsiveSpacing(
                context,
                mobile: 12,
                tablet: 16,
                desktop: 16,
              ),
              mainAxisSpacing: MobileOptimization.getResponsiveSpacing(
                context,
                mobile: 12,
                tablet: 16,
                desktop: 16,
              ),
              childAspectRatio: isNarrowMobile ? 1.4 : (isMobile ? 1.15 : 1.4),
              children: [
                SalesStatCard(
                  title: 'dashboard.todays_sales'.tr(),
                  value: '${currency.symbol}${totalSales.toStringAsFixed(2)}',
                  change:
                      totalSales > 0 ? '+12.5%' : 'dashboard.no_sales_yet'.tr(),
                  isPositive: totalSales > 0,
                  onTap: () => context.go('/sales'),
                ),
                InventoryStatCard(
                  title: 'dashboard.total_orders'.tr(),
                  value: '$totalOrders',
                  change: totalOrders > 0
                      ? '+8.2%'
                      : 'dashboard.no_orders_yet'.tr(),
                  isPositive: totalOrders > 0,
                  onTap: () => context.go('/reports'),
                ),
                CustomerStatCard(
                  title: 'dashboard.customers'.tr(),
                  value: '$totalCustomers',
                  change: customerChangeLabel,
                  isPositive: isCustomerPositive,
                  onTap: () => context.go('/customers'),
                ),
                EnhancedStatCard(
                  title: 'dashboard.products'.tr(),
                  value: '${products.length}',
                  icon: Icons.inventory,
                  color: AppColors.khataColor,
                  change: products.length > 0
                      ? '+5.7%'
                      : 'dashboard.no_products_yet'.tr(),
                  isPositive: products.length > 0,
                  onTap: () => context.go('/products'),
                ),
              ],
            );
          },
          loading: () => _buildStatsLoadingGrid(isMobile),
          error: (error, stack) => _buildErrorStats(error),
        );
      },
      loading: () => _buildStatsLoadingGrid(isMobile),
      error: (error, stack) => _buildErrorStats(error),
    );
  }

  Widget _buildInteractiveChartsSection(Currency currency, bool isMobile) {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'dashboard.sales_analytics'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                fontFamily: 'Roboto',
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF334155)
                    : const Color(0xFFE0E7FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'dashboard.last_7_days'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color:
                          isDarkMode ? Colors.white70 : const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          height: isMobile ? 300 : 400,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF23272F) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode
                  ? const Color(0xFF374151)
                  : const Color(0xFFE5E7EB),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.1 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: _buildInteractiveChart(currency),
        ),
      ],
    );
  }

  Widget _buildInteractiveChart(Currency currency) {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return FutureBuilder<List<SaleModel>>(
      future: _getWeekSales(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading chart data: ${snapshot.error}',
              style: TextStyle(
                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          );
        } else if (snapshot.hasData) {
          final sales = snapshot.data!;

          // Group sales by day
          final today = DateTime.now();
          final weekAgo = today.subtract(const Duration(days: 7));
          final Map<int, double> dailySales = {};
          for (int i = 0; i < 7; i++) {
            dailySales[i] = 0.0;
          }

          for (final sale in sales) {
            final daysDiff = sale.date.difference(weekAgo).inDays;
            if (daysDiff >= 0 && daysDiff < 7) {
              dailySales[daysDiff] = (dailySales[daysDiff] ?? 0.0) + sale.total;
            }
          }

          final maxValue = dailySales.values.isNotEmpty
              ? dailySales.values.reduce((a, b) => a > b ? a : b)
              : 100.0;
          final chartMaxValue = math.max(maxValue, 1.0);
          final yInterval = chartMaxValue / 4;

          return LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                drawHorizontalLine: true,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: isDarkMode
                        ? const Color(0xFF334155)
                        : const Color(0xFFE5E7EB),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    interval: yInterval,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '${currency.symbol}${value.toInt()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
                                ? Colors.white70
                                : const Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      const days = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun'
                      ];
                      if (value.toInt() < days.length) {
                        return Text(
                          days[value.toInt()],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
                                ? Colors.white70
                                : const Color(0xFF64748B),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: chartMaxValue * 1.3,
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                      7,
                      (index) =>
                          FlSpot(index.toDouble(), dailySales[index] ?? 0.0)),
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: const Color(0xFF3B82F6),
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 6,
                        color: const Color(0xFF3B82F6),
                        strokeWidth: 3,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        const Color(0xFF3B82F6).withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor:
                      isDarkMode ? const Color(0xFF374151) : Colors.white,
                  tooltipRoundedRadius: 12,
                  tooltipPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  tooltipBorder: BorderSide(
                    color: isDarkMode
                        ? const Color(0xFF4B5563)
                        : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((touchedSpot) {
                      return LineTooltipItem(
                        '${currency.symbol}${touchedSpot.y.toStringAsFixed(2)}',
                        TextStyle(
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      );
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
              ),
            ),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _buildQuickActionsFAB() {
    final businessNature = 'retail';
    final isRetail = businessNature == 'retail';

    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: const Color(0xFF3B82F6),
      foregroundColor: Colors.white,
      children: [
        // Show Purchase Invoice, Stock Movement, and Purchase Order only for retail
        if (isRetail) ...[
          SpeedDialChild(
            child: const Icon(Icons.receipt),
            backgroundColor: const Color(0xFF10B981),
            label: 'dashboard.quick_purchase_invoice'.tr(),
            onTap: () {
              print('Dashboard: navigating to /purchase-invoice');
              context.go('/purchase-invoice');
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.swap_vert),
            backgroundColor: const Color(0xFF14B8A6),
            label: 'dashboard.quick_stock_movement'.tr(),
            onTap: () => context.go('/stock-movements'),
          ),
          SpeedDialChild(
            child: const Icon(Icons.shopping_cart),
            backgroundColor: const Color(0xFFF59E0B),
            label: 'dashboard.quick_purchase_order'.tr(),
            onTap: () => context.go('/purchase-orders'),
          ),
        ],
        SpeedDialChild(
          child: const Icon(Icons.person),
          backgroundColor: const Color(0xFF10B981),
          label: 'dashboard.quick_employee'.tr(),
          onTap: () => context.go(AppRouter.employeeManagement),
        ),
        SpeedDialChild(
          child: const Icon(Icons.category),
          backgroundColor: const Color(0xFF0EA5E9),
          label: 'dashboard.quick_category'.tr(),
          onTap: () => context.go('/add-category'),
        ),
        SpeedDialChild(
          child: const Icon(Icons.inventory),
          backgroundColor: const Color(0xFFF59E0B),
          label: 'dashboard.quick_inventory'.tr(),
          onTap: () => context.go('/inventory-management'),
        ),
        SpeedDialChild(
          child: const Icon(Icons.assignment_return),
          backgroundColor: const Color(0xFF8B5CF6),
          label: 'dashboard.quick_return'.tr(),
          onTap: () => context.go('/returns-refunds'),
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFE2E8F0),
                ),
                Spacer(),
                CircleAvatar(
                  radius: 8,
                  backgroundColor: Color(0xFFE2E8F0),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 20,
              width: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 14,
              width: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingStats(bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.4 : 1.6,
      children: List.generate(4, (index) => _buildSkeletonCard()),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSkeletonLoader(40, 40, 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkeletonLoader(double.infinity, 16, 4),
                      const SizedBox(height: 8),
                      _buildSkeletonLoader(80, 12, 4),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSkeletonLoader(double.infinity, 24, 4),
            const SizedBox(height: 8),
            _buildSkeletonLoader(100, 14, 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader(
      double width, double height, double borderRadius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  Widget _buildTopProductsCard(Currency currency, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: AppColors.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'dashboard.top_products'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getTopProductsData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return Center(
                    child: Text(
                      'dashboard.no_products_data'.tr(),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              product['name'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Text(
                            '${currency.symbol}${product['revenue'].toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInsightsCard(Currency currency, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.people,
                  color: AppColors.successColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'dashboard.customer_insights'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _getCustomerInsightsData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final insights = snapshot.data ?? {};
              return Column(
                children: [
                  _buildInsightRow(
                    'dashboard.new_customers'.tr(),
                    '${insights['newCustomers'] ?? 0}',
                    Icons.person_add,
                    AppColors.successColor,
                    isDarkMode,
                  ),
                  _buildInsightRow(
                    'dashboard.returning_customers'.tr(),
                    '${insights['returningCustomers'] ?? 0}',
                    Icons.repeat,
                    AppColors.primaryColor,
                    isDarkMode,
                  ),
                  _buildInsightRow(
                    'dashboard.avg_order_value'.tr(),
                    '${currency.symbol}${(insights['avgOrderValue'] ?? 0).toStringAsFixed(2)}',
                    Icons.shopping_cart,
                    AppColors.warningColor,
                    isDarkMode,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryAlertsCard(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning,
                  color: AppColors.warningColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'dashboard.inventory_alerts'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getInventoryAlertsData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final alerts = snapshot.data ?? [];
              if (alerts.isEmpty) {
                return Center(
                  child: Text(
                    'dashboard.no_alerts'.tr(),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: alerts.length,
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          alert['type'] == 'low' ? Icons.warning : Icons.error,
                          color: alert['type'] == 'low'
                              ? AppColors.warningColor
                              : AppColors.errorColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            alert['product'],
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        Text(
                          'dashboard.stock_left'
                              .tr(namedArgs: {'count': '${alert['stock']}'}),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: alert['type'] == 'low'
                                ? AppColors.warningColor
                                : AppColors.errorColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetricsCard(Currency currency, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.infoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: AppColors.infoColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'dashboard.performance'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _getPerformanceMetricsData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final metrics = snapshot.data ?? {};
              return Column(
                children: [
                  _buildInsightRow(
                    'dashboard.conversion_rate'.tr(),
                    '${(metrics['conversionRate'] ?? 0).toStringAsFixed(1)}%',
                    Icons.trending_up,
                    AppColors.successColor,
                    isDarkMode,
                  ),
                  _buildInsightRow(
                    'dashboard.profit_margin'.tr(),
                    '${(metrics['profitMargin'] ?? 0).toStringAsFixed(1)}%',
                    Icons.attach_money,
                    AppColors.primaryColor,
                    isDarkMode,
                  ),
                  _buildInsightRow(
                    'dashboard.growth_rate'.tr(),
                    '${(metrics['growthRate'] ?? 0).toStringAsFixed(1)}%',
                    Icons.show_chart,
                    AppColors.warningColor,
                    isDarkMode,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(
      String label, String value, IconData icon, Color color, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getTopProductsData() async {
    final sales = await _getWeekSales();
    final revenueByProduct = <String, double>{};

    for (final sale in sales) {
      for (final item in sale.items) {
        final productName = item.product?.name ?? 'Product #${item.productId}';
        revenueByProduct.update(
          productName,
          (value) => value + item.subtotal,
          ifAbsent: () => item.subtotal,
        );
      }
    }

    final sorted = revenueByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(5)
        .map((entry) => {
              'name': entry.key,
              'revenue': entry.value,
            })
        .toList();
  }

  Future<Map<String, dynamic>> _getCustomerInsightsData() async {
    final sales = await _getWeekSales();
    final customerOrderCount = <int, int>{};

    for (final sale in sales) {
      final customerId = sale.customerId;
      if (customerId != null) {
        customerOrderCount.update(
          customerId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final newCustomers =
        customerOrderCount.values.where((count) => count == 1).length;
    final returningCustomers =
        customerOrderCount.values.where((count) => count > 1).length;
    final avgOrderValue = sales.isEmpty
        ? 0.0
        : sales.fold<double>(0.0, (sum, sale) => sum + sale.total) /
            sales.length;

    return {
      'newCustomers': newCustomers,
      'returningCustomers': returningCustomers,
      'avgOrderValue': avgOrderValue,
    };
  }

  Future<List<Map<String, dynamic>>> _getInventoryAlertsData() async {
    final products = await ref.read(productsProvider.future);
    final alerts = products.where((product) {
      final reorderLevel =
          product.reorderLevel <= 0 ? 1.0 : product.reorderLevel;
      return product.stock <= reorderLevel;
    }).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    return alerts.take(5).map((product) {
      return {
        'product': product.name,
        'stock': product.stock.toStringAsFixed(0),
        'type': product.stock <= 0 ? 'out' : 'low',
      };
    }).toList();
  }

  Future<Map<String, dynamic>> _getPerformanceMetricsData() async {
    final databaseService = ref.read(databaseServiceProvider);
    final now = DateTime.now();
    final thisWeekStart = now.subtract(const Duration(days: 7));
    final previousWeekStart = now.subtract(const Duration(days: 14));

    final thisWeekSales =
        await databaseService.getSalesByDateRange(thisWeekStart, now);
    final previousWeekSales = await databaseService.getSalesByDateRange(
        previousWeekStart, thisWeekStart);

    final thisWeekRevenue = thisWeekSales.fold<double>(
      0.0,
      (sum, sale) => sum + sale.total,
    );
    final previousWeekRevenue = previousWeekSales.fold<double>(
      0.0,
      (sum, sale) => sum + sale.total,
    );

    final conversionRate = thisWeekSales.isEmpty
        ? 0.0
        : ((thisWeekSales.where((sale) => sale.customerId != null).length /
                    thisWeekSales.length) *
                100)
            .clamp(0.0, 100.0);

    final totalProfit = thisWeekSales.fold<double>(
      0.0,
      (sum, sale) => sum + sale.profit,
    );
    final profitMargin =
        thisWeekRevenue <= 0 ? 0.0 : ((totalProfit / thisWeekRevenue) * 100);

    final growthRate = previousWeekRevenue <= 0
        ? (thisWeekRevenue > 0 ? 100.0 : 0.0)
        : (((thisWeekRevenue - previousWeekRevenue) / previousWeekRevenue) *
            100);

    return {
      'conversionRate': conversionRate,
      'profitMargin': profitMargin,
      'growthRate': growthRate,
    };
  }

  Widget _buildQuickActionFAB(bool isMobile) {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: AppColors.primaryColor,
      foregroundColor: Colors.white,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.receipt_long),
          backgroundColor: Colors.blue,
          label: 'New Sale',
          onTap: () {
            context.go(AppRouter.pos);
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.shopping_cart),
          backgroundColor: Colors.green,
          label: 'Purchase Invoice',
          onTap: () {
            context.go(AppRouter.purchaseInvoice);
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.inventory),
          backgroundColor: Colors.purple,
          label: 'Products',
          onTap: () {
            context.go(AppRouter.products);
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.group),
          backgroundColor: Colors.teal,
          label: 'Customers',
          onTap: () {
            context.go(AppRouter.customers);
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.supervisor_account),
          backgroundColor: Colors.orange,
          label: 'Suppliers',
          onTap: () {
            context.go(AppRouter.suppliers);
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.admin_panel_settings),
          backgroundColor: const Color(0xFF334155),
          label: 'Role Permissions',
          onTap: () {
            context.go(AppRouter.rolePermissions);
          },
        ),
      ],
    );
  }
}

// SpeedDial widget for quick actions
class SpeedDial extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final Color backgroundColor;
  final Color foregroundColor;
  final List<SpeedDialChild> children;

  const SpeedDial({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.children,
  });

  @override
  State<SpeedDial> createState() => _SpeedDialState();
}

class _SpeedDialState extends State<SpeedDial>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _handleChildTap(VoidCallback action) async {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
      });
      await _animationController.reverse();
      if (!mounted) return;
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen) ...[
          ...widget.children.map((child) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _handleChildTap(child.onTap),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          child.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton.small(
                        onPressed: () => _handleChildTap(child.onTap),
                        backgroundColor: child.backgroundColor,
                        heroTag: null,
                        child: child.child,
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: AppSpacing.lg),
        ],
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: widget.backgroundColor,
          heroTag: null,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _animation.value * 0.5 * 3.14159,
                child: Icon(_isOpen ? widget.activeIcon : widget.icon),
              );
            },
          ),
        ),
      ],
    );
  }
}

class SpeedDialChild {
  final Widget child;
  final Color backgroundColor;
  final String label;
  final VoidCallback onTap;

  const SpeedDialChild({
    required this.child,
    required this.backgroundColor,
    required this.label,
    required this.onTap,
  });
}

class _WindowsTileData {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String route;

  const _WindowsTileData({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    required this.route,
  });
}
