import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Versioned password hashing with legacy SHA-256 verification support.
///
/// New credentials use PBKDF2-HMAC-SHA256 with a unique random salt. Existing
/// 64-character SHA-256 hashes remain verifiable so installations can migrate
/// credentials after a successful login without locking users out.
class PasswordHasher {
  static const String _algorithm = 'pbkdf2_sha256';
  static const int _iterations = 120000;
  static const int _saltLength = 16;
  static const int _keyLength = 32;

  static String hash(String password) {
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty.');
    }
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => random.nextInt(256)),
    );
    final derived = _pbkdf2(utf8.encode(password), salt, _iterations);
    return '$_algorithm\$$_iterations\$${base64UrlEncode(salt)}\$${base64UrlEncode(derived)}';
  }

  static bool verify(String password, String encodedHash) {
    if (encodedHash.startsWith('$_algorithm\$')) {
      final parts = encodedHash.split(r'$');
      if (parts.length != 4) return false;
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations < 10000 || iterations > 1000000) {
        return false;
      }
      try {
        final salt = base64Url.decode(base64Url.normalize(parts[2]));
        final expected = base64Url.decode(base64Url.normalize(parts[3]));
        final actual = _pbkdf2(utf8.encode(password), salt, iterations,
            keyLength: expected.length);
        return _constantTimeEquals(actual, expected);
      } on FormatException {
        return false;
      }
    }

    // Compatibility with credentials created by older app versions.
    final legacy = sha256.convert(utf8.encode(password)).bytes;
    final expectedLegacy = _decodeHex(encodedHash);
    return expectedLegacy != null &&
        _constantTimeEquals(legacy, expectedLegacy);
  }

  static bool get needsUpgrade => true;

  static bool isLegacyHash(String encodedHash) =>
      !encodedHash.startsWith('$_algorithm\$');

  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations, {
    int keyLength = _keyLength,
  }) {
    final hmac = Hmac(sha256, password);
    final blockCount = (keyLength / 32).ceil();
    final result = BytesBuilder(copy: false);

    for (var block = 1; block <= blockCount; block++) {
      final initial = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..[salt.length] = (block >> 24) & 0xff
        ..[salt.length + 1] = (block >> 16) & 0xff
        ..[salt.length + 2] = (block >> 8) & 0xff
        ..[salt.length + 3] = block & 0xff;

      var u = Uint8List.fromList(hmac.convert(initial).bytes);
      final output = Uint8List.fromList(u);
      for (var round = 1; round < iterations; round++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var i = 0; i < output.length; i++) {
          output[i] ^= u[i];
        }
      }
      result.add(output);
    }

    return Uint8List.fromList(result.takeBytes().take(keyLength).toList());
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  static Uint8List? _decodeHex(String value) {
    if (value.length != 64 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
      return null;
    }
    return Uint8List.fromList(List<int>.generate(
      value.length ~/ 2,
      (i) => int.parse(value.substring(i * 2, i * 2 + 2), radix: 16),
    ));
  }
}
