import 'dart:convert';

import '../../core/storage/key_value_store.dart';

/// Everything needed to restore a session on cold start and to unlock the
/// vault key locally, without a network round trip: who the user is, and
/// the wrapped-vault-key material their password unwraps.
class StoredIdentity {
  final String serverAddress;
  final String userId;
  final String vaultId;
  final String deviceId;
  final String login;
  final String displayName;
  final String kdfSalt;
  final Map<String, dynamic> kdfParams;
  final String wrappedVaultKey;
  final String wrapNonce;

  const StoredIdentity({
    required this.serverAddress,
    required this.userId,
    required this.vaultId,
    required this.deviceId,
    required this.login,
    required this.displayName,
    required this.kdfSalt,
    required this.kdfParams,
    required this.wrappedVaultKey,
    required this.wrapNonce,
  });

  Map<String, dynamic> _toJson() => {
    'server_address': serverAddress,
    'user_id': userId,
    'vault_id': vaultId,
    'device_id': deviceId,
    'login': login,
    'display_name': displayName,
    'kdf_salt': kdfSalt,
    'kdf_params': kdfParams,
    'wrapped_vault_key': wrappedVaultKey,
    'wrap_nonce': wrapNonce,
  };

  static StoredIdentity _fromJson(Map<String, dynamic> json) => StoredIdentity(
    serverAddress: json['server_address'] as String,
    userId: json['user_id'] as String,
    vaultId: json['vault_id'] as String,
    deviceId: json['device_id'] as String,
    login: json['login'] as String,
    displayName: json['display_name'] as String,
    kdfSalt: json['kdf_salt'] as String,
    kdfParams: json['kdf_params'] as Map<String, dynamic>,
    wrappedVaultKey: json['wrapped_vault_key'] as String,
    wrapNonce: json['wrap_nonce'] as String,
  );
}

/// Persists [StoredIdentity] and the standalone server address (known
/// even before any account exists, e.g. while onboarding).
class IdentityStore {
  final KeyValueStore _storage;

  static const _identityKey = 'identity.current';
  static const _serverAddressKey = 'identity.server_address';

  IdentityStore({KeyValueStore? storage})
    : _storage = storage ?? SecureKeyValueStore();

  Future<String?> getServerAddress() => _storage.read(_serverAddressKey);

  Future<void> setServerAddress(String address) =>
      _storage.write(_serverAddressKey, address);

  Future<StoredIdentity?> load() async {
    final raw = await _storage.read(_identityKey);
    if (raw == null) return null;
    return StoredIdentity._fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(StoredIdentity identity) async {
    await _storage.write(_identityKey, jsonEncode(identity._toJson()));
    await setServerAddress(identity.serverAddress);
  }

  /// Clears the identity and server address - used when switching to a
  /// different server (which invalidates all local state, including
  /// which server to talk to).
  Future<void> clearAll() async {
    await _storage.delete(_identityKey);
    await _storage.delete(_serverAddressKey);
  }

  /// Clears only the identity, keeping the server address - used for
  /// sign-out, where the user returns to onboarding against the same
  /// server rather than to server selection.
  Future<void> clearIdentity() async {
    await _storage.delete(_identityKey);
  }
}
