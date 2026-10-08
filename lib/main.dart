import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'providers/theme_provider.dart';
import 'widgets/error_boundary.dart';
import 'services/app_initialization_service.dart';
import 'services/windows_backup_service.dart';
import 'services/window_manager_service.dart';
import 'services/system_tray_service.dart';
import 'services/theme_aware_system_ui_service.dart';
import 'database/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Initialize SharedPreferences early (especially important for Android)
  // This ensures theme persistence works correctly
  try {
    await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('Warning: Could not initialize SharedPreferences: $e');
  }

  // Initialize window manager for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await WindowManagerService.initialize();
    await SystemTrayService.initialize();
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize theme-aware system UI (especially for Android)
  ThemeAwareSystemUIService.initializeForAndroid();

  // Initialize Windows backup service if on Windows
  if (Platform.isWindows) {
    try {
      final database = AppDatabase();
      await WindowsBackupService.initializeAutoBackup(database);
      print('✅ Windows backup service initialized');
    } catch (e) {
      print('⚠️ Windows backup service initialization failed: $e');
    }
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('ar'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      saveLocale: true,
      child: const ProviderScope(
        child: AppInitializationWrapper(
          child: ErrorBoundary(
            child: OfflinePosApp(),
          ),
        ),
      ),
    ),
  );
}

class OfflinePosApp extends StatelessWidget {
  const OfflinePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone X design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, child) {
            try {
              // Ensure theme is initialized before building
              final themeInitialized = ref.watch(themeModeInitializedProvider);
              final themeMode = ref.watch(themeModeProvider);
              final brandCustomization = ref.watch(brandCustomizationProvider);
              
              // Show loading while theme initializes (only on first build)
              if (themeInitialized.isLoading) {
                return MaterialApp(
                  title: brandCustomization.businessName ?? 'Offline POS System',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: ThemeMode.system,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  home: const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }

              // Update system UI based on theme
              final brightness = themeMode == ThemeMode.dark
                  ? Brightness.dark
                  : themeMode == ThemeMode.light
                      ? Brightness.light
                      : MediaQuery.of(context).platformBrightness;
              
              // Update system UI overlay style when theme changes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ThemeAwareSystemUIService.updateSystemUIOverlayStyle(context, brightness);
              });

              return MaterialApp.router(
                title: brandCustomization.businessName ?? 'Offline POS System',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                routerConfig: AppRouter.router,
                builder: (context, child) {
                  // Update system UI in builder to ensure context is available
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ThemeAwareSystemUIService.updateSystemUIOverlayStyleFromThemeMode(
                      context,
                      themeMode,
                    );
                  });
                  
                  _registerWindowsCloseHandler(context);
                  return WillPopScope(
                    onWillPop: () async {
                      final shouldExit =
                          await _showExitConfirmationDialog(context);
                      return shouldExit;
                    },
                    child: MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: const TextScaler.linear(1.0)),
                      child: child ?? const SizedBox.shrink(),
                    ),
                  );
                },
              );
            } catch (e) {
              // Fallback UI in case of provider errors
              return MaterialApp(
                title: 'Offline POS System',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('app.init_error'.tr()),
                        const SizedBox(height: 8),
                        Text('Error: $e'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            // Restart the app
                            SystemNavigator.pop();
                          },
                          child: Text('app.restart'.tr()),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}

bool _closeHandlerRegistered = false;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _registerWindowsCloseHandler(BuildContext context) {
  if (!Platform.isWindows || _closeHandlerRegistered) return;
  final rootContext = navigatorKey.currentContext ?? context;
  SystemChannels.platform.setMethodCallHandler((call) async {
    if (call.method == 'SystemNavigator.pop') {
      final shouldExit = await _showExitConfirmationDialog(rootContext);
      if (shouldExit) {
        exit(0);
      }
      return null;
    }
    return null;
  });
  _closeHandlerRegistered = true;
}

Future<bool> _showExitConfirmationDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: Text('app.exit_title'.tr()),
        content: Text('app.exit_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('app.no'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('app.yes'.tr()),
          ),
        ],
      );
    },
  );

  if (result == true) {
    if (Navigator.of(context).canPop()) {
      return true;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      await SystemNavigator.pop();
      return false;
    }
    exit(0);
  }
  return false;
}
