import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/currency.dart';
import '../services/database_service.dart';
import '../providers/auth_provider.dart';
import '../services/device_identity_service.dart';
import '../services/multi_pc_bootstrapper.dart';
import '../utils/password_hasher.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/searchable_currency_picker.dart';

class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  ConsumerState<BusinessSetupScreen> createState() =>
      _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _adminUsernameController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _securityAnswerController = TextEditingController();

  Currency? _selectedCurrency;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _businessNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    _confirmPasswordController.dispose();
    _securityAnswerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _hashPassword(String password) {
    return PasswordHasher.hash(password);
  }

  String _hashSecurityAnswer(String answer) {
    return _hashPassword(answer.trim().toLowerCase());
  }

  Future<void> _saveBusinessSetup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCurrency == null) {
      AppSnackBar.show(
        context,
        SnackBar(content: Text('business_setup.snack_select_currency'.tr())),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final database = ref.read(databaseServiceProvider);

      // Ensure database is properly initialized by checking if we can query settings
      try {
        await database.getSettings();
      } catch (dbInitError) {
        print('Database initialization check failed: $dbInitError');
        // Database might need to be recreated - let the error propagate
        throw Exception('business_setup.err_db_init'.tr());
      }

      // Save business settings - ensure all values are trimmed
      final trimmedBusinessName = _businessNameController.text.trim();
      final trimmedAddress = _addressController.text.trim();
      final trimmedPhone = _phoneController.text.trim();
      final trimmedUsername = _adminUsernameController.text.trim();
      final trimmedPassword = _adminPasswordController.text.trim();
      final securityAnswer = _securityAnswerController.text.trim();

      // Validate that username is not empty
      if (trimmedUsername.isEmpty) {
        throw Exception('business_setup.err_username_empty'.tr());
      }

      // Validate that password is not empty
      if (trimmedPassword.isEmpty) {
        throw Exception('business_setup.err_password_empty'.tr());
      }

      if (securityAnswer.isEmpty) {
        throw Exception('business_setup.err_security_empty'.tr());
      }

      await database.setSetting('business_name', trimmedBusinessName);
      await database.setSetting('business_address', trimmedAddress);
      await database.setSetting('business_phone', trimmedPhone);
      await database.setSetting('currency_code', _selectedCurrency!.code);
      await database.setSetting('currency_symbol', _selectedCurrency!.symbol);
      // Save admin_username and also save as admin_email if it looks like an email (for backward compatibility)
      await database.setSetting('admin_username', trimmedUsername);
      if (trimmedUsername.contains('@')) {
        // Also save as admin_email for backward compatibility
        await database.setSetting('admin_email', trimmedUsername);
      }
      await database.setSetting(
          'admin_password', _hashPassword(trimmedPassword));
      await database.setSetting(
          'security_answer_favorite_book', _hashSecurityAnswer(securityAnswer));

      // Create default admin employee - check if it already exists first
      // Check by both username and employeeId to handle old users with email only
      try {
        final trimmedUsername = _adminUsernameController.text.trim();
        final trimmedPhone = _phoneController.text.trim();
        final hashedPassword =
            _hashPassword(_adminPasswordController.text.trim());

        final allEmployees = await database.getAllEmployees();
        final existingAdmin = allEmployees
            .where((emp) =>
                emp.employeeId == 'ADMIN001' ||
                (emp.username != null &&
                    emp.username!.toLowerCase() ==
                        trimmedUsername.toLowerCase()) ||
                (emp.email != null &&
                    emp.email!.toLowerCase() == trimmedUsername.toLowerCase()))
            .firstOrNull;

        if (existingAdmin == null) {
          // Create new admin employee
          await database.createEmployee(
            name: 'Admin',
            username: trimmedUsername,
            phone: trimmedPhone,
            role: 'admin',
            employeeId: 'ADMIN001',
            password: hashedPassword,
          );
        } else {
          // Update existing admin with new username/password
          // Preserve email for old users if username doesn't contain @
          final updatedAdmin = existingAdmin.copyWith(
            username: trimmedUsername,
            // If username is email-like, set email too. Otherwise preserve old email
            email: trimmedUsername.contains('@')
                ? trimmedUsername
                : (existingAdmin.email ?? trimmedUsername),
            password: hashedPassword,
            phone: trimmedPhone,
            updatedAt: DateTime.now(),
          );
          await database.updateEmployee(updatedAdmin);
        }
      } catch (employeeError) {
        print('Error creating/updating admin employee: $employeeError');
        // Re-throw the error so user knows what went wrong
        throw Exception('business_setup.err_admin_employee'
            .tr(namedArgs: {'error': '$employeeError'}));
      }

      // Set business_setup_complete flag AFTER all other settings are saved
      await database.setSetting('business_setup_complete', 'true');

      // Verify the setting was saved by reading it back
      final settings = await database.getSettings();
      final setupComplete = settings['business_setup_complete'] == 'true';

      if (!setupComplete) {
        throw Exception('business_setup.err_save_status'.tr());
      }

      // Mark this device as the admin device and start advertising so other PCs can discover it.
      try {
        await DeviceIdentityService.markAsAdminDevice(
          displayName: trimmedBusinessName.isEmpty ? null : trimmedBusinessName,
        );
        await MultiPcBootstrapper()
            .bootstrap(database, timeout: const Duration(seconds: 2));
      } catch (deviceError) {
        print(
            'Warning: failed to initialize admin server automatically: $deviceError');
      }

      // Refresh auth state to ensure it's updated before navigation
      // This is critical on Windows to prevent crashes
      try {
        await ref.read(authProvider.notifier).refresh();
        // Wait a bit more to ensure state propagation (important for Windows stability)
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (authError) {
        print('Error refreshing auth state: $authError');
        // Continue anyway - auth state will be checked on next load
      }

      // Show success message and navigate
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('business_setup.success'.tr()),
            backgroundColor: Colors.green,
          ),
        );

        // Longer delay to ensure all database writes are flushed and state is ready
        await Future.delayed(const Duration(milliseconds: 500));

        // Set loading to false before navigation to avoid setState after dispose
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        // Additional delay to ensure setState completes
        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          // Navigate to login (not dashboard) since user needs to login
          context.go('/login');
        }
      }
    } catch (e, stackTrace) {
      print('Business setup error: $e');
      print('Stack trace: $stackTrace');

      // Set loading to false before showing error
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage = e.toString();
        // Clean up error message
        if (errorMessage.contains('Exception: ')) {
          errorMessage = errorMessage.replaceFirst('Exception: ', '');
        }

        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('business_setup.error_with_message'
                .tr(namedArgs: {'message': errorMessage})),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'business_setup.title'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            fontSize: isMobile ? 18 : 20,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: (isDark ? colorScheme.surface : Colors.white)
                  .withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildGlassBackground(colorScheme, isDark)),
          SafeArea(
            child: Form(
              key: _formKey,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Header Section
                        _buildHeaderSection(colorScheme, isDark, isMobile),

                        SizedBox(height: isMobile ? 20 : 32),

                        // Business Information Card
                        _buildBusinessInfoCard(colorScheme, isDark, isMobile),

                        SizedBox(height: isMobile ? 16 : 24),

                        // Admin Account Card
                        _buildAdminAccountCard(colorScheme, isDark, isMobile),

                        SizedBox(height: isMobile ? 20 : 32),

                        // Submit Button
                        _buildSubmitButton(colorScheme, isMobile),

                        SizedBox(height: isMobile ? 16 : 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Soft gradient wash with a few large blurred color blobs so the glass
  /// cards have something translucent to show through.
  Widget _buildGlassBackground(ColorScheme colorScheme, bool isDark) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0B1220),
                  const Color(0xFF111827),
                  const Color(0xFF0F172A),
                ]
              : [
                  const Color(0xFFEFF4FF),
                  const Color(0xFFF7F7FB),
                  const Color(0xFFF1F5FF),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -60,
            child: _buildBlurBlob(
              color:
                  colorScheme.primary.withValues(alpha: isDark ? 0.28 : 0.30),
              size: 260,
            ),
          ),
          Positioned(
            top: 120,
            right: -100,
            child: _buildBlurBlob(
              color:
                  colorScheme.secondary.withValues(alpha: isDark ? 0.22 : 0.22),
              size: 300,
            ),
          ),
          Positioned(
            bottom: -120,
            left: -40,
            child: _buildBlurBlob(
              color: colorScheme.tertiary.withValues(alpha: isDark ? 0.2 : 0.2),
              size: 320,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurBlob({required Color color, required double size}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  /// Frosted-glass panel: blurred backdrop + translucent fill so the
  /// gradient/blobs behind the form remain visible through every card.
  Widget _glassCard({
    required Widget child,
    required EdgeInsets padding,
    required bool isDark,
    double radius = 16,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1E293B) : Colors.white)
                .withValues(alpha: isDark ? 0.45 : 0.55),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.white)
                  .withValues(alpha: isDark ? 0.08 : 0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeaderSection(
      ColorScheme colorScheme, bool isDark, bool isMobile) {
    return _glassCard(
      isDark: isDark,
      radius: isMobile ? 12 : 16,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.business_center_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'business_setup.header'.tr(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'business_setup.subtitle'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.business_center_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'business_setup.header'.tr(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'business_setup.subtitle'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBusinessInfoCard(
      ColorScheme colorScheme, bool isDark, bool isMobile) {
    return _glassCard(
      isDark: isDark,
      radius: isMobile ? 12 : 16,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: isMobile ? 18 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'business_setup.section_business'.tr(),
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),
          _buildModernTextField(
            controller: _businessNameController,
            label: 'business_setup.business_name'.tr(),
            hint: 'business_setup.business_name_hint'.tr(),
            icon: Icons.business_rounded,
            colorScheme: colorScheme,
            isDark: isDark,
            isMobile: isMobile,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'business_setup.business_name_required'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),
          _buildModernTextField(
            controller: _addressController,
            label: 'business_setup.business_address'.tr(),
            hint: 'business_setup.business_address_hint'.tr(),
            icon: Icons.location_on_rounded,
            colorScheme: colorScheme,
            isDark: isDark,
            isMobile: isMobile,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'business_setup.business_address_required'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),
          _buildModernTextField(
            controller: _phoneController,
            label: 'business_setup.phone'.tr(),
            hint: 'business_setup.phone_hint'.tr(),
            icon: Icons.phone_rounded,
            colorScheme: colorScheme,
            isDark: isDark,
            isMobile: isMobile,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'business_setup.phone_required'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),
          _buildModernCurrencySelector(colorScheme, isDark, isMobile),
        ],
      ),
    );
  }

  Widget _buildAdminAccountCard(
      ColorScheme colorScheme, bool isDark, bool isMobile) {
    return _glassCard(
      isDark: isDark,
      radius: isMobile ? 12 : 16,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                ),
                child: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: colorScheme.onSecondaryContainer,
                  size: isMobile ? 18 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'business_setup.section_admin'.tr(),
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),
          _buildModernTextField(
            controller: _adminUsernameController,
            label: 'business_setup.admin_username'.tr(),
            hint: 'business_setup.admin_username_hint'.tr(),
            icon: Icons.person_rounded,
            colorScheme: colorScheme,
            isDark: isDark,
            isMobile: isMobile,
            keyboardType: TextInputType.text,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'business_setup.admin_username_required'.tr();
              }
              if (value.trim().length < 3) {
                return 'business_setup.username_min'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),
          _buildModernTextField(
            controller: _adminPasswordController,
            label: 'business_setup.admin_password'.tr(),
            hint: 'business_setup.admin_password_hint'.tr(),
            icon: Icons.lock_rounded,
            colorScheme: colorScheme,
            isDark: isDark,
            isMobile: isMobile,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: isMobile ? 18 : 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'business_setup.password_required'.tr();
              }
              if (value.length < 6) {
                return 'business_setup.password_min'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),
          _buildModernTextField(
            controller: _confirmPasswordController,
            label: 'business_setup.confirm_password'.tr(),
            hint: 'business_setup.confirm_password_hint'.tr(),
            icon: Icons.lock_outline_rounded,
            colorScheme: colorScheme,
            isDark: isDark,
            isMobile: isMobile,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: isMobile ? 18 : 20,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'business_setup.confirm_required'.tr();
              }
              if (value != _adminPasswordController.text) {
                return 'business_setup.passwords_mismatch'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),
          _buildModernTextField(
            controller: _securityAnswerController,
            label: 'business_setup.security_book'.tr(),
            hint: 'business_setup.security_book_hint'.tr(),
            icon: Icons.menu_book_rounded,
            colorScheme: colorScheme,
            isDark: isDark,
            isMobile: isMobile,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'business_setup.security_answer_required'.tr();
              }
              if (value.trim().length < 3) {
                return 'business_setup.security_answer_min'.tr();
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ColorScheme colorScheme,
    required bool isDark,
    required bool isMobile,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.9),
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(
            fontSize: isMobile ? 16 : 15,
            color: colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: isMobile ? 16 : 15,
            ),
            prefixIcon: Icon(
              icon,
              size: isMobile ? 22 : 20,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            suffixIcon: suffixIcon != null
                ? IconTheme(
                    data: IconThemeData(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      size: isMobile ? 22 : 20,
                    ),
                    child: suffixIcon,
                  )
                : null,
            filled: true,
            fillColor: isDark
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              borderSide: BorderSide(
                color: colorScheme.error,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              borderSide: BorderSide(
                color: colorScheme.error,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 16,
              vertical: isMobile ? 18 : 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernCurrencySelector(
      ColorScheme colorScheme, bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'business_setup.currency'.tr(),
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.9),
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
            onTap: () async {
              final picked = await showSearchableCurrencyPicker(
                context,
                selected: _selectedCurrency,
              );
              if (picked != null && mounted) {
                setState(() => _selectedCurrency = picked);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                border: Border.all(
                  color: _selectedCurrency == null
                      ? colorScheme.error.withValues(alpha: 0.5)
                      : colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isMobile ? 12 : 10,
              ),
              child: Row(
                children: [
                  if (_selectedCurrency != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selectedCurrency!.symbol,
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 10 : 12),
                    Text(
                      _selectedCurrency!.code,
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 15,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(width: isMobile ? 6 : 8),
                    Expanded(
                      child: Text(
                        _selectedCurrency!.name,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: isMobile ? 15 : 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        'business_setup.select_currency_title'.tr(),
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: isMobile ? 16 : 15,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    size: isMobile ? 24 : 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_selectedCurrency == null)
          Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: isMobile ? 16 : 14,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  'business_setup.select_currency_prompt'.tr(),
                  style: TextStyle(
                    color: colorScheme.error,
                    fontSize: isMobile ? 13 : 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitButton(ColorScheme colorScheme, bool isMobile) {
    return SizedBox(
      width: double.infinity,
      height: isMobile ? 52 : 56,
      child: FilledButton(
        onPressed: _isLoading ? null : _saveBusinessSetup,
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
          ),
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 32),
        ),
        child: _isLoading
            ? SizedBox(
                width: isMobile ? 22 : 24,
                height: isMobile ? 22 : 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: isMobile ? 22 : 20,
                  ),
                  SizedBox(width: isMobile ? 10 : 12),
                  Text(
                    'business_setup.complete_setup'.tr(),
                    style: TextStyle(
                      fontSize: isMobile ? 17 : 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
