import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pos_system/services/secure_sync_codec.dart';

void main() {
  test('round trips an encrypted sync message', () async {
    final sender = await SecureSyncCodec.fromPairingCode('shop-secret-1234');
    final receiver = await SecureSyncCodec.fromPairingCode('shop-secret-1234');

    final frame = await sender.encode({
      'type': 'data_update',
      'data': {'sales': <dynamic>[]},
    });
    final decoded = await receiver.decode(frame);

    expect(decoded['type'], 'data_update');
    expect(decoded['data'], isA<Map>());
    expect(frame, isNot(contains('data_update')));
  });

  test('rejects a wrong pairing code', () async {
    final sender = await SecureSyncCodec.fromPairingCode('shop-secret-1234');
    final receiver = await SecureSyncCodec.fromPairingCode('wrong-secret-5678');

    final frame = await sender.encode({'type': 'heartbeat'});

    expect(() => receiver.decode(frame), throwsA(anything));
  });

  test('rejects a modified encrypted frame', () async {
    final sender = await SecureSyncCodec.fromPairingCode('shop-secret-1234');
    final receiver = await SecureSyncCodec.fromPairingCode('shop-secret-1234');
    final envelope = jsonDecode(await sender.encode({'type': 'heartbeat'}))
        as Map<String, dynamic>;
    final cipherText = envelope['cipherText'] as String;
    envelope['cipherText'] =
        '${cipherText.substring(0, cipherText.length - 2)}AA';

    expect(() => receiver.decode(jsonEncode(envelope)), throwsA(anything));
  });

  test('rejects replayed frames', () async {
    final sender = await SecureSyncCodec.fromPairingCode('shop-secret-1234');
    final receiver = await SecureSyncCodec.fromPairingCode('shop-secret-1234');
    final frame = await sender.encode({'type': 'heartbeat'});

    await receiver.decode(frame);

    expect(() => receiver.decode(frame), throwsA(isA<FormatException>()));
  });

  test('requires a strong pairing code', () {
    expect(
      () => SecureSyncCodec.fromPairingCode('short'),
      throwsArgumentError,
    );
  });
}
