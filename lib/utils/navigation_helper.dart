import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_snack_bar.dart';

class NavigationHelper {
  /// Handles back navigation with proper fallback
  /// Returns true if navigation was handled, false otherwise
  static bool handleBackNavigation(BuildContext context,
      {String? fallbackRoute}) {
    try {
      if (context.canPop()) {
        context.pop();
        return true;
      } else if (fallbackRoute != null) {
        context.go(fallbackRoute);
        return true;
      } else {
        // Default fallback to dashboard
        context.go('/');
        return true;
      }
    } catch (e) {
      // Windows-specific navigation error handling
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        debugPrint('Navigation error on Windows/Web: $e');
        // Try alternative navigation method
        try {
          Navigator.of(context).pop();
          return true;
        } catch (e2) {
          debugPrint('Alternative navigation also failed: $e2');
          return false;
        }
      }
      rethrow;
    }
  }

  /// Creates a standard back button for AppBar
  static Widget createBackButton(BuildContext context,
      {String? fallbackRoute}) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () =>
          handleBackNavigation(context, fallbackRoute: fallbackRoute),
      tooltip: 'Back',
    );
  }

  /// Creates a standard AppBar with back navigation
  static AppBar createAppBar(
    BuildContext context, {
    required String title,
    List<Widget>? actions,
    String? fallbackRoute,
    Color? backgroundColor,
    Color? foregroundColor,
    double? elevation,
    bool centerTitle = true,
    Widget? flexibleSpace,
  }) {
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: createBackButton(context, fallbackRoute: fallbackRoute),
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      centerTitle: centerTitle,
      flexibleSpace: flexibleSpace,
    );
  }

  /// Creates a standard SliverAppBar with back navigation
  static SliverAppBar createSliverAppBar(
    BuildContext context, {
    required String title,
    List<Widget>? actions,
    String? fallbackRoute,
    Color? backgroundColor,
    Color? foregroundColor,
    double? elevation,
    bool pinned = true,
    bool floating = false,
    double? expandedHeight,
    Widget? flexibleSpace,
  }) {
    return SliverAppBar(
      title: Text(title),
      actions: actions,
      leading: createBackButton(context, fallbackRoute: fallbackRoute),
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      pinned: pinned,
      floating: floating,
      expandedHeight: expandedHeight,
      flexibleSpace: flexibleSpace,
    );
  }

  /// Navigates to a route with proper error handling
  static void navigateTo(BuildContext context, String route) {
    try {
      context.go(route);
    } catch (e) {
      // If navigation fails, show error and go to dashboard
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text('Navigation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      context.go('/');
    }
  }

  /// Pushes a route with proper error handling
  static void pushTo(BuildContext context, String route) {
    try {
      context.push(route);
    } catch (e) {
      // If navigation fails, show error and go to dashboard
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text('Navigation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      context.go('/');
    }
  }

  /// Shows a confirmation dialog before navigation
  static Future<bool?> showNavigationConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'No',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Handles navigation with unsaved changes warning
  static Future<void> handleNavigationWithUnsavedChanges(
    BuildContext context, {
    required bool hasUnsavedChanges,
    String? fallbackRoute,
  }) async {
    if (hasUnsavedChanges) {
      final shouldNavigate = await showNavigationConfirmation(
        context,
        title: 'Unsaved Changes',
        message: 'You have unsaved changes. Are you sure you want to leave?',
        confirmText: 'Leave',
        cancelText: 'Stay',
      );

      if (shouldNavigate == true) {
        handleBackNavigation(context, fallbackRoute: fallbackRoute);
      }
    } else {
      handleBackNavigation(context, fallbackRoute: fallbackRoute);
    }
  }

  /// Windows-specific safe navigation pop
  static bool safePop(BuildContext context, [dynamic result]) {
    try {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(result);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Safe pop failed: $e');
      return false;
    }
  }

  /// Windows-specific safe dialog close
  static bool safeCloseDialog(BuildContext context, [dynamic result]) {
    try {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(result);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Safe dialog close failed: $e');
      return false;
    }
  }

  /// Windows-specific safe navigation with delay
  static Future<void> safePopWithDelay(BuildContext context,
      [dynamic result]) async {
    try {
      // Add a small delay for Windows to prevent navigation conflicts
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      debugPrint('Safe pop with delay failed: $e');
    }
  }

  /// Windows-specific export dialog handling
  static Future<void> safeExportDialog(
      BuildContext context, VoidCallback exportFunction) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Processing...'),
            ],
          ),
        ),
      );

      // Execute export function

      // Close loading dialog safely
      if (mounted(context)) {
        safeCloseDialog(context);
      }
    } catch (e) {
      // Close loading dialog safely
      if (mounted(context)) {
        safeCloseDialog(context);
      }

      // Show error message
      if (mounted(context)) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Check if context is still mounted (Windows-specific)
  static bool mounted(BuildContext context) {
    try {
      return context.mounted;
    } catch (e) {
      return false;
    }
  }
}
