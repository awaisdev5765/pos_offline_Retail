import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'touch_optimization.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';

/// Mobile optimization utilities for better mobile UX
class MobileOptimization {
  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return screenSize.width < 768;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return screenSize.width >= 768 && screenSize.width < 1024;
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return screenSize.width >= 1024;
  }

  /// Get mobile-optimized IconButton with proper touch targets
  static Widget mobileIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
    Color? color,
    double? iconSize,
    EdgeInsets? padding,
    BoxConstraints? constraints,
  }) {
    return Builder(
      builder: (context) {
        final isMobileDevice = isMobile(context);
        return IconButton(
          icon: Icon(icon, size: iconSize ?? (isMobileDevice ? 24 : 20)),
          onPressed: onPressed,
          tooltip: tooltip,
          color: color,
          padding: padding ?? (isMobileDevice ? const EdgeInsets.all(12) : null),
          constraints: constraints ??
              (isMobileDevice
                  ? TouchOptimization.getIconButtonConstraints()
                  : null),
        );
      },
    );
  }

  /// Get mobile-optimized button with proper touch targets
  static Widget mobileButton({
    required Widget child,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Color? foregroundColor,
    EdgeInsets? padding,
    double? minHeight,
    bool isFullWidth = false,
  }) {
    return Builder(
      builder: (context) {
        final isMobileDevice = isMobile(context);
        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            minimumSize: Size(
              isFullWidth ? double.infinity : 0,
              minHeight ??
                  (isMobileDevice
                      ? TouchOptimization.recommendedTouchTarget
                      : 40),
            ),
            padding: padding ??
                (isMobileDevice
                    ? TouchOptimization.getTouchPadding()
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: child,
        );
      },
    );
  }

  /// Get mobile-optimized text field padding
  static EdgeInsets getTextFieldPadding(BuildContext context) {
    return isMobile(context)
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
  }

  /// Get mobile-optimized form field spacing
  static double getFormFieldSpacing(BuildContext context) {
    return isMobile(context) ? 20.0 : 16.0;
  }

  /// Scroll to show widget when keyboard appears
  static void ensureVisible(BuildContext context, {Duration? duration}) {
    final renderObject = context.findRenderObject();
    if (renderObject == null) return;

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;

    final scrollPosition = scrollable.position;
    if (!scrollPosition.hasPixels) return;

    final renderBox = renderObject as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final viewport = scrollable.context.findRenderObject() as RenderBox?;
    if (viewport == null) return;

    final viewportHeight = viewport.size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final visibleHeight = viewportHeight - keyboardHeight;

    // If the field is hidden by keyboard, scroll to show it
    if (offset.dy + size.height > visibleHeight) {
      final scrollOffset = (offset.dy + size.height - visibleHeight) + 20;
      final newScrollPosition = scrollPosition.pixels + scrollOffset;
      
      // Ensure we don't scroll beyond the scroll extent
      final maxScroll = scrollPosition.maxScrollExtent;
      final targetPosition = newScrollPosition.clamp(
        scrollPosition.minScrollExtent,
        maxScroll.isFinite ? maxScroll : double.infinity,
      );
      
      scrollPosition.animateTo(
        targetPosition,
        duration: duration ?? const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Wrap form fields to handle keyboard and scrolling
  static Widget keyboardAwareForm({
    required Widget child,
    ScrollController? controller,
  }) {
    return Builder(
      builder: (context) {
        return SingleChildScrollView(
          controller: controller,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: child,
        );
      },
    );
  }

  /// Get mobile-optimized dialog padding
  static EdgeInsets getDialogPadding(BuildContext context) {
    return isMobile(context)
        ? const EdgeInsets.all(20)
        : const EdgeInsets.all(24);
  }

  /// Get mobile-optimized card padding
  static EdgeInsets getCardPadding(BuildContext context) {
    return isMobile(context)
        ? const EdgeInsets.all(16)
        : const EdgeInsets.all(20);
  }

  /// Get mobile-optimized list item padding
  static EdgeInsets getListItemPadding(BuildContext context) {
    return isMobile(context)
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  }

  /// Get mobile-optimized bottom sheet height
  static double? getBottomSheetHeight(BuildContext context) {
    if (isMobile(context)) {
      final screenHeight = MediaQuery.of(context).size.height;
      return screenHeight * 0.9; // 90% of screen height on mobile
    }
    return null; // Auto height on desktop
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(20);
    } else {
      return const EdgeInsets.all(24);
    }
  }

  /// Get responsive horizontal padding
  static EdgeInsets getResponsiveHorizontalPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 16);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 20);
    } else {
      return const EdgeInsets.symmetric(horizontal: 24);
    }
  }

  /// Get responsive grid cross axis count
  static int getGridCrossAxisCount(BuildContext context, {
    int mobile = 2,
    int tablet = 3,
    int desktop = 4,
  }) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }

  /// Get responsive font size
  static double getResponsiveFontSize(BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }

  /// Get responsive spacing
  static double getResponsiveSpacing(BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }

  /// Wrap widget with mobile-aware constraints
  static Widget responsiveContainer({
    required BuildContext context,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? maxWidth,
  }) {
    return Container(
      padding: padding ?? getResponsivePadding(context),
      margin: margin,
      constraints: maxWidth != null
          ? BoxConstraints(maxWidth: maxWidth)
          : null,
      child: child,
    );
  }

  /// Get mobile-optimized AppBar height
  static double getAppBarHeight(BuildContext context) {
    return isMobile(context) ? 56.0 : 64.0;
  }

  /// Check if screen is very narrow (small phones)
  static bool isNarrowMobile(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return isMobile(context) && screenWidth < 380;
  }

  /// Get mobile-optimized bottom navigation bar height
  static double getBottomNavBarHeight(BuildContext context) {
    return isMobile(context) ? 60.0 : 70.0;
  }

  /// Wrap form with mobile-optimized scrolling
  static Widget mobileScrollView({
    required Widget child,
    ScrollController? controller,
    EdgeInsets? padding,
  }) {
    return Builder(
      builder: (context) {
        return SingleChildScrollView(
          controller: controller,
          padding: padding ?? getResponsivePadding(context),
          child: child,
        );
      },
    );
  }

  /// Get mobile-optimized card margin
  static EdgeInsets getCardMargin(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    } else {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  /// Get responsive icon size
  static double getResponsiveIconSize(BuildContext context, {
    double mobile = 20,
    double tablet = 24,
    double desktop = 24,
  }) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }
}

/// Theme-aware color utilities for mobile dark mode
class ThemeAwareColors {
  /// Get surface color (white in light, dark surface in dark mode)
  static Color getSurfaceColor(BuildContext context, {required bool isDarkMode}) {
    return isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight;
  }

  /// Get background color
  static Color getBackgroundColor(BuildContext context, {required bool isDarkMode}) {
    return isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight;
  }

  /// Get text primary color
  static Color getTextPrimaryColor(BuildContext context, {required bool isDarkMode}) {
    return isDarkMode ? Colors.white : AppColors.textPrimary;
  }

  /// Get text secondary color
  static Color getTextSecondaryColor(BuildContext context, {required bool isDarkMode}) {
    return isDarkMode ? const Color(0xFF94A3B8) : AppColors.textSecondary;
  }

  /// Get text tertiary color
  static Color getTextTertiaryColor(BuildContext context, {required bool isDarkMode}) {
    return isDarkMode ? const Color(0xFF64748B) : AppColors.textTertiary;
  }

  /// Get border color
  static Color getBorderColor(BuildContext context, {required bool isDarkMode}) {
    return isDarkMode ? const Color(0xFF374151) : AppColors.borderColor;
  }

  /// Get divider color
  static Color getDividerColor(BuildContext context, {required bool isDarkMode}) {
    return isDarkMode ? const Color(0xFF374151) : AppColors.dividerColor;
  }

  /// Get grey shade color (for icons, disabled states, etc.)
  static Color getGreyColor(BuildContext context, {required bool isDarkMode, int shade = 400}) {
    if (isDarkMode) {
      switch (shade) {
        case 50:
          return const Color(0xFF374151);
        case 100:
          return const Color(0xFF4B5563);
        case 200:
          return const Color(0xFF6B7280);
        case 300:
          return const Color(0xFF9CA3AF);
        case 400:
          return const Color(0xFF94A3B8);
        case 500:
          return const Color(0xFF64748B);
        case 600:
          return const Color(0xFF64748B);
        case 700:
          return const Color(0xFF475569);
        default:
          return const Color(0xFF94A3B8);
      }
    } else {
      return Colors.grey.shade400;
    }
  }

  /// Get card background color
  static Color getCardBackgroundColor(BuildContext context, {required bool isDarkMode}) {
    return isDarkMode ? AppColors.surfaceDark : Colors.white;
  }

  /// Get input fill color
  static Color getInputFillColor(BuildContext context, {required bool isDarkMode}) {
    return isDarkMode ? AppColors.surfaceDark : Colors.white;
  }

  /// Get shadow color (for cards, etc.)
  static Color getShadowColor(BuildContext context, {required bool isDarkMode, double opacity = 0.1}) {
    return Colors.black.withValues(alpha: isDarkMode ? opacity * 2 : opacity);
  }
}

