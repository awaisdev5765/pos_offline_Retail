import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../widgets/app_snack_bar.dart';

class ClipboardService {
  /// Copy text to clipboard
  static Future<bool> copyToClipboard(String text, BuildContext? context) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context != null && context.mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Copied to clipboard'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      if (context != null && context.mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Failed to copy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Get text from clipboard
  static Future<String?> getFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      return clipboardData?.text;
    } catch (e) {
      return null;
    }
  }

  /// Paste text from clipboard (returns the text, doesn't show UI)
  static Future<String?> pasteFromClipboard() async {
    return await getFromClipboard();
  }

  /// Check if clipboard has text
  static Future<bool> hasText() async {
    final text = await getFromClipboard();
    return text != null && text.isNotEmpty;
  }

  /// Copy text without showing notification
  static Future<bool> copySilently(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (e) {
      return false;
    }
  }
}

