import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown for unknown URLs (catch-all) or [GoRouter] [GoRouter.errorBuilder].
class NavigationFallbackScreen extends StatelessWidget {
  const NavigationFallbackScreen.unknown({
    super.key,
    required this.location,
  }) : routingError = null;

  const NavigationFallbackScreen.error({
    super.key,
    required this.routingError,
    this.location,
  });

  final String? location;
  final Object? routingError;

  bool get _isUnknown => routingError == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = _isUnknown
        ? 'router.not_found_title'.tr()
        : 'router.error_title'.tr();
    final body = _isUnknown
        ? 'router.not_found_body'.tr()
        : 'router.error_body'.tr();
    final String? detail;
    if (_isUnknown) {
      detail = (location != null && location!.isNotEmpty)
          ? 'router.path_label'.tr(namedArgs: {'path': location!})
          : null;
    } else {
      final errText = '${routingError ?? ''}'.trim();
      final errLine = 'router.detail_label'.tr(namedArgs: {
        'detail': errText.isEmpty ? '—' : errText,
      });
      if (location != null && location!.isNotEmpty) {
        final pathLine =
            'router.path_label'.tr(namedArgs: {'path': location!});
        detail = '$pathLine\n\n$errLine';
      } else {
        detail = errLine;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isUnknown ? Icons.travel_explore_outlined : Icons.error_outline,
                    size: 56,
                    color: _isUnknown ? cs.primary : cs.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 16),
                    SelectableText(
                      detail,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.dashboard_outlined),
                    label: Text('router.go_dashboard'.tr()),
                  ),
                  if (context.canPop()) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: Text('router.go_back'.tr()),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
