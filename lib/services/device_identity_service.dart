import 'package:shared_preferences/shared_preferences.dart';

/// Provides helpers for tracking local device role in a multi-PC setup.
class DeviceIdentityService {
  static const String _adminFlagKey = 'is_admin_device';
  static const String _deviceNameKey = 'device_display_name';

  static SharedPreferences? _prefs;

  /// Ensures preferences are loaded.
  static Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Returns true if this device is marked as the admin/server device.
  static Future<bool> isAdminDevice() async {
    await _ensurePrefs();
    return _prefs?.getBool(_adminFlagKey) ?? false;
  }

  /// Marks this device as the admin/server device.
  static Future<void> markAsAdminDevice({String? displayName}) async {
    await _ensurePrefs();
    await _prefs?.setBool(_adminFlagKey, true);
    if (displayName != null && displayName.isNotEmpty) {
      await _prefs?.setString(_deviceNameKey, displayName);
    }
  }

  /// Marks this device as a client device (not admin).
  static Future<void> markAsClientDevice() async {
    await _ensurePrefs();
    await _prefs?.setBool(_adminFlagKey, false);
  }

  /// Returns an optional display name for this device.
  static Future<String?> getDeviceDisplayName() async {
    await _ensurePrefs();
    return _prefs?.getString(_deviceNameKey);
  }
}
