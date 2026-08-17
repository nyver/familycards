import '../storage/key_value_store.dart';
import 'token_store.dart';

/// [AuthTokenStore] backed by [KeyValueStore] (in production, the platform
/// secure storage). Tokens are the only thing this class persists - the
/// vault key has its own, separately-gated storage (see
/// core/crypto/vault_key.dart) because it is only ever written to disk
/// when the user has explicitly enabled biometric unlock.
class SecureTokenStore implements AuthTokenStore {
  final KeyValueStore _storage;

  /// Mutable (not constructor-only) so callers that must build this store
  /// before their own `this` is fully constructed (e.g. SessionController,
  /// which passes itself as the callback target) can wire it up
  /// immediately afterward in the constructor body.
  Future<void> Function()? onSessionExpiredCallback;

  static const _accessTokenKey = 'auth.access_token';
  static const _refreshTokenKey = 'auth.refresh_token';

  SecureTokenStore({KeyValueStore? storage, this.onSessionExpiredCallback})
    : _storage = storage ?? SecureKeyValueStore();

  @override
  Future<String?> getAccessToken() => _storage.read(_accessTokenKey);

  @override
  Future<String?> getRefreshToken() => _storage.read(_refreshTokenKey);

  @override
  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(_accessTokenKey, accessToken);
    await _storage.write(_refreshTokenKey, refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(_accessTokenKey);
    await _storage.delete(_refreshTokenKey);
  }

  @override
  Future<void> onSessionExpired() async {
    await clear();
    final callback = onSessionExpiredCallback;
    if (callback != null) await callback();
  }
}
