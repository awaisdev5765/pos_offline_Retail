import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_snack_bar.dart';

class AppRestartService {
  static Future<void> restartApp(BuildContext context) async {
    try {
      // Method 1: Using SystemNavigator (works on most platforms)
      await SystemNavigator.pop();

      // Method 2: Alternative approach for some platforms
      // This might not work on all platforms, but it's worth trying
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    } catch (e) {
      // If the above methods fail, show a dialog asking user to restart manually
      _showRestartDialog(context);
    }
  }

  static void _showRestartDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('App Restart Required'),
          content: const Text(
            'The app needs to be restarted to apply the currency change. '
            'Please close and reopen the app manually.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Try to exit the app
                SystemNavigator.pop();
              },
              child: Text('common.ok'.tr()),
            ),
          ],
        );
      },
    );
  }

  /// Alternative method using platform channels
  static Future<void> restartAppWithPlatformChannel() async {
    try {
      const platform = MethodChannel('app_restart');
      await platform.invokeMethod('restart');
    } catch (e) {
      // Fallback to SystemNavigator
      await SystemNavigator.pop();
    }
  }

  /// Show a snackbar with restart instruction
  static void showRestartSnackBar(BuildContext context) {
    AppSnackBar.show(
      context,
      SnackBar(
        content: const Text('Please restart the app to apply currency changes'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Restart',
          onPressed: () {},
        ),
      ),
    );
  }
}
