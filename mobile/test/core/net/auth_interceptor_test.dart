import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/net/auth_interceptor.dart';
import 'package:mobile/core/net/token_store.dart';

/// A minimal fake HttpClientAdapter that serves canned responses without
/// touching the network, keyed by path and, for the protected path, by
/// call count (so the first call can 401 and the retried call can 200).
class _FakeAdapter implements HttpClientAdapter {
  int protectedCallCount = 0;
  int refreshCallCount = 0;
  bool refreshShouldFail = false;

  final List<String> authorizationHeadersSeen = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authorizationHeadersSeen.add(
      options.headers['Authorization'] as String? ?? '',
    );

    if (options.path == '/v1/auth/refresh') {
      refreshCallCount++;
      if (refreshShouldFail) {
        return ResponseBody.fromString(
          '{"error":"unauthorized"}',
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString(
        jsonEncode({
          'access_token': 'new-access-token',
          'refresh_token': 'new-refresh-token',
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    if (options.path == '/protected') {
      protectedCallCount++;
      if (protectedCallCount == 1) {
        return ResponseBody.fromString(
          '{"error":"unauthorized"}',
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      // Second and subsequent calls: if it's carrying the refreshed
      // token, succeed; otherwise keep failing (simulates a still-bad
      // token, to prove we don't loop forever).
      final auth = options.headers['Authorization'] as String? ?? '';
      if (auth == 'Bearer new-access-token') {
        return ResponseBody.fromString(
          '{"ok":true}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString(
        '{"error":"unauthorized"}',
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    throw StateError('unexpected path ${options.path}');
  }
}

class _FakeTokenStore implements AuthTokenStore {
  String? accessToken = 'old-access-token';
  String? refreshToken = 'old-refresh-token';
  bool sessionExpiredCalled = false;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> onSessionExpired() async {
    sessionExpiredCalled = true;
    accessToken = null;
    refreshToken = null;
  }
}

({Dio dio, _FakeAdapter adapter, _FakeTokenStore store}) buildClient({
  bool refreshShouldFail = false,
}) {
  final adapter = _FakeAdapter()..refreshShouldFail = refreshShouldFail;
  final refreshDio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  final store = _FakeTokenStore();

  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  dio.interceptors.add(
    AuthInterceptor(store: store, refreshClient: refreshDio, retryClient: dio),
  );

  return (dio: dio, adapter: adapter, store: store);
}

void main() {
  test(
    'a 401 triggers exactly one refresh and one retry, then succeeds',
    () async {
      final c = buildClient();

      final response = await c.dio.get<Map<String, dynamic>>('/protected');

      expect(response.statusCode, 200);
      expect(response.data, {'ok': true});
      expect(
        c.adapter.protectedCallCount,
        2,
        reason: 'exactly one retry after the initial 401',
      );
      expect(c.adapter.refreshCallCount, 1, reason: 'exactly one refresh call');
      expect(c.store.accessToken, 'new-access-token');
    },
  );

  test(
    'a failed refresh marks the session expired and surfaces the original 401',
    () async {
      final c = buildClient(refreshShouldFail: true);

      await expectLater(
        c.dio.get<Map<String, dynamic>>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(c.store.sessionExpiredCalled, isTrue);
      expect(c.adapter.refreshCallCount, 1);
    },
  );

  test('the access token is attached to every outgoing request', () async {
    final c = buildClient();

    // First call 401s and retries, so two Authorization headers are seen.
    await c.dio.get<Map<String, dynamic>>('/protected');

    expect(c.adapter.authorizationHeadersSeen.first, 'Bearer old-access-token');
    expect(c.adapter.authorizationHeadersSeen.last, 'Bearer new-access-token');
  });
}
