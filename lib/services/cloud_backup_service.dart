import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Legacy public-host uploader.
///
/// Plain POS databases must never be sent to anonymous file hosts. This
/// service now accepts only an explicitly encrypted `.enc` artifact; callers
/// must use an authenticated encryption workflow before invoking it.
class CloudBackupService {
  static const Duration _timeout = Duration(minutes: 3);

  /// Uploads [filePath] and returns a public HTTPS URL, or throws on failure.
  static Future<String> uploadBackupFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Backup file not found');
    }
    if (!filePath.toLowerCase().endsWith('.enc')) {
      throw StateError(
          'Online backup blocked: encrypt the backup before uploading.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Backup file is empty');
    }

    final fileName = p.basename(filePath);
    String? url = await _tryTransferSh(fileName, bytes);
    url ??= await _try0x0St(filePath);

    if (url == null || url.isEmpty) {
      throw Exception(
          'Online upload failed. Check your internet connection and try again.');
    }
    return url.trim();
  }

  static Future<String?> _tryTransferSh(
      String fileName, List<int> bytes) async {
    try {
      final encoded = Uri.encodeComponent(fileName);
      final uri = Uri.parse('https://transfer.sh/$encoded');
      final response = await http.put(uri, body: bytes).timeout(_timeout);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          response.body.startsWith('http')) {
        return response.body.trim();
      }
    } catch (_) {
      // fall through
    }
    return null;
  }

  static Future<String?> _try0x0St(String filePath) async {
    try {
      final uri = Uri.parse('https://0x0.st');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          response.body.startsWith('http')) {
        return response.body.trim();
      }
    } catch (_) {
      // fall through
    }
    return null;
  }
}
