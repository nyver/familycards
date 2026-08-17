import 'package:cryptography/cryptography.dart';

/// Argon2id parameters as received from the server (`kdf_params` JSON:
/// `{"m": <KiB>, "t": <iterations>, "p": <parallelism>}`). The `m` value
/// is already in the 1 KiB blocks package:cryptography's [Argon2id]
/// expects, so no unit conversion is needed.
class Argon2Params {
  final int memoryKiB;
  final int iterations;
  final int parallelism;

  const Argon2Params({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
  });

  factory Argon2Params.fromJson(Map<String, dynamic> json) => Argon2Params(
    memoryKiB: json['m'] as int,
    iterations: json['t'] as int,
    parallelism: json['p'] as int,
  );

  Map<String, dynamic> toJson() => {
    'm': memoryKiB,
    't': iterations,
    'p': parallelism,
  };

  /// The parameters mandated by the spec for new accounts: m=64 MiB
  /// (65536 KiB), t=3, p=1.
  static const defaults = Argon2Params(
    memoryKiB: 65536,
    iterations: 3,
    parallelism: 1,
  );
}

const _keyLength = 32;

/// Derives a 32-byte key from [password] and [salt] using Argon2id.
/// Used for KEK (from the user's password), IKEK (from an invite code),
/// and RKEK (from the recovery phrase) - the three key-encryption-key
/// derivations in the spec all share this same shape, differing only in
/// what string is fed in and which salt accompanies it.
///
/// This is CPU- and memory-intensive (up to ~64 MiB and noticeable wall
/// time on low-end phones) by design - callers must run it off the UI
/// thread, e.g. via `compute()` or an isolate, to avoid janking the app.
Future<SecretKey> deriveKeyEncryptionKey({
  required String password,
  required List<int> salt,
  required Argon2Params params,
}) {
  final algorithm = Argon2id(
    parallelism: params.parallelism,
    memory: params.memoryKiB,
    iterations: params.iterations,
    hashLength: _keyLength,
  );
  return algorithm.deriveKeyFromPassword(password: password, nonce: salt);
}
