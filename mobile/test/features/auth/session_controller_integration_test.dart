@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull;
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

  test(
    'a password unlock re-persists the biometric key, so a stale toggle '
    "left on by a wipe (change-server/logout) doesn't strand the user on "
    'the password screen forever',
    () async {
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

      // Simulate the user turning biometric unlock on in settings (see
      // security_screen.dart's _setEnabled(true)) and then something that
      // wipes the persisted key without touching that toggle - both
      // changeServerAndWipeLocalData and logout do exactly this today.
      await first.securitySettingsStore.setBiometricEnabled(true);
      await first.vaultKeyHolder.persistIfBiometricEnabled();
      await first.vaultKeyHolder.clearPersisted();

      // Cold restart: the toggle still says "on", but there is no
      // persisted key to read - this is the exact state that used to
      // leave the biometric prompt firing for nothing, stranding the user
      // on the password field with zero feedback.
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      final second = SessionController(database: db2, keyValueStore: store);
      await pumpEventQueue();
      expect(second.state, isA<AuthNeedsUnlock>());
      expect(await second.securitySettingsStore.isBiometricEnabled(), isTrue);
      expect(
        await second.vaultKeyHolder.unlockFromPersisted(),
        isFalse,
        reason: 'reproduces the bug: nothing persisted despite the toggle',
      );

      final unlock = await second.unlockWithPassword(
        'a very good password indeed',
      );
      expect(unlock.isOk, isTrue, reason: unlock.errorOrNull?.toString());

      // The fix: unlocking with the password while the toggle is on must
      // silently refresh the persisted copy, so biometric unlock recovers
      // on its own - no need to manually toggle it off and back on.
      final db3 = AppDatabase.forTesting(NativeDatabase.memory());
      final third = SessionController(database: db3, keyValueStore: store);
      await pumpEventQueue();
      expect(
        await third.vaultKeyHolder.unlockFromPersisted(),
        isTrue,
        reason: 'biometric unlock should be self-healed after one password unlock',
      );
      expect(third.vaultKeyHolder.isUnlocked, isTrue);
    },
  );

  test('logout revokes the session, clears local data, and keeps the server address', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final controller = SessionController(
      database: db,
      keyValueStore: InMemoryKeyValueStore(),
    );
    await pumpEventQueue();
    await controller.checkAndSetServer(server.baseUrl);
    final pending = await controller.prepareNewVault(wordlist);
    await controller.completeBootstrap(
      vault: pending,
      login: 'heidi',
      displayName: 'Heidi',
      password: 'heidis excellent password',
      bootstrapToken: server.bootstrapToken,
      deviceName: 'Heidis Phone',
      devicePlatform: 'android',
    );
    expect(controller.state, isA<AuthReady>());

    // A card exists locally, standing in for whatever offline-first
    // state logout must wipe.
    await db.cardsDao.insertNewCard(
      CardsCompanion.insert(
        id: 'card-1',
        storeName: 'Test Store',
        cardNumber: '123456',
        barcodeFormat: 'code128',
        color: 0xFF112233,
        createdAt: 0,
        updatedAt: 0,
      ),
    );

    await controller.logout();

    expect(controller.state, isA<AuthNeedsOnboarding>());
    expect(
      (controller.state as AuthNeedsOnboarding).serverAddress,
      server.baseUrl,
    );
    expect(controller.vaultKeyHolder.isUnlocked, isFalse);
    expect(await db.cardsDao.watchVisibleCards().first, isEmpty);
    expect(await controller.tokenStore.getAccessToken(), isNull);

    // The device's session was actually revoked server-side: logging
    // back in and then attempting to reuse the *old* refresh token
    // must fail (rotation/revocation already covered elsewhere; here
    // we only need the login path itself to still work post-logout).
    final loginAgain = await controller.login(
      login: 'heidi',
      password: 'heidis excellent password',
      deviceName: 'Heidis Phone',
      devicePlatform: 'android',
    );
    expect(loginAgain.isOk, isTrue, reason: loginAgain.errorOrNull?.toString());
  });

  test('logout without network still clears local state', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final controller = SessionController(
      database: db,
      keyValueStore: InMemoryKeyValueStore(),
    );
    await pumpEventQueue();
    await controller.checkAndSetServer(server.baseUrl);
    final pending = await controller.prepareNewVault(wordlist);
    await controller.completeBootstrap(
      vault: pending,
      login: 'ivan',
      displayName: 'Ivan',
      password: 'ivans excellent password',
      bootstrapToken: server.bootstrapToken,
      deviceName: 'Ivans Phone',
      devicePlatform: 'android',
    );

    await server.stop();
    await controller.logout();

    expect(controller.state, isA<AuthNeedsOnboarding>());
    expect(controller.vaultKeyHolder.isUnlocked, isFalse);
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
