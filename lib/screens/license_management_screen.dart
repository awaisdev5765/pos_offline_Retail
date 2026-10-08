import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/license_service.dart';
import '../models/license.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack_bar.dart';

class LicenseManagementScreen extends ConsumerStatefulWidget {
  const LicenseManagementScreen({super.key});

  @override
  ConsumerState<LicenseManagementScreen> createState() =>
      _LicenseManagementScreenState();
}

class _LicenseManagementScreenState
    extends ConsumerState<LicenseManagementScreen> {
  LicenseModel? _currentLicense;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLicenseInfo();
  }

  Future<void> _loadLicenseInfo() async {
    try {
      final license = await LicenseService.getCurrentLicense();
      setState(() {
        _currentLicense = license;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('license.management_title'.tr()),
        backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLicenseStatusCard(),
                  const SizedBox(height: 24),
                  _buildLicenseDetailsCard(),
                  const SizedBox(height: 24),
                  _buildContactCard(),
                  const SizedBox(height: 24),
                  _buildActionsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildLicenseStatusCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isValid = _currentLicense?.isValid ?? false;

    return Card(
      elevation: 0,
      color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isValid ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.error,
                  color: isValid ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'license.status_heading'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isValid
                  ? 'license.active'.tr()
                  : 'license.expired'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isValid ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isValid
                  ? 'license.valid_body'.tr()
                  : 'license.expired_body'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseDetailsCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'license.details_heading'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            if (_currentLicense != null) ...[
              _buildDetailRow('Plan', _getPlanDisplayName(_currentLicense!)),
              _buildDetailRow('license.label_month'.tr(),
                  _currentLicense!.displayName),
              _buildDetailRow('license.label_code'.tr(), _currentLicense!.code),
              _buildDetailRow('license.label_activated'.tr(),
                  _formatDate(_currentLicense!.activatedAt)),
              _buildDetailRow('license.label_expires'.tr(),
                  _formatDate(_currentLicense!.expiresAt)),
            ] else ...[
              Text(
                'license.no_license'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.phone,
                  color: AppColors.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'license.support_heading'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'license.need_code'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'license.contact_intro'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF374151)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone,
                    color: AppColors.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '+92 331 2544969',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyToClipboard('+923312544969'),
                    icon: const Icon(Icons.copy),
                    tooltip: 'license.copy_phone_tooltip'.tr(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'license.whatsapp_note'.tr(),
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white60 : const Color(0xFF64748B),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'license.actions_heading'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _refreshLicense,
                icon: const Icon(Icons.refresh),
                label: Text('license.refresh_status'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearLicense,
                icon: const Icon(Icons.clear),
                label: Text('license.clear_testing'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'common.na'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getPlanDisplayName(LicenseModel license) {
    switch (license.planType) {
      case 'yearly':
        return '1 Year';
      case 'lifetime':
        return 'Lifetime';
      default:
        return 'Monthly';
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text(text.contains('+')
              ? 'license.copied_phone'.tr()
              : 'license.copied_code'.tr()),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _refreshLicense() async {
    setState(() {
      _isLoading = true;
    });
    await _loadLicenseInfo();
  }

  Future<void> _clearLicense() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('license.clear_dialog_title'.tr()),
        content: Text('license.clear_dialog_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('common.clear'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await LicenseService.clearLicense();
      await _loadLicenseInfo();
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('license.cleared_snackbar'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}
