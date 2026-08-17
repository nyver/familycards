// The public constructor parameter names intentionally differ from the
// private field names they populate (store -> _store, etc.), so
// initializing formals (`this._store`) cannot be used without also making
// the fields non-private.
// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';

import 'dto/dto.dart';
import 'token_store.dart';

/// Attaches the current access token to every request and, on a 401,
/// refreshes exactly once and retries the original request. Concurrent
/// requests that all hit 401 at the same time share a single in-flight
/// refresh rather than each triggering their own. If the refresh itself
/// fails, the store is told the session expired and the original 401 is
/// forwarded to the caller.
class AuthInterceptor extends Interceptor {
  final AuthTokenStore _store;
  final Dio _refreshClient;
  final Dio _retryClient;
  final String _refreshPath;

  Future<TokenPair>? _inFlightRefresh;

  /// [retryClient] must be the same Dio instance this interceptor is
  /// attached to (or one sharing its adapter/interceptor chain), so a
  /// retried request goes through the same transport as the original -
  /// critical both for production consistency (logging, other
  /// interceptors) and for testability (a fake adapter installed on the
  /// caller's Dio must also serve the retry).
  AuthInterceptor({
    required AuthTokenStore store,
    required Dio refreshClient,
    required Dio retryClient,
    String refreshPath = '/v1/auth/refresh',
  }) : _store = store,
       _refreshClient = refreshClient,
       _retryClient = retryClient,
       _refreshPath = refreshPath;

  static const _retriedKey = 'auth_interceptor_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _store.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;

    if (response?.statusCode != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }

    try {
      final pair = await _refreshOnce();
      await _store.setTokens(
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
      );

      final retryOptions = err.requestOptions;
      retryOptions.extra[_retriedKey] = true;
      retryOptions.headers['Authorization'] = 'Bearer ${pair.accessToken}';

      final retryResponse = await _retryClient.fetch(retryOptions);
      handler.resolve(retryResponse);
    } on DioException {
      await _store.onSessionExpired();
      handler.next(err);
    }
  }

  /// Ensures only one refresh request is ever in flight at a time; any
  /// request that hits 401 while a refresh is already running waits for
  /// that same refresh instead of starting a second one.
  Future<TokenPair> _refreshOnce() {
    final existing = _inFlightRefresh;
    if (existing != null) return existing;

    final refreshToken = _store.getRefreshToken();
    final future = refreshToken.then((token) async {
      if (token == null) {
        throw DioException(requestOptions: RequestOptions(path: _refreshPath));
      }
      final response = await _refreshClient.post<Map<String, dynamic>>(
        _refreshPath,
        data: {'refresh_token': token},
      );
      return TokenPair.fromJson(response.data!);
    });

    _inFlightRefresh = future;
    // whenComplete() on a future that rejects produces a derivative future
    // that also rejects; since nothing else awaits it, it must be
    // explicitly ignored or Dart reports it as an unhandled async error
    // even though the original `future` is properly awaited/caught below.
    future.whenComplete(() => _inFlightRefresh = null).ignore();
    return future;
  }
}
