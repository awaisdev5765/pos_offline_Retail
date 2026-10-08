import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/employee.dart';
import '../providers/auth_provider.dart';
import '../services/role_permission_service.dart';

class RolePermissionsScreen extends ConsumerStatefulWidget {
  const RolePermissionsScreen({super.key});

  @override
  ConsumerState<RolePermissionsScreen> createState() =>
      _RolePermissionsScreenState();
}

class _RolePermissionsScreenState extends ConsumerState<RolePermissionsScreen> {
  Map<String, bool> adminPermissions = {};
  Map<String, bool> managerPermissions = {};
  Map<String, bool> cashierPermissions = {};
  Map<String, bool> staffPermissions = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() => isLoading = true);
    try {
      adminPermissions =
          await RolePermissionService.loadPermissions(EmployeeRole.admin);
      managerPermissions =
          await RolePermissionService.loadPermissions(EmployeeRole.manager);
      cashierPermissions =
          await RolePermissionService.loadPermissions(EmployeeRole.cashier);
      staffPermissions =
          await RolePermissionService.loadPermissions(EmployeeRole.staff);
    } catch (e) {
      print('Error loading permissions: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _savePermissions(
      EmployeeRole role, Map<String, bool> permissions) async {
    try {
      await RolePermissionService.savePermissions(role, permissions);
    } catch (e) {
      print('Error saving permissions: $e');
    }
  }

  Map<String, bool> _getPermissionsForRole(EmployeeRole role) {
    switch (role) {
      case EmployeeRole.admin:
        return adminPermissions;
      case EmployeeRole.manager:
        return managerPermissions;
      case EmployeeRole.cashier:
        return cashierPermissions;
      case EmployeeRole.staff:
        return staffPermissions;
    }
  }

  void _updatePermissionForRole(
      EmployeeRole role, String permissionKey, bool value) {
    setState(() {
      final permissions = _getPermissionsForRole(role);
      permissions[permissionKey] = value;
      _savePermissions(role, permissions);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;

    if (currentUser == null || !currentUser.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text('roles.title'.tr()),
          automaticallyImplyLeading: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 16),
                Text(
                  'roles.access_restricted'.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'roles.admin_only'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/settings');
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: Text('roles.go_back'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('roles.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPermissions,
            tooltip: 'common.refresh'.tr(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      labelColor: const Color(0xFF3B82F6),
                      unselectedLabelColor: const Color(0xFF64748B),
                      indicatorColor: const Color(0xFF3B82F6),
                      tabs: [
                        Tab(text: 'roles.tab_admin'.tr()),
                        Tab(text: 'roles.tab_manager'.tr()),
                        Tab(text: 'roles.tab_cashier'.tr()),
                        Tab(text: 'roles.tab_staff'.tr()),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildRolePermissions(EmployeeRole.admin),
                        _buildRolePermissions(EmployeeRole.manager),
                        _buildRolePermissions(EmployeeRole.cashier),
                        _buildRolePermissions(EmployeeRole.staff),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRolePermissions(EmployeeRole role) {
    final permissions = _getPermissionsForRole(role);

    // Group permissions by category
    final Map<String, List<Map<String, dynamic>>> groupedPermissions = {};
    for (final definition in RolePermissionService.definitions) {
      final category = definition.category;
      if (!groupedPermissions.containsKey(category)) {
        groupedPermissions[category] = [];
      }
      groupedPermissions[category]!.add({
        'key': definition.key,
        'name': definition.name,
        'description': definition.description,
      });
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Role info card
        Card(
          color: _getRoleColor(role).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _getRoleIcon(role),
                  size: 48,
                  color: _getRoleColor(role),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getRoleName(role),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getRoleDescription(role),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Permissions by category
        ...groupedPermissions.entries.map((entry) {
          final category = entry.key;
          final perms = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Divider(height: 24),
                    ...perms.map((perm) {
                      final key = perm['key'] as String;
                      final name = perm['name'] as String;
                      final isEnabled = permissions[key] ?? false;

                      return SwitchListTile(
                        title: Text(name),
                        subtitle: Text(
                          perm['description'] as String,
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: isEnabled,
                        onChanged: role == EmployeeRole.admin
                            ? null // Admin has all permissions, cannot be changed
                            : (value) =>
                                _updatePermissionForRole(role, key, value),
                        secondary: Icon(
                          isEnabled
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color:
                              isEnabled ? const Color(0xFF10B981) : Colors.grey,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _getRoleName(EmployeeRole role) {
    switch (role) {
      case EmployeeRole.admin:
        return 'roles.name_admin'.tr();
      case EmployeeRole.manager:
        return 'roles.name_manager'.tr();
      case EmployeeRole.cashier:
        return 'roles.name_cashier'.tr();
      case EmployeeRole.staff:
        return 'roles.name_staff'.tr();
    }
  }

  String _getRoleDescription(EmployeeRole role) {
    switch (role) {
      case EmployeeRole.admin:
        return 'roles.desc_admin'.tr();
      case EmployeeRole.manager:
        return 'roles.desc_manager'.tr();
      case EmployeeRole.cashier:
        return 'roles.desc_cashier'.tr();
      case EmployeeRole.staff:
        return 'roles.desc_staff'.tr();
    }
  }

  IconData _getRoleIcon(EmployeeRole role) {
    switch (role) {
      case EmployeeRole.admin:
        return Icons.admin_panel_settings;
      case EmployeeRole.manager:
        return Icons.manage_accounts;
      case EmployeeRole.cashier:
        return Icons.point_of_sale;
      case EmployeeRole.staff:
        return Icons.person;
    }
  }

  Color _getRoleColor(EmployeeRole role) {
    switch (role) {
      case EmployeeRole.admin:
        return const Color(0xFFEF4444);
      case EmployeeRole.manager:
        return const Color(0xFF3B82F6);
      case EmployeeRole.cashier:
        return const Color(0xFF10B981);
      case EmployeeRole.staff:
        return const Color(0xFF6B7280);
    }
  }
}
