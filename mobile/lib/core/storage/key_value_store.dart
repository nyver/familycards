import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A minimal secure string key-value store, abstracted away from
/// `flutter_secure_storage`'s concrete platform-channel-backed class so
/// callers (IdentityStore, SecureTokenStore) can be tested with an
/// in-memory fake instead of requiring a real platform binding.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Real implementation backed by the platform secure storage
/// (Keychain/EncryptedSharedPreferences).
class SecureKeyValueStore implements KeyValueStore {
  final FlutterSecureStorage _storage;

  SecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
