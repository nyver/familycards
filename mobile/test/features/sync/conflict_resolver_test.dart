import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/sync/conflict_resolver.dart';

/// Locates `testdata/lww_vectors.json` at the repo root by walking up from
/// the current working directory - mirrors
/// server/internal/sync/resolve_test.go's relative path, but robust to
/// `flutter test` being invoked from a different working directory.
Future<File> _findVectorFile() async {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = File('${dir.path}/testdata/lww_vectors.json');
    if (await candidate.exists()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError(
    'could not locate testdata/lww_vectors.json from ${Directory.current.path}',
  );
}

void main() {
  test(
    'resolves every shared LWW vector identically to the Go server',
    () async {
      final file = await _findVectorFile();
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final cases = data['cases'] as List<dynamic>;
      expect(cases.length, greaterThanOrEqualTo(12));

      for (final raw in cases) {
        final c = raw as Map<String, dynamic>;
        final current = CurrentItemState(
          exists: c['current_exists'] as bool,
          rev: c['current_rev'] as int,
          updatedAt: c['current_updated_at'] as int,
          deviceId: c['current_device_id'] as String,
        );
        final incoming = IncomingItemState(
          baseRev: c['base_rev'] as int,
          updatedAt: c['updated_at'] as int,
          deviceId: c['device_id'] as String,
        );
        final accept = ConflictResolver.accept(current, incoming);
        expect(
          accept,
          c['accept'] as bool,
          reason: 'case "${c['name']}": ${c['description']}',
        );
      }
    },
  );

  test('a base_rev match is a normal update regardless of timestamps', () {
    final current = CurrentItemState(
      exists: true,
      rev: 3,
      updatedAt: 999999,
      deviceId: 'z',
    );
    final incoming = IncomingItemState(baseRev: 3, updatedAt: 1, deviceId: 'a');
    expect(ConflictResolver.accept(current, incoming), isTrue);
  });

  group('localWinsOverRemote', () {
    test('local wins when its base_rev matches the remote revision', () {
      final wins = ConflictResolver.localWinsOverRemote(
        localBaseRev: 5,
        localUpdatedAt: 100,
        localDeviceId: 'dev-a',
        remoteRev: 5,
        remoteUpdatedAt: 999,
        remoteDeviceId: 'dev-b',
      );
      expect(wins, isTrue);
    });

    test('remote wins when it is newer and local is stale', () {
      final wins = ConflictResolver.localWinsOverRemote(
        localBaseRev: 3,
        localUpdatedAt: 100,
        localDeviceId: 'dev-a',
        remoteRev: 5,
        remoteUpdatedAt: 200,
        remoteDeviceId: 'dev-b',
      );
      expect(wins, isFalse);
    });

    test('local wins when stale on base_rev but newer on wall clock', () {
      final wins = ConflictResolver.localWinsOverRemote(
        localBaseRev: 3,
        localUpdatedAt: 500,
        localDeviceId: 'dev-a',
        remoteRev: 5,
        remoteUpdatedAt: 200,
        remoteDeviceId: 'dev-b',
      );
      expect(wins, isTrue);
    });
  });
}
