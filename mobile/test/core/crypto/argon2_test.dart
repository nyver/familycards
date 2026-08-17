import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/crypto/argon2.dart';

void main() {
  // Deliberately tiny parameters so the test suite stays fast; the real
  // app uses Argon2Params.defaults (64 MiB) as mandated by the spec.
  const testParams = Argon2Params(memoryKiB: 8, iterations: 1, parallelism: 1);

  test('Argon2Params round-trips through JSON', () {
    final json = Argon2Params.defaults.toJson();
    expect(json, {'m': 65536, 't': 3, 'p': 1});

    final parsed = Argon2Params.fromJson(json);
    expect(parsed.memoryKiB, 65536);
    expect(parsed.iterations, 3);
    expect(parsed.parallelism, 1);
  });

  test(
    'deriving the same password and salt twice yields the same key',
    () async {
      final salt = List.generate(16, (i) => i);
      final key1 = await deriveKeyEncryptionKey(
        password: 'hunter2',
        salt: salt,
        params: testParams,
      );
      final key2 = await deriveKeyEncryptionKey(
        password: 'hunter2',
        salt: salt,
        params: testParams,
      );

      expect(await key1.extractBytes(), equals(await key2.extractBytes()));
    },
  );

  test(
    'different salts produce different keys for the same password',
    () async {
      final key1 = await deriveKeyEncryptionKey(
        password: 'hunter2',
        salt: List.filled(16, 1),
        params: testParams,
      );
      final key2 = await deriveKeyEncryptionKey(
        password: 'hunter2',
        salt: List.filled(16, 2),
        params: testParams,
      );

      expect(
        await key1.extractBytes(),
        isNot(equals(await key2.extractBytes())),
      );
    },
  );

  test(
    'different passwords produce different keys for the same salt',
    () async {
      final salt = List.generate(16, (i) => i);
      final key1 = await deriveKeyEncryptionKey(
        password: 'password-a',
        salt: salt,
        params: testParams,
      );
      final key2 = await deriveKeyEncryptionKey(
        password: 'password-b',
        salt: salt,
        params: testParams,
      );

      expect(
        await key1.extractBytes(),
        isNot(equals(await key2.extractBytes())),
      );
    },
  );

  test('derives a 32-byte key', () async {
    final salt = List.generate(16, (i) => i);
    final key = await deriveKeyEncryptionKey(
      password: 'hunter2',
      salt: salt,
      params: testParams,
    );
    expect((await key.extractBytes()).length, 32);
  });
}
