import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/crypto/envelope.dart';
import 'package:mobile/core/crypto/vault_key.dart';

class _FakeSecureStore implements VaultKeySecureStore {
  Uint8List? saved;
  int saveCalls = 0;
  int clearCalls = 0;

  @override
  Future<void> save(Uint8List vaultKey) async {
    saved = vaultKey;
    saveCalls++;
  }

  @override
  Future<Uint8List?> load() async => saved;

  @override
  Future<void> clear() async {
    saved = null;
    clearCalls++;
  }
}

void main() {
  test('generates a 32-byte vault key', () async {
    final vk = await generateVaultKey();
    expect((await vk.extractBytes()).length, 32);
  });

  test('a password wrap round-trips the vault key', () async {
    final vk = await generateVaultKey();
    final kek = await generateVaultKey(); // any 32-byte key works as a stand-in KEK here

    final envelope = await wrapVaultKeyWithPasswordOrRecoveryKey(
      vaultKey: vk,
      keyEncryptionKey: kek,
    );
    final unwrapped = await unwrapVaultKeyWithPasswordOrRecoveryKey(
      envelope: envelope,
      keyEncryptionKey: kek,
    );

    expect(await unwrapped.extractBytes(), equals(await vk.extractBytes()));
  });

  test('an invite wrap round-trips the vault key and is not interchangeable with a password wrap', () async {
    final vk = await generateVaultKey();
    final ikek = await generateVaultKey();

    final envelope = await wrapVaultKeyWithInviteKey(
      vaultKey: vk,
      inviteKeyEncryptionKey: ikek,
    );
    final unwrapped = await unwrapVaultKeyWithInviteKey(
      envelope: envelope,
      inviteKeyEncryptionKey: ikek,
    );
    expect(await unwrapped.extractBytes(), equals(await vk.extractBytes()));

    // The same envelope must not unwrap under the password/recovery AAD.
    await expectLater(
      unwrapVaultKeyWithPasswordOrRecoveryKey(
        envelope: envelope,
        keyEncryptionKey: ikek,
      ),
      throwsA(isA<DecryptionFailedException>()),
    );
  });

  group('VaultKeyHolder background lock', () {
    test('is locked before any unlock', () {
      final holder = VaultKeyHolder();
      expect(holder.isUnlocked, isFalse);
    });

    test('unlock makes the key available', () async {
      final holder = VaultKeyHolder();
      final vk = await generateVaultKey();
      holder.unlock(vk);
      expect(holder.isUnlocked, isTrue);
    });

    test('short background does not lock', () async {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final holder = VaultKeyHolder(now: () => now);
      holder.unlock(await generateVaultKey());

      holder.enterBackground();
      now = now.add(const Duration(minutes: 4));
      holder.enterForeground();

      expect(holder.isUnlocked, isTrue);
    });

    test('background longer than the timeout locks the key', () async {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final holder = VaultKeyHolder(now: () => now);
      holder.unlock(await generateVaultKey());

      holder.enterBackground();
      now = now.add(const Duration(minutes: 6));
      holder.enterForeground();

      expect(holder.isUnlocked, isFalse);
    });

    test('exactly at the boundary does not lock (strictly greater-than triggers the lock)', () async {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final holder = VaultKeyHolder(now: () => now);
      holder.unlock(await generateVaultKey());

      holder.enterBackground();
      now = now.add(backgroundLockTimeout);
      holder.enterForeground();

      expect(holder.isUnlocked, isTrue);
    });

    test('foreground without a prior background is a no-op', () async {
      final holder = VaultKeyHolder();
      holder.unlock(await generateVaultKey());
      holder.enterForeground();
      expect(holder.isUnlocked, isTrue);
    });

    test('lock wipes the key', () async {
      final holder = VaultKeyHolder();
      holder.unlock(await generateVaultKey());
      holder.lock();
      expect(holder.isUnlocked, isFalse);
    });
  });

  group('VaultKeyHolder secure storage gating', () {
    test(
      'persistIfBiometricEnabled is a no-op without a configured store',
      () async {
        final holder = VaultKeyHolder();
        holder.unlock(await generateVaultKey());
        await holder.persistIfBiometricEnabled(); // must not throw
      },
    );

    test('persistIfBiometricEnabled saves the key bytes when a store is configured', () async {
      final store = _FakeSecureStore();
      final holder = VaultKeyHolder(secureStore: store);
      final vk = await generateVaultKey();
      holder.unlock(vk);

      await holder.persistIfBiometricEnabled();

      expect(store.saveCalls, 1);
      expect(store.saved, equals(await vk.extractBytes()));
    });

    test(
      'clearPersisted removes the stored key (biometric turned off)',
      () async {
        final store = _FakeSecureStore();
        final holder = VaultKeyHolder(secureStore: store);
        holder.unlock(await generateVaultKey());
        await holder.persistIfBiometricEnabled();

        await holder.clearPersisted();

        expect(store.clearCalls, 1);
        expect(store.saved, isNull);
      },
    );

    test('unlockFromPersisted applies a previously saved key', () async {
      final store = _FakeSecureStore();
      final writer = VaultKeyHolder(secureStore: store);
      final vk = await generateVaultKey();
      writer.unlock(vk);
      await writer.persistIfBiometricEnabled();

      final reader = VaultKeyHolder(secureStore: store);
      expect(reader.isUnlocked, isFalse);
      final applied = await reader.unlockFromPersisted();

      expect(applied, isTrue);
      expect(reader.isUnlocked, isTrue);
      expect(
        await reader.keyOrNull!.extractBytes(),
        equals(await vk.extractBytes()),
      );
    });

    test('unlockFromPersisted reports false when nothing was saved', () async {
      final holder = VaultKeyHolder(secureStore: _FakeSecureStore());
      final applied = await holder.unlockFromPersisted();
      expect(applied, isFalse);
      expect(holder.isUnlocked, isFalse);
    });

    test('unlockFromPersisted is a no-op without a configured store', () async {
      final holder = VaultKeyHolder();
      final applied = await holder.unlockFromPersisted();
      expect(applied, isFalse);
    });
  });
}
