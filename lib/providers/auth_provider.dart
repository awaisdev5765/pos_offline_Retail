import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../services/role_permission_service.dart';
import '../models/employee.dart';
import '../utils/password_hasher.dart';

// Authentication state
class AuthState {
  final bool isAuthenticated;
  final bool isBusinessSetup;
  final String? businessName;
  final String? adminUsername;
  final EmployeeModel? currentUser;
  final bool isLoading;

  const AuthState({
    this.isAuthenticated = false,
    this.isBusinessSetup = false,
    this.businessName,
    this.adminUsername,
    this.currentUser,
    this.isLoading = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isBusinessSetup,
    String? businessName,
    String? adminUsername,
    EmployeeModel? currentUser,
    bool? isLoading,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isBusinessSetup: isBusinessSetup ?? this.isBusinessSetup,
      businessName: businessName ?? this.businessName,
      adminUsername: adminUsername ?? this.adminUsername,
      currentUser: currentUser ?? this.currentUser,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Authentication notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final DatabaseService _databaseService;

  AuthNotifier(this._databaseService) : super(const AuthState()) {
    _checkAuthStatus();
  }

  String _hashPassword(String password) {
    return PasswordHasher.hash(password);
  }

  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);

    try {
      final settings = await _databaseService.getSettings();
      final businessSetupComplete =
          settings['business_setup_complete'] == 'true';
      final businessName = settings['business_name'];
      final adminUsername =
          settings['admin_username'] ?? settings['admin_email'];

      // A completed business setup is not an authenticated session. Requiring
      // an explicit login here prevents restarting the app from bypassing the
      // login screen and inheriting admin access.
      state = AuthState(
        isBusinessSetup: businessSetupComplete,
        businessName: businessName,
        adminUsername: adminUsername,
        isAuthenticated: false,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isBusinessSetup: false,
        isAuthenticated: false,
        isLoading: false,
      );
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true);

    try {
      // First check if it's admin login
      final settings = await _databaseService.getSettings();
      // Support both admin_username and admin_email for backward compatibility
      final adminUsername =
          settings['admin_username'] ?? settings['admin_email'];
      final adminPassword = settings['admin_password'];

      // Trim and compare case-insensitively for username (but keep exact match for email if it looks like email)
      final trimmedInputUsername = username.trim();
      final trimmedAdminUsername = adminUsername?.trim() ?? '';

      // Case-insensitive comparison for both username and email
      final usernameMatches = trimmedAdminUsername.isNotEmpty &&
          (trimmedAdminUsername.toLowerCase() ==
                  trimmedInputUsername.toLowerCase() ||
              trimmedAdminUsername == trimmedInputUsername);

      if (usernameMatches &&
          adminPassword != null &&
          PasswordHasher.verify(password, adminPassword)) {
        String? upgradedAdminPassword;
        if (PasswordHasher.isLegacyHash(adminPassword)) {
          upgradedAdminPassword = PasswordHasher.hash(password);
          await _databaseService.setSetting(
              'admin_password', upgradedAdminPassword);
        }
        // Admin login - prefer the persisted employee record so we retain the employee ID
        EmployeeModel? adminUser =
            await _databaseService.getEmployeeByUsername(trimmedAdminUsername);

        if (adminUser == null) {
          final allEmployees = await _databaseService.getAllEmployees();
          EmployeeModel? matchedAdmin;

          // Try to match any admin record by username or email
          for (final employee in allEmployees) {
            final matchesIdentifier = (employee.username != null &&
                    employee.username!.toLowerCase() ==
                        trimmedInputUsername.toLowerCase()) ||
                (employee.email != null &&
                    employee.email!.toLowerCase() ==
                        trimmedInputUsername.toLowerCase());
            if (employee.role == EmployeeRole.admin && matchesIdentifier) {
              matchedAdmin = employee;
              break;
            }
          }

          // Fallback to the first admin record if we still didn't find a direct match
          if (matchedAdmin == null) {
            for (final employee in allEmployees) {
              if (employee.role == EmployeeRole.admin) {
                matchedAdmin = employee;
                break;
              }
            }
          }

          adminUser = matchedAdmin;
        }

        // If an admin employee record still doesn't exist (legacy installs), create one now
        if (adminUser == null) {
          try {
            final newEmployeeId = await _databaseService.createEmployee(
              name: 'Admin',
              username: trimmedInputUsername,
              phone: settings['business_phone'] ?? '',
              role: 'admin',
              employeeId: 'ADMIN001',
              password: upgradedAdminPassword ?? adminPassword,
              canLogin: true,
            );
            adminUser = await _databaseService.getEmployeeById(newEmployeeId);
          } catch (_) {
            // If creation fails, fall back to an in-memory admin user
          }
        }

        adminUser ??= EmployeeModel(
          id: null,
          name: 'Admin',
          username: trimmedInputUsername,
          email:
              trimmedInputUsername.contains('@') ? trimmedInputUsername : null,
          phone: settings['business_phone'] ?? '',
          role: EmployeeRole.admin,
          employeeId: 'ADMIN001',
          hireDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        if (upgradedAdminPassword != null && adminUser.id != null) {
          adminUser = adminUser.copyWith(
            password: upgradedAdminPassword,
            updatedAt: DateTime.now(),
          );
          await _databaseService.updateEmployee(adminUser);
        }

        final enrichedAdminUser = await _withRolePermissions(adminUser);

        state = state.copyWith(
          isAuthenticated: true,
          currentUser: enrichedAdminUser,
          isLoading: false,
        );
        return;
      }

      // Check if it's an employee login (support both username and email for old users)
      // Always fetch fresh employee data to avoid stale cache
      final employees = await _databaseService.getAllEmployees();
      final employee = employees.where(
        (emp) {
          // Check if employee can be logged in with the provided identifier (username or email)
          if (!emp.canLoginWith(username)) {
            return false;
          }

          // Check if password matches (password can be null for employees without login access)
          if (emp.password == null ||
              !PasswordHasher.verify(password, emp.password!)) {
            return false;
          }

          return true;
        },
      ).firstOrNull;

      if (employee == null) {
        throw Exception('Invalid username or password');
      }

      if (!employee.isActive) {
        throw Exception('Account is deactivated');
      }

      if (!employee.canLogin) {
        throw Exception('Login access is not enabled for this employee');
      }
      var authenticatedEmployee = employee;
      if (employee.password != null &&
          PasswordHasher.isLegacyHash(employee.password!)) {
        authenticatedEmployee = employee.copyWith(
          password: PasswordHasher.hash(password),
          updatedAt: DateTime.now(),
        );
        await _databaseService.updateEmployee(authenticatedEmployee);
      }
      final enrichedEmployee =
          await _withRolePermissions(authenticatedEmployee);

      state = state.copyWith(
        isAuthenticated: true,
        currentUser: enrichedEmployee,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        currentUser: null,
        isLoading: false,
      );
      rethrow;
    }
  }

  Future<void> completeBusinessSetup({
    required String businessName,
    required String address,
    required String phone,
    required String currencyCode,
    required String currencySymbol,
    required String adminUsername,
    required String adminPassword,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await _databaseService.setSetting('business_name', businessName);
      await _databaseService.setSetting('business_address', address);
      await _databaseService.setSetting('business_phone', phone);
      await _databaseService.setSetting('currency_code', currencyCode);
      await _databaseService.setSetting('currency_symbol', currencySymbol);
      await _databaseService.setSetting('admin_username', adminUsername);
      // Hash the admin password before storing
      final hashedPassword = _hashPassword(adminPassword);
      await _databaseService.setSetting('admin_password', hashedPassword);
      await _databaseService.setSetting('business_setup_complete', 'true');

      // Create default admin employee
      await _databaseService.createEmployee(
        name: 'Admin',
        username: adminUsername,
        phone: phone,
        role: 'admin',
        employeeId: 'ADMIN001',
        password: hashedPassword,
      );

      // Create admin user for current session
      final adminUser = EmployeeModel(
        name: 'Admin',
        username: adminUsername,
        phone: phone,
        role: EmployeeRole.admin,
        employeeId: 'ADMIN001',
        hireDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final enrichedAdminUser = await _withRolePermissions(adminUser);

      state = state.copyWith(
        isBusinessSetup: true,
        isAuthenticated: true,
        businessName: businessName,
        adminUsername: adminUsername,
        currentUser: enrichedAdminUser,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isBusinessSetup: false,
        isAuthenticated: false,
        isLoading: false,
      );
      rethrow;
    }
  }

  Future<EmployeeModel> _withRolePermissions(EmployeeModel user) async {
    if (user.isAdmin) {
      final perms =
          RolePermissionService.defaultPermissionsFor(EmployeeRole.admin);
      return user.copyWith(permissions: perms);
    }

    final rolePerms = await RolePermissionService.loadPermissions(user.role);
    final merged = Map<String, bool>.from(rolePerms);
    user.permissions.forEach((key, value) {
      merged[key] = value;
    });
    return user.copyWith(permissions: merged);
  }

  void logout() {
    // Clear the authenticated user, then reload business metadata only.
    state = AuthState(
      isBusinessSetup: state.isBusinessSetup,
      businessName: state.businessName,
      adminUsername: state.adminUsername,
    );
    _checkAuthStatus();
  }

  Future<void> refresh() async {
    await _checkAuthStatus();
  }

  // Update admin profile (username and password)
  Future<void> updateAdminProfile(String newUsername, String currentPassword,
      {String? newPassword}) async {
    state = state.copyWith(isLoading: true);

    try {
      final settings = await _databaseService.getSettings();
      final currentAdminUsername = settings['admin_username'];
      final currentAdminPassword = settings['admin_password'];
      // Verify current password
      if (currentAdminPassword == null ||
          !PasswordHasher.verify(currentPassword, currentAdminPassword)) {
        throw Exception('Current password is incorrect');
      }

      // Update username
      await _databaseService.setSetting('admin_username', newUsername);

      // Update password if provided
      if (newPassword != null && newPassword.isNotEmpty) {
        final hashedNewPassword = _hashPassword(newPassword);
        await _databaseService.setSetting('admin_password', hashedNewPassword);
      }

      // Update admin employee record if exists
      final employees = await _databaseService.getAllEmployees();
      final adminEmployee = employees.firstWhere(
        (emp) => emp.employeeId == 'ADMIN001',
        orElse: () => throw Exception('Admin employee not found'),
      );

      final updatedPassword = newPassword != null && newPassword.isNotEmpty
          ? _hashPassword(newPassword)
          : currentAdminPassword;

      // Update the admin employee in database
      await _databaseService.updateEmployee(adminEmployee.copyWith(
        username: newUsername,
        password: updatedPassword,
        updatedAt: DateTime.now(),
      ));

      // Update current user
      final updatedAdminUser = adminEmployee.copyWith(
        username: newUsername,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        adminUsername: newUsername,
        currentUser: updatedAdminUser,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return AuthNotifier(databaseService);
});
