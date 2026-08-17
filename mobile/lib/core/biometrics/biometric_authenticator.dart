import 'package:local_auth/local_auth.dart';

/// Thin wrapper over `local_auth`, abstracted so the security screen and
/// unlock screen are testable without a real platform biometric channel.
abstract class BiometricAuthenticator {
  /// Whether biometric hardware is present, enrolled, and usable right
  /// now (e.g. false on an emulator with no fingerprint configured).
  Future<bool> isAvailable();

  /// Shows the platform biometric prompt with [reason] as the rationale
  /// text. Returns whether the user authenticated successfully; never
  /// throws - any platform error is treated as a failed attempt.
  Future<bool> authenticate(String reason);
}

class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
