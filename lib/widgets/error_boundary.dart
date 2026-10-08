import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/keyboard_error_utils.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? fallback;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool hasError = false;
  String? errorMessage;
  FlutterExceptionHandler? _previousErrorHandler;
  FlutterExceptionHandler? _errorHandler;
  bool _errorUpdateScheduled = false;

  @override
  void initState() {
    super.initState();

    _previousErrorHandler = FlutterError.onError;
    _errorHandler = (FlutterErrorDetails details) {
      // A lost desktop key-up event can briefly desynchronize Flutter's
      // internal keyboard state. It is recoverable and must not cascade
      // through nested boundaries or replace the POS with a fallback screen.
      if (isRecoverableKeyboardStateError(details.exception)) return;

      // Preserve logging/reporting installed by the application or Flutter.
      _previousErrorHandler?.call(details);

      if (!mounted || _errorUpdateScheduled) return;

      // Flutter may report an exception while a descendant is still building.
      // Calling setState synchronously here causes another exception and masks
      // the useful, original error. Update the fallback after that frame ends.
      _errorUpdateScheduled = true;
      final message = details.exceptionAsString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _errorUpdateScheduled = false;
        if (!mounted) return;
        setState(() {
          hasError = true;
          errorMessage = message;
        });
      });
    };
    FlutterError.onError = _errorHandler;
  }

  @override
  void dispose() {
    // Do not leave a callback that references a disposed State, and do not
    // overwrite a newer handler installed elsewhere in the application.
    if (identical(FlutterError.onError, _errorHandler)) {
      FlutterError.onError = _previousErrorHandler;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return widget.fallback ?? _buildErrorWidget();
    }

    return widget.child;
  }

  Widget _buildErrorWidget() {
    // ErrorBoundary is mounted above OfflinePosApp/MaterialApp. Its fallback
    // must therefore provide its own Directionality, Theme, Navigator and
    // MediaQuery instead of returning a bare Scaffold at the application root.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF206BC4)),
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The app encountered an unexpected error. Please try again.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          hasError = false;
                          errorMessage = null;
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        SystemNavigator.pop();
                      },
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Exit App'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SafeAreaWrapper extends StatelessWidget {
  final Widget child;

  const SafeAreaWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ErrorBoundary(
        child: child,
      ),
    );
  }
}
