import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../result.dart';
import 'auth_interceptor.dart';
import 'dto/dto.dart';
import 'sync_api.dart';
import 'token_store.dart';

/// Typed HTTP client for the wallet sync server (see docs/API.md). Wraps
/// dio, translates every failure into an [AppError] via [Result], and
/// attaches the auth interceptor for bearer token handling and refresh.
class ApiClient implements SyncApi {
  final Dio _dio;
  final Dio _plainDio; // no auth interceptor - used for /health and refresh

  ApiClient({required String baseUrl, required AuthTokenStore tokenStore})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
        ),
      ),
      _plainDio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
        ),
      ) {
    _dio.interceptors.add(
      AuthInterceptor(
        store: tokenStore,
        refreshClient: _plainDio,
        retryClient: _dio,
      ),
    );
  }

  /// Updates the base URL for both the authenticated and plain clients,
  /// used when the user changes server address in settings.
  void setBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
    _plainDio.options.baseUrl = baseUrl;
  }

  String get currentBaseUrl => _dio.options.baseUrl;

  // ---- Health ----

  Future<Result<HealthResponse>> health() {
    return _run(() async {
      final resp = await _plainDio.get<Map<String, dynamic>>('/v1/health');
      return HealthResponse.fromJson(resp.data!);
    });
  }

  // ---- Auth ----

  Future<Result<SessionResponse>> bootstrap(
    BootstrapRequest req, {
    required String bootstrapToken,
  }) {
    return _run(() async {
      final resp = await _plainDio.post<Map<String, dynamic>>(
        '/v1/auth/bootstrap',
        data: req.toJson(),
        options: Options(headers: {'X-Bootstrap-Token': bootstrapToken}),
      );
      return SessionResponse.fromJson(resp.data!);
    });
  }

  Future<Result<PreloginResponse>> prelogin(String login) {
    return _run(() async {
      final resp = await _plainDio.post<Map<String, dynamic>>(
        '/v1/auth/prelogin',
        data: {'login': login},
      );
      return PreloginResponse.fromJson(resp.data!);
    });
  }

  Future<Result<SessionResponse>> login({
    required String login,
    required String password,
    required DeviceDto device,
  }) {
    return _run(() async {
      final resp = await _plainDio.post<Map<String, dynamic>>(
        '/v1/auth/login',
        data: {'login': login, 'password': password, 'device': device.toJson()},
      );
      return SessionResponse.fromJson(resp.data!);
    });
  }

  Future<Result<void>> logout(String refreshToken) {
    return _run(() async {
      await _dio.post<void>(
        '/v1/auth/logout',
        data: {'refresh_token': refreshToken},
      );
    });
  }

  Future<Result<void>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String kdfSalt,
    required Map<String, dynamic> kdfParams,
    required String wrappedVaultKey,
    required String wrapNonce,
  }) {
    return _run(() async {
      await _dio.post<void>(
        '/v1/auth/password',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
          'kdf_salt': kdfSalt,
          'kdf_params': kdfParams,
          'wrapped_vault_key': wrappedVaultKey,
          'wrap_nonce': wrapNonce,
        },
      );
    });
  }

  Future<Result<MeResponse>> me() {
    return _run(() async {
      final resp = await _dio.get<Map<String, dynamic>>('/v1/me');
      return MeResponse.fromJson(resp.data!);
    });
  }

  Future<Result<RecoveryPreloginResponse>> recoveryPrelogin(String login) {
    return _run(() async {
      final resp = await _plainDio.post<Map<String, dynamic>>(
        '/v1/auth/recovery/prelogin',
        data: {'login': login},
      );
      return RecoveryPreloginResponse.fromJson(resp.data!);
    });
  }

  Future<Result<SessionResponse>> recoveryRedeem({
    required String login,
    required String verifier,
    required String newPassword,
    required String kdfSalt,
    required Map<String, dynamic> kdfParams,
    required String wrappedVaultKey,
    required String wrapNonce,
    required DeviceDto device,
  }) {
    return _run(() async {
      final resp = await _plainDio.post<Map<String, dynamic>>(
        '/v1/auth/recovery/redeem',
        data: {
          'login': login,
          'verifier': verifier,
          'new_password': newPassword,
          'kdf_salt': kdfSalt,
          'kdf_params': kdfParams,
          'wrapped_vault_key': wrappedVaultKey,
          'wrap_nonce': wrapNonce,
          'device': device.toJson(),
        },
      );
      return SessionResponse.fromJson(resp.data!);
    });
  }

  // ---- Membership ----

  Future<Result<void>> createInvite({
    required String codeHash,
    required String wrappedVaultKey,
    required String wrapNonce,
    required String kdfSalt,
    required Map<String, dynamic> kdfParams,
    required int ttlHours,
  }) {
    return _run(() async {
      await _dio.post<void>(
        '/v1/invites',
        data: {
          'code_hash': codeHash,
          'wrapped_vault_key': wrappedVaultKey,
          'wrap_nonce': wrapNonce,
          'kdf_salt': kdfSalt,
          'kdf_params': kdfParams,
          'ttl_hours': ttlHours,
        },
      );
    });
  }

  Future<Result<InviteMaterialDto>> getInvite(String codeHash) {
    return _run(() async {
      final resp = await _plainDio.get<Map<String, dynamic>>(
        '/v1/invites/$codeHash',
      );
      return InviteMaterialDto.fromJson(resp.data!);
    });
  }

  Future<Result<SessionResponse>> redeemInvite({
    required String codeHash,
    required String login,
    required String displayName,
    required String password,
    required String kdfSalt,
    required Map<String, dynamic> kdfParams,
    required String wrappedVaultKey,
    required String wrapNonce,
    required DeviceDto device,
  }) {
    return _run(() async {
      final resp = await _plainDio.post<Map<String, dynamic>>(
        '/v1/invites/$codeHash/redeem',
        data: {
          'login': login,
          'display_name': displayName,
          'password': password,
          'kdf_salt': kdfSalt,
          'kdf_params': kdfParams,
          'wrapped_vault_key': wrappedVaultKey,
          'wrap_nonce': wrapNonce,
          'device': device.toJson(),
        },
      );
      return SessionResponse.fromJson(resp.data!);
    });
  }

  Future<Result<void>> deleteInvite(String codeHash) {
    return _run(() async {
      await _dio.delete<void>('/v1/invites/$codeHash');
    });
  }

  Future<Result<List<MemberDto>>> listMembers() {
    return _run(() async {
      final resp = await _dio.get<List<dynamic>>('/v1/members');
      return resp.data!
          .map((e) => MemberDto.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Result<void>> removeMember(String userId) {
    return _run(() async {
      await _dio.delete<void>('/v1/members/$userId');
    });
  }

  // ---- Sync ----

  @override
  Future<Result<ChangesResponse>> getChanges({
    required int since,
    int limit = 200,
  }) {
    return _run(() async {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/v1/sync/changes',
        queryParameters: {'since': since, 'limit': limit},
      );
      return ChangesResponse.fromJson(resp.data!);
    });
  }

  @override
  Future<Result<PushResponse>> push({
    required String deviceId,
    required List<PushItemDto> items,
  }) {
    return _run(() async {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/v1/sync/push',
        data: {
          'device_id': deviceId,
          'items': items.map((e) => e.toJson()).toList(),
        },
      );
      return PushResponse.fromJson(resp.data!);
    });
  }

  // ---- Blobs ----

  @override
  Future<Result<UploadBlobResponse>> uploadBlob({
    required String blobId,
    required Uint8List body,
  }) {
    return _run(() async {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/v1/blobs',
        data: Stream.fromIterable([body]),
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': body.length,
            'X-Blob-Id': blobId,
          },
        ),
      );
      return UploadBlobResponse.fromJson(resp.data!);
    });
  }

  @override
  Future<Result<Uint8List>> getBlob(String blobId) {
    return _run(() async {
      final resp = await _dio.get<List<int>>(
        '/v1/blobs/$blobId',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(resp.data!);
    });
  }

  // ---- Error translation ----

  Future<Result<T>> _run<T>(Future<T> Function() fn) async {
    try {
      return Result.ok(await fn());
    } on DioException catch (e) {
      return Result.err(_translate(e));
    } catch (e) {
      return Result.err(AppError.unknown('Unexpected error: $e', cause: e));
    }
  }

  AppError _translate(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    final message = (body is Map && body['message'] is String)
        ? body['message'] as String
        : e.message ?? 'Request failed';

    if (status == null) {
      return AppError.network(message, cause: e);
    }
    switch (status) {
      case 400:
        return AppError.invalidRequest(message, cause: e);
      case 401:
        return AppError.unauthorized(message, cause: e);
      case 403:
        return AppError.forbidden(message, cause: e);
      case 404:
        return AppError.notFound(message, cause: e);
      case 409:
        return AppError.conflict(message, cause: e);
      case 410:
        return AppError.gone(message, cause: e);
      default:
        return AppError.unknown(message, cause: e);
    }
  }
}
