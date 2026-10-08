import 'package:flutter/material.dart';
import 'dart:io';

/// A Fluent UI-style button for Windows 11 design language
/// 
/// This widget provides a button that follows Windows 11 Fluent Design principles
/// with rounded corners, smooth animations, and modern styling.
class WindowsFluentButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final double borderRadius;

  const WindowsFluentButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height,
    this.padding,
    this.borderRadius = 4.0,
  }) : super(key: key);

  @override
  State<WindowsFluentButton> createState() => _WindowsFluentButtonState();
}

class _WindowsFluentButtonState extends State<WindowsFluentButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getBackgroundColor(ThemeData theme) {
    if (!Platform.isWindows) {
      return widget.backgroundColor ?? theme.colorScheme.primary;
    }

    if (widget.onPressed == null) {
      return widget.backgroundColor?.withOpacity(0.3) ??
          theme.colorScheme.primary.withOpacity(0.3);
    }

    if (_isPressed) {
      return widget.backgroundColor?.withOpacity(0.8) ??
          theme.colorScheme.primary.withOpacity(0.8);
    }

    if (_isHovered) {
      return widget.backgroundColor?.withOpacity(0.9) ??
          theme.colorScheme.primary.withOpacity(0.9);
    }

    return widget.backgroundColor ?? theme.colorScheme.primary;
  }

  Color _getForegroundColor(ThemeData theme) {
    return widget.foregroundColor ?? theme.colorScheme.onPrimary;
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      // Fallback to standard Material button on non-Windows platforms
      return ElevatedButton(
        onPressed: widget.onPressed,
        child: widget.icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 18),
                  const SizedBox(width: 8),
                  Text(widget.text),
                ],
              )
            : Text(widget.text),
      );
    }

    final theme = Theme.of(context);
    final backgroundColor = _getBackgroundColor(theme);
    final foregroundColor = _getForegroundColor(theme);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
        },
        onExit: (_) {
          setState(() => _isHovered = false);
        },
        child: GestureDetector(
          onTapDown: (_) {
            setState(() => _isPressed = true);
            _animationController.forward();
          },
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _animationController.reverse();
            widget.onPressed?.call();
          },
          onTapCancel: () {
            setState(() => _isPressed = false);
            _animationController.reverse();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: widget.width,
            height: widget.height ?? 40,
            padding: widget.padding ??
                const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: backgroundColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 18,
                    color: foregroundColor,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.text,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A Fluent UI-style card widget for Windows 11
class WindowsFluentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final double borderRadius;
  final VoidCallback? onTap;

  const WindowsFluentCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius = 8.0,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return Card(
        margin: margin,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      );
    }

    final theme = Theme.of(context);
    final bgColor = backgroundColor ??
        (theme.brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.grey[50]);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

