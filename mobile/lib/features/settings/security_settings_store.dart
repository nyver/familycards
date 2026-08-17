import '../../core/storage/key_value_store.dart';

/// Persists the user's security preferences that aren't part of the
/// account identity itself - currently just whether biometric unlock is
/// enabled.
class SecuritySettingsStore {
  final KeyValueStore _storage;

  static const _biometricEnabledKey = 'settings.biometric_enabled';

  SecuritySettingsStore({KeyValueStore? storage})
    : _storage = storage ?? SecureKeyValueStore();

  Future<bool> isBiometricEnabled() async =>
      (await _storage.read(_biometricEnabledKey)) == 'true';

  Future<void> setBiometricEnabled(bool enabled) =>
      _storage.write(_biometricEnabledKey, enabled.toString());
}
