import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/network_provider.dart';
import '../services/database_service.dart' show databaseServiceProvider;
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack_bar.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // FocusNodes for Enter key navigation (Windows-style)
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // Helper method to launch WhatsApp
  Future<void> _launchWhatsApp() async {
    const phoneNumber = '+923312544969';
    const message = 'Hello! I need support with the Offline POS System.';
    final whatsappUrl =
        'https://wa.me/${phoneNumber.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}';

    try {
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to showing the number
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('login.whatsapp_fallback'.tr()),
              backgroundColor: const Color(0xFF25D366),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('login.whatsapp_fallback'.tr()),
            backgroundColor: const Color(0xFF25D366),
          ),
        );
      }
    }
  }

  // Helper method to launch email
  Future<void> _launchEmail() async {
    const email = 'awaisdev5765@gmail.com';
    const subject = 'Support Request - Offline POS System';
    const body =
        'Hello,\n\nI need support with the Offline POS System.\n\nPlease provide assistance.\n\nThank you.';

    try {
      final uri = Uri(
        scheme: 'mailto',
        path: email,
        query:
            'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback to showing the email
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('login.email_fallback'.tr()),
              backgroundColor: AppColors.primaryColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('login.email_fallback'.tr()),
            backgroundColor: AppColors.primaryColor,
          ),
        );
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final databaseService = ref.read(databaseServiceProvider);
      final syncService = ref.read(databaseSyncProvider);

      // If connected to admin PC, ensure sync is complete before login
      if (syncService.isConnected && !syncService.isServer) {
        // Wait a bit to ensure sync completed
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify employees are synced (if connected to admin, we should have employees)
        try {
          final employees = await databaseService.getAllEmployees();
          if (employees.isEmpty) {
            // Wait a bit more for sync to complete
            print('⏳ Waiting for employee data to sync...');
            await Future.delayed(const Duration(seconds: 2));

            // Check again
            final employeesRetry = await databaseService.getAllEmployees();
            if (employeesRetry.isEmpty) {
              throw Exception(
                  'Employee data not synced yet. Please wait a moment and try again.');
            }
          }
        } catch (e) {
          print('⚠️ Error checking employees: $e');
          // Continue anyway, login might still work
        }
      }

      final authNotifier = ref.read(authProvider.notifier);

      // Use the auth provider's login method
      await authNotifier.login(
          _usernameController.text.trim(), _passwordController.text);

      // Login successful
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('login.login_success'.tr()),
            backgroundColor: AppColors.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        // Navigate based on user role
        final authState = ref.read(authProvider);
        final currentUser = authState.currentUser;

        if (currentUser != null) {
          if (currentUser.isCashier) {
            // Cashiers go directly to POS
            context.go('/pos');
          } else {
            // Admin and Manager go to dashboard
            context.go('/');
          }
        } else {
          // Fallback to dashboard
          context.go('/');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showBrandPanel = constraints.maxWidth >= 900;
            return Row(
              children: [
                if (showBrandPanel)
                  Expanded(
                    flex: 11,
                    child: _buildBrandPanel(),
                  ),
                Expanded(
                  flex: showBrandPanel ? 9 : 1,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth < 520 ? 20 : 48,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: _buildModernLoginCard(
                            isDarkMode: isDarkMode,
                            colors: colors,
                            showCompactBrand: !showBrandPanel,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.primaryGradient,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -90,
            top: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBrandMark(onDark: true),
              const Spacer(),
              const Text(
                'Run your counter with confidence.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Fast checkout, clear stock visibility, and reliable reporting — even when the internet is unavailable.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 16,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 32),
              const Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _LoginFeature(
                      icon: Icons.bolt_rounded, label: 'Fast billing'),
                  _LoginFeature(
                      icon: Icons.wifi_off_rounded, label: 'Works offline'),
                  _LoginFeature(
                      icon: Icons.shield_outlined, label: 'Secure access'),
                ],
              ),
              const Spacer(),
              Text(
                'Offline POS • Built for everyday retail',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernLoginCard({
    required bool isDarkMode,
    required ColorScheme colors,
    required bool showCompactBrand,
  }) {
    final fieldFill =
        isDarkMode ? AppColors.surfaceDark : AppColors.backgroundLight;
    final border =
        isDarkMode ? const Color(0xFF334155) : const Color(0xFFDCE3EC);

    InputDecoration decoration({
      required String label,
      required String hint,
      required IconData icon,
      Widget? suffix,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 21),
        suffixIcon: suffix,
        filled: true,
        fillColor: fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.20 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showCompactBrand) ...[
              _buildBrandMark(onDark: false),
              const SizedBox(height: 32),
            ],
            Text(
              'login.welcome_back'.tr(),
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'login.sign_in_subtitle'.tr(),
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _usernameController,
              focusNode: _usernameFocusNode,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
              decoration: decoration(
                label: 'login.username'.tr(),
                hint: 'login.username_hint'.tr(),
                icon: Icons.person_outline_rounded,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'login.username_required'.tr()
                  : null,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _login(),
              decoration: decoration(
                label: 'login.password'.tr(),
                hint: 'login.password_hint'.tr(),
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'login.password_required'.tr()
                  : null,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline,
                        color: colors.onErrorContainer, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                            color: colors.onErrorContainer, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _login,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(
                  _isLoading
                      ? 'login.signing_in'.tr()
                      : 'login.login_button'.tr(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _launchWhatsApp,
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('WhatsApp help'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _launchEmail,
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: const Text('Email support'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandMark({required bool onDark}) {
    return Semantics(
      image: true,
      label: 'Retail POS',
      child: Container(
        width: 190,
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: onDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.18))
              : Border.all(color: AppColors.borderColor),
        ),
        child: Image.asset(
          'assets/images/app_logo.png',
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );
  }

  Widget _buildLegacyLogin(BuildContext context) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;

    return Scaffold(
      body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [
                      const Color(0xFF1C2128),
                      const Color(0xFF23272F),
                      AppColors.primaryDark,
                    ]
                  : [
                      AppColors.primaryColor,
                      AppColors.primaryDark,
                      AppColors.secondaryColor,
                    ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: Stack(children: [
            // Background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _LoginBackgroundPainter(),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Enhanced Logo and Title
                      Container(
                        width: isMobile ? 90 : 120,
                        height: isMobile ? 90 : 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              Colors.white.withValues(alpha: 0.95),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(isMobile ? 22 : 30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: isMobile ? 20 : 30,
                              offset: Offset(0, isMobile ? 10 : 15),
                            ),
                            BoxShadow(
                              color:
                                  AppColors.primaryColor.withValues(alpha: 0.3),
                              blurRadius: isMobile ? 15 : 20,
                              offset: Offset(0, isMobile ? 3 : 5),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: isMobile ? 60 : 80,
                              height: isMobile ? 60 : 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primaryColor
                                        .withValues(alpha: 0.1),
                                    AppColors.secondaryColor
                                        .withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius.circular(isMobile ? 30 : 40),
                              ),
                            ),
                            Icon(
                              Icons.point_of_sale_rounded,
                              size: isMobile ? 30 : 40,
                              color: AppColors.primaryColor,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isMobile ? 24 : 40),

                      Text(
                        'login.welcome_back'.tr(),
                        style: AppTypography.hero.copyWith(
                          color: Colors.white,
                          fontSize: isMobile ? 26 : 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isMobile ? 8 : 12),

                      Text(
                        'login.sign_in_subtitle'.tr(),
                        style: AppTypography.section.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      SizedBox(height: isMobile ? 32 : 50),

                      // Enhanced Login Form
                      Container(
                        padding: EdgeInsets.all(isMobile ? 20 : AppSpacing.xl),
                        decoration: BoxDecoration(
                          color:
                              isDarkMode ? AppColors.surfaceDark : Colors.white,
                          borderRadius:
                              BorderRadius.circular(isMobile ? 16 : 20),
                          border: Border.all(
                            color: isDarkMode
                                ? AppColors.borderColor.withValues(alpha: 0.3)
                                : AppColors.borderColor.withValues(alpha: 0.1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDarkMode ? 0.4 : 0.15),
                              blurRadius: isMobile ? 20 : 30,
                              offset: Offset(0, isMobile ? 10 : 15),
                            ),
                            BoxShadow(
                              color:
                                  AppColors.primaryColor.withValues(alpha: 0.1),
                              blurRadius: isMobile ? 15 : 20,
                              offset: Offset(0, isMobile ? 3 : 5),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Username Field
                              TextFormField(
                                controller: _usernameController,
                                focusNode: _usernameFocusNode,
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    _passwordFocusNode.requestFocus(),
                                style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                  fontSize: isMobile ? 17 : 16,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'login.username'.tr(),
                                  hintText: 'login.username_hint'.tr(),
                                  labelStyle:
                                      AppTypography.cardSubtitle.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: isMobile ? 13 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  hintStyle:
                                      AppTypography.cardSubtitle.copyWith(
                                    color: AppColors.textTertiary,
                                    fontSize: isMobile ? 15 : 14,
                                  ),
                                  prefixIcon: Container(
                                    margin: EdgeInsets.all(isMobile ? 10 : 12),
                                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.person_outline,
                                      color: AppColors.primaryColor,
                                      size: isMobile ? 22 : 20,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        isMobile ? 10 : 12),
                                    borderSide: BorderSide(
                                      color: isDarkMode
                                          ? AppColors.borderColor
                                              .withValues(alpha: 0.3)
                                          : AppColors.borderColor,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        isMobile ? 10 : 12),
                                    borderSide: BorderSide(
                                      color: isDarkMode
                                          ? AppColors.borderColor
                                              .withValues(alpha: 0.3)
                                          : AppColors.borderColor,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        isMobile ? 10 : 12),
                                    borderSide: BorderSide(
                                      color: AppColors.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDarkMode
                                      ? AppColors.backgroundDark
                                      : Colors.grey[50],
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 16 : 20,
                                    vertical: isMobile ? 18 : 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'login.username_required'.tr();
                                  }
                                  return null;
                                },
                              ),

                              // Enhanced Password Field
                              TextFormField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context).unfocus();
                                  _login();
                                },
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontSize: isMobile ? 17 : 16,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'login.password'.tr(),
                                  labelStyle:
                                      AppTypography.cardSubtitle.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: isMobile ? 13 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  hintText: 'login.password_hint'.tr(),
                                  hintStyle:
                                      AppTypography.cardSubtitle.copyWith(
                                    color: AppColors.textTertiary,
                                    fontSize: isMobile ? 15 : 14,
                                  ),
                                  prefixIcon: Container(
                                    margin: EdgeInsets.all(isMobile ? 10 : 12),
                                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.lock_outline,
                                      color: AppColors.primaryColor,
                                      size: isMobile ? 22 : 20,
                                    ),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.textSecondary,
                                      size: isMobile ? 22 : 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        isMobile ? 10 : 12),
                                    borderSide: BorderSide(
                                      color: isDarkMode
                                          ? AppColors.borderColor
                                              .withValues(alpha: 0.3)
                                          : AppColors.borderColor,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        isMobile ? 10 : 12),
                                    borderSide: BorderSide(
                                      color: isDarkMode
                                          ? AppColors.borderColor
                                              .withValues(alpha: 0.3)
                                          : AppColors.borderColor,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        isMobile ? 10 : 12),
                                    borderSide: BorderSide(
                                      color: AppColors.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDarkMode
                                      ? AppColors.backgroundDark
                                      : Colors.grey[50],
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 16 : 20,
                                    vertical: isMobile ? 18 : 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'login.password_required'.tr();
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: isMobile ? 16 : 20),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => context
                                          .push(AppRouter.forgotPassword),
                                  child: Text(
                                    'login.forgot_password'.tr(),
                                    style: TextStyle(
                                      fontSize: isMobile ? 14 : 16,
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: isMobile ? 12 : AppSpacing.md),

                              // Error Message
                              if (_errorMessage != null)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.errorColor
                                          .withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.errorColor
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.error_outline,
                                          color: AppColors.errorColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: AppColors.errorColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: AppSpacing.xl),

                              // Enhanced Login Button
                              Container(
                                width: double.infinity,
                                height: isMobile ? 52 : 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primaryColor,
                                      AppColors.primaryDark,
                                    ],
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(isMobile ? 14 : 16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryColor
                                          .withValues(alpha: 0.3),
                                      blurRadius: isMobile ? 10 : 12,
                                      offset: Offset(0, isMobile ? 4 : 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          isMobile ? 14 : 16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: isMobile ? 18 : 20,
                                              height: isMobile ? 18 : 20,
                                              child:
                                                  const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            ),
                                            SizedBox(
                                                width: isMobile
                                                    ? 8
                                                    : AppSpacing.sm),
                                            Text(
                                              'login.signing_in'.tr(),
                                              style: AppTypography.cardSubtitle
                                                  .copyWith(
                                                color: Colors.white,
                                                fontSize: isMobile ? 17 : 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.login_rounded,
                                              color: Colors.white,
                                              size: isMobile ? 22 : 20,
                                            ),
                                            SizedBox(
                                                width: isMobile
                                                    ? 8
                                                    : AppSpacing.sm),
                                            Text(
                                              'login.login_button'.tr(),
                                              style: AppTypography.cardSubtitle
                                                  .copyWith(
                                                color: Colors.white,
                                                fontSize: isMobile ? 17 : 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: isMobile ? 24 : AppSpacing.xl),

                      // Professional Support Section
                      Container(
                        padding: EdgeInsets.all(isMobile ? 16 : AppSpacing.lg),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(isMobile ? 16 : 20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: isMobile ? 15 : 20,
                              offset: Offset(0, isMobile ? 6 : 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Professional Header
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : AppSpacing.md,
                                vertical: isMobile ? 8 : AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.support_agent_rounded,
                                      color: Colors.white,
                                      size: isMobile ? 18 : 20,
                                    ),
                                  ),
                                  SizedBox(width: isMobile ? 8 : AppSpacing.sm),
                                  Text(
                                    'Technical Support',
                                    style: AppTypography.section.copyWith(
                                      color: Colors.white,
                                      fontSize: isMobile ? 16 : 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: isMobile ? 12 : AppSpacing.lg),

                            // Professional Contact Cards
                            isMobile
                                ? Column(
                                    children: [
                                      // WhatsApp Support Card
                                      _buildSupportCard(
                                        icon: Icons.call,
                                        title: 'WhatsApp Support',
                                        subtitle: 'Quick Response',
                                        contact: '+92 331 2544969',
                                        color: const Color(0xFF25D366),
                                        onTap: _launchWhatsApp,
                                        isMobile: isMobile,
                                      ),
                                      SizedBox(
                                          height:
                                              isMobile ? 12 : AppSpacing.md),
                                      // Email Support Card
                                      _buildSupportCard(
                                        icon: Icons.email_rounded,
                                        title: 'Email Support',
                                        subtitle: 'Detailed Queries',
                                        contact: 'awaisdev5765@gmail.com',
                                        color: AppColors.primaryColor,
                                        onTap: _launchEmail,
                                        isMobile: isMobile,
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      // WhatsApp Support Card
                                      Expanded(
                                        child: _buildSupportCard(
                                          icon: Icons.call,
                                          title: 'WhatsApp Support',
                                          subtitle: 'Quick Response',
                                          contact: '+92 331 2544969',
                                          color: const Color(0xFF25D366),
                                          onTap: _launchWhatsApp,
                                          isMobile: isMobile,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      // Email Support Card
                                      Expanded(
                                        child: _buildSupportCard(
                                          icon: Icons.email_rounded,
                                          title: 'Email Support',
                                          subtitle: 'Detailed Queries',
                                          contact: 'awaisdev5765@gmail.com',
                                          color: AppColors.primaryColor,
                                          onTap: _launchEmail,
                                          isMobile: isMobile,
                                        ),
                                      ),
                                    ],
                                  ),

                            SizedBox(height: isMobile ? 12 : AppSpacing.lg),

                            // Professional Footer Text
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : AppSpacing.md,
                                vertical: isMobile ? 8 : AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '24/7 Professional Support',
                                    style: AppTypography.cardSubtitle.copyWith(
                                      color: Colors.white,
                                      fontSize: isMobile ? 13 : 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: isMobile ? 3 : 4),
                                  Text(
                                    'Licensed Software • Secure Transactions • Business Solutions',
                                    style: AppTypography.cardSubtitle.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      fontSize: isMobile ? 11 : 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isMobile ? 16 : AppSpacing.lg),

                      // Professional Footer
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : AppSpacing.md,
                          vertical: isMobile ? 8 : AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.business_rounded,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  size: isMobile ? 14 : 16,
                                ),
                                SizedBox(width: isMobile ? 6 : AppSpacing.xs),
                                Text(
                                  'Offline POS System',
                                  style: AppTypography.cardSubtitle.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: isMobile ? 13 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isMobile ? 3 : 4),
                            Text(
                              'Professional Point of Sale Solution',
                              style: AppTypography.cardSubtitle.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: isMobile ? 11 : 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ])),
    );
  }

  // Professional support card widget
  Widget _buildSupportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String contact,
    required Color color,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 14 : AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: isMobile ? 10 : 12,
              offset: Offset(0, isMobile ? 4 : 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 5 : 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isMobile ? 20 : 18,
                  ),
                ),
                SizedBox(width: isMobile ? 8 : AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.cardSubtitle.copyWith(
                          color: Colors.white,
                          fontSize: isMobile ? 14 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.cardSubtitle.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: isMobile ? 12 : 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 10 : AppSpacing.sm),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 10 : AppSpacing.sm,
                vertical: isMobile ? 6 : 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                contact,
                style: AppTypography.cardSubtitle.copyWith(
                  color: Colors.white,
                  fontSize: isMobile ? 13 : 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for login background pattern
class _LoginBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    // Draw geometric pattern
    for (int i = 0; i < 15; i++) {
      final x = (i * 120.0) % size.width;
      final y = (i * 100.0) % size.height;
      final radius = 30 + (i % 4) * 15;

      // Draw circles
      canvas.drawCircle(
        Offset(x, y),
        radius.toDouble(),
        paint,
      );

      // Draw rectangles
      if (i % 3 == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x + 50, y + 50),
              width: 40,
              height: 40,
            ),
            const Radius.circular(8),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginFeature extends StatelessWidget {
  const _LoginFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
