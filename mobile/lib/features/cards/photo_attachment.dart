import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/crypto/envelope.dart';
import '../../core/db/daos/local_blobs_dao.dart';
import '../../core/db/database.dart';

/// Server-enforced maximum size for a single blob upload (see
/// server/internal/blobs/handlers.go). Photos are compressed to stay under
/// this before encryption, since encryption adds only a fixed 40-byte
/// overhead (24-byte nonce + 16-byte Poly1305 tag).
const maxBlobBytes = 8 << 20;

/// Re-encodes [imageBytes] as JPEG, iteratively lowering quality until the
/// result fits under [maxBlobBytes] (encryption overhead is negligible, so
/// compressing to the raw limit is sufficient). Returns null if the image
/// cannot be brought under the limit even at minimum quality.
Future<Uint8List?> _compressToLimit(Uint8List imageBytes) async {
  for (final quality in [85, 70, 55, 40, 25]) {
    final compressed = await FlutterImageCompress.compressWithList(
      imageBytes,
      minWidth: 1600,
      minHeight: 1600,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    if (compressed.length <= maxBlobBytes - 64) {
      return Uint8List.fromList(compressed);
    }
  }
  return null;
}

/// The on-disk directory holding cached blob files (encrypted bytes, as
/// downloaded from or uploaded to the server). Shared with the sync
/// engine, which writes lazily-downloaded photos here alongside the ones
/// created locally by [pickAndAttachPhoto].
Future<Directory> blobCacheDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'blob_cache'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Picks a photo from [source], compresses it under the server's blob size
/// limit, encrypts it with [vaultKey], writes the encrypted bytes to the
/// local blob cache, and records it in [LocalBlobs] as not-yet-uploaded.
/// Returns the new blob's content-addressed id, or null if the user
/// cancelled the picker or the image could not be compressed small enough.
Future<String?> pickAndAttachPhoto({
  required ImageSource source,
  required SecretKey vaultKey,
  required LocalBlobsDao dao,
  ImagePicker? picker,
}) async {
  final file = await (picker ?? ImagePicker()).pickImage(source: source);
  if (file == null) return null;

  final rawBytes = await file.readAsBytes();
  final compressed = await _compressToLimit(rawBytes);
  if (compressed == null) return null;

  final encrypted = await encryptBlob(
    imageBytes: compressed,
    vaultKey: vaultKey,
  );

  final dir = await blobCacheDir();
  final path = p.join(dir.path, encrypted.blobId);
  await File(path).writeAsBytes(encrypted.uploadBytes, flush: true);

  await dao.recordBlob(
    LocalBlobsCompanion.insert(
      blobId: encrypted.blobId,
      path: path,
      size: encrypted.uploadBytes.length,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      uploaded: const Value(false),
    ),
  );

  return encrypted.blobId;
}

/// Loads and decrypts a previously attached photo for display. Returns
/// null if the blob is not present in the local cache (e.g. not yet
/// downloaded from the server on this device).
Future<Uint8List?> loadPhoto({
  required String blobId,
  required SecretKey vaultKey,
  required LocalBlobsDao dao,
}) async {
  final row = await dao.getBlob(blobId);
  if (row == null) return null;
  final file = File(row.path);
  if (!await file.exists()) return null;
  final uploadBytes = await file.readAsBytes();
  return decryptBlob(uploadBytes: uploadBytes, vaultKey: vaultKey);
}
