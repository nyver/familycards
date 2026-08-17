/// Storage for the current session's tokens, abstracted so the network
/// layer does not depend on a specific storage mechanism (the real
/// implementation lives in features/auth and is backed by
/// flutter_secure_storage plus in-memory state).
abstract class AuthTokenStore {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
  });

  /// Called when a refresh attempt itself fails (refresh token invalid or
  /// expired) - the caller must route the user back to login.
  Future<void> onSessionExpired();
}
