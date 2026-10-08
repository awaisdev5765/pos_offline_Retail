import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Authenticated encryption and replay protection for LAN synchronization.
///
/// The pairing code never crosses the network. It is expanded with PBKDF2 and
/// every frame is protected with AES-256-GCM. A timestamp and unique message
/// identifier are encrypted with the payload to reject stale/replayed frames.
class SecureSyncCodec {
  SecureSyncCodec._(this._key);

  static const int minimumPairingCodeLength = 12;
  static const Duration maximumClockSkew = Duration(minutes: 5);
  static const int _maxRememberedMessageIds = 4096;
  static const List<int> _salt = <int>[
    0x52,
    0x65,
    0x74,
    0x61,
    0x69,
    0x6c,
    0x50,
    0x4f,
    0x53,
    0x2d,
    0x53,
    0x79,
    0x6e,
    0x63,
    0x2d,
    0x76,
    0x31,
  ];

  final SecretKey _key;
  final AesGcm _cipher = AesGcm.with256bits();
  final Set<String> _seenMessageIds = <String>{};
  final List<String> _seenMessageOrder = <String>[];

  static Future<SecureSyncCodec> fromPairingCode(String pairingCode) async {
    final normalized = pairingCode.trim();
    if (normalized.length < minimumPairingCodeLength) {
      throw ArgumentError(
        'Pairing code must contain at least $minimumPairingCodeLength characters.',
      );
    }

    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 210000,
      bits: 256,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(normalized)),
      nonce: _salt,
    );
    return SecureSyncCodec._(key);
  }

  Future<String> encode(Map<String, dynamic> message) async {
    final now = DateTime.now().toUtc();
    final nonce = _cipher.newNonce();
    final messageId = '${now.microsecondsSinceEpoch}-${base64UrlEncode(nonce)}';
    final clearText = utf8.encode(jsonEncode(<String, dynamic>{
      'messageId': messageId,
      'sentAt': now.toIso8601String(),
      'payload': message,
    }));
    final box = await _cipher.encrypt(
      clearText,
      secretKey: _key,
      nonce: nonce,
    );

    return jsonEncode(<String, dynamic>{
      'version': 1,
      'nonce': base64UrlEncode(box.nonce),
      'cipherText': base64UrlEncode(box.cipherText),
      'mac': base64UrlEncode(box.mac.bytes),
    });
  }

  Future<Map<String, dynamic>> decode(String frame) async {
    final envelope = jsonDecode(frame);
    if (envelope is! Map || envelope['version'] != 1) {
      throw const FormatException('Unsupported secure sync frame.');
    }

    final box = SecretBox(
      base64Url.decode(envelope['cipherText'] as String),
      nonce: base64Url.decode(envelope['nonce'] as String),
      mac: Mac(base64Url.decode(envelope['mac'] as String)),
    );
    final clearText = await _cipher.decrypt(box, secretKey: _key);
    final decoded = jsonDecode(utf8.decode(clearText));
    if (decoded is! Map) {
      throw const FormatException('Invalid secure sync payload.');
    }

    final messageId = decoded['messageId'] as String?;
    final sentAtText = decoded['sentAt'] as String?;
    final payload = decoded['payload'];
    if (messageId == null || sentAtText == null || payload is! Map) {
      throw const FormatException('Incomplete secure sync payload.');
    }

    final sentAt = DateTime.tryParse(sentAtText)?.toUtc();
    if (sentAt == null ||
        DateTime.now().toUtc().difference(sentAt).abs() > maximumClockSkew) {
      throw const FormatException('Expired secure sync frame.');
    }
    if (_seenMessageIds.contains(messageId)) {
      throw const FormatException('Replayed secure sync frame.');
    }
    _rememberMessageId(messageId);

    return payload.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  void _rememberMessageId(String messageId) {
    _seenMessageIds.add(messageId);
    _seenMessageOrder.add(messageId);
    if (_seenMessageOrder.length > _maxRememberedMessageIds) {
      final expired = _seenMessageOrder.removeAt(0);
      _seenMessageIds.remove(expired);
    }
  }
}
