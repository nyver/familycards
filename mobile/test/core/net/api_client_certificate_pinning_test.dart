import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/net/api_client.dart';
import 'package:mobile/core/net/token_store.dart';
import 'package:mobile/core/result.dart';
import 'package:path/path.dart' as p;

class _NoopTokenStore implements AuthTokenStore {
  @override
  Future<String?> getAccessToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
  @override
  Future<void> onSessionExpired() async {}
}

/// Reads the DER bytes out of a PEM-encoded certificate file (strips the
/// header/footer/newlines and base64-decodes the remainder), independently
/// of anything in lib/core/net/certificate_fingerprint.dart, so the
/// expected digest in these tests is derived straight from the fixture
/// file rather than from the code under test.
Uint8List _derFromPemCertificate(String pem) {
  final body = pem
      .replaceAll('-----BEGIN CERTIFICATE-----', '')
      .replaceAll('-----END CERTIFICATE-----', '')
      .replaceAll(RegExp(r'\s+'), '');
  return base64Decode(body);
}

// This is an end-to-end test of certificate pinning against a real TLS
// handshake (a genuine self-signed certificate served over a real
// HttpServer.bindSecure listener), not a mock - the whole point of pinning
// is a property of dart:io's TLS stack (SecurityContext.withTrustedRoots:
// false plus badCertificateCallback), which a fake HttpClientAdapter
// cannot exercise. See design.md, "Строгое закрепление".
void main() {
  late HttpServer server;
  late Uint8List actualFingerprint;
  late String baseUrl;

  setUpAll(() async {
    final fixturesDir = p.join(
      Directory.current.path,
      'test',
      'fixtures',
    );
    final certPem = File(
      p.join(fixturesDir, 'pinning_test_cert.pem'),
    ).readAsStringSync();
    final keyPem = File(
      p.join(fixturesDir, 'pinning_test_key.pem'),
    ).readAsStringSync();

    actualFingerprint = Uint8List.fromList(
      crypto.sha256.convert(_derFromPemCertificate(certPem)).bytes,
    );

    final context = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(certPem))
      ..usePrivateKeyBytes(utf8.encode(keyPem));

    server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'ok', 'version': 'test'}));
      await request.response.close();
    });
    baseUrl = 'https://127.0.0.1:${server.port}';
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  ApiClient makeClient() =>
      ApiClient(baseUrl: baseUrl, tokenStore: _NoopTokenStore());

  test(
    'without a pin, a self-signed certificate is rejected as untrusted',
    () async {
      final client = makeClient();
      final result = await client.health();

      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.kind, AppErrorKind.certificateMismatch);
    },
  );

  test('the correct pinned fingerprint is accepted', () async {
    final client = makeClient();
    client.setBaseUrl(baseUrl, pinnedFingerprint: actualFingerprint);

    final result = await client.health();

    expect(result.isOk, isTrue, reason: result.errorOrNull?.toString());
    expect(result.valueOrNull!.status, 'ok');
  });

  test('a wrong pinned fingerprint is rejected as a mismatch, not a network error', () async {
    final client = makeClient();
    final wrongFingerprint = Uint8List.fromList(
      List.generate(32, (i) => (actualFingerprint[i] + 1) % 256),
    );
    client.setBaseUrl(baseUrl, pinnedFingerprint: wrongFingerprint);

    final result = await client.health();

    expect(result.isErr, isTrue);
    expect(result.errorOrNull!.kind, AppErrorKind.certificateMismatch);
  });

  test(
    'replacing a wrong pin with the correct one recovers the connection - '
    'the diagnostics screen relies on exactly this to let a user fix a '
    'mismatch',
    () async {
      final client = makeClient();
      final wrongFingerprint = Uint8List.fromList(List.filled(32, 0xAA));
      client.setBaseUrl(baseUrl, pinnedFingerprint: wrongFingerprint);
      final mismatch = await client.health();
      expect(mismatch.errorOrNull?.kind, AppErrorKind.certificateMismatch);

      client.setBaseUrl(baseUrl, pinnedFingerprint: actualFingerprint);
      final recovered = await client.health();
      expect(recovered.isOk, isTrue, reason: recovered.errorOrNull?.toString());
    },
  );
}
