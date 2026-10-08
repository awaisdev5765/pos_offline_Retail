import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import 'mobile_optimization.dart';

class ModernDialogBuilder {
  /// Shows a modern confirmation dialog
  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    IconData? icon,
    bool isDestructive = false,
  }) {
    final defaultColor =
        isDestructive ? AppColors.errorColor : AppColors.primaryColor;

    return showDialog<bool>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final isDarkMode = ref.watch(isDarkModeProvider);
          final screenSize = MediaQuery.of(context).size;
          final isMobile = screenSize.width < 768;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: isMobile ? screenSize.width * 0.9 : null,
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenSize.width * 0.9 : 500,
                maxHeight: isMobile ? screenSize.height * 0.8 : 600,
              ),
              padding: MobileOptimization.getDialogPadding(context),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color:
                    isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border.all(color: AppColors.borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Container
                  if (icon != null)
                    Container(
                      width: isMobile ? 60 : 80,
                      height: isMobile ? 60 : 80,
                      decoration: BoxDecoration(
                        color: (confirmColor ?? defaultColor).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: confirmColor ?? defaultColor,
                        size: isMobile ? 30 : 40,
                      ),
                    ),
                  if (icon != null) SizedBox(height: isMobile ? 12 : 20),

                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isMobile ? 8 : 12),

                  // Message
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 24),

                  // Buttons
                  isMobile
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: confirmColor ?? defaultColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  minimumSize: const Size(double.infinity,
                                      44), // 44px minimum touch target
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  confirmText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  minimumSize: const Size(double.infinity,
                                      44), // 44px minimum touch target
                                  side:
                                      BorderSide(color: AppColors.borderColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  cancelText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? AppColors.textSecondary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  minimumSize: const Size(
                                      0, 44), // 44px minimum touch target
                                  side:
                                      BorderSide(color: AppColors.borderColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  cancelText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? AppColors.textSecondary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: confirmColor ?? defaultColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  minimumSize: const Size(
                                      0, 44), // 44px minimum touch target
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  confirmText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Shows a modern information dialog
  static Future<void> showInfoDialog({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.info_outline,
    Color? iconColor,
    String buttonText = 'OK',
  }) {
    final defaultIconColor = iconColor ?? AppColors.primaryColor;
    return showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final isDarkMode = ref.watch(isDarkModeProvider);
          final screenSize = MediaQuery.of(context).size;
          final isMobile = screenSize.width < 768;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: isMobile ? screenSize.width * 0.9 : null,
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenSize.width * 0.9 : 500,
                maxHeight: isMobile ? screenSize.height * 0.8 : 600,
              ),
              padding: MobileOptimization.getDialogPadding(context),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color:
                    isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border.all(color: AppColors.borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Container
                  Container(
                    width: isMobile ? 60 : 80,
                    height: isMobile ? 60 : 80,
                    decoration: BoxDecoration(
                      color: defaultIconColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: defaultIconColor,
                      size: isMobile ? 30 : 40,
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 20),

                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isMobile ? 8 : 12),

                  // Message
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          color: isDarkMode
                              ? AppColors.textTertiary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 24),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: defaultIconColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size(
                            double.infinity, 44), // 44px minimum touch target
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Shows a modern details dialog with custom content
  static Future<void> showDetailsDialog({
    required BuildContext context,
    required String title,
    required Widget content,
    IconData icon = Icons.info_outline,
    Color? iconColor,
    String buttonText = 'Close',
  }) {
    final defaultIconColor = iconColor ?? AppColors.primaryColor;
    return showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final isDarkMode = ref.watch(isDarkModeProvider);
          final screenSize = MediaQuery.of(context).size;
          final isMobile = screenSize.width < 768;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: isMobile ? screenSize.width * 0.9 : null,
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenSize.width * 0.9 : 500,
                maxHeight: isMobile ? screenSize.height * 0.8 : 600,
              ),
              padding: MobileOptimization.getDialogPadding(context),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color:
                    isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border.all(color: AppColors.borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isMobile ? 8 : 12),
                        decoration: BoxDecoration(
                          color: defaultIconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: defaultIconColor,
                          size: isMobile ? 20 : 28,
                        ),
                      ),
                      SizedBox(width: isMobile ? 8 : 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 12 : 20),

                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      child: content,
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 20),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size(
                            double.infinity, 44), // 44px minimum touch target
                        side: BorderSide(color: AppColors.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        buttonText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Shows a modern loading dialog
  static void showLoadingDialog({
    required BuildContext context,
    String message = 'Please wait...',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final isDarkMode = ref.watch(isDarkModeProvider);
          final screenSize = MediaQuery.of(context).size;
          final isMobile = screenSize.width < 768;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: isMobile ? screenSize.width * 0.9 : null,
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenSize.width * 0.9 : 400,
                maxHeight: isMobile ? screenSize.height * 0.5 : 300,
              ),
              padding: MobileOptimization.getDialogPadding(context),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color:
                    isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border.all(color: AppColors.borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode
                          ? AppColors.textTertiary
                          : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Hides the current dialog
  static void hideDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Shows a mobile-optimized bottom sheet
  static Future<T?> showMobileBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
    double? height,
  }) {
    final isMobileDevice = MobileOptimization.isMobile(context);
    final screenHeight = MediaQuery.of(context).size.height;
    
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: height ?? (isMobileDevice ? screenHeight * 0.9 : screenHeight * 0.7),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            if (title != null)
              Padding(
                padding: MobileOptimization.getResponsiveHorizontalPadding(context),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: MobileOptimization.getResponsiveFontSize(
                            context,
                            mobile: 20,
                            tablet: 22,
                            desktop: 24,
                          ),
                        ),
                      ),
                    ),
                    MobileOptimization.mobileIconButton(
                      icon: Icons.close,
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
            if (title != null)
              Divider(
                height: 24,
                thickness: 1,
              ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: MobileOptimization.getResponsivePadding(context),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
