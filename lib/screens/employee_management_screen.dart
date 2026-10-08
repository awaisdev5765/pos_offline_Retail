import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../widgets/app_snack_bar.dart';
import '../utils/password_hasher.dart';

class EmployeeManagementScreen extends ConsumerStatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  ConsumerState<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState
    extends ConsumerState<EmployeeManagementScreen> {
  bool _loading = true;
  String _query = '';
  List<EmployeeModel> _employees = <EmployeeModel>[];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(databaseServiceProvider);
      final list = await db.getAllEmployees();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() => _employees = list);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text('Failed to load employees: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _hashPassword(String value) => PasswordHasher.hash(value);

  String _generateEmployeeId(EmployeeRole role, List<EmployeeModel> all) {
    final prefix = switch (role) {
      EmployeeRole.admin => 'ADM',
      EmployeeRole.manager => 'MGR',
      EmployeeRole.cashier => 'CSH',
      EmployeeRole.staff => 'STF',
    };
    final maxNum = all
        .where((e) => e.employeeId.startsWith(prefix))
        .map((e) =>
            int.tryParse(e.employeeId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .fold<int>(0, (prev, n) => n > prev ? n : prev);
    return '$prefix${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _showEmployeeDialog({EmployeeModel? existing}) async {
    final all = List<EmployeeModel>.from(_employees);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final usernameCtrl = TextEditingController(text: existing?.username ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final employeeIdCtrl = TextEditingController(
      text:
          existing?.employeeId ?? _generateEmployeeId(EmployeeRole.staff, all),
    );
    final passwordCtrl = TextEditingController();

    EmployeeRole role = existing?.role ?? EmployeeRole.staff;
    bool canLogin = existing?.canLogin ?? true;
    bool isActive = existing?.isActive ?? true;
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Employee' : 'Add Employee'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Full name'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: usernameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Username (for login)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: employeeIdCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Employee ID'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<EmployeeRole>(
                        value: role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: EmployeeRole.values
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.name.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setLocal(() {
                            role = value;
                            if (!isEdit) {
                              employeeIdCtrl.text =
                                  _generateEmployeeId(role, all);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Can Login'),
                        value: canLogin,
                        onChanged: (v) => setLocal(() => canLogin = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (v) => setLocal(() => isActive = v),
                      ),
                      if (canLogin) ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: passwordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: isEdit
                                ? 'New password (leave empty to keep)'
                                : 'Password',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: Text('common.cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final username = usernameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          final employeeId =
                              employeeIdCtrl.text.trim().toUpperCase();
                          final password = passwordCtrl.text;

                          if (name.isEmpty ||
                              username.isEmpty ||
                              phone.isEmpty ||
                              employeeId.isEmpty) {
                            AppSnackBar.show(
                              context,
                              const SnackBar(
                                  content:
                                      Text('Please fill all required fields')),
                            );
                            return;
                          }
                          if (canLogin && !isEdit && password.isEmpty) {
                            AppSnackBar.show(
                              context,
                              const SnackBar(
                                  content:
                                      Text('Password is required for login')),
                            );
                            return;
                          }

                          final duplicateUsername = all.any((e) =>
                              e.id != existing?.id &&
                              (e.username?.toLowerCase() ==
                                  username.toLowerCase()));
                          if (duplicateUsername) {
                            AppSnackBar.show(
                              context,
                              const SnackBar(
                                  content: Text('Username already exists')),
                            );
                            return;
                          }

                          final duplicateId = all.any((e) =>
                              e.id != existing?.id &&
                              e.employeeId.toUpperCase() == employeeId);
                          if (duplicateId) {
                            AppSnackBar.show(
                              context,
                              const SnackBar(
                                  content: Text('Employee ID already exists')),
                            );
                            return;
                          }

                          setLocal(() => saving = true);
                          try {
                            final db = ref.read(databaseServiceProvider);
                            if (!isEdit) {
                              await db.createEmployee(
                                name: name,
                                username: username,
                                phone: phone,
                                role: role.name,
                                employeeId: employeeId,
                                password:
                                    canLogin ? _hashPassword(password) : null,
                                canLogin: canLogin,
                                permissions: '',
                              );
                            } else {
                              final updated = existing!.copyWith(
                                name: name,
                                username: username,
                                phone: phone,
                                role: role,
                                employeeId: employeeId,
                                canLogin: canLogin,
                                isActive: isActive,
                                password: password.isEmpty
                                    ? existing.password
                                    : _hashPassword(password),
                                updatedAt: DateTime.now(),
                              );
                              await db.updateEmployee(updated);
                            }
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            await _loadEmployees();
                            AppSnackBar.show(
                              context,
                              SnackBar(
                                content: Text(isEdit
                                    ? 'Employee updated successfully'
                                    : 'Employee created successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            AppSnackBar.show(
                              context,
                              SnackBar(
                                content: Text('Failed to save employee: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            if (ctx.mounted) setLocal(() => saving = false);
                          }
                        },
                  child: Text(isEdit ? 'Update' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleActive(EmployeeModel employee) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateEmployee(employee.copyWith(
        isActive: !employee.isActive,
        updatedAt: DateTime.now(),
      ));
      await _loadEmployees();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).currentUser;
    final canManage = currentUser != null &&
        (currentUser.isAdmin ||
            currentUser.permissions['manage_employees'] == true);

    if (!canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Employee Management')),
        body: const Center(
          child: Text(
              'Access denied. Only admin/authorized users can manage employees.'),
        ),
      );
    }

    final filtered = _employees.where((e) {
      final q = _query.toLowerCase();
      return q.isEmpty ||
          e.name.toLowerCase().contains(q) ||
          (e.username ?? '').toLowerCase().contains(q) ||
          e.employeeId.toLowerCase().contains(q) ||
          e.role.name.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEmployeeDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search employee by name, username, id, role',
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(e.name.isNotEmpty
                              ? e.name[0].toUpperCase()
                              : '?'),
                        ),
                        title: Text('${e.name} (${e.role.name.toUpperCase()})'),
                        subtitle: Text(
                          'User: ${e.username ?? '-'} | ID: ${e.employeeId} | '
                          'Login: ${e.canLogin ? "Yes" : "No"} | '
                          'Status: ${e.isActive ? "Active" : "Inactive"}',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => _showEmployeeDialog(existing: e),
                              icon: const Icon(Icons.edit),
                            ),
                            IconButton(
                              tooltip: e.isActive ? 'Deactivate' : 'Activate',
                              onPressed: () => _toggleActive(e),
                              icon: Icon(
                                e.isActive ? Icons.block : Icons.check_circle,
                                color:
                                    e.isActive ? Colors.orange : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
