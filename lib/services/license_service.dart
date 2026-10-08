import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/license.dart';

class LicenseService {
  static const String _licenseKey = 'monthly_license';
  static const String _activationKey = 'license_activation';
  static const String _yearlyPlanType = 'yearly';
  static const String _lifetimePlanType = 'lifetime';

  // Monthly activation codes (2025–2030); one valid code per calendar month.
  // More secure, complex codes with mixed patterns
  static const Map<String, String> _monthlyCodes = {
    // 2025 Codes - Advanced Security Pattern
    '2025-01': 'Z9A2B4C6D8E1F3G5',
    '2025-02': 'Y8Z1A3B5C7D9E2F4',
    '2025-03': 'X7Y9Z2A4B6C8D1E3',
    '2025-04': 'W6X8Y1Z3A5B7C9D2',
    '2025-05': 'V5W7X9Y2Z4A6B8C1',
    '2025-06': 'U4V6W8X1Y3Z5A7B9',
    '2025-07': 'T3U5V7W9X2Y4Z6A8',
    '2025-08': 'S2T4U6V8W1X3Y5Z7',
    '2025-09': 'R1S3T5U7V9W2X4Y6',
    '2025-10': 'Q9R2S4T6U8V1W3X5',
    '2025-11': 'P8Q1R3S5T7U9V2W4',
    '2025-12': 'O7P9Q2R4S6T8U1V3',

    // 2026 Codes - Enhanced Security Pattern
    '2026-01': 'K7X9M2P4Q8R1S5T3',
    '2026-02': 'N6Y8L3O7P9Q2R4S6',
    '2026-03': 'A5B7C9D1E3F5G7H9',
    '2026-04': 'X4Z6Y8W2V4U6T8S1',
    '2026-05': 'M3N5O7P9Q1R3S5T7',
    '2026-06': 'K2L4M6N8O1P3Q5R7',
    '2026-07': 'J1K3L5M7N9O2P4Q6',
    '2026-08': 'I9J2K4L6M8N1O3P5',
    '2026-09': 'H8I1J3K5L7M9N2O4',
    '2026-10': 'G7H9I2J4K6L8M1N3',
    '2026-11': 'F6G8H1I3J5K7L9M2',
    '2026-12': 'E5F7G9H2I4J6K8L1',

    // 2027 Codes - Advanced Security Pattern
    '2027-01': 'N6O8P1Q3R5S7T9U2',
    '2027-02': 'M5N7O9P2Q4R6S8T1',
    '2027-03': 'L4M6N8O1P3Q5R7S9',
    '2027-04': 'K3L5M7N9O2P4Q6R8',
    '2027-05': 'J2K4L6M8N1O3P5Q7',
    '2027-06': 'I1J3K5L7M9N2O4P6',
    '2027-07': 'H9I2J4K6L8M1N3O5',
    '2027-08': 'G8H1I3J5K7L9M2N4',
    '2027-09': 'F7G9H2I4J6K8L1M3',
    '2027-10': 'E6F8G1H3I5J7K9L2',
    '2027-11': 'D5E7F9G2H4I6J8K1',
    '2027-12': 'C4D6E8F1G3H5I7J9',

    // 2028 Codes (12)
    '2028-01': 'Q3W5E7R9T2Y4U6I8',
    '2028-02': 'P2O4I6U8Y1T3R5E7',
    '2028-03': 'L9K7J5H3G1F8D6S4',
    '2028-04': 'M1N3B5V7C9X2Z4L6',
    '2028-05': 'Z8X6C4V2B1N9M7Q3',
    '2028-06': 'W5E3R1T7Y9U2I4O6',
    '2028-07': 'S4D6F8G1H3J5K7L9',
    '2028-08': 'A2S4D6F8G1H3J5K7',
    '2028-09': 'Q9W1E3R5T7Y9U2I4',
    '2028-10': 'O8P6L4K2J1H9G7F5',
    '2028-11': 'N7M5B3V1C9X8Z6L4',
    '2028-12': 'B1V3C5X7Z9L2K4J6',

    // 2029 Codes (12)
    '2029-01': 'H8J2K4L6M8N1P3R5',
    '2029-02': 'G7F9D1S3A5Q2W4E6',
    '2029-03': 'T9R7E5W3Q1Y8U6I4',
    '2029-04': 'O2P4R6T8V1B3N5M7',
    '2029-05': 'X9C7V5B3N1M8L6K4',
    '2029-06': 'Z2L4K6J8H1G3F5D7',
    '2029-07': 'S9A7Q5W3E1R8T6Y4',
    '2029-08': 'U1I3O5P7L9K2J4H6',
    '2029-09': 'M8N6B4V2C1X9Z7Q5',
    '2029-10': 'W4E6R8T1Y3U5I7O9',
    '2029-11': 'D2F4G6H8J1K3L5M7',
    '2029-12': 'P9O7I5U3Y1T8R6E4',

    // 2030 Codes (5) — extends prepaid coverage through May 2030
    '2030-01': 'A3S5D7F9G2H4J6K8',
    '2030-02': 'Q1W3E5R7T9Y2U4I6',
    '2030-03': 'Z4X6C8V1B3N5M7L9',
    '2030-04': 'K2J4H6G8F1D3S5A7',
    '2030-05': 'L5M7N9P1Q3R5T7V9',
  };

  static const Set<String> _yearlyCodes = {
    'YR1A3C5E7G9I2K4M',
    'YR2B4D6F8H1J3L5N',
    'YR3C5E7G9I2K4M6O',
  };

  static const Set<String> _lifetimeCodes = {
    'LF1A3C5E7G9I2K4P',
    'LF2B4D6F8H1J3L5Q',
  };

  /// Check if license is valid for current month
  static Future<LicenseStatus> checkLicenseStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final licenseJson = prefs.getString(_licenseKey);

      if (licenseJson == null) {
        return LicenseStatus.requiresActivation();
      }

      final license = LicenseModel.fromJson(jsonDecode(licenseJson));
      final now = DateTime.now();

      if (!license.isActive) {
        return LicenseStatus.expired();
      }

      if (license.planType == _lifetimePlanType) {
        return LicenseStatus.valid();
      }

      if (license.expiresAt != null) {
        if (now.isAfter(license.expiresAt!)) {
          return LicenseStatus.expired();
        }
        return LicenseStatus.valid();
      }

      // Backward compatibility for legacy monthly licenses without expiresAt.
      final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      if (license.month != currentMonthKey.split('-')[1] ||
          license.year != currentMonthKey.split('-')[0]) {
        return LicenseStatus.expired();
      }

      return LicenseStatus.valid();
    } catch (e) {
      return LicenseStatus.invalid();
    }
  }

  /// Activate license with monthly/yearly/lifetime code
  static Future<LicenseStatus> activateLicense(String code) async {
    try {
      final normalizedCode = code.trim().toUpperCase();
      final currentDate = DateTime.now();
      final currentMonthKey =
          '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}';

      LicenseModel? license;

      if (_yearlyCodes.contains(normalizedCode)) {
        license = LicenseModel(
          id: 'license_${currentDate.millisecondsSinceEpoch}',
          month: currentDate.month.toString().padLeft(2, '0'),
          year: currentDate.year.toString(),
          code: normalizedCode,
          planType: _yearlyPlanType,
          isActive: true,
          createdAt: currentDate,
          activatedAt: currentDate,
          expiresAt: currentDate.add(const Duration(days: 365)),
        );
      } else if (_lifetimeCodes.contains(normalizedCode)) {
        license = LicenseModel(
          id: 'license_${currentDate.millisecondsSinceEpoch}',
          month: currentDate.month.toString().padLeft(2, '0'),
          year: currentDate.year.toString(),
          code: normalizedCode,
          planType: _lifetimePlanType,
          isActive: true,
          createdAt: currentDate,
          activatedAt: currentDate,
          expiresAt: null,
        );
      } else if (_monthlyCodes.containsKey(currentMonthKey) &&
          _monthlyCodes[currentMonthKey] == normalizedCode) {
        license = LicenseModel(
          id: 'license_${currentDate.millisecondsSinceEpoch}',
          month: currentDate.month.toString().padLeft(2, '0'),
          year: currentDate.year.toString(),
          code: normalizedCode,
          planType: 'monthly',
          isActive: true,
          createdAt: currentDate,
          activatedAt: currentDate,
          expiresAt: DateTime(currentDate.year, currentDate.month + 1, 1),
        );
      }

      if (license != null) {

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_licenseKey, jsonEncode(license.toJson()));
        await prefs.setString(_activationKey, currentMonthKey);

        return LicenseStatus.valid();
      } else {
        return LicenseStatus.invalid();
      }
    } catch (e) {
      return LicenseStatus.invalid();
    }
  }

  /// Get current license information
  static Future<LicenseModel?> getCurrentLicense() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final licenseJson = prefs.getString(_licenseKey);

      if (licenseJson != null) {
        return LicenseModel.fromJson(jsonDecode(licenseJson));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get all available monthly codes (for admin reference)
  static Map<String, String> getAllMonthlyCodes() {
    return Map.from(_monthlyCodes);
  }

  static Set<String> getAllYearlyCodes() {
    return Set.from(_yearlyCodes);
  }

  static Set<String> getAllLifetimeCodes() {
    return Set.from(_lifetimeCodes);
  }

  /// Get current month code
  static String? getCurrentMonthCode() {
    final currentDate = DateTime.now();
    final currentMonthKey =
        '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}';
    return _monthlyCodes[currentMonthKey];
  }

  /// Get next month code (for preview)
  static String? getNextMonthCode() {
    final currentDate = DateTime.now();
    final nextMonth = currentDate.month == 12 ? 1 : currentDate.month + 1;
    final nextYear =
        currentDate.month == 12 ? currentDate.year + 1 : currentDate.year;
    final nextMonthKey = '$nextYear-${nextMonth.toString().padLeft(2, '0')}';
    return _monthlyCodes[nextMonthKey];
  }

  /// Check if license will expire soon (within 7 days)
  static Future<bool> isLicenseExpiringSoon() async {
    try {
      final license = await getCurrentLicense();
      if (license?.expiresAt == null) return false;

      final daysUntilExpiry =
          license!.expiresAt!.difference(DateTime.now()).inDays;
      return daysUntilExpiry <= 7 && daysUntilExpiry >= 0;
    } catch (e) {
      return false;
    }
  }

  /// Clear license (for testing or reset)
  static Future<void> clearLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseKey);
    await prefs.remove(_activationKey);
  }

  /// Get license status message
  static Future<String> getLicenseStatusMessage() async {
    final status = await checkLicenseStatus();
    return status.message ?? 'Unknown license status';
  }

  /// Validate code format (basic validation)
  static bool isValidCodeFormat(String code) {
    // Basic format validation: should be 16 characters, alphanumeric
    final normalizedCode = code.trim().toUpperCase();
    return normalizedCode.length == 16 &&
        RegExp(r'^[A-Z0-9]+$').hasMatch(normalizedCode);
  }
}
