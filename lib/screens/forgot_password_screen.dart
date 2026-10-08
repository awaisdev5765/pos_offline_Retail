import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../models/employee.dart';
import '../router/app_router.dart';
import '../widgets/app_snack_bar.dart';
import '../utils/password_hasher.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _answerController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();

  bool _answerVerified = false;
  bool _isVerifying = false;
  bool _isUpdatingPassword = false;

  @override
  void dispose() {
    _answerController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('forgot.title'.tr()),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'forgot.headline'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'forgot.intro'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                _buildSecurityQuestionCard(isDarkMode),
                if (_answerVerified) ...[
                  const SizedBox(height: 24),
                  _buildPasswordResetCard(isDarkMode),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityQuestionCard(bool isDarkMode) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded,
                    color: isDarkMode ? Colors.white : AppColors.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'forgot.security_question'.tr(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'forgot.book_question'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _answerController,
              decoration: InputDecoration(
                hintText: 'forgot.answer_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
              enabled: !_answerVerified,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _answerVerified || _isVerifying ? null : _verifyAnswer,
                icon: _isVerifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.verified_user_outlined),
                label: Text(_answerVerified
                    ? 'forgot.verified'.tr()
                    : 'forgot.verify'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordResetCard(bool isDarkMode) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _passwordFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.password_rounded,
                      color:
                          isDarkMode ? Colors.white : AppColors.primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Set New Admin Password',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm the password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdatingPassword ? null : _updatePassword,
                  icon: _isUpdatingPassword
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                      _isUpdatingPassword ? 'Updating...' : 'Update Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verifyAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      _showMessage('Please enter your favourite book.');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final database = ref.read(databaseServiceProvider);
      final settings = await database.getSettings();
      final storedHash = settings['security_answer_favorite_book'];

      if (storedHash == null || storedHash.isEmpty) {
        _showMessage(
            'Security question is not configured. Please contact your administrator.');
        return;
      }

      if (PasswordHasher.verify(
          _answerController.text.trim().toLowerCase(), storedHash)) {
        setState(() {
          _answerVerified = true;
        });
        _showMessage('Answer verified. Please set a new password.',
            success: true);
      } else {
        _showMessage('Incorrect answer. Please try again.');
      }
    } catch (e) {
      _showMessage('Failed to verify answer: $e');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isUpdatingPassword = true);

    try {
      final newPassword = _newPasswordController.text;
      final hashedPassword = _hashPassword(newPassword);

      final database = ref.read(databaseServiceProvider);
      final settings = await database.getSettings();
      await database.setSetting('admin_password', hashedPassword);

      final employees = await database.getAllEmployees();
      EmployeeModel? adminEmployee;
      for (final employee in employees) {
        if (employee.employeeId == 'ADMIN001') {
          adminEmployee = employee;
          break;
        }
      }
      if (adminEmployee == null) {
        for (final employee in employees) {
          if (employee.role == EmployeeRole.admin) {
            adminEmployee = employee;
            break;
          }
        }
      }

      final adminUsername =
          settings['admin_username'] ?? settings['admin_email'] ?? 'admin';
      final adminPhone = settings['business_phone'] ?? '';

      if (adminEmployee == null || adminEmployee.id == null) {
        await database.createEmployee(
          name: adminEmployee?.name ?? 'Admin',
          username: adminUsername,
          phone: adminPhone,
          role: 'admin',
          employeeId: 'ADMIN001',
          password: hashedPassword,
        );
      } else {
        await database.updateEmployee(
          adminEmployee.copyWith(
            username: adminUsername,
            phone: adminPhone,
            password: hashedPassword,
            updatedAt: DateTime.now(),
          ),
        );
      }

      await ref.read(authProvider.notifier).refresh();

      if (mounted) {
        _showMessage(
            'Password updated successfully. Please log in with the new password.',
            success: true);
        context.go(AppRouter.login);
      }
    } catch (e) {
      _showMessage('Failed to update password: $e');
    } finally {
      setState(() => _isUpdatingPassword = false);
    }
  }

  String _hashPassword(String password) {
    return PasswordHasher.hash(password);
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    AppSnackBar.show(
      context,
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? AppColors.successColor : AppColors.errorColor,
      ),
    );
  }
}
