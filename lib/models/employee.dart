import 'package:drift/drift.dart';
import '../database/database.dart';

enum EmployeeRole { admin, manager, cashier, staff }

class EmployeeModel {
  final int? id;
  final String name;
  final String? username; // Can be null for old users
  final String? email; // Legacy field for old users
  final String phone;
  final String? address;
  final EmployeeRole role;
  final String employeeId;
  final double? salary;
  final DateTime hireDate;
  final DateTime? terminationDate;
  final bool isActive;
  final bool canLogin;
  final String? password;
  final Map<String, bool> permissions;
  final double? commissionPercentage; // Commission percentage for salon employees
  final DateTime createdAt;
  final DateTime updatedAt;

  EmployeeModel({
    this.id,
    required this.name,
    this.username,
    this.email,
    required this.phone,
    this.address,
    this.role = EmployeeRole.staff,
    required this.employeeId,
    this.salary,
    required this.hireDate,
    this.terminationDate,
    this.isActive = true,
    this.canLogin = true,
    this.password,
    this.permissions = const {},
    this.commissionPercentage,
    required this.createdAt,
    required this.updatedAt,
  });

  // Getter to return username or email (for backward compatibility)
  String get displayUsername => username ?? email ?? '';

  // Check if employee can be logged in with this identifier
  bool canLoginWith(String identifier) {
    if (identifier.isEmpty) return false;
    return (username != null &&
            username!.toLowerCase() == identifier.toLowerCase()) ||
        (email != null && email!.toLowerCase() == identifier.toLowerCase());
  }

  factory EmployeeModel.fromEmployee(Employee employee) {
    DateTime parseDate(String dateString) {
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        print('Error parsing date: $dateString - $e');
        return DateTime.now();
      }
    }

    return EmployeeModel(
      id: employee.id,
      name: employee.name.isEmpty ? 'Unknown' : employee.name,
      username:
          employee.username ?? employee.email, // Support both old and new users
      email: employee.email,
      phone: employee.phone.isEmpty ? '0000000' : employee.phone,
      address: employee.address,
      role: EmployeeRole.values.firstWhere(
        (e) => e.name == employee.role,
        orElse: () => EmployeeRole.staff,
      ),
      employeeId: employee.employeeId.isEmpty ? 'EMP001' : employee.employeeId,
      salary: employee.salary?.isNaN == true ? null : employee.salary,
      hireDate: parseDate(employee.hireDate),
      terminationDate: employee.terminationDate != null
          ? parseDate(employee.terminationDate!)
          : null,
      isActive: employee.isActive,
      canLogin: employee.canLogin,
      password: employee.password,
      permissions: _parsePermissions(employee.permissions),
      commissionPercentage: employee.commissionPercentage?.isNaN == true ? null : employee.commissionPercentage,
      createdAt: parseDate(employee.createdAt),
      updatedAt: parseDate(employee.updatedAt),
    );
  }

  Employee toEmployee() {
    return Employee(
      id: id ?? 0,
      name: name,
      username: username,
      email: email,
      phone: phone,
      address: address,
      role: role.name,
      employeeId: employeeId,
      salary: salary,
      hireDate: hireDate.toIso8601String(),
      terminationDate: terminationDate?.toIso8601String(),
      isActive: isActive,
      canLogin: canLogin,
      password: password,
      permissions: _serializePermissions(permissions),
      commissionPercentage: commissionPercentage,
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  EmployeesCompanion toCompanion() {
    return EmployeesCompanion(
      name: Value(name),
      username: Value(username),
      email: Value(email),
      phone: Value(phone),
      address: Value(address),
      role: Value(role.name),
      employeeId: Value(employeeId),
      salary: Value(salary),
      hireDate: Value(hireDate.toIso8601String()),
      terminationDate: Value(terminationDate?.toIso8601String()),
      isActive: Value(isActive),
      canLogin: Value(canLogin),
      password: Value(password),
      permissions: Value(_serializePermissions(permissions)),
      commissionPercentage: Value(commissionPercentage),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }

  EmployeeModel copyWith({
    int? id,
    String? name,
    String? username,
    String? email,
    String? phone,
    String? address,
    EmployeeRole? role,
    String? employeeId,
    double? salary,
    DateTime? hireDate,
    DateTime? terminationDate,
    bool? isActive,
    bool? canLogin,
    String? password,
    Map<String, bool>? permissions,
    double? commissionPercentage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      role: role ?? this.role,
      employeeId: employeeId ?? this.employeeId,
      salary: salary ?? this.salary,
      hireDate: hireDate ?? this.hireDate,
      terminationDate: terminationDate ?? this.terminationDate,
      isActive: isActive ?? this.isActive,
      canLogin: canLogin ?? this.canLogin,
      password: password ?? this.password,
      permissions: permissions ?? this.permissions,
      commissionPercentage: commissionPercentage ?? this.commissionPercentage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static Map<String, bool> _parsePermissions(String? permissionsJson) {
    if (permissionsJson == null || permissionsJson.isEmpty) {
      return {};
    }
    try {
      // Simple JSON parsing - you might want to use a proper JSON library
      final Map<String, dynamic> parsed =
          Map<String, dynamic>.from(Uri.splitQueryString(permissionsJson));
      return parsed.map((key, value) => MapEntry(key, value == 'true'));
    } catch (e) {
      return {};
    }
  }

  static String _serializePermissions(Map<String, bool> permissions) {
    if (permissions.isEmpty) return '';
    return permissions.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  bool get isAdmin => role == EmployeeRole.admin;
  bool get isManager => role == EmployeeRole.manager;
  bool get isCashier => role == EmployeeRole.cashier;
  bool get isStaff => role == EmployeeRole.staff;
  bool get isTerminated => terminationDate != null;
  bool get isCurrentlyActive => isActive && !isTerminated;

  // Permission checks
  bool canManageProducts() => isAdmin || permissions['edit_products'] == true;
  bool canManageCustomers() =>
      isAdmin || permissions['manage_customers'] == true;
  bool canAddCustomer() =>
      isAdmin || permissions['add_customer'] == true || permissions['manage_customers'] == true;
  bool canEditCustomer() =>
      isAdmin || permissions['edit_customer'] == true || permissions['manage_customers'] == true;
  bool canDeleteCustomer() => isAdmin;
  bool canManageSales() => isAdmin || permissions['manage_sales'] == true;
  bool canViewReports() => isAdmin || permissions['view_reports'] == true;
  bool canManageInventory() =>
      isAdmin || permissions['manage_inventory'] == true;
  bool canManageEmployees() =>
      isAdmin || permissions['manage_employees'] == true;
  bool canManageSettings() => isAdmin || permissions['manage_settings'] == true;
  bool canProcessReturns() => isAdmin || permissions['process_returns'] == true;
  bool canManageSuppliers() =>
      isAdmin || permissions['manage_suppliers'] == true;
  bool canAddSupplier() =>
      isAdmin || permissions['add_supplier'] == true || permissions['manage_suppliers'] == true;
  bool canEditSupplier() =>
      isAdmin || permissions['edit_supplier'] == true || permissions['manage_suppliers'] == true;
  bool canDeleteSupplier() => isAdmin;
  bool canManageBanks() => isAdmin || permissions['edit_banking'] == true;
  bool canViewLedgers() => isAdmin || permissions['view_banking'] == true;

  String get roleDisplayName {
    switch (role) {
      case EmployeeRole.admin:
        return 'Administrator';
      case EmployeeRole.manager:
        return 'Manager';
      case EmployeeRole.cashier:
        return 'Cashier';
      case EmployeeRole.staff:
        return 'Staff';
    }
  }

  @override
  String toString() {
    return 'EmployeeModel(id: $id, name: $name, role: $role, employeeId: $employeeId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmployeeModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
