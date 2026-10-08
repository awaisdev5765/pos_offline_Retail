import 'package:flutter/material.dart';

/// Touch optimization utilities for Windows touch screens
class TouchOptimization {
  // Minimum touch target size (44x44 pixels recommended by Material Design)
  static const double minTouchTarget = 44.0;
  
  // Recommended touch target size for better usability
  static const double recommendedTouchTarget = 48.0;
  
  // Large touch target for important actions
  static const double largeTouchTarget = 56.0;
  
  // Spacing between touch targets
  static const double touchTargetSpacing = 8.0;

  /// Get minimum size constraints for touch targets
  static BoxConstraints getMinTouchConstraints() {
    return const BoxConstraints(
      minWidth: minTouchTarget,
      minHeight: minTouchTarget,
    );
  }

  /// Get recommended size constraints for touch targets
  static BoxConstraints getRecommendedTouchConstraints() {
    return const BoxConstraints(
      minWidth: recommendedTouchTarget,
      minHeight: recommendedTouchTarget,
    );
  }

  /// Get large size constraints for important actions
  static BoxConstraints getLargeTouchConstraints() {
    return const BoxConstraints(
      minWidth: largeTouchTarget,
      minHeight: largeTouchTarget,
    );
  }

  /// Get minimum size for buttons
  static Size getMinButtonSize() {
    return const Size(minTouchTarget, minTouchTarget);
  }

  /// Get recommended size for buttons
  static Size getRecommendedButtonSize() {
    return const Size(double.infinity, recommendedTouchTarget);
  }

  /// Get padding for touch-friendly buttons
  static EdgeInsets getTouchPadding() {
    return const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    );
  }

  /// Get icon button constraints for touch
  static BoxConstraints getIconButtonConstraints() {
    return const BoxConstraints(
      minWidth: minTouchTarget,
      minHeight: minTouchTarget,
    );
  }

  /// Check if device is likely a touch screen
  static bool isTouchScreen(BuildContext context) {
    // On Windows, assume touch screen if screen is large enough
    // In production, you might want to detect actual touch capability
    final size = MediaQuery.of(context).size;
    return size.width >= 1024; // Desktop with potential touch
  }

  /// Get appropriate button style for touch screens
  static ButtonStyle getTouchButtonStyle({
    Color? backgroundColor,
    Color? foregroundColor,
    double? minHeight,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minimumSize: Size(double.infinity, minHeight ?? recommendedTouchTarget),
      padding: getTouchPadding(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  /// Get appropriate icon button style for touch screens
  static ButtonStyle getTouchIconButtonStyle({
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return IconButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minimumSize: getMinButtonSize(),
      padding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

