import 'dart:convert';
import 'dart:typed_data';

import '../storage/key_value_store.dart';
import 'vault_key.dart';

/// Real [VaultKeySecureStore] backed by the platform secure storage
/// (Keychain/EncryptedSharedPreferences via [KeyValueStore]). Only ever
/// written to while biometric unlock is enabled - see
/// features/settings/security_screen.dart.
class SecureVaultKeyStore implements VaultKeySecureStore {
  final KeyValueStore _storage;

  static const _key = 'vault_key.persisted';

  SecureVaultKeyStore({KeyValueStore? storage})
    : _storage = storage ?? SecureKeyValueStore();

  @override
  Future<void> save(Uint8List vaultKey) =>
      _storage.write(_key, base64Encode(vaultKey));

  @override
  Future<Uint8List?> load() async {
    final raw = await _storage.read(_key);
    if (raw == null) return null;
    return base64Decode(raw);
  }

  @override
  Future<void> clear() => _storage.delete(_key);
}
