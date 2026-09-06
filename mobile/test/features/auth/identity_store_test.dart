import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/identity_store.dart';

import '../../test_helpers/in_memory_key_value_store.dart';

void main() {
  late IdentityStore store;

  setUp(() {
    store = IdentityStore(storage: InMemoryKeyValueStore());
  });

  StoredIdentity sampleIdentity({String serverAddress = 'https://old.example.com'}) {
    return StoredIdentity(
      serverAddress: serverAddress,
      userId: 'user-1',
      vaultId: 'vault-1',
      deviceId: 'device-1',
      login: 'alice',
      displayName: 'Alice',
      kdfSalt: 'salt',
      kdfParams: const {'m': 1},
      wrappedVaultKey: 'wrapped',
      wrapNonce: 'nonce',
    );
  }

  test('getPinnedCertificateFingerprint is null when nothing was pinned', () async {
    expect(await store.getPinnedCertificateFingerprint(), isNull);
  });

  test('setPinnedCertificateFingerprint persists and reads back the value', () async {
    await store.setPinnedCertificateFingerprint('AA:BB:CC');
    expect(await store.getPinnedCertificateFingerprint(), 'AA:BB:CC');
  });

  test('setPinnedCertificateFingerprint(null) clears a previously set pin', () async {
    await store.setPinnedCertificateFingerprint('AA:BB:CC');
    await store.setPinnedCertificateFingerprint(null);
    expect(await store.getPinnedCertificateFingerprint(), isNull);
  });

  test('clearAll deletes the identity, server address, and pinned fingerprint', () async {
    await store.save(sampleIdentity());
    await store.setServerAddress('https://old.example.com');
    await store.setPinnedCertificateFingerprint('AA:BB:CC');

    await store.clearAll();

    expect(await store.load(), isNull);
    expect(await store.getServerAddress(), isNull);
    expect(
      await store.getPinnedCertificateFingerprint(),
      isNull,
      reason: 'a stale pin from the old server must not survive clearAll',
    );
  });

  test('clearIdentity keeps the server address and pinned fingerprint', () async {
    await store.save(sampleIdentity());
    await store.setPinnedCertificateFingerprint('AA:BB:CC');

    await store.clearIdentity();

    expect(await store.load(), isNull);
    expect(await store.getServerAddress(), 'https://old.example.com');
    expect(
      await store.getPinnedCertificateFingerprint(),
      'AA:BB:CC',
      reason: 'signing out must not lose the pin for the current server',
    );
  });
}
