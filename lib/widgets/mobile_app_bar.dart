import 'package:flutter/material.dart';
import '../utils/mobile_optimization.dart';

/// Mobile-optimized AppBar widget
class MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final PreferredSizeWidget? bottom;

  const MobileAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.bottom,
  }) : assert(title == null || titleWidget == null,
            'Cannot provide both title and titleWidget');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AppBar(
      title: titleWidget ?? (title != null ? Text(title!) : null),
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ?? theme.appBarTheme.backgroundColor,
      foregroundColor: foregroundColor ?? theme.appBarTheme.foregroundColor,
      elevation: elevation ?? theme.appBarTheme.elevation,
      bottom: bottom,
      actions: actions?.map((action) {
        // Wrap IconButtons with mobile optimization
        if (action is IconButton) {
          return MobileOptimization.mobileIconButton(
            icon: action.icon as IconData,
            onPressed: action.onPressed,
            tooltip: action.tooltip,
            color: action.color,
          );
        }
        return action;
      }).toList(),
      toolbarHeight: MobileOptimization.getAppBarHeight(context),
    );
  }

  @override
  Size get preferredSize {
    // Default AppBar height if context is not available
    final defaultHeight = 56.0;
    return Size.fromHeight(
      defaultHeight + (bottom?.preferredSize.height ?? 0),
    );
  }
}

