import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/database_service.dart';
import '../services/license_service.dart';
import '../theme/app_theme.dart';
import '../services/multi_pc_bootstrapper.dart';
import '../services/network_discovery_service.dart';
import '../services/database_sync_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _loadingController;
  late Animation<double> _logoAnimation;
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Loading animation
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
  }

  void _startAnimations() async {
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadingController.forward();

    // Check if business is set up and navigate accordingly
    await _checkBusinessSetup();
  }

  Future<void> _checkBusinessSetup() async {
    try {
      // First check license status
      final licenseStatus = await LicenseService.checkLicenseStatus();

      if (!licenseStatus.isValid) {
        // License not valid, go to license activation
        if (mounted) {
          context.go('/license-activation');
        }
        return;
      }

      // License is valid, check business setup
      final database = ref.read(databaseServiceProvider);

      final settings = await database.getSettings();

      // Check if business setup is complete locally
      final businessSetupComplete =
          settings['business_setup_complete'] == 'true';
      final businessName = settings['business_name'];
      // Support both admin_username and admin_email for backward compatibility
      final adminUsername =
          settings['admin_username'] ?? settings['admin_email'];
      final adminPassword = settings['admin_password'];

      // Business is set up locally if flag is set AND we have name and admin credentials
      if (businessSetupComplete &&
          businessName != null &&
          adminUsername != null &&
          adminPassword != null) {
        // Business is set up locally, attempt to bootstrap and go to login
        try {
          await MultiPcBootstrapper().bootstrap(database);
        } catch (bootstrapError) {
          print('Multi-PC bootstrap warning: $bootstrapError');
        }

        if (mounted) {
          context.go('/login');
        }
        return;
      }

      // Business setup NOT complete locally - check if admin PC exists on network
      bool adminFoundOnNetwork = false;

      try {
        // Initialize network discovery to check for admin PC
        final discoveryService = NetworkDiscoveryService();
        await discoveryService.initialize();

        // Wait a bit for network discovery to find admin servers
        await Future.delayed(const Duration(seconds: 3));

        // Check if any admin servers were discovered
        final adminServers = discoveryService.adminServers;
        if (adminServers.isNotEmpty) {
          print(
              '✅ Admin PC found on network: ${adminServers.first.name} (${adminServers.first.address})');
          adminFoundOnNetwork = true;

          // Attempt to bootstrap and connect to admin PC
          try {
            final connected = await MultiPcBootstrapper()
                .bootstrap(database, timeout: const Duration(seconds: 10));

            if (connected) {
              print('✅ Successfully connected to admin PC');

              // Wait a bit for initial sync to complete
              await Future.delayed(const Duration(seconds: 2));

              // After connecting, check settings again (they should be synced from admin)
              final syncedSettings = await database.getSettings();
              final syncedBusinessSetupComplete =
                  syncedSettings['business_setup_complete'] == 'true';

              if (syncedBusinessSetupComplete) {
                print('✅ Business setup data synced from admin PC');
                // Go to login screen - employee/manager can login now
                if (mounted) {
                  context.go('/login');
                }
                return;
              }
            } else {
              print('⚠️ Failed to connect to admin PC, but admin exists');
            }
          } catch (bootstrapError) {
            print('❌ Error connecting to admin PC: $bootstrapError');
          }
        } else {
          print('ℹ️ No admin PC found on network');
        }
      } catch (networkError) {
        print('⚠️ Network discovery error: $networkError');
      }

      // If admin not found on network, go to business setup
      if (!adminFoundOnNetwork) {
        if (mounted) {
          context.go('/business-setup');
        }
      } else {
        // Admin was found but connection failed - still go to login
        // User can try to connect manually later or retry
        if (mounted) {
          context.go('/login');
        }
      }
    } catch (e) {
      print('❌ Error in business setup check: $e');
      // Error occurred, go to business setup
      if (mounted) {
        context.go('/business-setup');
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.primaryGradient,
            stops: [0.0, 0.32, 0.64, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _BackgroundPatternPainter(),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo with enhanced animation
                  AnimatedBuilder(
                    animation: _logoAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoAnimation.value.clamp(0.0, 1.0),
                        child: Container(
                          width: 360,
                          constraints: const BoxConstraints(maxWidth: 360),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.20),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.contain,
                            semanticLabel: 'Retail POS',
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // App Name with enhanced typography
                  AnimatedBuilder(
                    animation: _logoAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoAnimation.value.clamp(0.0, 1.0),
                        child: Column(
                          children: [
                            Text(
                              'splash.subtitle'.tr(),
                              style: AppTypography.section.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 44),

                  // Enhanced loading indicator
                  AnimatedBuilder(
                    animation: _loadingAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _loadingAnimation.value.clamp(0.0, 1.0),
                        child: Column(
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
                              'splash.initializing'.tr(),
                              style: AppTypography.cardSubtitle.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'splash.please_wait'.tr(),
                              style: AppTypography.cardSubtitle.copyWith(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Version info at bottom
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _loadingAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _loadingAnimation.value.clamp(0.0, 1.0),
                    child: Text(
                      'common.version'.tr(namedArgs: {'v': '1.0.0'}),
                      style: AppTypography.cardSubtitle.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for background pattern
class _BackgroundPatternPainter extends CustomPainter {
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
