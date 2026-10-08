import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/currency.dart';
import '../models/license.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bank_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/discount_provider.dart';
import '../providers/inventory_settings_provider.dart';
import '../providers/product_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/stock_movement_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/quick_actions_provider.dart';
import '../providers/wallpaper_provider.dart';
import '../providers/dashboard_theme_provider.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/license_service.dart';
import '../services/windows_backup_service.dart';
import '../services/cloud_backup_service.dart';
import '../utils/password_hasher.dart';
import '../theme/app_theme.dart';
import '../utils/modern_dialog_builder.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/searchable_currency_picker.dart';
import '../router/app_router.dart' show navigationRefreshTriggerProvider;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsSection {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() builder;
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _adminUsernameController = TextEditingController();
  final _licenseCodeController = TextEditingController();

  bool _isDarkMode = false;
  bool _isLoading = false;
  bool _isActivatingLicense = false;
  String? _licenseActivationError;
  String? _licenseActivationSuccess;
  int _licenseRefreshKey = 0;
  Currency? _selectedCurrency;
  bool _hideStatsCards = false; // Default to showing stats cards
  bool _bundlesEnabled = false; // Default to deactivated
  int _selectedSettingsSection = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _businessPhoneController.dispose();
    _taxRateController.dispose();
    _adminUsernameController.dispose();
    _licenseCodeController.dispose();
    super.dispose();
  }

  String _effectiveLocaleCode(BuildContext context) {
    const supported = {'en', 'fr', 'ar'};
    final code = context.locale.languageCode;
    return supported.contains(code) ? code : 'en';
  }

  Future<void> _loadSettings() async {
    final databaseService = ref.read(databaseServiceProvider);

    final businessName =
        await databaseService.getSetting('business_name') ?? '';
    final businessAddress =
        await databaseService.getSetting('business_address') ?? '';
    final businessPhone =
        await databaseService.getSetting('business_phone') ?? '';
    final currencyCode =
        await databaseService.getSetting('currency_code') ?? 'INR';
    final taxRate = await databaseService.getSetting('tax_rate') ?? '0';
    final isDarkMode = await databaseService.getSetting('dark_mode') == 'true';
    final adminUsername =
        await databaseService.getSetting('admin_username') ?? '';
    final hideStatsCards =
        await databaseService.getSetting('hide_stats_cards') == 'true';
    final bundlesEnabled =
        await databaseService.getSetting('bundles_enabled') == 'true';
    final localeCode = await databaseService.getSetting('locale_code');

    // Find the currency by code
    final currency = Currency.uniqueCurrencies.firstWhere(
      (c) => c.code == currencyCode,
      orElse: () => Currency.uniqueCurrencies.first,
    );

    if (mounted) {
      setState(() {
        _businessNameController.text = businessName;
        _businessAddressController.text = businessAddress;
        _businessPhoneController.text = businessPhone;
        _taxRateController.text = taxRate;
        _isDarkMode = isDarkMode;
        _selectedCurrency = currency;
        _adminUsernameController.text = adminUsername;
        _hideStatsCards = hideStatsCards;
        _bundlesEnabled = bundlesEnabled;
      });
      if (localeCode != null &&
          localeCode.isNotEmpty &&
          const ['en', 'fr', 'ar'].contains(localeCode) &&
          mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (context.locale.languageCode != localeCode) {
            context.setLocale(Locale(localeCode));
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final sections = _settingsSections();

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 24,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'settings.title'.tr(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const Text(
                  'Manage business and application preferences',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.primaryGradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.save_outlined, size: 19),
              label: Text('settings.save_tooltip'.tr()),
              onPressed: _saveSettings,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final useSidebar = constraints.maxWidth >= 980;
                final content = AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: SingleChildScrollView(
                    key: ValueKey(_selectedSettingsSection),
                    padding: EdgeInsets.fromLTRB(
                      useSidebar ? 28 : 16,
                      20,
                      useSidebar ? 28 : 16,
                      32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: sections[_selectedSettingsSection].builder(),
                      ),
                    ),
                  ),
                );

                if (!useSidebar) {
                  return Column(
                    children: [
                      _buildMobileSettingsNavigation(sections, isDarkMode),
                      Expanded(child: content),
                    ],
                  );
                }

                return Row(
                  children: [
                    SizedBox(
                      width: 258,
                      child: _buildSettingsSidebar(sections, isDarkMode),
                    ),
                    VerticalDivider(
                      width: 1,
                      color: isDarkMode
                          ? const Color(0xFF334155)
                          : AppColors.borderColor,
                    ),
                    Expanded(child: content),
                  ],
                );
              },
            ),
    );
  }

  List<_SettingsSection> _settingsSections() => [
        _SettingsSection(
          title: 'Business profile',
          subtitle: 'Store details and administrator account',
          icon: Icons.storefront_outlined,
          builder: _buildBusinessInfoSection,
        ),
        _SettingsSection(
          title: 'Appearance & currency',
          subtitle: 'Language, theme and regional preferences',
          icon: Icons.palette_outlined,
          builder: _buildAppearanceSection,
        ),
        _SettingsSection(
          title: 'Dashboard',
          subtitle: 'Dashboard cards and display preferences',
          icon: Icons.dashboard_outlined,
          builder: _buildDashboardSettingsSection,
        ),
        _SettingsSection(
          title: 'Sales & discount',
          subtitle: 'Discount rules and sales controls',
          icon: Icons.percent_rounded,
          builder: _buildDiscountSettingsSection,
        ),
        _SettingsSection(
          title: 'Receipt & printers',
          subtitle: 'Receipt layout and Bluetooth printers',
          icon: Icons.print_outlined,
          builder: _buildReceiptPrinterManagementSection,
        ),
        _SettingsSection(
          title: 'Roles & permissions',
          subtitle: 'Control employee access',
          icon: Icons.admin_panel_settings_outlined,
          builder: _buildRolePermissionsSection,
        ),
        _SettingsSection(
          title: 'Stock management',
          subtitle: 'Inventory and bundle preferences',
          icon: Icons.inventory_2_outlined,
          builder: _buildStockManagementSection,
        ),
        _SettingsSection(
          title: 'Data & backup',
          subtitle: 'Import, export and database tools',
          icon: Icons.storage_outlined,
          builder: _buildDataManagementSection,
        ),
        _SettingsSection(
          title: 'License',
          subtitle: 'Activation and license status',
          icon: Icons.verified_user_outlined,
          builder: _buildLicenseSection,
        ),
        _SettingsSection(
          title: 'About',
          subtitle: 'Application details and support',
          icon: Icons.info_outline_rounded,
          builder: _buildAboutSection,
        ),
      ];

  Widget _buildSettingsSidebar(
      List<_SettingsSection> sections, bool isDarkMode) {
    return ColoredBox(
      color: isDarkMode ? const Color(0xFF161C25) : Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 20),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Text(
              'SETTINGS',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFF94A3B8)
                    : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          ...List.generate(sections.length, (index) {
            final section = sections[index];
            final selected = _selectedSettingsSection == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                selected: selected,
                selectedColor: AppColors.primaryColor,
                selectedTileColor:
                    AppColors.primaryColor.withValues(alpha: 0.10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                leading: Icon(section.icon, size: 21),
                title: Text(
                  section.title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                onTap: () => setState(() => _selectedSettingsSection = index),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMobileSettingsNavigation(
      List<_SettingsSection> sections, bool isDarkMode) {
    final selected = sections[_selectedSettingsSection];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : Colors.white,
        border: const Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      child: DropdownButtonFormField<int>(
        value: _selectedSettingsSection,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Settings category',
          prefixIcon: Icon(selected.icon, color: AppColors.primaryColor),
          filled: true,
          fillColor:
              isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        items: List.generate(
          sections.length,
          (index) => DropdownMenuItem(
            value: index,
            child: Text(sections[index].title),
          ),
        ),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedSettingsSection = value);
          }
        },
      ),
    );
  }

  Widget _buildBusinessInfoSection() {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.borderColor.withValues(alpha: 0.3)
              : AppColors.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.04),
            blurRadius: 12,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: AppColors.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Business Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _businessNameController,
              style: TextStyle(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Business Name',
                hintText: 'Enter your business name',
                prefixIcon:
                    const Icon(Icons.business, color: AppColors.primaryColor),
                filled: true,
                fillColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primaryColor, width: 2),
                ),
                labelStyle: TextStyle(
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : AppColors.textSecondary),
                hintStyle: TextStyle(
                    color: isDarkMode
                        ? AppColors.textTertiary
                        : AppColors.textTertiary),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _businessAddressController,
              style: TextStyle(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Business Address',
                hintText: 'Enter your business address',
                prefixIcon: const Icon(Icons.location_on,
                    color: AppColors.primaryColor),
                filled: true,
                fillColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primaryColor, width: 2),
                ),
                labelStyle: TextStyle(
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : AppColors.textSecondary),
                hintStyle: TextStyle(
                    color: isDarkMode
                        ? AppColors.textTertiary
                        : AppColors.textTertiary),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _businessPhoneController,
              style: TextStyle(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Business Phone',
                hintText: 'Enter your business phone number',
                prefixIcon:
                    const Icon(Icons.phone, color: AppColors.primaryColor),
                filled: true,
                fillColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primaryColor, width: 2),
                ),
                labelStyle: TextStyle(
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : AppColors.textSecondary),
                hintStyle: TextStyle(
                    color: isDarkMode
                        ? AppColors.textTertiary
                        : AppColors.textTertiary),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            // Admin Username
            TextFormField(
              controller: _adminUsernameController,
              style: TextStyle(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Admin Username',
                hintText: 'Admin username',
                prefixIcon:
                    const Icon(Icons.person, color: AppColors.primaryColor),
                filled: true,
                fillColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primaryColor, width: 2),
                ),
                labelStyle: TextStyle(
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : AppColors.textSecondary),
                hintStyle: TextStyle(
                    color: isDarkMode
                        ? AppColors.textTertiary
                        : AppColors.textTertiary),
              ),
            ),
            const SizedBox(height: 20),
            // Edit Profile Button
            ElevatedButton.icon(
              onPressed: _showEditProfileDialog,
              icon: const Icon(Icons.edit),
              label: Text('settings.edit_profile'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.borderColor.withValues(alpha: 0.3)
              : AppColors.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.04),
            blurRadius: 12,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.palette,
                    color: AppColors.secondaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'settings.appearance_currency'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final picked = await showSearchableCurrencyPicker(
                    context,
                    selected: _selectedCurrency,
                  );
                  if (picked == null ||
                      picked.code == _selectedCurrency?.code ||
                      !mounted) {
                    return;
                  }
                  setState(() {
                    _selectedCurrency = picked;
                  });
                  try {
                    final currencyNotifier =
                        ref.read(currencyProvider.notifier);
                    await currencyNotifier.changeCurrency(picked);

                    if (mounted) {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      if (messenger != null) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'settings.currency_changed'.tr(namedArgs: {
                                'name': picked.name,
                                'symbol': picked.symbol,
                              }),
                            ),
                            backgroundColor: AppColors.successColor,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      if (messenger != null) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'settings.currency_error'
                                  .tr(namedArgs: {'error': '$e'}),
                            ),
                            backgroundColor: AppColors.errorColor,
                          ),
                        );
                      }
                    }
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'settings.currency'.tr(),
                    hintText: 'settings.select_currency'.tr(),
                    prefixIcon: const Icon(Icons.currency_exchange,
                        color: AppColors.secondaryColor),
                    suffixIcon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor:
                        isDarkMode ? AppColors.backgroundDark : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppColors.primaryColor, width: 2),
                    ),
                    labelStyle: TextStyle(
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : AppColors.textSecondary),
                  ),
                  child: Text(
                    _selectedCurrency != null
                        ? '${_selectedCurrency!.symbol} ${_selectedCurrency!.name} (${_selectedCurrency!.code})'
                        : 'settings.select_currency'.tr(),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _effectiveLocaleCode(context),
              style: TextStyle(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'settings.language'.tr(),
                hintText: 'settings.language_hint'.tr(),
                prefixIcon:
                    const Icon(Icons.language, color: AppColors.secondaryColor),
                filled: true,
                fillColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primaryColor, width: 2),
                ),
                labelStyle: TextStyle(
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : AppColors.textSecondary),
              ),
              dropdownColor: isDarkMode ? AppColors.surfaceDark : Colors.white,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'ar', child: Text('العربية')),
              ],
              onChanged: (String? v) async {
                if (v == null) return;
                await context.setLocale(Locale(v));
                await ref.read(databaseServiceProvider).setSetting(
                      'locale_code',
                      v,
                    );
                if (context.mounted) setState(() {});
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _taxRateController,
              style: TextStyle(
                  color: isDarkMode ? Colors.white : AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'settings.default_tax_rate'.tr(),
                hintText: '0',
                prefixIcon:
                    const Icon(Icons.percent, color: AppColors.secondaryColor),
                filled: true,
                fillColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primaryColor, width: 2),
                ),
                labelStyle: TextStyle(
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : AppColors.textSecondary),
                hintStyle: TextStyle(
                    color: isDarkMode
                        ? AppColors.textTertiary
                        : AppColors.textTertiary),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.backgroundDark
                    : AppColors.hoverColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_isDarkMode
                                  ? AppColors.primaryColor
                                  : AppColors.secondaryColor)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                          color: _isDarkMode
                              ? AppColors.primaryColor
                              : AppColors.secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'settings.theme_dark'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'settings.use_dark_theme'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? AppColors.textTertiary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: _isDarkMode,
                    onChanged: (value) {
                      setState(() {
                        _isDarkMode = value;
                      });
                      // Update theme provider
                      ref
                          .read(themeModeProvider.notifier)
                          .setTheme(value ? ThemeMode.dark : ThemeMode.light);
                    },
                    activeColor: AppColors.primaryColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardSettingsSection() {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;
    final wallpaperPath = ref.watch(dashboardWallpaperProvider);
    final dashboardAppearance = ref.watch(dashboardAppearanceProvider);

    // Only show this section for admin users
    if (currentUser == null || !currentUser.isAdmin) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.borderColor.withValues(alpha: 0.3)
              : AppColors.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.04),
            blurRadius: 12,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.dashboard,
                    color: AppColors.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Dashboard Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.backgroundDark
                    : AppColors.hoverColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          Icons.bar_chart,
                          color: AppColors.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hide Stats Cards',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Hide statistics cards from dashboard (applies to all users)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? AppColors.textTertiary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: _hideStatsCards,
                    onChanged: (value) {
                      setState(() {
                        _hideStatsCards = value;
                      });
                      // Save immediately
                      _saveStatsCardsSetting(value);
                    },
                    activeColor: AppColors.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Bundles Enable/Disable Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: AppColors.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable Bundles',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Show bundles option in sidebar navigation',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? AppColors.textTertiary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _bundlesEnabled,
                  onChanged: (value) {
                    setState(() {
                      _bundlesEnabled = value;
                    });
                    // Save immediately
                    _saveBundlesSetting(value);
                  },
                  activeColor: AppColors.primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Dashboard Wallpaper',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.backgroundDark
                    : AppColors.hoverColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode
                      ? AppColors.borderColor.withValues(alpha: 0.3)
                      : AppColors.borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set a custom dashboard wallpaper (stored locally).',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? AppColors.textTertiary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          wallpaperPath ?? 'No wallpaper selected',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: kIsWeb ? null : _pickDashboardWallpaper,
                        child: Text('settings.choose_wallpaper'.tr()),
                      ),
                      if (wallpaperPath != null)
                        TextButton(
                          onPressed: _resetDashboardWallpaper,
                          child: Text('common.reset'.tr()),
                        ),
                    ],
                  ),
                  if (wallpaperPath != null &&
                      !kIsWeb &&
                      File(wallpaperPath).existsSync())
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(wallpaperPath),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Custom Dashboard Colors',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.backgroundDark
                    : AppColors.hoverColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode
                      ? AppColors.borderColor.withValues(alpha: 0.3)
                      : AppColors.borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use custom gradient for dashboard header/background',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Applies to the top banner and background when no wallpaper is set.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? AppColors.textTertiary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: dashboardAppearance.useCustomGradient,
                        onChanged: (value) => _toggleDashboardGradient(value),
                        activeColor: AppColors.primaryColor,
                      ),
                    ],
                  ),
                  if (dashboardAppearance.useCustomGradient) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            dashboardAppearance.gradientStart,
                            dashboardAppearance.gradientEnd,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.borderColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _changeDashboardGradientColor(isStart: true),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: dashboardAppearance.gradientStart,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('settings.start_color'.tr()),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _changeDashboardGradientColor(isStart: false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: dashboardAppearance.gradientEnd,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('settings.end_color'.tr()),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetDashboardGradient,
                        child: Text('settings.reset_colors'.tr()),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveBundlesSetting(bool bundlesEnabled) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      await databaseService.setSetting(
          'bundles_enabled', bundlesEnabled.toString());

      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(bundlesEnabled
                  ? 'Bundles enabled - will appear in sidebar'
                  : 'Bundles disabled - hidden from sidebar'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        // Trigger navigation refresh without invalidating auth
        ref.read(navigationRefreshTriggerProvider.notifier).state++;
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error saving setting: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveStatsCardsSetting(bool hideStatsCards) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      await databaseService.setSetting(
          'hide_stats_cards', hideStatsCards.toString());

      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(hideStatsCards
                  ? 'Stats cards hidden from dashboard'
                  : 'Stats cards shown on dashboard'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error saving setting: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickDashboardWallpaper() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Dashboard Wallpaper',
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final notifier = ref.read(dashboardWallpaperProvider.notifier);

      if (!kIsWeb && file.path != null) {
        await notifier.setWallpaperFromPath(file.path!);
      } else if (file.bytes != null) {
        await notifier.setWallpaperFromBytes(
          file.bytes!,
          fileExtension: file.extension != null ? '.${file.extension}' : null,
        );
      } else {
        throw Exception('Unable to read selected file.');
      }

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Dashboard wallpaper updated'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Failed to update wallpaper: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetDashboardWallpaper() async {
    try {
      await ref.read(dashboardWallpaperProvider.notifier).resetWallpaper();
      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Dashboard wallpaper removed'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Failed to reset wallpaper: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleDashboardGradient(bool enabled) async {
    await ref
        .read(dashboardAppearanceProvider.notifier)
        .setUseCustomGradient(enabled);
    if (mounted) {
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text(enabled
              ? 'Custom dashboard colors enabled'
              : 'Custom dashboard colors disabled'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _changeDashboardGradientColor({required bool isStart}) async {
    final current = ref.read(dashboardAppearanceProvider);
    final initialColor = isStart ? current.gradientStart : current.gradientEnd;
    final color = await _showColorPicker(initialColor);
    if (color == null) return;

    final startColor = isStart ? color : current.gradientStart;
    final endColor = isStart ? current.gradientEnd : color;

    await ref
        .read(dashboardAppearanceProvider.notifier)
        .updateGradientColors(startColor, endColor);
  }

  Future<void> _resetDashboardGradient() async {
    await ref.read(dashboardAppearanceProvider.notifier).resetToDefault();
    if (mounted) {
      AppSnackBar.show(
        context,
        const SnackBar(
          content: Text('Dashboard colors reset to default'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildQuickActionsManagementSection() {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;
    // Only Admin and Manager
    final canManage =
        currentUser?.isAdmin == true || currentUser?.isManager == true;
    if (!canManage) {
      return const SizedBox.shrink();
    }

    final quickActionsState = ref.watch(quickActionsProvider);
    final actions = quickActionsState.orderedActions;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.borderColor.withValues(alpha: 0.3)
              : AppColors.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.04),
            blurRadius: 12,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: AppColors.accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              isDarkMode ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Drag & drop to choose the order seen on the Dashboard',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? AppColors.textTertiary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 420,
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: actions.length,
                onReorder: (oldIndex, newIndex) async {
                  final currentOrder = actions.map((a) => a.id).toList();
                  if (newIndex > oldIndex) newIndex -= 1;
                  final String moved = currentOrder.removeAt(oldIndex);
                  currentOrder.insert(newIndex, moved);
                  await ref
                      .read(quickActionsProvider.notifier)
                      .setOrder(currentOrder);
                  // Immediate feedback
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  messenger?.showSnackBar(
                    const SnackBar(
                      content: Text('Quick actions order updated'),
                      duration: Duration(milliseconds: 800),
                    ),
                  );
                  setState(() {});
                },
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return ListTile(
                    key: ValueKey(action.id),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: action.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(action.icon, color: Colors.white, size: 20),
                    ),
                    title: Text(
                      action.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Position: ${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? AppColors.textTertiary
                            : AppColors.textSecondary,
                      ),
                    ),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_indicator,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : AppColors.textTertiary,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only Admin and Manager can change this order. All other roles will see the saved order.',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode
                    ? AppColors.textTertiary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Customize Button Colors',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Click on any action below to customize its button colors',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode
                    ? AppColors.textTertiary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final action = actions[index];
                  final quickActionsState = ref.watch(quickActionsProvider);
                  final customColors =
                      quickActionsState.customColors[action.id];
                  final currentColors = customColors ?? action.gradient;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.backgroundDark
                          : AppColors.hoverColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDarkMode
                            ? AppColors.borderColor.withValues(alpha: 0.3)
                            : AppColors.borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: currentColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              Icon(action.icon, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            action.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.color_lens),
                          onPressed: () => _showColorPickerDialog(
                              action.id, action.title, currentColors),
                          tooltip: 'Change Colors',
                        ),
                        if (customColors != null)
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () async {
                              await ref
                                  .read(quickActionsProvider.notifier)
                                  .resetActionColor(action.id);
                              if (mounted) {
                                AppSnackBar.show(
                                  context,
                                  const SnackBar(
                                    content: Text('Colors reset to default'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            tooltip: 'Reset to Default',
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Color?> _showColorPicker(Color initialColor) async {
    return await showDialog<Color>(
      context: context,
      builder: (context) {
        final isDarkMode = ref.watch(isDarkModeProvider);
        Color selectedColor = initialColor;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('settings.pick_color'.tr()),
              backgroundColor:
                  isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Color preview
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Material color palette
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Colors.red,
                        Colors.pink,
                        Colors.purple,
                        Colors.deepPurple,
                        Colors.indigo,
                        Colors.blue,
                        Colors.lightBlue,
                        Colors.cyan,
                        Colors.teal,
                        Colors.green,
                        Colors.lightGreen,
                        Colors.lime,
                        Colors.yellow,
                        Colors.amber,
                        Colors.orange,
                        Colors.deepOrange,
                        Colors.brown,
                        Colors.grey,
                        Colors.blueGrey,
                        Colors.black,
                      ].map((color) {
                        return GestureDetector(
                          onTap: () => setState(() => selectedColor = color),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == color
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('common.cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedColor),
                  child: Text('settings.select_color'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showColorPickerDialog(
      String actionId, String actionTitle, List<Color> currentColors) {
    Color startColor =
        currentColors.isNotEmpty ? currentColors[0] : AppColors.primaryColor;
    Color endColor =
        currentColors.length > 1 ? currentColors[1] : AppColors.primaryDark;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDarkMode = ref.watch(isDarkModeProvider);

            return AlertDialog(
              title: Text('Customize Colors: $actionTitle'),
              backgroundColor:
                  isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Preview
                  Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [startColor, endColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.preview, color: Colors.white, size: 32),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Start Color Picker
                  Text(
                    'Start Color',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: startColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final color = await _showColorPicker(startColor);
                          if (color != null) {
                            setDialogState(() => startColor = color);
                          }
                        },
                        child: Text('settings.pick_color'.tr()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // End Color Picker
                  Text(
                    'End Color',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: endColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final color = await _showColorPicker(endColor);
                          if (color != null) {
                            setDialogState(() => endColor = color);
                          }
                        },
                        child: Text('settings.pick_color'.tr()),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('common.cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(quickActionsProvider.notifier)
                        .setActionColor(
                      actionId,
                      [startColor, endColor],
                    );
                    Navigator.pop(context);
                    if (mounted) {
                      AppSnackBar.show(
                        context,
                        const SnackBar(
                          content: Text('Colors updated successfully'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Text('common.save'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReceiptPrinterManagementSection() {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.borderColor.withValues(alpha: 0.3)
              : AppColors.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.04),
            blurRadius: 12,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: AppColors.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Receipt & Printer Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Unified management for receipt customization, printer configuration, and live preview',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode
                    ? AppColors.textTertiary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push('/receipt-customization'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.settings,
                            color: AppColors.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Open Receipt & Printer Management',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Configure receipts, printers, preview, and all printing settings in one place',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? AppColors.textTertiary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          size: 16,
                          color: isDarkMode
                              ? AppColors.textTertiary
                              : AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseSection() {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.borderColor.withValues(alpha: 0.3)
              : AppColors.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.04),
            blurRadius: 12,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.security,
                    color: AppColors.warningColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'License Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FutureBuilder<LicenseModel?>(
              key: ValueKey(_licenseRefreshKey),
              future: LicenseService.getCurrentLicense(),
              builder: (context, snapshot) {
                final license = snapshot.data;
                final isValid = license?.isValid ?? false;
                final planType = license?.planType ?? '';
                final planLabel = planType == 'yearly'
                    ? '1-Year Plan'
                    : planType == 'lifetime'
                        ? 'Lifetime Plan'
                        : planType == 'monthly'
                            ? 'Monthly Plan'
                            : '';

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isValid
                                ? AppColors.successColor
                                : AppColors.errorColor)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isValid
                              ? AppColors.successColor
                              : AppColors.errorColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isValid ? Icons.check_circle : Icons.error,
                            color: isValid
                                ? AppColors.successColor
                                : AppColors.errorColor,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isValid
                                          ? 'License Active'
                                          : 'License Expired',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (planLabel.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryColor
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          planLabel,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isValid
                                      ? (license?.expiresAt != null
                                          ? 'Valid until ${_formatDate(license?.expiresAt)}'
                                          : 'Lifetime — never expires')
                                      : 'Please activate your license',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? AppColors.textTertiary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Inline license code update
                    Text(
                      'Update License',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? Colors.white70 : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter a new code to switch between Monthly, 1-Year, or Lifetime plans.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? AppColors.textTertiary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _licenseCodeController,
                      decoration: InputDecoration(
                        hintText: 'Enter 16-character license code',
                        prefixIcon: const Icon(Icons.vpn_key, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.paste, size: 20),
                          tooltip: 'Paste from clipboard',
                          onPressed: () async {
                            final data =
                                await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null) {
                              _licenseCodeController.text = data!.text!.trim();
                            }
                          },
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? const Color(0xFF374151)
                            : Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: isDarkMode
                                  ? const Color(0xFF4B5563)
                                  : Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: isDarkMode
                                  ? const Color(0xFF4B5563)
                                  : Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primaryColor, width: 2),
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: 'monospace',
                        letterSpacing: 1.1,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) {
                        if (_licenseActivationError != null ||
                            _licenseActivationSuccess != null) {
                          setState(() {
                            _licenseActivationError = null;
                            _licenseActivationSuccess = null;
                          });
                        }
                      },
                    ),
                    if (_licenseActivationError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error,
                                color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _licenseActivationError!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_licenseActivationSuccess != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _licenseActivationSuccess!,
                                style: const TextStyle(
                                    color: Colors.green, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isActivatingLicense
                            ? null
                            : _activateLicenseFromSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isActivatingLicense
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Activate / Update License',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => context.push('/license-management'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.info_outline,
                                    color: AppColors.primaryColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'View License Details',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isDarkMode
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Full license history and management',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDarkMode
                                            ? AppColors.textTertiary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios,
                                  size: 16,
                                  color: isDarkMode
                                      ? AppColors.textTertiary
                                      : AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activateLicenseFromSettings() async {
    final code = _licenseCodeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _licenseActivationError = 'Please enter a license code.';
      });
      return;
    }
    if (!LicenseService.isValidCodeFormat(code)) {
      setState(() {
        _licenseActivationError =
            'Invalid code format. Code must be 16 alphanumeric characters.';
      });
      return;
    }

    setState(() {
      _isActivatingLicense = true;
      _licenseActivationError = null;
      _licenseActivationSuccess = null;
    });

    try {
      final status = await LicenseService.activateLicense(code);
      if (status.isValid) {
        _licenseCodeController.clear();
        setState(() {
          _licenseActivationSuccess = 'License updated successfully!';
          _licenseRefreshKey++;
        });
      } else {
        setState(() {
          _licenseActivationError =
              status.message ?? 'Invalid code. Please check and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _licenseActivationError = 'An error occurred. Please try again.';
      });
    } finally {
      setState(() {
        _isActivatingLicense = false;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildDataManagementSection() {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.borderColor.withValues(alpha: 0.3)
              : AppColors.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.04),
            blurRadius: 12,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.infoColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.storage,
                    color: AppColors.infoColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Data Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Backup Status
            FutureBuilder<BackupStatus>(
              future: WindowsBackupService.getBackupStatus(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final status = snapshot.data!;
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: status.isAutoBackupEnabled
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: status.isAutoBackupEnabled
                                ? Colors.green
                                : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              status.isAutoBackupEnabled
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: status.isAutoBackupEnabled
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    status.isAutoBackupEnabled
                                        ? 'Auto Backup Enabled'
                                        : 'Auto Backup Disabled',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (status.lastBackupTime != null)
                                    Text(
                                      'Last backup: ${DateFormat('MMM dd, yyyy hh:mm a').format(status.lastBackupTime!)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 20),
            // Manual Backup
            _buildDataManagementTile(
              'Create Backup',
              'Create manual backup to Documents/posbackup',
              Icons.backup,
              AppColors.successColor,
              _createManualBackup,
            ),
            const SizedBox(height: 12),
            _buildDataManagementTile(
              'Online backup (free)',
              'Save a fresh backup to the internet and get a link (transfer.sh / 0x0.st)',
              Icons.cloud_upload_outlined,
              AppColors.infoColor,
              _onlineBackupToCloud,
            ),
            const SizedBox(height: 12),
            // Restore Data
            _buildDataManagementTile(
              'Restore Data',
              'Import data from a backup file',
              Icons.restore,
              AppColors.warningColor,
              _restoreData,
            ),
            const SizedBox(height: 12),
            // View Backups
            _buildDataManagementTile(
              'View Backups',
              'Browse available backup files',
              Icons.folder_open,
              AppColors.infoColor,
              _viewBackups,
            ),
            const SizedBox(height: 20),
            // Auto Backup Toggle (Windows-only)
            FutureBuilder<BackupStatus>(
              future: WindowsBackupService.getBackupStatus(),
              builder: (context, snapshot) {
                if (!Platform.isWindows || !snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                final status = snapshot.data!;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.backgroundDark
                        : AppColors.hoverColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.infoColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.schedule,
                            color: AppColors.infoColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Automatic Windows Backup',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Backs up data every 2 hours to Documents/posbackup and available drives (D:, E:...).',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? AppColors.textTertiary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: status.isAutoBackupEnabled,
                        onChanged: (value) => _toggleAutoBackup(value),
                        activeColor: AppColors.successColor,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // Clear Cache
            _buildDataManagementTile(
              'Clear Cache',
              'Clear all database data (cannot be undone)',
              Icons.cached,
              AppColors.warningColor,
              _showClearCacheDialog,
            ),
            const SizedBox(height: 12),
            // Clear All Data
            _buildDataManagementTile(
              'Clear All Data',
              'Delete all data including settings (cannot be undone)',
              Icons.delete_forever,
              AppColors.errorColor,
              _showClearDataDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementTile(
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? AppColors.textTertiary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode
                      ? AppColors.textTertiary
                      : AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.borderColor.withValues(alpha: 0.3)
              : AppColors.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.04),
            blurRadius: 12,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: AppColors.secondaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'About',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildAboutTile(
              Icons.info,
              'Version',
              '1.0.0',
              AppColors.infoColor,
            ),
            const SizedBox(height: 12),
            _buildAboutTile(
              Icons.offline_bolt,
              'Offline POS System',
              'Fully offline Point-of-Sale system with Khata management',
              AppColors.primaryColor,
            ),
            const SizedBox(height: 12),
            _buildAboutTile(
              Icons.security,
              'Data Security',
              'All data is encrypted and stored locally',
              AppColors.successColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTile(
      IconData icon, String title, String subtitle, Color iconColor) {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.backgroundDark : AppColors.hoverColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.textTertiary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    // Validate required fields
    if (_businessNameController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business name is required'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final databaseService = ref.read(databaseServiceProvider);

      // Save all business information
      await databaseService.setSetting(
          'business_name', _businessNameController.text.trim());
      await databaseService.setSetting(
          'business_address', _businessAddressController.text.trim());
      await databaseService.setSetting(
          'business_phone', _businessPhoneController.text.trim());

      // Save tax rate with validation
      final taxRate = _taxRateController.text.trim();
      if (taxRate.isNotEmpty) {
        final taxRateNum = double.tryParse(taxRate);
        if (taxRateNum == null || taxRateNum < 0 || taxRateNum > 100) {
          throw Exception('Tax rate must be a number between 0 and 100');
        }
      }
      await databaseService.setSetting('tax_rate', taxRate);

      // Save currency if selected
      if (_selectedCurrency != null) {
        await databaseService.setSetting(
            'currency_code', _selectedCurrency!.code);
        await databaseService.setSetting(
            'currency_symbol', _selectedCurrency!.symbol);

        // Update currency provider
        final currencyNotifier = ref.read(currencyProvider.notifier);
        await currencyNotifier.changeCurrency(_selectedCurrency!);
      }

      // Save UI settings
      await databaseService.setSetting('dark_mode', _isDarkMode.toString());
      await databaseService.setSetting(
          'hide_stats_cards', _hideStatsCards.toString());
      await databaseService.setSetting(
          'bundles_enabled', _bundlesEnabled.toString());

      // Save language setting
      await databaseService.setSetting(
          'locale_code', _effectiveLocaleCode(context));

      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('✓ Settings saved successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error saving settings: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _backupData() async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      await BackupService.createBackup(databaseService.db);

      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Backup created and shared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error creating backup: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _createManualBackup() async {
    try {
      setState(() => _isLoading = true);

      final databaseService = ref.read(databaseServiceProvider);
      final backupPath = await WindowsBackupService.createBackup(
          databaseService.db,
          isAutomatic: false);

      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                  'Backup created successfully!\nLocation: ${backupPath.split('\\').last}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error creating backup: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Creates a local JSON backup, uploads it to a free host (no account), shows download link.
  Future<void> _onlineBackupToCloud() async {
    try {
      setState(() => _isLoading = true);

      final databaseService = ref.read(databaseServiceProvider);
      final backupPath = await WindowsBackupService.createBackup(
        databaseService.db,
        isAutomatic: false,
      );
      final url = await CloudBackupService.uploadBackupFile(backupPath);

      if (!mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Online backup complete'),
          content: SingleChildScrollView(
            child: SelectableText(
              'Save this link somewhere safe (email, notes, cloud drive). '
              'Anyone with the link can download your backup until the host removes it.\n\n$url',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.pop(ctx);
                messenger?.showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
              child: const Text('Copy link'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Online backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restoreData() async {
    try {
      setState(() => _isLoading = true);

      // Show backup selection dialog
      final backupFiles = await WindowsBackupService.getAvailableBackups();

      if (backupFiles.isEmpty) {
        if (mounted) {
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (messenger != null) {
            messenger.showSnackBar(
              const SnackBar(
                content:
                    Text('No backup files found in Documents/posbackup folder'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        return;
      }

      // Show backup selection dialog
      final selectedBackup = await _showBackupSelectionDialog(backupFiles);
      if (selectedBackup == null) return;

      final databaseService = ref.read(databaseServiceProvider);
      await WindowsBackupService.restoreBackup(
          databaseService.db, selectedBackup.filePath);

      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                  'Data restored successfully from ${selectedBackup.fileName}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error restoring data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<BackupFileInfo?> _showBackupSelectionDialog(
      List<BackupFileInfo> backupFiles) async {
    return await showDialog<BackupFileInfo>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.backup_select_title'.tr()),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: backupFiles.length,
            itemBuilder: (context, index) {
              final backup = backupFiles[index];
              return ListTile(
                leading: Icon(
                  backup.isAutomatic ? Icons.schedule : Icons.backup,
                  color: backup.isAutomatic ? Colors.blue : Colors.green,
                ),
                title: Text(backup.fileName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Size: ${(backup.size / 1024).toStringAsFixed(1)} KB'),
                    Text(
                        'Created: ${DateFormat('MMM dd, yyyy hh:mm a').format(backup.created)}'),
                    if (backup.isAutomatic)
                      Text('settings.automatic_backup'.tr(),
                          style: TextStyle(fontSize: 12, color: Colors.blue)),
                  ],
                ),
                onTap: () => Navigator.of(context).pop(backup),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _viewBackups() async {
    try {
      final backupFiles = await WindowsBackupService.getAvailableBackups();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('settings.available_backups'.tr()),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: backupFiles.isEmpty
                  ? Center(
                      child: Text('settings.no_backups_found'.tr()),
                    )
                  : ListView.builder(
                      itemCount: backupFiles.length,
                      itemBuilder: (context, index) {
                        final backup = backupFiles[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              backup.isAutomatic
                                  ? Icons.schedule
                                  : Icons.backup,
                              color: backup.isAutomatic
                                  ? Colors.blue
                                  : Colors.green,
                            ),
                            title: Text(backup.fileName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Size: ${(backup.size / 1024).toStringAsFixed(1)} KB'),
                                Text(
                                    'Created: ${DateFormat('MMM dd, yyyy hh:mm a').format(backup.created)}'),
                                if (backup.isAutomatic)
                                  Text('settings.automatic_backup'.tr(),
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.blue)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.folder_open),
                              onPressed: () {
                                // Open file location
                                final messenger =
                                    ScaffoldMessenger.maybeOf(context);
                                if (messenger != null) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Backup location: ${backup.filePath}'),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('common.close'.tr()),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error loading backups: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleAutoBackup(bool enabled) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      await WindowsBackupService.setAutoBackupEnabled(
          enabled, databaseService.db);

      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(enabled
                  ? 'Automatic backup enabled'
                  : 'Automatic backup disabled'),
              backgroundColor: enabled ? Colors.green : Colors.orange,
            ),
          );
        }
        setState(() {}); // Refresh the UI
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error updating auto backup: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.clear_all_data'.tr()),
        content: const Text(
          'This will permanently delete all your data including products, customers, sales, and settings. This action cannot be undone.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllData();
            },
            child: const Text(
              'Clear All Data',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.clear_cache'.tr()),
        content: const Text(
          'This will permanently delete all database data including products, customers, sales, suppliers, employees, banks, and all other records. Business settings will be preserved.\n\nThis action cannot be undone.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCache();
            },
            child: const Text(
              'Clear Cache',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    setState(() => _isLoading = true);
    try {
      final databaseService = ref.read(databaseServiceProvider);
      await BackupService.clearAllData(databaseService.db);

      // Invalidate all providers to refresh the UI
      ref.invalidate(productNotifierProvider);
      ref.invalidate(supplierNotifierProvider);
      ref.invalidate(salesProvider);
      ref.invalidate(bankNotifierProvider);
      ref.invalidate(categoryNotifierProvider);

      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                  'Cache cleared successfully. All database data has been deleted.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error clearing cache: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearAllData() async {
    setState(() => _isLoading = true);
    try {
      final databaseService = ref.read(databaseServiceProvider);
      await BackupService.clearAllData(databaseService.db);

      // Also clear settings
      await databaseService.db.delete(databaseService.db.settings).go();

      // Invalidate all providers to refresh the UI
      ref.invalidate(productNotifierProvider);
      ref.invalidate(supplierNotifierProvider);
      ref.invalidate(salesProvider);
      ref.invalidate(bankNotifierProvider);
      ref.invalidate(categoryNotifierProvider);

      // Reload settings to reset UI
      await _loadSettings();

      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('All data and settings have been cleared'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error clearing data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildRolePermissionsSection() {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;

    if (currentUser == null || !currentUser.isAdmin) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.borderColor.withValues(alpha: 0.3)
              : AppColors.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.04),
            blurRadius: 12,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: AppColors.warningColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Role Permissions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              isDarkMode ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configure permissions for each role',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? AppColors.textTertiary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/role-permissions'),
              icon: const Icon(Icons.security),
              label: Text('settings.manage_roles'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/employee-management'),
              icon: const Icon(Icons.badge),
              label: const Text('Manage Employees'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                side: BorderSide(
                  color: isDarkMode
                      ? AppColors.borderColor.withValues(alpha: 0.5)
                      : AppColors.borderColor,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockManagementSection() {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final authState = ref.watch(authProvider);
    final inventorySettings = ref.watch(inventorySettingsProvider);
    final currentUser = authState.currentUser;

    // Only show this section for admin users
    if (currentUser == null || !currentUser.isAdmin) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.borderColor.withValues(alpha: 0.3)
              : AppColors.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.04),
            blurRadius: 12,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2,
                    color: AppColors.errorColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              isDarkMode ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage product stock levels',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? AppColors.textTertiary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildAudioSwitchTile(
              'Opening stock in Add Product',
              inventorySettings.allowOpeningStockOnProductCreate
                  ? 'Enabled: new products can start with a current stock quantity.'
                  : 'Disabled: stock must be received through a purchase invoice.',
              inventorySettings.allowOpeningStockOnProductCreate,
              Icons.inventory_outlined,
              () async {
                final enabled =
                    !inventorySettings.allowOpeningStockOnProductCreate;
                try {
                  await ref
                      .read(inventorySettingsProvider.notifier)
                      .setAllowOpeningStockOnProductCreate(enabled);
                  if (mounted) {
                    AppSnackBar.show(
                      context,
                      SnackBar(
                        content: Text(
                          enabled
                              ? 'Opening stock entry enabled for new products.'
                              : 'Opening stock disabled. Use purchase invoices to receive stock.',
                        ),
                        backgroundColor: AppColors.successColor,
                      ),
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    AppSnackBar.show(
                      context,
                      const SnackBar(
                        content: Text('Unable to save the stock setting.'),
                        backgroundColor: AppColors.errorColor,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            Divider(
              color: isDarkMode
                  ? AppColors.borderColor.withValues(alpha: 0.3)
                  : AppColors.borderColor,
            ),
            const SizedBox(height: 16),
            _buildDataManagementTile(
              'Make All Product Stock Zero',
              'Set stock = 0 for all products (cannot be undone)',
              Icons.exposure_zero,
              AppColors.errorColor,
              _showMakeAllStockZeroDialog,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMakeAllStockZeroDialog() async {
    // First show confirmation dialog
    final confirmed = await ModernDialogBuilder.showConfirmDialog(
      context: context,
      title: 'Make All Product Stock Zero',
      message:
          'Are you sure you want to set all product stock to zero?\n\nThis action cannot be undone.',
      confirmText: 'Yes, Make Zero',
      cancelText: 'Cancel',
      confirmColor: AppColors.errorColor,
      icon: Icons.warning_amber_rounded,
      isDestructive: true,
    );

    if (confirmed != true) return;

    // Then verify admin password
    final passwordVerified = await _verifyAdminPassword(
      title: 'Admin Password Required',
      message: 'Please enter your admin password to set all stock to zero.',
    );

    if (passwordVerified == true) {
      _makeAllStockZero();
    }
  }

  Future<void> _makeAllStockZero() async {
    setState(() => _isLoading = true);

    try {
      final databaseService = ref.read(databaseServiceProvider);
      final products = await databaseService.getAllProducts();
      final authState = ref.read(authProvider);

      // Get current user/admin name
      final currentUser = authState.currentUser;
      final userName = currentUser?.name ??
          currentUser?.displayUsername ??
          authState.adminUsername ??
          'Stock Manager';

      // Get current date for reference
      final currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());

      int successCount = 0;
      int errorCount = 0;

      // Update each product's stock to 0 through stock adjustments
      // This ensures proper ledger entries are created
      for (final product in products) {
        if (product.id != null && product.stock > 0) {
          try {
            // Calculate the adjustment needed (negative quantity to bring stock to zero)
            final adjustmentQuantity = -product.stock;

            // Create stock adjustment entry with proper reason and reference
            // Include stock manager name and date in the reference for ledger tracking
            await databaseService.adjustStock(
              product.id!,
              adjustmentQuantity,
              'Stock set to zero by Stock Manager',
              reference:
                  'Stock Manager: $userName set stock to zero on $currentDate',
            );
            successCount++;
          } catch (e) {
            print('Error adjusting stock for product ${product.id}: $e');
            errorCount++;
          }
        }
      }

      // Refresh product and stock movement providers
      ref.read(productNotifierProvider.notifier).refresh();
      ref.read(stockMovementNotifierProvider.notifier).refresh();

      // Invalidate product ledger providers for all products to refresh ledger entries
      // This ensures the stock zero entries appear in the item ledger
      // Use a small delay to ensure database writes are complete
      await Future.delayed(const Duration(milliseconds: 100));
      for (final product in products) {
        if (product.id != null) {
          ref.invalidate(productLedgerProvider(product.id!));
        }
      }

      // Also invalidate stock movements provider to trigger ledger refresh
      ref.invalidate(stockMovementsProvider);

      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          String message;
          if (errorCount == 0) {
            message =
                'All product stock has been set to zero. $successCount products updated.';
          } else {
            message =
                'Stock updated for $successCount products. $errorCount errors occurred.';
          }
          messenger.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: errorCount == 0 ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error setting stock to zero: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Verify admin password before allowing stock to zero operations
  Future<bool?> _verifyAdminPassword({
    required String title,
    required String message,
  }) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;
    String? errorMessage;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.lock, color: Color(0xFFF59E0B)),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Admin Password',
                    hintText: 'Enter your admin password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    errorText: errorMessage,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) async {
                    if (formKey.currentState?.validate() ?? false) {
                      await _checkPassword(
                        context,
                        passwordController.text,
                        setDialogState,
                        (error) {
                          setDialogState(() {
                            errorMessage = error;
                          });
                        },
                      );
                    }
                  },
                ),
                if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppColors.errorColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.errorColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: AppColors.errorColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  await _checkPassword(
                    context,
                    passwordController.text,
                    setDialogState,
                    (error) {
                      setDialogState(() {
                        errorMessage = error;
                      });
                    },
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
              ),
              child: Text('settings.verify'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if the entered password matches admin password
  Future<void> _checkPassword(
    BuildContext dialogContext,
    String password,
    StateSetter setDialogState,
    Function(String?) setError,
  ) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final settings = await databaseService.getSettings();
      final adminPassword = settings['admin_password'];

      if (adminPassword == null) {
        setDialogState(() {
          setError('Admin password not configured');
        });
        return;
      }

      // Compare with stored admin password
      if (PasswordHasher.verify(password, adminPassword)) {
        // Close dialog and return true
        if (Navigator.canPop(dialogContext)) {
          Navigator.of(dialogContext).pop(true);
        }
      } else {
        setDialogState(() {
          setError('Incorrect password. Please try again.');
        });
      }
    } catch (e) {
      setDialogState(() {
        setError('Error verifying password: $e');
      });
    }
  }

  Widget _buildAudioSwitchTile(
    String title,
    String subtitle,
    bool value,
    IconData icon,
    VoidCallback onChanged,
  ) {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.backgroundDark : AppColors.hoverColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.textTertiary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (_) => onChanged(),
            activeColor: AppColors.successColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountSettingsSection() {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final discountSettings = ref.watch(discountSettingsProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.borderColor.withValues(alpha: 0.3)
              : AppColors.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.04),
            blurRadius: 12,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_offer,
                    color: Color(0xFF8B5CF6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Discount Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildAudioSwitchTile(
              'Overall Discount',
              'Show overall discount option in POS',
              discountSettings.overallDiscountEnabled,
              Icons.percent,
              () => ref
                  .read(discountSettingsProvider.notifier)
                  .toggleOverallDiscount(),
            ),
            const SizedBox(height: 12),
            _buildAudioSwitchTile(
              'Item Discount',
              'Show item discount option in POS',
              discountSettings.itemDiscountEnabled,
              Icons.discount,
              () => ref
                  .read(discountSettingsProvider.notifier)
                  .toggleItemDiscount(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final newUsernameController =
        TextEditingController(text: _adminUsernameController.text);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('settings.edit_profile'.tr()),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: newUsernameController,
                    decoration: const InputDecoration(
                      labelText: 'New Username',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username is required';
                      }
                      if (value.trim().length < 3) {
                        return 'Username must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Current password is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password (Optional)',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value != null &&
                          value.isNotEmpty &&
                          value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (newPasswordController.text.isNotEmpty) {
                        if (value == null ||
                            value != newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                currentPasswordController.dispose();
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                newUsernameController.dispose();
              },
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final authNotifier = ref.read(authProvider.notifier);
                    await authNotifier.updateAdminProfile(
                      newUsernameController.text.trim(),
                      currentPasswordController.text,
                      newPassword: newPasswordController.text.isNotEmpty
                          ? newPasswordController.text
                          : null,
                    );

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      _adminUsernameController.text =
                          newUsernameController.text.trim();
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      if (messenger != null) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      if (messenger != null) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } finally {
                    if (context.mounted) {
                      currentPasswordController.dispose();
                      newPasswordController.dispose();
                      confirmPasswordController.dispose();
                      newUsernameController.dispose();
                    }
                  }
                }
              },
              child: Text('common.save'.tr()),
            ),
          ],
        );
      },
    );
  }
}
