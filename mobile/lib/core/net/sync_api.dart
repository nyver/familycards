import 'dart:typed_data';

import '../result.dart';
import 'dto/dto.dart';

/// The subset of [ApiClient] the sync engine depends on. Exists so tests
/// can exercise `SyncService` against an in-memory fake server instead of
/// a real HTTP client - see test/features/sync/fake_sync_api.dart.
abstract class SyncApi {
  Future<Result<ChangesResponse>> getChanges({
    required int since,
    int limit = 200,
  });
  Future<Result<PushResponse>> push({
    required String deviceId,
    required List<PushItemDto> items,
  });
  Future<Result<UploadBlobResponse>> uploadBlob({
    required String blobId,
    required Uint8List body,
  });
  Future<Result<Uint8List>> getBlob(String blobId);
}
