import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/license_service.dart';
import '../models/license.dart';
import 'dashboard_screen.dart';
import 'license_activation_screen.dart';

class LicenseWrapper extends ConsumerStatefulWidget {
  const LicenseWrapper({super.key});

  @override
  ConsumerState<LicenseWrapper> createState() => _LicenseWrapperState();
}

class _LicenseWrapperState extends ConsumerState<LicenseWrapper> {
  bool _isCheckingLicense = true;
  LicenseStatus? _licenseStatus;

  @override
  void initState() {
    super.initState();
    _checkLicenseStatus();
  }

  Future<void> _checkLicenseStatus() async {
    try {
      final status = await LicenseService.checkLicenseStatus();

      if (mounted) {
        setState(() {
          _licenseStatus = status;
          _isCheckingLicense = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _licenseStatus = LicenseStatus.invalid();
          _isCheckingLicense = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingLicense) {
      return _buildLoadingScreen();
    }

    if (_licenseStatus?.isValid == true) {
      // License is valid, show main app
      return const DashboardScreen();
    } else {
      // License is invalid or expired, show activation screen
      return LicenseActivationScreen();
    }
  }

  Widget _buildLoadingScreen() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.point_of_sale,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            // App Name
            Text(
              'Offline POS System',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Business Management Solution',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 48),

            // Loading Indicator
            const CircularProgressIndicator(
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),

            Text(
              'Checking license status...',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white60 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
