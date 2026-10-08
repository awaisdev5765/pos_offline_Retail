import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppSnackBar {
  static OverlayEntry? _activeEntry;

  static void show(BuildContext context, SnackBar snackBar) {
    if (_shouldUseDesktopToast) {
      _showDesktopToast(context, snackBar);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static bool get _shouldUseDesktopToast {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static void _showDesktopToast(BuildContext context, SnackBar snackBar) {
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    _activeEntry?.remove();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _DesktopSnackBar(
        snackBar: snackBar,
        onDismissed: () {
          if (_activeEntry == entry) {
            _activeEntry = null;
          }
          entry.remove();
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }
}

class _DesktopSnackBar extends StatefulWidget {
  const _DesktopSnackBar({
    required this.snackBar,
    required this.onDismissed,
  });

  final SnackBar snackBar;
  final VoidCallback onDismissed;

  @override
  State<_DesktopSnackBar> createState() => _DesktopSnackBarState();
}

class _DesktopSnackBarState extends State<_DesktopSnackBar>
    with SingleTickerProviderStateMixin {
  static const Duration _animationDuration = Duration(milliseconds: 250);
  static const Duration _displayDuration = Duration(seconds: 1);

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(_displayDuration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismissed();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24, right: 24),
            child: IgnorePointer(
              ignoring: false,
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      color: widget.snackBar.backgroundColor ??
                          Theme.of(context).colorScheme.inverseSurface,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: DefaultTextStyle(
                                style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.white) ??
                                    const TextStyle(color: Colors.white),
                                child: widget.snackBar.content,
                              ),
                            ),
                            if (widget.snackBar.action != null) ...[
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: () {
                                  widget.snackBar.action!.onPressed();
                                  _controller.reverse().then((_) {
                                    widget.onDismissed();
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(widget.snackBar.action!.label),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
