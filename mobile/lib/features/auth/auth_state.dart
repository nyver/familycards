import 'identity_store.dart';

/// The app's top-level session state, driving which flow is shown:
/// server address entry, onboarding (create/join/login), unlock, or the
/// main app.
sealed class AuthState {
  const AuthState();
}

/// Still reading persisted state from secure storage.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// No server address has been configured yet.
class AuthNeedsServer extends AuthState {
  const AuthNeedsServer();
}

/// A server is configured but no local account exists on this device.
class AuthNeedsOnboarding extends AuthState {
  final String serverAddress;
  const AuthNeedsOnboarding(this.serverAddress);
}

/// A local account exists but the vault key is not in memory (cold start,
/// or the background lock timeout elapsed) - the user must unlock with
/// their password or biometrics.
class AuthNeedsUnlock extends AuthState {
  final StoredIdentity identity;
  const AuthNeedsUnlock(this.identity);
}

/// Fully unlocked: the vault key is in memory and the app can decrypt
/// cards.
class AuthReady extends AuthState {
  final StoredIdentity identity;
  const AuthReady(this.identity);
}
