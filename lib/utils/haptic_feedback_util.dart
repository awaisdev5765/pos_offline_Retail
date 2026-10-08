import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Enum for different types of haptic feedback
enum HapticFeedbackType {
  light,
  medium,
  heavy,
  success,
  error,
}

/// Utility class for providing haptic feedback across the app
class HapticFeedbackUtil {
  /// Triggers haptic feedback based on the type
  /// 
  /// Uses Flutter's built-in HapticFeedback on all platforms,
  /// with additional vibration on mobile platforms when available.
  static Future<void> trigger(HapticFeedbackType type) async {
    try {
      // Skip vibration on Windows - it's not supported and can cause crashes
      if (Platform.isWindows) {
        // Use Flutter's built-in haptic feedback instead
        switch (type) {
          case HapticFeedbackType.success:
          case HapticFeedbackType.light:
            HapticFeedback.lightImpact();
            break;
          case HapticFeedbackType.error:
          case HapticFeedbackType.medium:
            HapticFeedback.mediumImpact();
            break;
          case HapticFeedbackType.heavy:
            HapticFeedback.heavyImpact();
            break;
        }
        return;
      }

      // For mobile platforms, use vibration if available
      if (await Vibration.hasVibrator() == true) {
        switch (type) {
          case HapticFeedbackType.success:
            Vibration.vibrate(duration: 100);
            break;
          case HapticFeedbackType.error:
            Vibration.vibrate(duration: 200, amplitude: 255);
            break;
          case HapticFeedbackType.light:
            HapticFeedback.lightImpact();
            break;
          case HapticFeedbackType.medium:
            HapticFeedback.mediumImpact();
            break;
          case HapticFeedbackType.heavy:
            HapticFeedback.heavyImpact();
            break;
        }
      } else {
        // Fallback to Flutter's built-in haptic feedback
        switch (type) {
          case HapticFeedbackType.success:
          case HapticFeedbackType.light:
            HapticFeedback.lightImpact();
            break;
          case HapticFeedbackType.error:
          case HapticFeedbackType.medium:
            HapticFeedback.mediumImpact();
            break;
          case HapticFeedbackType.heavy:
            HapticFeedback.heavyImpact();
            break;
        }
      }
    } catch (e) {
      // Silently fail - haptic feedback is not critical
      debugPrint('Haptic feedback error: $e');
    }
  }

  /// Convenience method for light haptic feedback
  static Future<void> light() => trigger(HapticFeedbackType.light);

  /// Convenience method for medium haptic feedback
  static Future<void> medium() => trigger(HapticFeedbackType.medium);

  /// Convenience method for heavy haptic feedback
  static Future<void> heavy() => trigger(HapticFeedbackType.heavy);

  /// Convenience method for success haptic feedback
  static Future<void> success() => trigger(HapticFeedbackType.success);

  /// Convenience method for error haptic feedback
  static Future<void> error() => trigger(HapticFeedbackType.error);
}

