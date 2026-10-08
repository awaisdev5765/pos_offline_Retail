import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'unified_print_service.dart';

/// Service to save and load print settings
class PrintSettingsService {
  static const String _settingsKey = 'print_settings';
  static const String _defaultProfileKey = 'default_print_profile';

  /// Save print settings
  static Future<void> saveSettings(PrintSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = _settingsToJson(settings);
      await prefs.setString(_settingsKey, jsonEncode(json));
    } catch (e) {
      throw Exception('Failed to save print settings: $e');
    }
  }

  /// Load saved print settings
  static Future<PrintSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_settingsKey);

      if (jsonString == null) {
        return PrintSettings.getDefault();
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return _settingsFromJson(json);
    } catch (e) {
      // Return default settings if loading fails
      return PrintSettings.getDefault();
    }
  }

  /// Save a named print profile
  static Future<void> saveProfile(String name, PrintSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profiles = await getAllProfiles();
      profiles[name] = _settingsToJson(settings);
      await prefs.setString('print_profiles', jsonEncode(profiles));
    } catch (e) {
      throw Exception('Failed to save print profile: $e');
    }
  }

  /// Load a named print profile
  static Future<PrintSettings?> loadProfile(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesString = prefs.getString('print_profiles');

      if (profilesString == null) return null;

      final profiles = jsonDecode(profilesString) as Map<String, dynamic>;
      final profileJson = profiles[name];

      if (profileJson == null) return null;

      return _settingsFromJson(profileJson as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Get all saved profiles
  static Future<Map<String, Map<String, dynamic>>> getAllProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesString = prefs.getString('print_profiles');

      if (profilesString == null) return {};

      final profiles = jsonDecode(profilesString) as Map<String, dynamic>;
      return profiles
          .map((key, value) => MapEntry(key, value as Map<String, dynamic>));
    } catch (e) {
      return {};
    }
  }

  /// Delete a profile
  static Future<void> deleteProfile(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profiles = await getAllProfiles();
      profiles.remove(name);
      await prefs.setString('print_profiles', jsonEncode(profiles));
    } catch (e) {
      throw Exception('Failed to delete print profile: $e');
    }
  }

  /// Set default profile
  static Future<void> setDefaultProfile(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_defaultProfileKey, name);
    } catch (e) {
      throw Exception('Failed to set default profile: $e');
    }
  }

  /// Get default profile name
  static Future<String?> getDefaultProfileName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_defaultProfileKey);
    } catch (e) {
      return null;
    }
  }

  /// Get default settings (either from default profile or saved settings)
  static Future<PrintSettings> getDefaultSettings() async {
    try {
      final defaultProfileName = await getDefaultProfileName();
      if (defaultProfileName != null) {
        final profile = await loadProfile(defaultProfileName);
        if (profile != null) return profile;
      }
      return await loadSettings();
    } catch (e) {
      return PrintSettings.getDefault();
    }
  }

  /// Convert PrintSettings to JSON
  static Map<String, dynamic> _settingsToJson(PrintSettings settings) {
    return {
      'printerType': settings.printerType.name,
      'printerName': settings.printerName,
      'printerIp': settings.printerIp,
      'printerPort': settings.printerPort,
      'paperSize': settings.paperSize.name,
      'orientation': settings.orientation.name,
      'showLogo': settings.showLogo,
      'showBusinessInfo': settings.showBusinessInfo,
      'showCustomerInfo': settings.showCustomerInfo,
      'showItemDetails': settings.showItemDetails,
      'showTaxBreakdown': settings.showTaxBreakdown,
      'showPaymentInfo': settings.showPaymentInfo,
      'showFooter': settings.showFooter,
      'showQRCode': settings.showQRCode,
      'footerText': settings.footerText,
      'fontSize': settings.fontSize,
      'fontFamily': settings.fontFamily,
      'copies': settings.copies,
      'autoCut': settings.autoCut,
      'openCashDrawer': settings.openCashDrawer,
      'receiptStyle': settings.receiptStyle.name,
      'marginTop': settings.marginTop,
      'marginBottom': settings.marginBottom,
      'marginLeft': settings.marginLeft,
      'marginRight': settings.marginRight,
    };
  }

  /// Convert JSON to PrintSettings
  static PrintSettings _settingsFromJson(Map<String, dynamic> json) {
    return PrintSettings(
      printerType: PrinterType.values.firstWhere(
        (e) => e.name == json['printerType'],
        orElse: () => PrinterType.auto,
      ),
      printerName: json['printerName'],
      printerIp: json['printerIp'],
      printerPort: json['printerPort'] ?? 9100,
      paperSize: PaperSize.values.firstWhere(
        (e) => e.name == json['paperSize'],
        orElse: () => PaperSize.auto,
      ),
      orientation: PrintOrientation.values.firstWhere(
        (e) => e.name == json['orientation'],
        orElse: () => PrintOrientation.portrait,
      ),
      showLogo: json['showLogo'] ?? true,
      showBusinessInfo: json['showBusinessInfo'] ?? true,
      showCustomerInfo: json['showCustomerInfo'] ?? true,
      showItemDetails: json['showItemDetails'] ?? true,
      showTaxBreakdown: json['showTaxBreakdown'] ?? true,
      showPaymentInfo: json['showPaymentInfo'] ?? true,
      showFooter: json['showFooter'] ?? true,
      showQRCode: json['showQRCode'] ?? false,
      footerText: json['footerText'],
      fontSize: json['fontSize'] ?? 12,
      fontFamily: json['fontFamily'] ?? 'Roboto',
      copies: json['copies'] ?? 1,
      autoCut: json['autoCut'] ?? true,
      openCashDrawer: json['openCashDrawer'] ?? false,
      receiptStyle: ReceiptStyle.values.firstWhere(
        (e) => e.name == json['receiptStyle'],
        orElse: () => ReceiptStyle.modern,
      ),
      marginTop: (json['marginTop'] ?? 10.0).toDouble(),
      marginBottom: (json['marginBottom'] ?? 10.0).toDouble(),
      marginLeft: (json['marginLeft'] ?? 10.0).toDouble(),
      marginRight: (json['marginRight'] ?? 10.0).toDouble(),
    );
  }
}
