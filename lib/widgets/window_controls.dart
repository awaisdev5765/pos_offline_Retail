import 'dart:io';
import 'package:flutter/material.dart';
import '../services/window_manager_service.dart';

/// Window control buttons for desktop platforms (minimize, maximize, close)
class WindowControls extends StatelessWidget {
  final bool showMinimize;
  final bool showMaximize;
  final bool showClose;
  final Color? iconColor;
  final double iconSize;

  const WindowControls({
    super.key,
    this.showMinimize = true,
    this.showMaximize = true,
    this.showClose = true,
    this.iconColor,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    // Only show on desktop platforms
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return const SizedBox.shrink();
    }

    final color = iconColor ?? Theme.of(context).iconTheme.color ?? Colors.black;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white70 : Colors.black87;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMinimize)
          _WindowControlButton(
            icon: Icons.remove,
            tooltip: 'Minimize',
            onPressed: () => WindowManagerService.minimize(),
            color: color,
            iconSize: iconSize,
          ),
        if (showMaximize)
          _WindowControlButton(
            icon: Icons.crop_square,
            tooltip: 'Maximize',
            onPressed: () => WindowManagerService.toggleMaximize(),
            color: color,
            iconSize: iconSize,
          ),
        if (showClose)
          _WindowControlButton(
            icon: Icons.close,
            tooltip: 'Close',
            onPressed: () => WindowManagerService.close(),
            color: color,
            iconSize: iconSize,
            isClose: true,
          ),
      ],
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  final double iconSize;
  final bool isClose;

  const _WindowControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    required this.iconSize,
    this.isClose = false,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).iconTheme.color ?? Colors.black87;
    final hoverColor = widget.isClose ? Colors.red : Colors.blue;

    return Tooltip(
      message: widget.tooltip,
      child: InkWell(
        onTap: widget.onPressed,
        onHover: (hovered) {
          setState(() {
            _isHovered = hovered;
          });
        },
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _isHovered ? hoverColor : color,
          ),
        ),
      ),
    );
  }
}

