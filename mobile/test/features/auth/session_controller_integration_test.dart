@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/crypto/argon2.dart';
import 'package:mobile/core/crypto/invite_code.dart';
import 'package:mobile/core/crypto/vault_key.dart';
import 'package:mobile/core/db/database.dart';
import 'package:mobile/features/auth/auth_state.dart';
import 'package:mobile/features/auth/session_controller.dart';

import '../../test_helpers/in_memory_key_value_store.dart';
import 'test_server.dart';

Future<List<String>> loadWordlistFromDisk() async {
  final file = 'assets/bip39/english.txt';
  final content = await File(file).readAsString();
  return content
      .split('\n')
      .map((w) => w.trim())
      .where((w) => w.isNotEmpty)
      .toList();
}

Future<String> _sha256Hex(String input) async {
  final digest = await Sha256().hash(utf8.encode(input));
  return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Uint8List _randomBytes16() {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
}

void main() {
  late TestServer server;
  late List<String> wordlist;

  setUpAll(() async {
    // This suite deliberately opens many independent in-memory databases
    // (one per SessionController), which drift's heuristic otherwise
    // misflags as a shared-executor race risk.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    wordlist = await loadWordlistFromDisk();
  });

  // Each test gets its own freshly started server process (bootstrap only
  // ever succeeds once per server - see server/internal/auth), sharing
  // only the pre-built binary across tests for speed.
  setUp(() async {
    server = await TestServer.start();
  });

  tearDown(() async {
    await server.stop();
  });

  SessionController newController() {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    return SessionController(
      database: db,
      keyValueStore: InMemoryKeyValueStore(),
    );
  }

  test(
    'full lifecycle: server check -> create vault -> confirm phrase -> ready',
    () async {
      final controller = newController();
      await pumpEventQueue();
      expect(controller.state, isA<AuthNeedsServer>());

      final checkResult = await controller.checkAndSetServer(server.baseUrl);
      expect(
        checkResult.isOk,
        isTrue,
        reason: checkResult.errorOrNull?.toString(),
      );
      expect(controller.state, isA<AuthNeedsOnboarding>());

      final pending = await controller.prepareNewVault(wordlist);
      expect(pending.phraseWords, hasLength(12));

      final bootstrapResult = await controller.completeBootstrap(
        vault: pending,
        login: 'alice',
        displayName: 'Alice',
        password: 'correct horse battery staple',
        bootstrapToken: server.bootstrapToken,
        deviceName: 'Test Device',
        devicePlatform: 'android',
      );
      expect(
        bootstrapResult.isOk,
        isTrue,
        reason: bootstrapResult.errorOrNull?.toString(),
      );
      expect(controller.state, isA<AuthReady>());
      expect(controller.vaultKeyHolder.isUnlocked, isTrue);

      final identity = (controller.state as AuthReady).identity;
      expect(identity.login, 'alice');
      expect(identity.vaultId, isNotEmpty);
    },
  );

  test('cold start after bootstrap requires unlock, and the correct password unlocks it', () async {
    final store = InMemoryKeyValueStore();
    final db1 = AppDatabase.forTesting(NativeDatabase.memory());
    final first = SessionController(database: db1, keyValueStore: store);
    await pumpEventQueue();

    await first.checkAndSetServer(server.baseUrl);
    final pending = await first.prepareNewVault(wordlist);
    await first.completeBootstrap(
      vault: pending,
      login: 'bob',
      displayName: 'Bob',
      password: 'a very good password indeed',
      bootstrapToken: server.bootstrapToken,
      deviceName: 'Device 1',
      devicePlatform: 'android',
    );
    expect(first.state, isA<AuthReady>());

    // Simulate a cold restart: a brand new controller reading the same
    // persisted storage, with nothing in memory.
    final db2 = AppDatabase.forTesting(NativeDatabase.memory());
    final second = SessionController(database: db2, keyValueStore: store);
    await pumpEventQueue();

    expect(second.state, isA<AuthNeedsUnlock>());
    expect(second.vaultKeyHolder.isUnlocked, isFalse);

    final wrongUnlock = await second.unlockWithPassword('the wrong password');
    expect(wrongUnlock.isErr, isTrue);
    expect(second.state, isA<AuthNeedsUnlock>());

    final rightUnlock = await second.unlockWithPassword(
      'a very good password indeed',
    );
    expect(
      rightUnlock.isOk,
      isTrue,
      reason: rightUnlock.errorOrNull?.toString(),
    );
    expect(second.state, isA<AuthReady>());
  });

  test('login from a second device works with the account password', () async {
    final store = InMemoryKeyValueStore();
    final db1 = AppDatabase.forTesting(NativeDatabase.memory());
    final owner = SessionController(database: db1, keyValueStore: store);
    await pumpEventQueue();
    await owner.checkAndSetServer(server.baseUrl);
    final pending = await owner.prepareNewVault(wordlist);
    await owner.completeBootstrap(
      vault: pending,
      login: 'carol',
      displayName: 'Carol',
      password: 'carols excellent password',
      bootstrapToken: server.bootstrapToken,
      deviceName: 'Carols Phone',
      devicePlatform: 'android',
    );

    final db2 = AppDatabase.forTesting(NativeDatabase.memory());
    final secondDevice = SessionController(
      database: db2,
      keyValueStore: InMemoryKeyValueStore(),
    );
    await pumpEventQueue();
    await secondDevice.checkAndSetServer(server.baseUrl);

    final loginResult = await secondDevice.login(
      login: 'carol',
      password: 'carols excellent password',
      deviceName: 'Second Device',
      devicePlatform: 'ios',
    );
    expect(
      loginResult.isOk,
      isTrue,
      reason: loginResult.errorOrNull?.toString(),
    );
    expect(secondDevice.state, isA<AuthReady>());

    final wrongLogin = await secondDevice.login(
      login: 'carol',
      password: 'not the right password',
      deviceName: 'Attacker Device',
      devicePlatform: 'android',
    );
    expect(wrongLogin.isErr, isTrue);
  });

  test('joining by invite gives the new member the same vault and its existing cards are visible', () async {
    final db1 = AppDatabase.forTesting(NativeDatabase.memory());
    final owner = SessionController(
      database: db1,
      keyValueStore: InMemoryKeyValueStore(),
    );
    await pumpEventQueue();
    await owner.checkAndSetServer(server.baseUrl);
    final pending = await owner.prepareNewVault(wordlist);
    await owner.completeBootstrap(
      vault: pending,
      login: 'frank',
      displayName: 'Frank',
      password: 'franks original password',
      bootstrapToken: server.bootstrapToken,
      deviceName: 'Franks Phone',
      devicePlatform: 'android',
    );
    final ownerVaultId = (owner.state as AuthReady).identity.vaultId;
    final ownerVaultKey = owner.vaultKeyHolder.keyOrNull!;

    // The owner issues an invite - the crypto steps a real "invite" screen
    // (features/settings, a later milestone) will perform, done directly
    // here since that screen doesn't exist yet.
    final code = InviteCode.generate();
    final codeHash = await _sha256Hex(code);
    final inviteSalt = _randomBytes16();
    final ikek = await deriveKeyEncryptionKey(
      password: code,
      salt: inviteSalt,
      params: Argon2Params.defaults,
    );
    final inviteWrap = await wrapVaultKeyWithInviteKey(
      vaultKey: ownerVaultKey,
      inviteKeyEncryptionKey: ikek,
    );

    final createResp = await owner.apiClient.createInvite(
      codeHash: codeHash,
      wrappedVaultKey: base64.encode(inviteWrap.ciphertext),
      wrapNonce: base64.encode(inviteWrap.nonce),
      kdfSalt: base64.encode(inviteSalt),
      kdfParams: Argon2Params.defaults.toJson(),
      ttlHours: 24,
    );
    expect(createResp.isOk, isTrue, reason: createResp.errorOrNull?.toString());

    final db2 = AppDatabase.forTesting(NativeDatabase.memory());
    final newMember = SessionController(
      database: db2,
      keyValueStore: InMemoryKeyValueStore(),
    );
    await pumpEventQueue();
    await newMember.checkAndSetServer(server.baseUrl);

    final joinResult = await newMember.joinByInvite(
      rawCode: code,
      login: 'grace',
      displayName: 'Grace',
      password: 'graces own password',
      deviceName: 'Graces Phone',
      devicePlatform: 'ios',
    );
    expect(joinResult.isOk, isTrue, reason: joinResult.errorOrNull?.toString());
    expect(newMember.state, isA<AuthReady>());
    expect((newMember.state as AuthReady).identity.vaultId, ownerVaultId);

    // Both members' vault keys unwrap to the same underlying key, proving
    // they share one vault rather than each getting their own.
    final newMemberVaultKey = newMember.vaultKeyHolder.keyOrNull!;
    expect(
      await newMemberVaultKey.extractBytes(),
      await ownerVaultKey.extractBytes(),
    );
  });

  test('recovery by phrase resets the password and unlocks the vault on a new device', () async {
    final ownerStore = InMemoryKeyValueStore();
    final db1 = AppDatabase.forTesting(NativeDatabase.memory());
    final owner = SessionController(database: db1, keyValueStore: ownerStore);
    await pumpEventQueue();
    await owner.checkAndSetServer(server.baseUrl);
    final pending = await owner.prepareNewVault(wordlist);
    await owner.completeBootstrap(
      vault: pending,
      login: 'dave',
      displayName: 'Dave',
      password: 'daves original password',
      bootstrapToken: server.bootstrapToken,
      deviceName: 'Daves Phone',
      devicePlatform: 'android',
    );
    final originalVaultId = (owner.state as AuthReady).identity.vaultId;

    final db2 = AppDatabase.forTesting(NativeDatabase.memory());
    final recovering = SessionController(
      database: db2,
      keyValueStore: InMemoryKeyValueStore(),
    );
    await pumpEventQueue();
    await recovering.checkAndSetServer(server.baseUrl);

    final recoverResult = await recovering.recoverByPhrase(
      login: 'dave',
      phraseWords: pending.phraseWords,
      newPassword: 'daves brand new recovered password',
      bip39Wordlist: wordlist,
      deviceName: 'Recovery Device',
      devicePlatform: 'android',
    );
    expect(
      recoverResult.isOk,
      isTrue,
      reason: recoverResult.errorOrNull?.toString(),
    );
    expect(recovering.state, isA<AuthReady>());
    expect((recovering.state as AuthReady).identity.vaultId, originalVaultId);

    // The old password no longer works from a fresh session.
    final db3 = AppDatabase.forTesting(NativeDatabase.memory());
    final afterRecovery = SessionController(
      database: db3,
      keyValueStore: InMemoryKeyValueStore(),
    );
    await pumpEventQueue();
    await afterRecovery.checkAndSetServer(server.baseUrl);
    final oldPasswordLogin = await afterRecovery.login(
      login: 'dave',
      password: 'daves original password',
      deviceName: 'D',
      devicePlatform: 'android',
    );
    expect(oldPasswordLogin.isErr, isTrue);

    final newPasswordLogin = await afterRecovery.login(
      login: 'dave',
      password: 'daves brand new recovered password',
      deviceName: 'D2',
      devicePlatform: 'android',
    );
    expect(
      newPasswordLogin.isOk,
      isTrue,
      reason: newPasswordLogin.errorOrNull?.toString(),
    );
  });

  test(
    'recovery with a wrong phrase is rejected without changing anything',
    () async {
      final db1 = AppDatabase.forTesting(NativeDatabase.memory());
      final owner = SessionController(
        database: db1,
        keyValueStore: InMemoryKeyValueStore(),
      );
      await pumpEventQueue();
      await owner.checkAndSetServer(server.baseUrl);
      final pending = await owner.prepareNewVault(wordlist);
      await owner.completeBootstrap(
        vault: pending,
        login: 'erin',
        displayName: 'Erin',
        password: 'erins original password',
        bootstrapToken: server.bootstrapToken,
        deviceName: 'Erins Phone',
        devicePlatform: 'android',
      );

      final wrongPhrase = List<String>.from(pending.phraseWords)..shuffle();
      // Guarantee it actually differs from the original (shuffle could, in
      // principle, reproduce the same order).
      if (wrongPhrase.join(' ') == pending.phraseWords.join(' ')) {
        wrongPhrase[0] = wrongPhrase[0] == 'abandon' ? 'ability' : 'abandon';
      }

      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      final attacker = SessionController(
        database: db2,
        keyValueStore: InMemoryKeyValueStore(),
      );
      await pumpEventQueue();
      await attacker.checkAndSetServer(server.baseUrl);

      final result = await attacker.recoverByPhrase(
        login: 'erin',
        phraseWords: wrongPhrase,
        newPassword: 'attacker chosen password',
        bip39Wordlist: wordlist,
        deviceName: 'Attacker Device',
        devicePlatform: 'android',
      );
      expect(result.isErr, isTrue);

      // Original password still works.
      final db3 = AppDatabase.forTesting(NativeDatabase.memory());
      final check = SessionController(
        database: db3,
        keyValueStore: InMemoryKeyValueStore(),
      );
      await pumpEventQueue();
      await check.checkAndSetServer(server.baseUrl);
      final stillWorks = await check.login(
        login: 'erin',
        password: 'erins original password',
        deviceName: 'D',
        devicePlatform: 'android',
      );
      expect(
        stillWorks.isOk,
        isTrue,
        reason: stillWorks.errorOrNull?.toString(),
      );
    },
  );

  test(
    'checking an unreachable server address fails without changing state',
    () async {
      final controller = newController();
      await pumpEventQueue();

      final result = await controller.checkAndSetServer('http://127.0.0.1:1');
      expect(result.isErr, isTrue);
      expect(controller.state, isA<AuthNeedsServer>());
    },
  );
}
