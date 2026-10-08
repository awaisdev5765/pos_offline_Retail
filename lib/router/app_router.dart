import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/keyboard_shortcuts_service.dart';
import '../screens/splash_screen.dart';
import '../screens/business_setup_screen.dart';
import '../screens/login_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/pos_screen.dart';
import '../screens/products_screen.dart';
import '../screens/customers_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/add_product_screen.dart';
import '../screens/add_customer_screen.dart';
import '../screens/customer_ledger_screen.dart';
import '../screens/sale_details_screen.dart';
import '../screens/sales_screen.dart';
import '../screens/categories_screen.dart';
import '../screens/purchase_orders_screen.dart';
import '../screens/purchase_invoice_screen.dart';
import '../screens/advanced_inventory_reports_screen.dart';
import '../screens/daily_comprehensive_report_screen.dart';
import '../screens/returns_refunds_screen.dart';
import '../screens/inventory_management_screen.dart';
import '../screens/add_category_screen.dart';
import '../screens/stock_movements_screen.dart';
import '../screens/comprehensive_reports_screen.dart';
import '../screens/expense_heads_screen.dart';
import '../screens/expense_entry_screen.dart';
import '../screens/expense_report_screen.dart';
import '../screens/item_wise_sales_report_screen.dart';
import '../screens/suppliers_screen.dart';
import '../screens/add_supplier_screen.dart';
import '../screens/supplier_ledger_screen.dart';
import '../screens/supplier_payment_screen.dart';
import '../screens/banking_system_screen.dart';
import '../screens/bank_payment_screen.dart';
import '../screens/bank_ledger_screen.dart';
import '../screens/add_bank_screen.dart';
import '../screens/receipt_settings_screen.dart';
import '../screens/license_management_screen.dart';
import '../screens/license_activation_screen.dart';
import '../screens/staff_performance_screen.dart';
import '../screens/network_config_screen.dart';
import '../screens/role_permissions_screen.dart';
import '../screens/product_ledger_screen.dart';
import '../screens/negative_inventory_screen.dart';
import '../screens/bundles_screen.dart';
import '../screens/add_bundle_screen.dart';
import '../screens/employee_management_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/global_refresh_service.dart';
import '../services/database_service.dart' show databaseServiceProvider;
import '../widgets/navigation_fallback_screen.dart';

// Provider to trigger navigation refresh without invalidating auth
final navigationRefreshTriggerProvider = StateProvider<int>((ref) => 0);

class AppRouter {
  static const String splash = '/splash';
  static const String businessSetup = '/business-setup';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String licenseActivation = '/license-activation';
  static const String bankmanagment = '/bank-managment';

  static const String dashboard = '/';
  static const String pos = '/pos';
  static const String products = '/products';
  static const String customers = '/customers';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String addProduct = '/add-product';
  static const String editProduct = '/edit-product';
  static const String addCustomer = '/add-customer';
  static const String editCustomer = '/edit-customer';
  static const String customerLedger = '/customer-ledger';
  static const String saleDetails = '/sale-details';
  static const String sales = '/sales';
  static const String categories = '/categories';
  static const String purchaseOrders = '/purchase-orders';
  static const String purchaseInvoice = '/purchase-invoice';
  static const String inventoryReports = '/inventory-reports';
  static const String returnsRefunds = '/returns-refunds';
  static const String inventoryManagement = '/inventory-management';
  static const String stockMovements = '/stock-movements';
  static const String comprehensiveReports = '/comprehensive-reports';
  static const String suppliers = '/suppliers';
  static const String addSupplier = '/add-supplier';
  static const String editSupplier = '/edit-supplier';
  static const String supplierLedger = '/supplier-ledger';
  static const String supplierPayment = '/supplier-payment';
  static const String bankingSystem = '/banking-system';
  static const String bankLedger = '/bank-ledger';
  static const String bankPayment = '/bank-payment';
  static const String addBank = '/add-bank';
  static const String editBank = '/edit-bank';
  static const String receiptCustomization = '/receipt-customization';
  static const String licenseManagement = '/license-management';
  static const String staffPerformance = '/staff-performance';
  static const String printerSettings = '/printer-settings';
  static const String networkConfig = '/network-config';
  static const String rolePermissions = '/role-permissions';
  static const String itemWiseSalesReport = '/item-wise-sales-report';
  static const String expenseHeads = '/expense-heads';
  static const String expenseEntry = '/expense-entry';
  static const String expenseReport = '/expense-report';
  static const String productLedger = '/product-ledger';
  static const String negativeInventory = '/negative-inventory';
  static const String dailyComprehensiveReport = '/daily-comprehensive-report';
  static const String employeeManagement = '/employee-management';
  static const String bundles = '/bundles';
  static const String addBundle = '/add-bundle';
  static const String editBundle = '/edit-bundle';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    redirect: (context, state) {
      // Handle any unknown routes by redirecting to dashboard
      final currentPath = state.uri.path;
      if (currentPath == '/dashboard' || currentPath == '/home') {
        return '/';
      }
      return null; // No redirect needed
    },
    routes: [
      // Splash screen
      GoRoute(
        path: splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Business setup screen
      GoRoute(
        path: businessSetup,
        name: 'business-setup',
        builder: (context, state) => const BusinessSetupScreen(),
      ),

      // Login screen
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: forgotPassword,
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // License activation screen
      GoRoute(
        path: licenseActivation,
        name: 'license-activation',
        builder: (context, state) => const LicenseActivationScreen(),
      ),

      // Main navigation routes
      ShellRoute(
        builder: (context, state, child) {
          return MainNavigationWrapper(child: child);
        },
        routes: [
          GoRoute(
            path: dashboard,
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: pos,
            name: 'pos',
            builder: (context, state) => const PosScreen(),
          ),
          GoRoute(
            path: products,
            name: 'products',
            builder: (context, state) => const ProductsScreen(),
          ),
          GoRoute(
            path: bundles,
            name: 'bundles',
            builder: (context, state) => const BundlesScreen(),
          ),
          GoRoute(
            path: addBundle,
            name: 'add-bundle',
            builder: (context, state) => const AddBundleScreen(),
          ),
          GoRoute(
            path: editBundle,
            name: 'edit-bundle',
            builder: (context, state) {
              final bundleId =
                  int.tryParse(state.uri.queryParameters['id'] ?? '') ?? 0;
              return AddBundleScreen(bundleId: bundleId);
            },
          ),
          GoRoute(
            path: customers,
            name: 'customers',
            builder: (context, state) => const CustomersScreen(),
          ),
          GoRoute(
            path: reports,
            name: 'reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: settings,
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: categories,
            name: 'categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
          GoRoute(
            path: sales,
            name: 'sales',
            builder: (context, state) => const SalesScreen(),
          ),
          GoRoute(
            path: purchaseOrders,
            name: 'purchase-orders',
            builder: (context, state) => const PurchaseOrdersScreen(),
          ),
          GoRoute(
            path: purchaseInvoice,
            name: 'purchase-invoice',
            builder: (context, state) {
              print('Router: building /purchase-invoice');
              return const PurchaseInvoiceScreen();
            },
          ),
          GoRoute(
            path: inventoryReports,
            name: 'inventory-reports',
            builder: (context, state) => const AdvancedInventoryReportsScreen(),
          ),
          GoRoute(
            path: returnsRefunds,
            name: 'returns-refunds',
            builder: (context, state) => const ReturnsRefundsScreen(),
          ),
          GoRoute(
            path: inventoryManagement,
            name: 'inventory-management',
            builder: (context, state) => const InventoryManagementScreen(),
          ),
          GoRoute(
            path: stockMovements,
            name: 'stock-movements',
            builder: (context, state) => const StockMovementsScreen(),
          ),
          GoRoute(
            path: expenseHeads,
            name: 'expense-heads',
            builder: (context, state) => const ExpenseHeadsScreen(),
          ),
          GoRoute(
            path: expenseEntry,
            name: 'expense-entry',
            builder: (context, state) => const ExpenseEntryScreen(),
          ),
          GoRoute(
            path: expenseReport,
            name: 'expense-report',
            builder: (context, state) => const ExpenseReportScreen(),
          ),
          GoRoute(
            path: comprehensiveReports,
            name: 'comprehensive-reports',
            builder: (context, state) => const ComprehensiveReportsScreen(),
          ),
          GoRoute(
            path: itemWiseSalesReport,
            name: 'item-wise-sales-report',
            builder: (context, state) => const ItemWiseSalesReportScreen(),
          ),
          GoRoute(
            path: suppliers,
            name: 'suppliers',
            builder: (context, state) => const SuppliersScreen(),
          ),
          GoRoute(
            path: addProduct,
            name: 'add-product',
            builder: (context, state) => const AddProductScreen(),
          ),
          GoRoute(
            path: editProduct,
            name: 'edit-product',
            builder: (context, state) {
              final productId =
                  int.parse(state.uri.queryParameters['id'] ?? '0');
              return AddProductScreen(productId: productId);
            },
          ),
          GoRoute(
            path: '/add-category',
            name: 'add-category',
            builder: (context, state) {
              final editId = state.uri.queryParameters['editId'];
              return AddCategoryScreen(
                  categoryId: editId != null ? int.parse(editId) : null);
            },
          ),
          GoRoute(
            path: addCustomer,
            name: 'add-customer',
            builder: (context, state) => const AddCustomerScreen(),
          ),
          GoRoute(
            path: addSupplier,
            name: 'add-supplier',
            builder: (context, state) {
              print('Router: building /add-supplier');
              return const AddSupplierScreen();
            },
          ),
          GoRoute(
            path: editSupplier,
            name: 'edit-supplier',
            builder: (context, state) {
              final supplierId =
                  int.tryParse(state.uri.queryParameters['id'] ?? '') ?? 0;
              print('Router: building /edit-supplier id=$supplierId');
              return AddSupplierScreen(supplierId: supplierId);
            },
          ),
          GoRoute(
            path: supplierLedger,
            name: 'supplier-ledger',
            builder: (context, state) {
              final supplierId =
                  int.parse(state.uri.queryParameters['id'] ?? '0');
              return SupplierLedgerScreen(supplierId: supplierId);
            },
          ),
          GoRoute(
            path: supplierPayment,
            name: 'supplier-payment',
            builder: (context, state) {
              final supplierId =
                  int.parse(state.uri.queryParameters['id'] ?? '0');
              return SupplierPaymentScreen(supplierId: supplierId);
            },
          ),
          GoRoute(
            path: bankingSystem,
            name: 'banking-system',
            builder: (context, state) => const BankingSystemScreen(),
          ),
          GoRoute(
            path: bankPayment,
            name: 'bank-payment',
            builder: (context, state) {
              final bankId = state.uri.queryParameters['bankId'] != null
                  ? int.parse(state.uri.queryParameters['bankId']!)
                  : null;
              return BankPaymentScreen(bankId: bankId);
            },
          ),
          GoRoute(
            path: addBank,
            name: 'add-bank',
            builder: (context, state) => const AddBankScreen(),
          ),
          GoRoute(
            path: editBank,
            name: 'edit-bank',
            builder: (context, state) {
              final bankId = int.parse(state.uri.queryParameters['id'] ?? '0');
              return AddBankScreen(bankId: bankId);
            },
          ),
          GoRoute(
            path: bankLedger,
            name: 'bank-ledger',
            builder: (context, state) {
              final bankId = int.parse(state.uri.queryParameters['id'] ?? '0');
              return BankLedgerScreen(bankId: bankId);
            },
          ),
          GoRoute(
            path: editCustomer,
            name: 'edit-customer',
            builder: (context, state) {
              final customerId =
                  int.parse(state.uri.queryParameters['id'] ?? '0');
              return AddCustomerScreen(customerId: customerId);
            },
          ),
          GoRoute(
            path: customerLedger,
            name: 'customer-ledger',
            builder: (context, state) {
              final customerId =
                  int.parse(state.uri.queryParameters['id'] ?? '0');
              return CustomerLedgerScreen(customerId: customerId);
            },
          ),
          GoRoute(
            path: saleDetails,
            name: 'sale-details',
            builder: (context, state) {
              final saleId = int.parse(state.uri.queryParameters['id'] ?? '0');
              return SaleDetailsScreen(saleId: saleId);
            },
          ),
          GoRoute(
            path: receiptCustomization,
            name: 'receipt-customization',
            builder: (context, state) => const ReceiptSettingsScreen(),
          ),
          GoRoute(
            path: licenseManagement,
            name: 'license-management',
            builder: (context, state) => const LicenseManagementScreen(),
          ),
          GoRoute(
            path: staffPerformance,
            name: 'staff-performance',
            builder: (context, state) => const StaffPerformanceScreen(),
          ),
          GoRoute(
            path: printerSettings,
            name: 'printer-settings',
            builder: (context, state) => const ReceiptSettingsScreen(),
          ),
          GoRoute(
            path: networkConfig,
            name: 'network-config',
            builder: (context, state) => const NetworkConfigScreen(),
          ),
          GoRoute(
            path: rolePermissions,
            name: 'role-permissions',
            builder: (context, state) => const RolePermissionsScreen(),
          ),
          GoRoute(
            path: employeeManagement,
            name: 'employee-management',
            builder: (context, state) => const EmployeeManagementScreen(),
          ),
          GoRoute(
            path: productLedger,
            name: 'product-ledger',
            builder: (context, state) {
              final productId =
                  int.tryParse(state.uri.queryParameters['id'] ?? '') ?? 0;
              return ProductLedgerScreen(productId: productId);
            },
          ),
          GoRoute(
            path: negativeInventory,
            name: 'negative-inventory',
            builder: (context, state) => const NegativeInventoryScreen(),
          ),
          GoRoute(
            path: dailyComprehensiveReport,
            name: 'daily-comprehensive-report',
            builder: (context, state) => const DailyComprehensiveReportScreen(),
          ),
        ],
      ),

      // Catch-all for unknown top-level paths (single segment, e.g. /foo)
      GoRoute(
        path: '/:path',
        builder: (context, state) {
          return NavigationFallbackScreen.unknown(
            location: state.uri.path,
          );
        },
      ),
    ],
    errorBuilder: (context, state) {
      return NavigationFallbackScreen.error(
        routingError: state.error,
        location: state.uri.toString(),
      );
    },
  );
}

class MainNavigationWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const MainNavigationWrapper({super.key, required this.child});

  @override
  ConsumerState<MainNavigationWrapper> createState() =>
      _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends ConsumerState<MainNavigationWrapper>
    with SingleTickerProviderStateMixin {
  static const String _expensesSectionRoute = '__expenses_section';
  int _currentIndex = 0;
  bool _isDesktop = false;
  bool _isTablet = false;
  bool _isSidebarCollapsed = false;
  bool _isPosSidebarVisible = false;
  late AnimationController _sidebarAnimationController;
  late Animation<double> _sidebarAnimation;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isComprehensiveReportsExpanded = false;
  bool _isDailyReportExpanded = false;
  bool _isExpensesExpanded = false;
  String? _lastRoute; // Track last route to detect navigation changes
  bool _bundlesEnabled = false; // Track bundles enabled setting
  int _lastNavigationRefreshTick = -1;
  DateTime _desktopClock = DateTime.now();

  @override
  void initState() {
    super.initState();
    _sidebarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarAnimationController,
      curve: Curves.easeInOut,
    );
    _sidebarAnimationController.forward(); // Start expanded
    _startDesktopClock();

    // Listen to animation status to sync state
    _sidebarAnimationController.addStatusListener((status) {
      if (mounted) {
        setState(() {
          if (status == AnimationStatus.completed) {
            _isSidebarCollapsed = false;
          } else if (status == AnimationStatus.dismissed) {
            _isSidebarCollapsed = true;
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScreenSize();
      // Trigger global refresh when navigation wrapper initializes
      GlobalRefreshService.refreshAllData(ref);
      // Load bundles enabled setting
      _loadBundlesSetting();
    });
  }

  Future<void> _loadBundlesSetting() async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final bundlesEnabled =
          await databaseService.getSetting('bundles_enabled') == 'true';
      if (mounted) {
        setState(() {
          _bundlesEnabled = bundlesEnabled;
        });
      }
    } catch (e) {
      // Default to false if error
      if (mounted) {
        setState(() {
          _bundlesEnabled = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _sidebarAnimationController.dispose();
    super.dispose();
  }

  void _startDesktopClock() {
    Future.doWhile(() async {
      if (!mounted) return false;
      await Future.delayed(const Duration(seconds: 30));
      if (mounted) {
        setState(() {
          _desktopClock = DateTime.now();
        });
      }
      return mounted;
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
      if (_isSidebarCollapsed) {
        _sidebarAnimationController.reverse();
      } else {
        _sidebarAnimationController.forward();
      }
    });
  }

  void _updateScreenSize() {
    if (mounted) {
      final screenSize = MediaQuery.of(context).size;
      // For Windows desktop, use desktop layout even for smaller windows
      final isWindows = Theme.of(context).platform == TargetPlatform.windows;
      setState(() {
        _isDesktop =
            screenSize.width >= 1024 || (isWindows && screenSize.width >= 768);
        _isTablet =
            screenSize.width >= 768 && screenSize.width < 1024 && !isWindows;
      });
    }
  }

  List<NavigationItem> get _navigationItems {
    final currentUser = ref.watch(authProvider).currentUser;
    if (currentUser == null) return [];

    final items = <NavigationItem>[];

    void addItem(String permissionKey, NavigationItem item) {
      if (_hasPermission(permissionKey)) {
        items.add(item);
      }
    }

    addItem(
      'view_dashboard',
      NavigationItem(
        icon: Icons.dashboard,
        label: 'nav.dashboard',
        route: AppRouter.dashboard,
        description: 'nav_desc.dashboard',
      ),
    );

    addItem(
      'access_pos',
      NavigationItem(
        icon: Icons.point_of_sale,
        label: 'nav.pos',
        route: AppRouter.pos,
        description: 'nav_desc.pos',
      ),
    );

    addItem(
      'view_products',
      NavigationItem(
        icon: Icons.inventory,
        label: 'nav.products',
        route: AppRouter.products,
        description: 'nav_desc.products',
      ),
    );

    // Add Bundles only if enabled in settings
    if (_bundlesEnabled) {
      addItem(
        'view_products',
        NavigationItem(
          icon: Icons.inventory_2,
          label: 'nav.bundles',
          route: AppRouter.bundles,
          description: 'nav_desc.bundles',
        ),
      );
    }

    addItem(
      'view_customers',
      NavigationItem(
        icon: Icons.people,
        label: 'nav.customers',
        route: AppRouter.customers,
        description: 'nav_desc.customers',
      ),
    );

    addItem(
      'view_suppliers',
      NavigationItem(
        icon: Icons.business,
        label: 'nav.suppliers',
        route: AppRouter.suppliers,
        description: 'nav_desc.suppliers',
      ),
    );

    addItem(
      'view_reports',
      NavigationItem(
        icon: Icons.analytics,
        label: 'nav.reports',
        route: AppRouter.reports,
        description: 'nav_desc.reports',
      ),
    );

    // Daily Report and Comprehensive Reports
    if (_hasPermission('view_all_reports')) {
      // Daily Report section
      items.add(
        NavigationItem(
          icon: Icons.calendar_today,
          label: 'nav.daily_report',
          route: AppRouter.comprehensiveReports,
          description: 'nav_desc.daily_report',
          navGroupId: 'daily_report',
          subItems: [
            NavigationSubItem(
              icon: Icons.dashboard,
              label: 'nav_sub.overview',
              route: AppRouter.comprehensiveReports,
              tabIndex: 0,
            ),
            NavigationSubItem(
              icon: Icons.assessment,
              label: 'nav_sub.item_wise_report',
              route: AppRouter.comprehensiveReports,
              tabIndex: 14,
            ),
            NavigationSubItem(
              icon: Icons.money,
              label: 'nav_sub.cash_report',
              route: AppRouter.comprehensiveReports,
              tabIndex: 6,
            ),
          ],
        ),
      );

      // All Reports section
      items.add(
        NavigationItem(
          icon: Icons.assessment,
          label: 'nav.all_reports',
          route: AppRouter.comprehensiveReports,
          description: 'nav_desc.all_reports',
          navGroupId: 'all_reports',
          subItems: [
            NavigationSubItem(
              icon: Icons.dashboard,
              label: 'nav_sub.overview',
              route: AppRouter.comprehensiveReports,
              tabIndex: 0,
            ),
            NavigationSubItem(
              icon: Icons.trending_up,
              label: 'nav_sub.sales_analytics',
              route: AppRouter.comprehensiveReports,
              tabIndex: 1,
            ),
            NavigationSubItem(
              icon: Icons.list,
              label: 'nav_sub.item_list',
              route: AppRouter.comprehensiveReports,
              tabIndex: 2,
            ),
            NavigationSubItem(
              icon: Icons.warning,
              label: 'nav_sub.low_stock',
              route: AppRouter.comprehensiveReports,
              tabIndex: 3,
            ),
            NavigationSubItem(
              icon: Icons.payments,
              label: 'nav_sub.payments',
              route: AppRouter.comprehensiveReports,
              tabIndex: 5,
            ),
            NavigationSubItem(
              icon: Icons.money,
              label: 'nav_sub.cash_report',
              route: AppRouter.comprehensiveReports,
              tabIndex: 6,
            ),
            NavigationSubItem(
              icon: Icons.credit_card,
              label: 'nav_sub.credit_report',
              route: AppRouter.comprehensiveReports,
              tabIndex: 7,
            ),
            NavigationSubItem(
              icon: Icons.move_up,
              label: 'nav_sub.stock_movement',
              route: AppRouter.comprehensiveReports,
              tabIndex: 8,
            ),
            NavigationSubItem(
              icon: Icons.account_balance_wallet,
              label: 'nav_sub.profit_analysis',
              route: AppRouter.comprehensiveReports,
              tabIndex: 9,
            ),
            NavigationSubItem(
              icon: Icons.calendar_month,
              label: 'nav_sub.monthly_report',
              route: AppRouter.comprehensiveReports,
              tabIndex: 10,
            ),
            NavigationSubItem(
              icon: Icons.account_balance,
              label: 'nav_sub.monthly_pl',
              route: AppRouter.comprehensiveReports,
              tabIndex: 11,
            ),
            NavigationSubItem(
              icon: Icons.receipt_long,
              label: 'nav_sub.expense_report',
              route: AppRouter.comprehensiveReports,
              tabIndex: 12,
            ),
            NavigationSubItem(
              icon: Icons.store,
              label: 'nav_sub.wholesale_report',
              route: AppRouter.comprehensiveReports,
              tabIndex: 13,
            ),
            NavigationSubItem(
              icon: Icons.assessment,
              label: 'nav_sub.item_wise_sales',
              route: AppRouter.comprehensiveReports,
              tabIndex: 14,
            ),
            NavigationSubItem(
              icon: Icons.table_chart,
              label: 'nav_sub.daily_comprehensive',
              route: AppRouter.comprehensiveReports,
              tabIndex: 15,
            ),
          ],
        ),
      );
    }

    if (_hasPermission('view_expenses')) {
      items.add(
        NavigationItem(
          icon: Icons.receipt_long,
          label: 'nav.expenses',
          route: _expensesSectionRoute,
          description: 'nav_desc.expenses',
          navGroupId: 'expenses',
          subItems: [
            NavigationSubItem(
              icon: Icons.playlist_add_check,
              label: 'nav_sub.expense_entry',
              route: AppRouter.expenseEntry,
            ),
            NavigationSubItem(
              icon: Icons.category,
              label: 'nav_sub.expense_heads',
              route: AppRouter.expenseHeads,
            ),
          ],
        ),
      );
    }

    addItem(
      'view_negative_inventory',
      NavigationItem(
        icon: Icons.report_problem,
        label: 'nav.negative_inventory',
        route: AppRouter.negativeInventory,
        description: 'nav_desc.negative_inventory',
      ),
    );

    addItem(
      'view_banking',
      NavigationItem(
        icon: Icons.account_balance,
        label: 'nav.banking',
        route: AppRouter.bankingSystem,
        description: 'nav_desc.banking',
      ),
    );

    addItem(
      'manage_employees',
      NavigationItem(
        icon: Icons.badge,
        label: 'Employees',
        route: AppRouter.employeeManagement,
        description: 'Manage employee accounts',
      ),
    );

    addItem(
      'manage_settings',
      NavigationItem(
        icon: Icons.settings,
        label: 'nav.settings',
        route: AppRouter.settings,
        description: 'nav_desc.settings',
      ),
    );

    addItem(
      'view_multi_pc',
      NavigationItem(
        icon: Icons.network_check,
        label: 'nav.multi_pc',
        route: AppRouter.networkConfig,
        description: 'nav_desc.multi_pc',
      ),
    );

    return items;
  }

  bool _hasPermission(String permissionKey) {
    final currentUser = ref.read(authProvider).currentUser;
    if (currentUser == null) return false;
    if (currentUser.isAdmin) return true;
    return currentUser.permissions[permissionKey] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.path;
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;
    final isDarkMode = ref.watch(isDarkModeProvider);

    // Reload sidebar settings only when trigger value changes.
    // Running this on every build can create rebuild loops and UI hangs.
    final navigationRefreshTick = ref.watch(navigationRefreshTriggerProvider);
    if (_lastNavigationRefreshTick != navigationRefreshTick) {
      _lastNavigationRefreshTick = navigationRefreshTick;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadBundlesSetting();
      });
    }

    // Check if user is authenticated for protected routes
    final protectedRoutes = [
      '/',
      '/pos',
      '/products',
      '/customers',
      '/suppliers',
      '/reports',
      '/settings'
    ];
    if (protectedRoutes.contains(currentLocation) &&
        !authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/login');
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Update current index based on current location
    _currentIndex = _navigationItems.indexWhere(
      (item) =>
          item.route == currentLocation ||
          (item.subItems?.any((sub) => sub.route == currentLocation) ?? false),
    );

    // Auto-expand All Reports only when navigating TO that route (not on every rebuild)
    // This prevents auto-expanding after user manually collapses it
    if (currentLocation == AppRouter.comprehensiveReports &&
        _lastRoute != AppRouter.comprehensiveReports &&
        !_isComprehensiveReportsExpanded) {
      _lastRoute = currentLocation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isComprehensiveReportsExpanded = true;
          });
        }
      });
    } else if (_lastRoute != currentLocation) {
      // Update last route when navigation changes
      _lastRoute = currentLocation;
    }

    // Auto-expand Expenses only when navigating TO that route (not on every rebuild)
    if ((currentLocation == AppRouter.expenseEntry ||
            currentLocation == AppRouter.expenseHeads) &&
        _lastRoute != AppRouter.expenseEntry &&
        _lastRoute != AppRouter.expenseHeads &&
        !_isExpensesExpanded) {
      _lastRoute = currentLocation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isExpensesExpanded = true;
          });
        }
      });
    } else if (_lastRoute != currentLocation &&
        currentLocation != AppRouter.expenseEntry &&
        currentLocation != AppRouter.expenseHeads) {
      // Update last route when navigation changes away from expenses
      _lastRoute = currentLocation;
    }

    // If cashier is on dashboard route, redirect to POS only if they don't have dashboard permission
    if (currentUser != null &&
        currentUser.isCashier &&
        currentLocation == '/' &&
        !_hasPermission('view_dashboard')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/pos');
        }
      });
    }

    if (_currentIndex == -1) _currentIndex = 0;

    // Desktop layout with sidebar
    if (_isDesktop) {
      if (currentLocation == AppRouter.pos) {
        return KeyboardShortcutWrapper(
          child: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: _buildDesktopContentShell(
                    currentLocation: currentLocation,
                    isDarkMode: isDarkMode,
                    child: widget.child,
                  ),
                ),
                if (_isPosSidebarVisible)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isPosSidebarVisible = false;
                      }),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: _isPosSidebarVisible ? 0 : -260,
                  top: 0,
                  bottom: 0,
                  width: 260,
                  child: IgnorePointer(
                    ignoring: !_isPosSidebarVisible,
                    child: _buildDesktopSidebar(),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: SafeArea(
                    child: Material(
                      color: AppColors.textPrimary,
                      elevation: 6,
                      borderRadius: BorderRadius.circular(10),
                      child: IconButton(
                        onPressed: () {
                          if (!_isPosSidebarVisible) {
                            _sidebarAnimationController.forward();
                          }
                          setState(() {
                            _isPosSidebarVisible = !_isPosSidebarVisible;
                          });
                        },
                        tooltip: _isPosSidebarVisible
                            ? 'Hide navigation'
                            : 'Show navigation',
                        icon: Icon(
                          _isPosSidebarVisible ? Icons.close : Icons.menu,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return KeyboardShortcutWrapper(
        child: Scaffold(
          body: Row(
            children: [
              _buildDesktopSidebar(),
              Expanded(
                child: _buildDesktopContentShell(
                  currentLocation: currentLocation,
                  isDarkMode: isDarkMode,
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tablet layout with navigation rail (same global shortcuts as desktop)
    if (_isTablet) {
      final tabletCs = Theme.of(context).colorScheme;
      return KeyboardShortcutWrapper(
        child: Scaffold(
          body: Row(
            children: [
              _buildTabletNavigationRail(),
              Expanded(
                child: Container(
                  color: tabletCs.surfaceContainerLowest,
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile layout with bottom navigation and drawer
    final hasMoreItems = _navigationItems.length > 4;
    return Scaffold(
      key: _scaffoldKey,
      body: widget.child,
      drawer: hasMoreItems ? _buildMobileDrawer() : null,
      bottomNavigationBar: _navigationItems.isEmpty
          ? null
          : Builder(
              builder: (context) =>
                  _buildMobileBottomNavigationWithContext(context),
            ),
    );
  }

  Widget _buildDesktopSidebar() {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return AnimatedBuilder(
      animation: _sidebarAnimation,
      builder: (context, child) {
        final width = 72.0 +
            (184.0 * _sidebarAnimation.value); // 72px collapsed, 256px expanded
        // Sync collapsed state with animation
        final isCurrentlyCollapsed = _sidebarAnimation.value < 0.5;
        return Container(
          width: width,
          decoration: BoxDecoration(
            color: AppColors.sidebarBackground,
            border: Border(
              right: BorderSide(
                color: AppColors.primaryDark,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Logo and title - Clean Minimal Header with Toggle Button
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.sidebarBackground,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.primaryDark,
                      width: 1,
                    ),
                  ),
                ),
                child: isCurrentlyCollapsed
                    ? Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.asset(
                                'assets/app_icon.png',
                                fit: BoxFit.cover,
                                semanticLabel: 'Retail POS',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Toggle button when collapsed
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _toggleSidebar,
                              borderRadius: BorderRadius.circular(8),
                              hoverColor: isDarkMode
                                  ? const Color(0xFF252932)
                                      .withValues(alpha: 0.6)
                                  : const Color(0xFFF1F3F5)
                                      .withValues(alpha: 0.8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.chevron_right,
                                  color: AppColors.sidebarInactive,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                fit: BoxFit.contain,
                                alignment: Alignment.centerLeft,
                                semanticLabel: 'Retail POS',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Toggle button when expanded
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _toggleSidebar,
                              borderRadius: BorderRadius.circular(8),
                              hoverColor: isDarkMode
                                  ? const Color(0xFF252932)
                                      .withValues(alpha: 0.6)
                                  : const Color(0xFFF1F3F5)
                                      .withValues(alpha: 0.8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.chevron_left,
                                  color: AppColors.sidebarInactive,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              // Navigation items - Modern Minimal Design
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  children: _navigationItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = _currentIndex == index;
                    final hasSubItems =
                        item.subItems != null && item.subItems!.isNotEmpty;
                    final isDailyReport = item.navGroupId == 'daily_report';
                    final isComprehensiveReports =
                        item.navGroupId == 'all_reports';
                    final isExpensesSection =
                        item.route == _expensesSectionRoute;
                    final isExpanded = hasSubItems
                        ? (isDailyReport
                            ? _isDailyReportExpanded
                            : isComprehensiveReports
                                ? _isComprehensiveReportsExpanded
                                : isExpensesSection
                                    ? _isExpensesExpanded
                                    : false)
                        : false;

                    return Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (hasSubItems && !isCurrentlyCollapsed) {
                                  // Toggle expand/collapse
                                  setState(() {
                                    if (isDailyReport) {
                                      _isDailyReportExpanded =
                                          !_isDailyReportExpanded;
                                    } else if (isComprehensiveReports) {
                                      _isComprehensiveReportsExpanded =
                                          !_isComprehensiveReportsExpanded;
                                    } else if (isExpensesSection) {
                                      _isExpensesExpanded =
                                          !_isExpensesExpanded;
                                    }
                                  });
                                } else {
                                  // Navigate to route (or first sub-item for grouped sections)
                                  final targetRoute = (hasSubItems &&
                                          item.route == _expensesSectionRoute)
                                      ? item.subItems!.first.route
                                      : item.route;
                                  context.go(targetRoute);
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              hoverColor: isDarkMode
                                  ? const Color(0xFF252932)
                                      .withValues(alpha: 0.6)
                                  : const Color(0xFFF1F3F5)
                                      .withValues(alpha: 0.8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                padding: EdgeInsets.symmetric(
                                    horizontal: isCurrentlyCollapsed ? 14 : 13,
                                    vertical: 11),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: isCurrentlyCollapsed
                                      ? MainAxisAlignment.center
                                      : MainAxisAlignment.start,
                                  children: [
                                    Icon(
                                      item.icon,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFFAEBBCB),
                                      size: 21,
                                    ),
                                    if (!isCurrentlyCollapsed) ...[
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          item.label.tr(),
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFFD8E0EA),
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                      if (hasSubItems)
                                        AnimatedRotation(
                                          turns: isExpanded ? 0.5 : 0.0,
                                          duration:
                                              const Duration(milliseconds: 200),
                                          child: Icon(
                                            Icons.chevron_right,
                                            size: 18,
                                            color: AppColors.sidebarInactive,
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Sub-items (when expanded)
                        if (hasSubItems && isExpanded && !isCurrentlyCollapsed)
                          ...item.subItems!.map((subItem) {
                            final currentLocation =
                                GoRouterState.of(context).uri.path;
                            final queryParams =
                                GoRouterState.of(context).uri.queryParameters;
                            final isSubSelected =
                                currentLocation == subItem.route &&
                                    (subItem.tabIndex != null
                                        ? queryParams['tab'] ==
                                            subItem.tabIndex.toString()
                                        : true);

                            return Container(
                              margin: const EdgeInsets.only(
                                  left: 16, bottom: 2, top: 2),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    // Navigate to comprehensive reports with tab index
                                    if (subItem.tabIndex != null) {
                                      context.go(
                                          '${subItem.route}?tab=${subItem.tabIndex}');
                                    } else {
                                      context.go(subItem.route);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  hoverColor: isDarkMode
                                      ? const Color(0xFF252932)
                                          .withValues(alpha: 0.4)
                                      : const Color(0xFFF1F3F5)
                                          .withValues(alpha: 0.6),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSubSelected
                                          ? (isDarkMode
                                              ? AppColors.primaryColor
                                                  .withValues(alpha: 0.15)
                                              : AppColors.primaryColor
                                                  .withValues(alpha: 0.06))
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: isSubSelected
                                          ? Border.all(
                                              color: AppColors.primaryColor
                                                  .withValues(alpha: 0.25),
                                              width: 1,
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          subItem.icon,
                                          color: isSubSelected
                                              ? AppColors.primaryColor
                                              : (isDarkMode
                                                  ? const Color(0xFF9CA3AF)
                                                  : const Color(0xFF6B7280)),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            subItem.label.tr(),
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: isSubSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: isSubSelected
                                                  ? AppColors.primaryColor
                                                  : (isDarkMode
                                                      ? Colors.white
                                                      : Colors.white),
                                              letterSpacing: -0.1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                      ],
                    );
                  }).toList(),
                ),
              ),

              // User section - Modern Bottom Design
              Builder(
                builder: (context) {
                  final authState = ref.watch(authProvider);
                  final currentUser = authState.currentUser;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.sidebarBackground,
                      border: Border(
                        top: BorderSide(
                          color: AppColors.primaryDark,
                          width: 1,
                        ),
                      ),
                    ),
                    child: isCurrentlyCollapsed
                        ? Center(
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primaryColor,
                              child: const Icon(Icons.person,
                                  color: Colors.white, size: 20),
                            ),
                          )
                        : Row(
                            children: [
                              // Profile Image
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primaryColor,
                                child: const Icon(Icons.person,
                                    color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              // User Name and Role
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currentUser?.name ??
                                          'user.current_user'.tr(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFF1F5F9),
                                        letterSpacing: -0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currentUser?.roleDisplayName ??
                                          'user.admin'.tr(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                              // Logout Button - Aligned to the right
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    ref.read(authProvider.notifier).logout();
                                    context.go('/login');
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  hoverColor: isDarkMode
                                      ? const Color(0xFF2A3038)
                                          .withValues(alpha: 0.5)
                                      : const Color(0xFFE8EAED)
                                          .withValues(alpha: 0.5),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.logout_rounded,
                                      size: 20,
                                      color: isDarkMode
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopContentShell({
    required String currentLocation,
    required bool isDarkMode,
    required Widget child,
  }) {
    // Dashboard has its own custom desktop composition.
    if (currentLocation == AppRouter.dashboard) {
      return Container(
        color: AppColors.backgroundLight,
        child: child,
      );
    }

    return Container(
      color: AppColors.backgroundLight,
      child: Column(
        children: [
          _buildDesktopTopStrip(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.surfaceDark
                      : AppColors.surfaceLight,
                  border: Border.all(
                    color: isDarkMode
                        ? const Color(0xFF374151)
                        : AppColors.borderColor,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTopStrip() {
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.primaryColor,
      child: Row(
        children: [
          const Icon(Icons.storefront, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Retail POS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Text(
            DateFormat('d MMMM yyyy hh:mm a').format(_desktopClock),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            currentUser?.name ?? 'Admin',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletNavigationRail() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) =>
          context.go(_navigationItems[index].route),
      labelType: NavigationRailLabelType.all,
      backgroundColor: cs.surface,
      indicatorColor: cs.primary.withValues(alpha: 0.12),
      selectedIconTheme: IconThemeData(color: cs.primary),
      unselectedIconTheme: IconThemeData(color: cs.onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(
        color: cs.primary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      destinations: _navigationItems
          .map(
            (item) => NavigationRailDestination(
              icon: Icon(item.icon),
              label: Text(item.label.tr()),
            ),
          )
          .toList(),
    );
  }

  static bool _routeBelongsToNavItem(String path, NavigationItem item) {
    if (item.route == path) return true;
    final subs = item.subItems;
    if (subs == null) return false;
    return subs.any((s) => s.route == path);
  }

  /// Selected index for [BottomNavigationBar]: main slots first, then "More" if applicable.
  int _mobileBottomNavSelectedIndex(
    List<NavigationItem> mainItems,
    bool hasMoreItems,
  ) {
    final path = GoRouterState.of(context).uri.path;
    for (var i = 0; i < mainItems.length; i++) {
      if (_routeBelongsToNavItem(path, mainItems[i])) return i;
    }
    if (hasMoreItems) {
      for (final item in _navigationItems.skip(mainItems.length)) {
        if (_routeBelongsToNavItem(path, item)) {
          return mainItems.length;
        }
      }
    }
    return 0;
  }

  Widget _buildMobileBottomNavigationWithContext(BuildContext scaffoldContext) {
    // Limit to 4 most important items for mobile
    // Use drawer for additional items
    final mainItems = _navigationItems.length > 4
        ? _navigationItems.take(4).toList()
        : _navigationItems;

    final hasMoreItems = _navigationItems.length > 4;
    final effectiveIndex =
        _mobileBottomNavSelectedIndex(mainItems, hasMoreItems);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return BottomNavigationBar(
      currentIndex: effectiveIndex,
      onTap: (index) {
        if (hasMoreItems && index == 4) {
          // Open drawer for "More" button
          _scaffoldKey.currentState?.openDrawer();
        } else if (index < mainItems.length) {
          context.go(mainItems[index].route);
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: cs.surface,
      selectedItemColor: cs.primary,
      unselectedItemColor: cs.onSurfaceVariant,
      selectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: cs.primary,
      ),
      unselectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: cs.onSurfaceVariant,
      ),
      elevation: isDark ? 0 : 8,
      showUnselectedLabels: true,
      items: [
        ...mainItems.map(
          (item) => BottomNavigationBarItem(
            icon: Icon(item.icon),
            label: item.label.tr(),
          ),
        ),
        // Add "More" button if there are more items
        if (_navigationItems.length > 4)
          BottomNavigationBarItem(
            icon: const Icon(Icons.more_horiz),
            label: 'drawer.more'.tr(),
          ),
      ],
    );
  }

  Widget _buildMobileDrawer() {
    final currentLocation = GoRouterState.of(context).uri.path;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;

    // Get items not shown in bottom nav (items 5+)
    final additionalItems = _navigationItems.length > 4
        ? _navigationItems.skip(4).toList()
        : <NavigationItem>[];

    return Drawer(
      backgroundColor: cs.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          DrawerHeader(
            decoration: BoxDecoration(
              color: cs.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: cs.onPrimary,
                  child: Icon(
                    Icons.point_of_sale,
                    color: cs.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'drawer.pos_system'.tr(),
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (currentUser != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    currentUser.name,
                    style: TextStyle(
                      color: cs.onPrimary.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Additional navigation items
          ...additionalItems.map((item) {
            final isSelected = item.route == currentLocation;
            return ListTile(
              leading: Icon(
                item.icon,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              title: Text(
                item.label.tr(),
                style: TextStyle(
                  color: isSelected ? cs.primary : cs.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              subtitle: item.description != null
                  ? Text(
                      item.description!.tr(),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    )
                  : null,
              selected: isSelected,
              onTap: () {
                Navigator.pop(context);
                context.go(item.route);
              },
            );
          }),
          Divider(height: 1, color: cs.outlineVariant),
          // Logout
          ListTile(
            leading: Icon(
              Icons.logout,
              color: cs.onSurfaceVariant,
            ),
            title: Text(
              'drawer.logout'.tr(),
              style: TextStyle(
                color: cs.onSurface,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;

  /// Translation key for [tr].
  final String label;
  final String route;

  /// Translation key for [tr].
  final String? description;

  /// Stable id for expand/collapse (not translated).
  final String? navGroupId;
  final List<NavigationSubItem>? subItems;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
    this.description,
    this.navGroupId,
    this.subItems,
  });
}

class NavigationSubItem {
  final IconData icon;
  final String label;
  final String route;
  final int? tabIndex; // For comprehensive reports tab index

  NavigationSubItem({
    required this.icon,
    required this.label,
    required this.route,
    this.tabIndex,
  });
}
