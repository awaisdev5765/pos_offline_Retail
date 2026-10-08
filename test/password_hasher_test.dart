import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pos_system/utils/password_hasher.dart';

void main() {
  test('new password hashes are salted and verifiable', () {
    final first = PasswordHasher.hash('Correct Horse Battery Staple');
    final second = PasswordHasher.hash('Correct Horse Battery Staple');

    expect(first, isNot(second));
    expect(
        PasswordHasher.verify('Correct Horse Battery Staple', first), isTrue);
    expect(PasswordHasher.verify('wrong password', first), isFalse);
  });

  test('legacy SHA-256 credentials remain verifiable for migration', () {
    const password = 'legacy-password';
    final legacy = sha256.convert(utf8.encode(password)).toString();

    expect(PasswordHasher.isLegacyHash(legacy), isTrue);
    expect(PasswordHasher.verify(password, legacy), isTrue);
    expect(PasswordHasher.verify('wrong', legacy), isFalse);
  });
}
