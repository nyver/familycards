import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/net/dto/dto.dart';

void main() {
  test(
    'BootstrapRequest serializes all fields including nested device/recovery',
    () {
      final req = BootstrapRequest(
        login: 'alice',
        displayName: 'Alice',
        password: 'secret',
        kdfSalt: 'c2FsdA==',
        kdfParams: const {'m': 65536, 't': 3, 'p': 1},
        wrappedVaultKey: 'd3Jhcw==',
        wrapNonce: 'bm9uY2U=',
        recovery: const RecoveryDto(
          wrappedVaultKey: 'cmVjb3ZlcnlXVks=',
          wrapNonce: 'cmVjb3ZlcnlOb25jZQ==',
          kdfSalt: 'cmVjb3ZlcnlTYWx0',
          kdfParams: {'m': 65536, 't': 3, 'p': 1},
          verifier: 'abandon ability able',
        ),
        device: const DeviceDto(name: 'Test Phone', platform: 'android'),
      );

      final json = req.toJson();
      expect(json['login'], 'alice');
      expect(json['device'], {'name': 'Test Phone', 'platform': 'android'});
      expect(json['recovery'], {
        'wrapped_vault_key': 'cmVjb3ZlcnlXVks=',
        'wrap_nonce': 'cmVjb3ZlcnlOb25jZQ==',
        'kdf_salt': 'cmVjb3ZlcnlTYWx0',
        'kdf_params': {'m': 65536, 't': 3, 'p': 1},
        'verifier': 'abandon ability able',
      });
    },
  );

  test('DeviceDto omits id when absent but includes it when present', () {
    const withId = DeviceDto(id: 'dev-1', name: 'Phone', platform: 'ios');
    const withoutId = DeviceDto(name: 'Phone', platform: 'ios');

    expect(withId.toJson()['id'], 'dev-1');
    expect(withoutId.toJson().containsKey('id'), isFalse);
  });

  test('SessionResponse round-trips from a full login-shaped JSON body', () {
    final json = {
      'user_id': 'u1',
      'vault_id': 'v1',
      'device_id': 'd1',
      'access_token': 'at',
      'refresh_token': 'rt',
      'wrapped_vault_key': 'wvk',
      'wrap_nonce': 'wn',
      'kdf_salt': 'ks',
      'kdf_params': {'m': 65536, 't': 3, 'p': 1},
    };

    final resp = SessionResponse.fromJson(json);
    expect(resp.userId, 'u1');
    expect(resp.wrappedVaultKey, 'wvk');
    expect(resp.kdfParams, {'m': 65536, 't': 3, 'p': 1});
  });

  test('SessionResponse round-trips from a bootstrap-shaped body without wrap fields', () {
    final json = {
      'user_id': 'u1',
      'vault_id': 'v1',
      'device_id': 'd1',
      'access_token': 'at',
      'refresh_token': 'rt',
    };

    final resp = SessionResponse.fromJson(json);
    expect(resp.wrappedVaultKey, isNull);
    expect(resp.kdfParams, isNull);
  });

  test('ItemDto parses a tombstone with null nonce/ciphertext', () {
    final json = {
      'item_id': 'i1',
      'kind': 'card',
      'rev': 5,
      'updated_at': 1000,
      'deleted': true,
      'device_id': 'dev-a',
      'nonce': null,
      'ciphertext': null,
      'blob_refs': <String>[],
    };

    final item = ItemDto.fromJson(json);
    expect(item.deleted, isTrue);
    expect(item.nonce, isNull);
    expect(item.ciphertext, isNull);
  });

  test('ItemDto defaults blob_refs to empty list when absent', () {
    final json = {
      'item_id': 'i1',
      'kind': 'card',
      'rev': 1,
      'updated_at': 0,
      'deleted': false,
      'device_id': 'dev-a',
      'nonce': 'n',
      'ciphertext': 'c',
    };

    final item = ItemDto.fromJson(json);
    expect(item.blobRefs, isEmpty);
  });

  test('PushItemDto serializes deleted items with null nonce/ciphertext', () {
    const item = PushItemDto(
      itemId: 'i1',
      kind: 'card',
      baseRev: 3,
      updatedAt: 2000,
      deleted: true,
    );

    final json = item.toJson();
    expect(json['deleted'], true);
    expect(json['nonce'], isNull);
    expect(json['ciphertext'], isNull);
    expect(json['blob_refs'], <String>[]);
  });

  test('ChangesResponse and PushResponse round-trip nested item lists', () {
    final changes = ChangesResponse.fromJson({
      'server_rev': 10,
      'next_since': 10,
      'has_more': false,
      'items': [
        {
          'item_id': 'i1',
          'kind': 'card',
          'rev': 10,
          'updated_at': 5000,
          'deleted': false,
          'device_id': 'dev-a',
          'nonce': 'n',
          'ciphertext': 'c',
          'blob_refs': ['b1', 'b2'],
        },
      ],
    });
    expect(changes.items, hasLength(1));
    expect(changes.items.first.blobRefs, ['b1', 'b2']);

    final push = PushResponse.fromJson({
      'server_rev': 11,
      'accepted': [
        {'item_id': 'i2', 'rev': 11},
      ],
      'conflicts': [],
    });
    expect(push.accepted, hasLength(1));
    expect(push.accepted.first.rev, 11);
    expect(push.conflicts, isEmpty);
  });

  test('MeResponse flattens nested user/vault objects', () {
    final me = MeResponse.fromJson({
      'user': {'id': 'u1', 'login': 'alice', 'display_name': 'Alice'},
      'vault': {'id': 'v1', 'max_users': 5, 'user_count': 2},
      'server_rev': 42,
    });

    expect(me.userId, 'u1');
    expect(me.maxUsers, 5);
    expect(me.serverRev, 42);
  });

  test('MemberDto round-trips nested devices list', () {
    final member = MemberDto.fromJson({
      'user_id': 'u1',
      'display_name': 'Alice',
      'login': 'alice',
      'created_at': 0,
      'last_seen_at': 100,
      'devices': [
        {
          'id': 'd1',
          'name': "Alice's Phone",
          'platform': 'android',
          'created_at': 0,
          'last_seen_at': 100,
          'revoked': false,
        },
      ],
    });

    expect(member.devices, hasLength(1));
    expect(member.devices.first.platform, 'android');
    expect(member.devices.first.revoked, isFalse);
  });
}
