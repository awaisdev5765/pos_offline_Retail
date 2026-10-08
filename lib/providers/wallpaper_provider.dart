import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dashboardWallpaperProvider =
    StateNotifierProvider<DashboardWallpaperNotifier, String?>(
  (ref) => DashboardWallpaperNotifier(),
);

class DashboardWallpaperNotifier extends StateNotifier<String?> {
  DashboardWallpaperNotifier() : super(null) {
    _loadWallpaper();
  }

  static const _prefsKey = 'dashboard_wallpaper_path';

  Future<void> _loadWallpaper() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPath = prefs.getString(_prefsKey);
      if (storedPath == null) {
        state = null;
        return;
      }

      final file = File(storedPath);
      if (await file.exists()) {
        state = storedPath;
      } else {
        await prefs.remove(_prefsKey);
        state = null;
      }
    } catch (e) {
      state = null;
    }
  }

  Future<void> setWallpaperFromBytes(
    Uint8List bytes, {
    String? fileExtension,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final wallpapersDir = Directory(p.join(directory.path, 'wallpapers'));
      if (!await wallpapersDir.exists()) {
        await wallpapersDir.create(recursive: true);
      }

      final sanitizedExtension = _sanitizeExtension(fileExtension);
      final fileName =
          'dashboard_wallpaper_${DateTime.now().millisecondsSinceEpoch}$sanitizedExtension';
      final targetFile = File(p.join(wallpapersDir.path, fileName));

      if (state != null && state != targetFile.path) {
        final previousFile = File(state!);
        if (await previousFile.exists()) {
          await previousFile.delete();
        }
      }

      await targetFile.writeAsBytes(bytes, flush: true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, targetFile.path);

      state = targetFile.path;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setWallpaperFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Selected file does not exist.', path);
    }

    final bytes = await file.readAsBytes();
    await setWallpaperFromBytes(bytes, fileExtension: p.extension(path));
  }

  Future<void> resetWallpaper() async {
    try {
      if (state != null) {
        final file = File(state!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } finally {
      state = null;
    }
  }

  String _sanitizeExtension(String? extension) {
    if (extension == null || extension.trim().isEmpty) {
      return '.jpg';
    }
    var ext = extension.trim();
    if (!ext.startsWith('.')) {
      ext = '.$ext';
    }
    if (ext.length > 10) {
      ext = ext.substring(0, 10);
    }
    return ext;
  }
}
