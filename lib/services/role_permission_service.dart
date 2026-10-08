import 'package:shared_preferences/shared_preferences.dart';

import '../models/employee.dart';

class RolePermissionDefinition {
  final String key;
  final String name;
  final String category;
  final String description;

  const RolePermissionDefinition({
    required this.key,
    required this.name,
    required this.category,
    required this.description,
  });
}

class RolePermissionService {
  static const String _storageKeyPrefix = 'role_permissions_';

  static const List<RolePermissionDefinition> definitions = [
    RolePermissionDefinition(
      key: 'view_dashboard',
      name: 'Dashboard',
      category: 'Navigation',
      description: 'Access the main dashboard overview.',
    ),
    RolePermissionDefinition(
      key: 'access_pos',
      name: 'Point of Sale',
      category: 'Navigation',
      description: 'Open and use the POS screen to create orders.',
    ),
    RolePermissionDefinition(
      key: 'view_products',
      name: 'View Products',
      category: 'Inventory',
      description: 'See product catalog and stock levels.',
    ),
    RolePermissionDefinition(
      key: 'edit_products',
      name: 'Edit Products',
      category: 'Inventory',
      description: 'Create, update, or delete product records.',
    ),
    RolePermissionDefinition(
      key: 'view_customers',
      name: 'View Customers',
      category: 'CRM',
      description: 'View customer lists and profiles.',
    ),
    RolePermissionDefinition(
      key: 'add_customer',
      name: 'Add Customer',
      category: 'CRM',
      description: 'Create new customer records.',
    ),
    RolePermissionDefinition(
      key: 'edit_customer',
      name: 'Edit Customer',
      category: 'CRM',
      description: 'Modify existing customer information.',
    ),
    RolePermissionDefinition(
      key: 'delete_customer',
      name: 'Delete Customer',
      category: 'CRM',
      description: 'Remove customer records from the system.',
    ),
    RolePermissionDefinition(
      key: 'manage_customers',
      name: 'Manage Customers',
      category: 'CRM',
      description: 'Create or edit customer records.',
    ),
    RolePermissionDefinition(
      key: 'view_suppliers',
      name: 'View Suppliers',
      category: 'Inventory',
      description: 'Access supplier directory.',
    ),
    RolePermissionDefinition(
      key: 'add_supplier',
      name: 'Add Supplier',
      category: 'Inventory',
      description: 'Create new supplier records.',
    ),
    RolePermissionDefinition(
      key: 'edit_supplier',
      name: 'Edit Supplier',
      category: 'Inventory',
      description: 'Modify existing supplier information.',
    ),
    RolePermissionDefinition(
      key: 'delete_supplier',
      name: 'Delete Supplier',
      category: 'Inventory',
      description: 'Remove supplier records from the system.',
    ),
    RolePermissionDefinition(
      key: 'manage_suppliers',
      name: 'Manage Suppliers',
      category: 'Inventory',
      description: 'Create or edit supplier records.',
    ),
    RolePermissionDefinition(
      key: 'manage_sales',
      name: 'Manage Sales',
      category: 'Sales',
      description: 'Edit orders and apply discounts.',
    ),
    RolePermissionDefinition(
      key: 'process_payments',
      name: 'Process Payments',
      category: 'Sales',
      description: 'Capture payments and finalize transactions.',
    ),
    RolePermissionDefinition(
      key: 'process_returns',
      name: 'Process Returns',
      category: 'Sales',
      description: 'Handle returns, refunds, and exchanges.',
    ),
    RolePermissionDefinition(
      key: 'view_reports',
      name: 'View Reports',
      category: 'Reports',
      description: 'Open standard reports module.',
    ),
    RolePermissionDefinition(
      key: 'view_all_reports',
      name: 'All Reports Workspace',
      category: 'Reports',
      description: 'Access the comprehensive All Reports screen.',
    ),
    RolePermissionDefinition(
      key: 'view_negative_inventory',
      name: 'Negative Inventory Report',
      category: 'Reports',
      description: 'Show the negative inventory audit.',
    ),
    RolePermissionDefinition(
      key: 'view_banking',
      name: 'View Banking',
      category: 'Finance',
      description: 'View bank accounts and ledgers.',
    ),
    RolePermissionDefinition(
      key: 'edit_banking',
      name: 'Edit Banking',
      category: 'Finance',
      description: 'Create or edit bank transactions.',
    ),
    RolePermissionDefinition(
      key: 'view_expenses',
      name: 'View Expenses',
      category: 'Finance',
      description: 'Access expense heads and entries.',
    ),
    RolePermissionDefinition(
      key: 'manage_expenses',
      name: 'Manage Expenses',
      category: 'Finance',
      description: 'Create or edit expense heads and entries.',
    ),
    RolePermissionDefinition(
      key: 'manage_inventory',
      name: 'Inventory Adjustments',
      category: 'Inventory',
      description: 'Access inventory tools and adjustments.',
    ),
    RolePermissionDefinition(
      key: 'manage_employees',
      name: 'Manage Employees',
      category: 'Administration',
      description: 'Add or edit employee records.',
    ),
    RolePermissionDefinition(
      key: 'manage_settings',
      name: 'Manage Settings',
      category: 'Administration',
      description: 'Access business and system settings.',
    ),
    RolePermissionDefinition(
      key: 'view_multi_pc',
      name: 'Multi-PC Setup',
      category: 'Administration',
      description: 'Access network / multi-device setup.',
    ),
  ];

  static final Map<EmployeeRole, List<String>> defaultRolePermissions = {
    EmployeeRole.admin: definitions.map((d) => d.key).toList(),
    EmployeeRole.manager: [
      'view_dashboard',
      'access_pos',
      'view_products',
      'edit_products',
      'view_customers',
      'add_customer',
      'edit_customer',
      'delete_customer',
      'manage_customers',
      'view_suppliers',
      'add_supplier',
      'edit_supplier',
      'delete_supplier',
      'manage_suppliers',
      'manage_sales',
      'process_payments',
      'process_returns',
      'view_reports',
      'view_all_reports',
      'view_negative_inventory',
      'view_banking',
      'edit_banking',
      'view_expenses',
      'manage_expenses',
      'manage_inventory',
      'manage_employees',
      'manage_settings',
      'view_multi_pc',
    ],
    EmployeeRole.cashier: [
      'access_pos',
      'view_products',
      'view_customers',
      'manage_sales',
      'process_payments',
      'process_returns',
      'view_reports',
      'view_banking',
      'edit_banking',
    ],
    EmployeeRole.staff: [
      'access_pos',
      'view_products',
      'view_customers',
    ],
  };

  static String _storageKey(EmployeeRole role) =>
      '$_storageKeyPrefix${role.name}';

  static Map<String, bool> defaultPermissionsFor(EmployeeRole role) {
    final defaults = defaultRolePermissions[role] ?? [];
    return {
      for (final definition in definitions)
        definition.key: defaults.contains(definition.key),
    };
  }

  static Future<Map<String, bool>> loadPermissions(EmployeeRole role) async {
    if (role == EmployeeRole.admin) {
      return defaultPermissionsFor(role);
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey(role));

    if (stored == null || stored.isEmpty) {
      return defaultPermissionsFor(role);
    }

    final enabled = stored
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    return {
      for (final definition in definitions)
        definition.key: enabled.contains(definition.key),
    };
  }

  static Future<void> savePermissions(
    EmployeeRole role,
    Map<String, bool> permissions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final enabledKeys = permissions.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .join(',');

    await prefs.setString(_storageKey(role), enabledKeys);
  }
}
