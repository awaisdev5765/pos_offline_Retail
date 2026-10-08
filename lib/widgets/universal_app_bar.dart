import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class UniversalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final String? fallbackRoute;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool centerTitle;
  final Widget? flexibleSpace;

  const UniversalAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.fallbackRoute,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle = true,
    this.flexibleSpace,
  });

  @override
  Widget build(BuildContext context) {
    final isWindowsDesktop =
        Theme.of(context).platform == TargetPlatform.windows &&
            MediaQuery.of(context).size.width >= 768;

    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading ?? _buildDefaultLeading(context),
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor:
          backgroundColor ?? (isWindowsDesktop ? AppColors.surfaceLight : null),
      foregroundColor:
          foregroundColor ?? (isWindowsDesktop ? AppColors.textPrimary : null),
      elevation: elevation ?? (isWindowsDesktop ? 0 : null),
      centerTitle: isWindowsDesktop ? false : centerTitle,
      toolbarHeight: isWindowsDesktop ? 58 : kToolbarHeight,
      bottom: isWindowsDesktop
          ? const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1),
            )
          : null,
      flexibleSpace: flexibleSpace,
    );
  }

  Widget _buildDefaultLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => _handleBackNavigation(context),
      tooltip: 'Back',
    );
  }

  void _handleBackNavigation(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else if (fallbackRoute != null) {
      context.go(fallbackRoute!);
    } else {
      // Default fallback to dashboard
      context.go('/');
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class UniversalSliverAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final String? fallbackRoute;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool pinned;
  final bool floating;
  final double? expandedHeight;
  final Widget? flexibleSpace;

  const UniversalSliverAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.fallbackRoute,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.pinned = true,
    this.floating = false,
    this.expandedHeight,
    this.flexibleSpace,
  });

  @override
  Widget build(BuildContext context) {
    final isWindowsDesktop =
        Theme.of(context).platform == TargetPlatform.windows &&
            MediaQuery.of(context).size.width >= 768;

    return SliverAppBar(
      title: Text(title),
      actions: actions,
      leading: leading ?? _buildDefaultLeading(context),
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor:
          backgroundColor ?? (isWindowsDesktop ? AppColors.surfaceLight : null),
      foregroundColor:
          foregroundColor ?? (isWindowsDesktop ? AppColors.textPrimary : null),
      elevation: elevation ?? (isWindowsDesktop ? 0 : null),
      pinned: pinned,
      floating: floating,
      expandedHeight: expandedHeight,
      flexibleSpace: flexibleSpace,
    );
  }

  Widget _buildDefaultLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => _handleBackNavigation(context),
      tooltip: 'Back',
    );
  }

  void _handleBackNavigation(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else if (fallbackRoute != null) {
      context.go(fallbackRoute!);
    } else {
      // Default fallback to dashboard
      context.go('/');
    }
  }
}

// Enhanced AppBar with refresh functionality
class RefreshableAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final String? fallbackRoute;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool centerTitle;
  final Widget? flexibleSpace;
  final VoidCallback? onRefresh;

  const RefreshableAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.fallbackRoute,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle = true,
    this.flexibleSpace,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isWindowsDesktop =
        Theme.of(context).platform == TargetPlatform.windows &&
            MediaQuery.of(context).size.width >= 768;

    final List<Widget> appBarActions = [
      if (onRefresh != null)
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh,
          tooltip: 'common.refresh_data'.tr(),
        ),
      if (actions != null) ...actions!,
    ];

    return AppBar(
      title: Text(title),
      actions: appBarActions,
      leading: leading ?? _buildDefaultLeading(context),
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor:
          backgroundColor ?? (isWindowsDesktop ? AppColors.surfaceLight : null),
      foregroundColor:
          foregroundColor ?? (isWindowsDesktop ? AppColors.textPrimary : null),
      elevation: elevation ?? (isWindowsDesktop ? 0 : null),
      centerTitle: isWindowsDesktop ? false : centerTitle,
      toolbarHeight: isWindowsDesktop ? 58 : kToolbarHeight,
      bottom: isWindowsDesktop
          ? const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1),
            )
          : null,
      flexibleSpace: flexibleSpace,
    );
  }

  Widget _buildDefaultLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => _handleBackNavigation(context),
      tooltip: 'Back',
    );
  }

  void _handleBackNavigation(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else if (fallbackRoute != null) {
      context.go(fallbackRoute!);
    } else {
      // Default fallback to dashboard
      context.go('/');
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
