// The public constructor parameter names intentionally differ from the
// private field names they populate, so initializing formals
// (`this._secureStore`) cannot be used without also making the fields
// non-private.
// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'envelope.dart';

/// How long the app may sit in the background before the vault key is
/// wiped from memory and the user must unlock again.
const backgroundLockTimeout = Duration(minutes: 5);

/// Generates a fresh 32-byte vault key (VK) from a CSPRNG. Called exactly
/// once, when a vault is first created.
Future<SecretKey> generateVaultKey() => Xchacha20.poly1305Aead().newSecretKey();

/// Wraps VK with a key-encryption key (KEK/IKEK/RKEK), tagged `vk-wrap-v1`
/// for password/recovery wraps.
Future<Envelope> wrapVaultKeyWithPasswordOrRecoveryKey({
  required SecretKey vaultKey,
  required SecretKey keyEncryptionKey,
}) async {
  final vkBytes = await vaultKey.extractBytes();
  return wrapVaultKey(
    vaultKey: Uint8List.fromList(vkBytes),
    keyEncryptionKey: keyEncryptionKey,
    aad: AadTags.vkWrap,
  );
}

/// Unwraps VK from a password/recovery wrap. Throws
/// [DecryptionFailedException] on a wrong password/phrase.
Future<SecretKey> unwrapVaultKeyWithPasswordOrRecoveryKey({
  required Envelope envelope,
  required SecretKey keyEncryptionKey,
}) async {
  final bytes = await unwrapVaultKey(
    envelope: envelope,
    keyEncryptionKey: keyEncryptionKey,
    aad: AadTags.vkWrap,
  );
  return SecretKey(bytes);
}

/// Wraps VK for an invite, tagged `invite-v1` so an invite wrap can never
/// be mistaken for (or substituted into) a password/recovery wrap.
Future<Envelope> wrapVaultKeyWithInviteKey({
  required SecretKey vaultKey,
  required SecretKey inviteKeyEncryptionKey,
}) async {
  final vkBytes = await vaultKey.extractBytes();
  return wrapVaultKey(
    vaultKey: Uint8List.fromList(vkBytes),
    keyEncryptionKey: inviteKeyEncryptionKey,
    aad: AadTags.invite,
  );
}

Future<SecretKey> unwrapVaultKeyWithInviteKey({
  required Envelope envelope,
  required SecretKey inviteKeyEncryptionKey,
}) async {
  final bytes = await unwrapVaultKey(
    envelope: envelope,
    keyEncryptionKey: inviteKeyEncryptionKey,
    aad: AadTags.invite,
  );
  return SecretKey(bytes);
}

/// Persists (or would persist) the vault key across app restarts, gated
/// on the user having enabled biometric unlock. Abstracted so the holder
/// below is testable without a real platform secure-storage channel; the
/// real implementation (backed by flutter_secure_storage) lives in
/// features/settings, wired up once the biometric toggle exists.
abstract class VaultKeySecureStore {
  Future<void> save(Uint8List vaultKey);
  Future<Uint8List?> load();
  Future<void> clear();
}

/// Holds the vault key in memory for the app session and enforces the
/// background-lock policy: the key is wiped after [backgroundLockTimeout]
/// spent backgrounded, requiring the user to unlock again (biometrics or
/// password) before any card can be decrypted.
///
/// [now] is injectable so tests can control elapsed time without real
/// delays; it defaults to the wall clock.
class VaultKeyHolder {
  SecretKey? _key;
  DateTime? _backgroundedAt;
  final DateTime Function() _now;
  final VaultKeySecureStore? _secureStore;

  VaultKeyHolder({DateTime Function()? now, VaultKeySecureStore? secureStore})
    : _now = now ?? DateTime.now,
      _secureStore = secureStore;

  bool get isUnlocked => _key != null;

  /// Returns the current vault key, or null if locked.
  SecretKey? get keyOrNull => _key;

  void unlock(SecretKey key) {
    _key = key;
    _backgroundedAt = null;
  }

  /// Wipes the key from memory (e.g. on logout, or after the background
  /// timeout elapses).
  void lock() {
    _key = null;
    _backgroundedAt = null;
  }

  /// Call when the app is backgrounded.
  void enterBackground() {
    _backgroundedAt = _now();
  }

  /// Call when the app returns to the foreground. If more than
  /// [backgroundLockTimeout] has elapsed since [enterBackground], the key
  /// is wiped and the caller must re-unlock.
  void enterForeground() {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) return;
    if (_now().difference(backgroundedAt) > backgroundLockTimeout) {
      lock();
    }
  }

  /// Persists the key to secure storage - only meaningful when a store
  /// was provided (i.e. biometric unlock is enabled). A no-op otherwise.
  Future<void> persistIfBiometricEnabled() async {
    final store = _secureStore;
    final key = _key;
    if (store == null || key == null) return;
    await store.save(Uint8List.fromList(await key.extractBytes()));
  }

  /// Removes any persisted copy of the key - called when biometric unlock
  /// is turned off, so no copy of VK survives outside memory.
  Future<void> clearPersisted() async {
    await _secureStore?.clear();
  }

  /// Whether a secure store was configured at all - i.e. whether
  /// biometric unlock is a meaningful option on this holder (a fresh
  /// holder with no store, as used by tests that don't exercise
  /// biometrics, always reports false).
  bool get hasSecureStore => _secureStore != null;

  /// Unlocks using a previously persisted key, if one exists (the
  /// biometric unlock path). The caller is responsible for the actual
  /// biometric prompt *before* calling this - this method only reads the
  /// already-encrypted-at-rest bytes and does not itself gate access on
  /// anything. Returns whether a persisted key was found and applied.
  Future<bool> unlockFromPersisted() async {
    final store = _secureStore;
    if (store == null) return false;
    final bytes = await store.load();
    if (bytes == null) return false;
    unlock(SecretKey(bytes));
    return true;
  }
}
