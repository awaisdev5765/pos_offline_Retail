import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_notification_service.dart';
import 'low_stock_monitor_service.dart';
import '../theme/app_theme.dart';
import '../utils/keyboard_error_utils.dart';

class AppInitializationService {
  static bool _isInitialized = false;
  static String? _initializationError;

  /// Initialize the app with proper error handling
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize core services
      await _initializeCoreServices();

      // Initialize database
      await _initializeDatabase();

      // Initialize preferences
      await _initializePreferences();

      // Set up error handling
      _setupErrorHandling();

      _isInitialized = true;
      return true;
    } catch (e) {
      _initializationError = e.toString();
      debugPrint('App initialization failed: $e');
      return false;
    }
  }

  /// Initialize core services
  static Future<void> _initializeCoreServices() async {
    try {
      // System UI overlay style is now handled by ThemeAwareSystemUIService
      // This ensures it updates based on theme changes

      // Set preferred orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      // Initialize local notifications
      try {
        await LocalNotificationService().initialize();
        debugPrint('✅ Local notifications initialized');
      } catch (e) {
        debugPrint('⚠️ Failed to initialize local notifications: $e');
        // Don't throw, continue with initialization
      }
    } catch (e) {
      debugPrint('Failed to initialize core services: $e');
      // Don't throw, continue with initialization
    }
  }

  /// Initialize database
  static Future<void> _initializeDatabase() async {
    try {
      // Database initialization is handled by the provider
      // This is just a placeholder for any additional database setup
      debugPrint('Database initialization completed');
    } catch (e) {
      debugPrint('Database initialization failed: $e');
      throw Exception('Database initialization failed: $e');
    }
  }

  /// Initialize shared preferences
  static Future<void> _initializePreferences() async {
    try {
      await SharedPreferences.getInstance();
      debugPrint('SharedPreferences initialized');
    } catch (e) {
      debugPrint('SharedPreferences initialization failed: $e');
      // Don't throw, continue with initialization
    }
  }

  /// Set up global error handling
  static void _setupErrorHandling() {
    // Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      // Filter out harmless keyboard state assertions that are known Flutter issues
      if (isRecoverableKeyboardStateError(details.exception)) return;

      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    };

    // Platform errors
    PlatformDispatcher.instance.onError = (error, stack) {
      // Filter out keyboard assertions in platform errors too
      if (isRecoverableKeyboardStateError(error)) return true;

      debugPrint('Platform Error: $error');
      debugPrint('Stack trace: $stack');
      return true;
    };
  }

  /// Check if app is initialized
  static bool get isInitialized => _isInitialized;

  /// Get initialization error if any
  static String? get initializationError => _initializationError;

  /// Reset initialization state
  static void reset() {
    _isInitialized = false;
    _initializationError = null;
  }
}

/// App initialization widget
class AppInitializationWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const AppInitializationWrapper({
    super.key,
    required this.child,
    this.loadingWidget,
    this.errorWidget,
  });

  @override
  ConsumerState<AppInitializationWrapper> createState() =>
      _AppInitializationWrapperState();
}

class _AppInitializationWrapperState
    extends ConsumerState<AppInitializationWrapper> {
  bool _isInitializing = true;
  bool _initializationFailed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final success = await AppInitializationService.initialize();

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initializationFailed = !success;
          _errorMessage = AppInitializationService.initializationError;
        });

        // Start low stock monitoring after initialization
        if (success && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                final monitorService = ref.read(lowStockMonitorServiceProvider);
                // Start low stock monitoring using the WidgetRef from this ConsumerState
                monitorService.startMonitoring(ref,
                    interval: const Duration(minutes: 5));
              } catch (e) {
                debugPrint('⚠️ Failed to start low stock monitoring: $e');
              }
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initializationFailed = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return widget.loadingWidget ?? _buildLoadingWidget();
    }

    if (_initializationFailed) {
      return widget.errorWidget ?? _buildErrorWidget();
    }

    return widget.child;
  }

  Widget _buildLoadingWidget() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryColor,
                AppColors.primaryDark,
                AppColors.secondaryColor,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Background pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: _SplashBackgroundPatternPainter(),
                ),
              ),
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Colors.white.withValues(alpha: 0.95),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                          BoxShadow(
                            color:
                                AppColors.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background circle
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primaryColor.withValues(alpha: 0.1),
                                  AppColors.secondaryColor
                                      .withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          // Main icon
                          Icon(
                            Icons.point_of_sale_rounded,
                            size: 50,
                            color: AppColors.primaryColor,
                          ),
                          // Accent dots
                          Positioned(
                            top: 20,
                            right: 20,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.accentColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 25,
                            left: 25,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.secondaryColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // App Name
                    Column(
                      children: [
                        Text(
                          'Offline POS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Point of Sale System',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),
                    // Loading indicator
                    Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Initializing System...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait while we set up your POS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
                  'Initialization Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The app failed to initialize properly. Please try again.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      _errorMessage!,
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
                          _isInitializing = true;
                          _initializationFailed = false;
                          _errorMessage = null;
                        });
                        _initializeApp();
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text('common.retry'.tr()),
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
                      label: const Text('Exit'),
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

// Custom painter for background pattern
class _SplashBackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    // Draw circles pattern
    for (int i = 0; i < 20; i++) {
      final x = (i * 100.0) % size.width;
      final y = (i * 80.0) % size.height;
      final radius = 20 + (i % 3) * 10;

      canvas.drawCircle(
        Offset(x, y),
        radius.toDouble(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
