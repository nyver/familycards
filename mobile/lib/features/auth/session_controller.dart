import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/argon2.dart';
import '../../core/crypto/envelope.dart';
import '../../core/crypto/invite_code.dart';
import '../../core/crypto/recovery_phrase.dart';
import '../../core/crypto/secure_vault_key_store.dart';
import '../../core/crypto/vault_key.dart';
import '../../core/db/database.dart';
import '../../core/net/api_client.dart';
import '../../core/net/certificate_fingerprint.dart';
import '../../core/net/dto/dto.dart';
import '../../core/net/secure_token_store.dart';
import '../../core/result.dart';
import '../../core/storage/key_value_store.dart';
import 'auth_state.dart';
import 'identity_store.dart';

/// A freshly generated, not-yet-persisted vault: the material needed to
/// show the recovery phrase for confirmation before any network call is
/// made (see the "create vault" flow's ordering requirement).
class PendingVault {
  final SecretKey vaultKey;
  final List<String> phraseWords;
  const PendingVault({required this.vaultKey, required this.phraseWords});
}

/// Owns the app's session lifecycle: server selection, account creation,
/// login, invite redemption, phrase-based recovery, and vault key
/// unlock/lock. Backed by secure storage for everything that must survive
/// a restart, and by [VaultKeyHolder] for the key itself, which never
/// touches disk unless biometric unlock is enabled (see
/// core/crypto/vault_key.dart).
class SessionController extends StateNotifier<AuthState> {
  final AppDatabase database;
  final IdentityStore identityStore;
  final VaultKeyHolder vaultKeyHolder;
  late final SecureTokenStore tokenStore;
  late final ApiClient apiClient;

  /// [keyValueStore], if given, backs both the identity store and the
  /// token store (an in-memory fake in tests, avoiding a dependency on
  /// real platform secure storage). Ignored if [identityStore] is also
  /// given explicitly.
  SessionController({
    required this.database,
    IdentityStore? identityStore,
    VaultKeyHolder? vaultKeyHolder,
    KeyValueStore? keyValueStore,
  }) : identityStore = identityStore ?? IdentityStore(storage: keyValueStore),
       vaultKeyHolder =
           vaultKeyHolder ??
           VaultKeyHolder(
             secureStore: SecureVaultKeyStore(storage: keyValueStore),
           ),
       super(const AuthLoading()) {
    tokenStore = SecureTokenStore(
      storage: keyValueStore,
      onSessionExpiredCallback: _handleSessionExpired,
    );
    apiClient = ApiClient(baseUrl: '', tokenStore: tokenStore);
    _init();
  }

  Future<void> _init() async {
    final address = await identityStore.getServerAddress();
    if (address == null) {
      state = const AuthNeedsServer();
      return;
    }
    final pinnedHex = await identityStore.getPinnedCertificateFingerprint();
    apiClient.setBaseUrl(
      address,
      pinnedFingerprint: pinnedHex == null
          ? null
          : _parsePersistedFingerprintOrFailClosed(pinnedHex),
    );

    final identity = await identityStore.load();
    if (identity == null) {
      state = AuthNeedsOnboarding(address);
      return;
    }
    state = AuthNeedsUnlock(identity);
  }

  Future<void> _handleSessionExpired() async {
    vaultKeyHolder.lock();
    final identity = await identityStore.load();
    if (identity != null) {
      state = AuthNeedsUnlock(identity);
    }
  }

  /// Normalizes user-entered server input into a full URL, defaulting to
  /// https when no scheme is given.
  static String normalizeServerAddress(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  /// Checks a candidate server address (and, if given, the certificate
  /// fingerprint to pin to it) via GET /v1/health and, if it responds
  /// like a compatible server, persists both and moves to onboarding.
  /// Does not change persisted state on failure - the caller shows the
  /// returned error and lets the user retry, optionally after confirming
  /// a fingerprint via [probePresentedCertificate].
  Future<Result<void>> checkAndSetServer(
    String rawAddress, {
    Uint8List? pinnedFingerprint,
  }) async {
    final address = normalizeServerAddress(rawAddress);
    final verified = await _verifyServer(
      address,
      pinnedFingerprint: pinnedFingerprint,
    );
    return verified.fold((_) async {
      apiClient.setBaseUrl(address, pinnedFingerprint: pinnedFingerprint);
      await identityStore.setServerAddress(address);
      await identityStore.setPinnedCertificateFingerprint(
        pinnedFingerprint == null ? null : formatFingerprint(pinnedFingerprint),
      );
      state = AuthNeedsOnboarding(address);
      return const Result.ok(null);
    }, (error) => Result.err(error));
  }

  /// Verifies that [address] answers GET /v1/health (optionally pinned to
  /// [pinnedFingerprint]) without changing anything persisted or
  /// left applied to [apiClient] - the previous base URL and pin are
  /// always restored before returning, regardless of outcome. Callers
  /// that want to keep a successful result apply it explicitly.
  Future<Result<void>> _verifyServer(
    String address, {
    Uint8List? pinnedFingerprint,
  }) async {
    final previousBaseUrl = apiClient.currentBaseUrl;
    final previousPin = apiClient.pinnedFingerprint;
    apiClient.setBaseUrl(address, pinnedFingerprint: pinnedFingerprint);
    final result = await apiClient.health();
    apiClient.setBaseUrl(previousBaseUrl, pinnedFingerprint: previousPin);
    return result.map((_) {});
  }

  /// Trust-on-first-use support: attempts to connect to [rawAddress]
  /// purely to capture the certificate it presents, without validating
  /// it. Used when a health check fails because no pin exists yet and the
  /// certificate isn't trusted by the system's CA store - the caller
  /// shows the user this certificate's fingerprint and, only after
  /// explicit confirmation, retries [checkAndSetServer] with it pinned.
  Future<X509Certificate?> probePresentedCertificate(String rawAddress) {
    return ApiClient.probeCertificate(normalizeServerAddress(rawAddress));
  }

  /// Phase 1 of vault creation: generates VK and a recovery phrase purely
  /// locally, with no network call, so the UI can show the phrase for
  /// confirmation before anything is sent to the server.
  Future<PendingVault> prepareNewVault(List<String> bip39Wordlist) async {
    final vaultKey = await generateVaultKey();
    final phrase = await RecoveryPhrase.generate(bip39Wordlist);
    return PendingVault(vaultKey: vaultKey, phraseWords: phrase);
  }

  /// Phase 2: called only after the user has confirmed the recovery
  /// phrase. Derives KEK and RKEK, wraps VK under both, and calls
  /// bootstrap.
  Future<Result<void>> completeBootstrap({
    required PendingVault vault,
    required String login,
    required String displayName,
    required String password,
    required String bootstrapToken,
    required String deviceName,
    required String devicePlatform,
  }) async {
    final kdfSalt = _randomSalt();
    final kek = await deriveKeyEncryptionKey(
      password: password,
      salt: kdfSalt,
      params: Argon2Params.defaults,
    );
    final passwordWrap = await wrapVaultKeyWithPasswordOrRecoveryKey(
      vaultKey: vault.vaultKey,
      keyEncryptionKey: kek,
    );

    final recoverySalt = _randomSalt();
    final rkek = await deriveKeyEncryptionKey(
      password: RecoveryPhrase.toKdfInput(vault.phraseWords),
      salt: recoverySalt,
      params: Argon2Params.defaults,
    );
    final recoveryWrap = await wrapVaultKeyWithPasswordOrRecoveryKey(
      vaultKey: vault.vaultKey,
      keyEncryptionKey: rkek,
    );

    final req = BootstrapRequest(
      login: login,
      displayName: displayName,
      password: password,
      kdfSalt: _b64(kdfSalt),
      kdfParams: Argon2Params.defaults.toJson(),
      wrappedVaultKey: _b64(passwordWrap.ciphertext),
      wrapNonce: _b64(passwordWrap.nonce),
      recovery: RecoveryDto(
        wrappedVaultKey: _b64(recoveryWrap.ciphertext),
        wrapNonce: _b64(recoveryWrap.nonce),
        kdfSalt: _b64(recoverySalt),
        kdfParams: Argon2Params.defaults.toJson(),
        verifier: RecoveryPhrase.toKdfInput(vault.phraseWords),
      ),
      device: DeviceDto(name: deviceName, platform: devicePlatform),
    );

    final result = await apiClient.bootstrap(
      req,
      bootstrapToken: bootstrapToken,
    );
    return result.fold((session) async {
      await _completeSession(
        session: session,
        login: login,
        displayName: displayName,
        kdfSalt: req.kdfSalt,
        kdfParams: req.kdfParams,
        wrappedVaultKey: req.wrappedVaultKey,
        wrapNonce: req.wrapNonce,
        vaultKey: vault.vaultKey,
      );
      return const Result.ok(null);
    }, (error) => Result.err(error));
  }

  Future<Result<void>> login({
    required String login,
    required String password,
    required String deviceName,
    required String devicePlatform,
  }) async {
    final preResult = await apiClient.prelogin(login);
    return preResult.fold((pre) async {
      final kek = await deriveKeyEncryptionKey(
        password: password,
        salt: _fromB64(pre.kdfSalt),
        params: Argon2Params.fromJson(pre.kdfParams),
      );

      final loginResult = await apiClient.login(
        login: login,
        password: password,
        device: DeviceDto(name: deviceName, platform: devicePlatform),
      );
      return loginResult.fold((session) async {
        SecretKey vaultKey;
        try {
          final vkBytes = await unwrapVaultKeyWithPasswordOrRecoveryKey(
            envelope: Envelope(
              nonce: _fromB64(session.wrapNonce!),
              ciphertext: _fromB64(session.wrappedVaultKey!),
            ),
            keyEncryptionKey: kek,
          );
          vaultKey = vkBytes;
        } on DecryptionFailedException catch (e) {
          return Result.err(
            AppError.crypto('Failed to unlock the vault key', cause: e),
          );
        }

        await _completeSession(
          session: session,
          login: login,
          displayName: login,
          kdfSalt: session.kdfSalt!,
          kdfParams: session.kdfParams!,
          wrappedVaultKey: session.wrappedVaultKey!,
          wrapNonce: session.wrapNonce!,
          vaultKey: vaultKey,
        );
        return const Result.ok(null);
      }, (error) => Result.err(error));
    }, (error) => Result.err(error));
  }

  Future<Result<void>> joinByInvite({
    required String rawCode,
    required String login,
    required String displayName,
    required String password,
    required String deviceName,
    required String devicePlatform,
  }) async {
    final normalizedCode = InviteCode.normalize(rawCode);
    if (normalizedCode == null) {
      return Result.err(AppError.invalidRequest('Invalid invite code'));
    }
    final codeHash = await _sha256Hex(normalizedCode);

    final inviteResult = await apiClient.getInvite(codeHash);
    return inviteResult.fold((invite) async {
      final ikek = await deriveKeyEncryptionKey(
        password: normalizedCode,
        salt: _fromB64(invite.kdfSalt),
        params: Argon2Params.fromJson(invite.kdfParams),
      );

      SecretKey vaultKey;
      try {
        vaultKey = await unwrapVaultKeyWithInviteKey(
          envelope: Envelope(
            nonce: _fromB64(invite.wrapNonce),
            ciphertext: _fromB64(invite.wrappedVaultKey),
          ),
          inviteKeyEncryptionKey: ikek,
        );
      } on DecryptionFailedException catch (e) {
        return Result.err(AppError.crypto('Invalid invite code', cause: e));
      }

      final ownSalt = _randomSalt();
      final ownKek = await deriveKeyEncryptionKey(
        password: password,
        salt: ownSalt,
        params: Argon2Params.defaults,
      );
      final ownWrap = await wrapVaultKeyWithPasswordOrRecoveryKey(
        vaultKey: vaultKey,
        keyEncryptionKey: ownKek,
      );

      final redeemResult = await apiClient.redeemInvite(
        codeHash: codeHash,
        login: login,
        displayName: displayName,
        password: password,
        kdfSalt: _b64(ownSalt),
        kdfParams: Argon2Params.defaults.toJson(),
        wrappedVaultKey: _b64(ownWrap.ciphertext),
        wrapNonce: _b64(ownWrap.nonce),
        device: DeviceDto(name: deviceName, platform: devicePlatform),
      );
      return redeemResult.fold((session) async {
        await _completeSession(
          session: session,
          login: login,
          displayName: displayName,
          kdfSalt: _b64(ownSalt),
          kdfParams: Argon2Params.defaults.toJson(),
          wrappedVaultKey: _b64(ownWrap.ciphertext),
          wrapNonce: _b64(ownWrap.nonce),
          vaultKey: vaultKey,
        );
        return const Result.ok(null);
      }, (error) => Result.err(error));
    }, (error) => Result.err(error));
  }

  Future<Result<void>> recoverByPhrase({
    required String login,
    required List<String> phraseWords,
    required String newPassword,
    required List<String> bip39Wordlist,
    required String deviceName,
    required String devicePlatform,
  }) async {
    final isValid = await RecoveryPhrase.validate(phraseWords, bip39Wordlist);
    if (!isValid) {
      return Result.err(AppError.invalidRequest('Invalid recovery phrase'));
    }

    final preResult = await apiClient.recoveryPrelogin(login);
    return preResult.fold((pre) async {
      final rkek = await deriveKeyEncryptionKey(
        password: RecoveryPhrase.toKdfInput(phraseWords),
        salt: _fromB64(pre.kdfSalt),
        params: Argon2Params.fromJson(pre.kdfParams),
      );

      // recovery/prelogin returns the wrap directly (mirroring how
      // login returns it after password verification) - it is safe to
      // hand out unconditionally because it is useless without RKEK,
      // which requires the actual phrase to derive. See docs/API.md.
      SecretKey vaultKey;
      try {
        vaultKey = await unwrapVaultKeyWithPasswordOrRecoveryKey(
          envelope: Envelope(
            nonce: _fromB64(pre.wrapNonce),
            ciphertext: _fromB64(pre.wrappedVaultKey),
          ),
          keyEncryptionKey: rkek,
        );
      } on DecryptionFailedException catch (e) {
        return Result.err(AppError.crypto('Invalid recovery phrase', cause: e));
      }

      final newSalt = _randomSalt();
      final newKek = await deriveKeyEncryptionKey(
        password: newPassword,
        salt: newSalt,
        params: Argon2Params.defaults,
      );
      final newWrap = await wrapVaultKeyWithPasswordOrRecoveryKey(
        vaultKey: vaultKey,
        keyEncryptionKey: newKek,
      );

      final redeemResult = await apiClient.recoveryRedeem(
        login: login,
        verifier: RecoveryPhrase.toKdfInput(phraseWords),
        newPassword: newPassword,
        kdfSalt: _b64(newSalt),
        kdfParams: Argon2Params.defaults.toJson(),
        wrappedVaultKey: _b64(newWrap.ciphertext),
        wrapNonce: _b64(newWrap.nonce),
        device: DeviceDto(name: deviceName, platform: devicePlatform),
      );
      return redeemResult.fold((session) async {
        await _completeSession(
          session: session,
          login: login,
          displayName: login,
          kdfSalt: _b64(newSalt),
          kdfParams: Argon2Params.defaults.toJson(),
          wrappedVaultKey: _b64(newWrap.ciphertext),
          wrapNonce: _b64(newWrap.nonce),
          vaultKey: vaultKey,
        );
        return const Result.ok(null);
      }, (error) => Result.err(error));
    }, (error) => Result.err(error));
  }

  /// Unlocks an existing local identity with the account password
  /// (post-cold-start or after the background timeout).
  Future<Result<void>> unlockWithPassword(String password) async {
    final identityState = state;
    if (identityState is! AuthNeedsUnlock) {
      return Result.err(AppError.unknown('No identity pending unlock'));
    }
    final identity = identityState.identity;

    final kek = await deriveKeyEncryptionKey(
      password: password,
      salt: _fromB64(identity.kdfSalt),
      params: Argon2Params.fromJson(identity.kdfParams),
    );
    try {
      final vaultKey = await unwrapVaultKeyWithPasswordOrRecoveryKey(
        envelope: Envelope(
          nonce: _fromB64(identity.wrapNonce),
          ciphertext: _fromB64(identity.wrappedVaultKey),
        ),
        keyEncryptionKey: kek,
      );
      vaultKeyHolder.unlock(vaultKey);
      state = AuthReady(identity);
      return const Result.ok(null);
    } on DecryptionFailedException catch (e) {
      return Result.err(AppError.crypto('Incorrect password', cause: e));
    }
  }

  /// Unlocks using a key previously persisted for biometric unlock. The
  /// caller must have already shown the platform biometric prompt (see
  /// core/biometrics/biometric_authenticator.dart) - this only applies
  /// the key if one was found, it does not itself authenticate the user.
  Future<Result<void>> unlockWithBiometrics() async {
    final identityState = state;
    if (identityState is! AuthNeedsUnlock) {
      return Result.err(AppError.unknown('No identity pending unlock'));
    }
    final applied = await vaultKeyHolder.unlockFromPersisted();
    if (!applied) {
      return Result.err(AppError.crypto('No biometric key available'));
    }
    state = AuthReady(identityState.identity);
    return const Result.ok(null);
  }

  /// Call when the app is backgrounded, to start the auto-lock timeout.
  void enterBackground() {
    vaultKeyHolder.enterBackground();
  }

  /// Call when the app returns to the foreground. If the background lock
  /// timeout elapsed, the vault key was wiped from memory - route back to
  /// the unlock screen so the user must re-authenticate before any card
  /// can be decrypted again.
  void enterForeground() {
    final wasUnlocked = vaultKeyHolder.isUnlocked;
    vaultKeyHolder.enterForeground();
    final currentState = state;
    if (wasUnlocked &&
        !vaultKeyHolder.isUnlocked &&
        currentState is AuthReady) {
      state = AuthNeedsUnlock(currentState.identity);
    }
  }

  /// Verifies [newAddress] (and, if given, a certificate fingerprint to
  /// pin to it) is reachable, then wipes all local state (identity,
  /// tokens, vault key, and the local database) and moves to onboarding
  /// against it - used when the user changes to a different server,
  /// which invalidates everything local. Nothing is wiped and no
  /// persisted state changes if verification fails - the caller shows
  /// the returned error and lets the user retry, optionally after
  /// confirming a fingerprint via [probePresentedCertificate].
  Future<Result<void>> changeServerAndWipeLocalData(
    String newAddress, {
    Uint8List? pinnedFingerprint,
  }) async {
    final normalized = normalizeServerAddress(newAddress);
    final verified = await _verifyServer(
      normalized,
      pinnedFingerprint: pinnedFingerprint,
    );
    return verified.fold((_) async {
      await database.cardsDao.watchVisibleCards().first; // ensure db is open
      for (final table in database.allTables) {
        await database.delete(table).go();
      }
      await identityStore.clearAll();
      await tokenStore.clear();
      await vaultKeyHolder.clearPersisted();
      vaultKeyHolder.lock();

      apiClient.setBaseUrl(normalized, pinnedFingerprint: pinnedFingerprint);
      await identityStore.setServerAddress(normalized);
      await identityStore.setPinnedCertificateFingerprint(
        pinnedFingerprint == null ? null : formatFingerprint(pinnedFingerprint),
      );
      state = AuthNeedsOnboarding(normalized);
      return const Result.ok(null);
    }, (error) => Result.err(error));
  }

  /// Signs out of the current account: best-effort revokes this device's
  /// session on the server (a failure here, e.g. no network, must not
  /// block sign-out - see "выход без сети"), then wipes local cards,
  /// tokens, the vault key (including any biometric-persisted copy), and
  /// the identity - but keeps the server address, so the user lands back
  /// on onboarding for the same server rather than server selection.
  Future<void> logout() async {
    final address =
        await identityStore.getServerAddress() ?? apiClient.currentBaseUrl;
    final refreshToken = await tokenStore.getRefreshToken();
    if (refreshToken != null) {
      await apiClient.logout(refreshToken);
    }

    for (final table in database.allTables) {
      await database.delete(table).go();
    }
    await identityStore.clearIdentity();
    await vaultKeyHolder.clearPersisted();
    vaultKeyHolder.lock();
    await tokenStore.clear();

    state = AuthNeedsOnboarding(address);
  }

  /// The plaintext code for a freshly generated invite (shown once - see
  /// client/settings spec, "Код показывается один раз") and its hash
  /// (used to cancel it later, while still on screen).
  Future<Result<({String code, String codeHash})>> createInvite({
    required SecretKey vaultKey,
    int ttlHours = 24,
  }) async {
    final code = InviteCode.generate();
    final codeHash = await _sha256Hex(code);
    final salt = _randomSalt();
    final ikek = await deriveKeyEncryptionKey(
      password: code,
      salt: salt,
      params: Argon2Params.defaults,
    );
    final wrap = await wrapVaultKeyWithInviteKey(
      vaultKey: vaultKey,
      inviteKeyEncryptionKey: ikek,
    );

    final result = await apiClient.createInvite(
      codeHash: codeHash,
      wrappedVaultKey: _b64(wrap.ciphertext),
      wrapNonce: _b64(wrap.nonce),
      kdfSalt: _b64(salt),
      kdfParams: Argon2Params.defaults.toJson(),
      ttlHours: ttlHours,
    );
    return result.fold(
      (_) => Result.ok((code: code, codeHash: codeHash)),
      (error) => Result.err(error),
    );
  }

  Future<void> _completeSession({
    required SessionResponse session,
    required String login,
    required String displayName,
    required String kdfSalt,
    required Map<String, dynamic> kdfParams,
    required String wrappedVaultKey,
    required String wrapNonce,
    required SecretKey vaultKey,
  }) async {
    await tokenStore.setTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );

    final identity = StoredIdentity(
      serverAddress: apiClient.currentBaseUrl,
      userId: session.userId,
      vaultId: session.vaultId,
      deviceId: session.deviceId,
      login: login,
      displayName: displayName,
      kdfSalt: kdfSalt,
      kdfParams: kdfParams,
      wrappedVaultKey: wrappedVaultKey,
      wrapNonce: wrapNonce,
    );
    await identityStore.save(identity);

    vaultKeyHolder.unlock(vaultKey);
    state = AuthReady(identity);
  }

  Uint8List _randomSalt() => _randomBytes(16);
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

String _b64(List<int> bytes) => base64.encode(bytes);

Uint8List _fromB64(String s) => base64.decode(s);

Future<String> _sha256Hex(String input) async {
  final digest = await Sha256().hash(utf8.encode(input));
  return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Parses a fingerprint read back from [IdentityStore], failing closed (a
/// fingerprint that can never match any real certificate) rather than
/// open (no pin at all) if the stored value is somehow unparseable - the
/// app itself only ever writes a value [formatFingerprint] produced, so
/// this should not happen, but a corrupted pin must still block the
/// connection rather than silently fall back to trusting the system's CA
/// store, which is exactly what pinning exists to override.
Uint8List _parsePersistedFingerprintOrFailClosed(String stored) {
  return tryParseSha256Fingerprint(stored) ?? Uint8List(sha256FingerprintLength);
}
