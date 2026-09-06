/// A typed outcome of an operation that can fail: either [Ok] with a value
/// of type [T], or [Err] with an [AppError]. Used throughout the app
/// instead of throwing exceptions across layer boundaries, so callers are
/// forced to handle failure explicitly.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(AppError error) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// Returns the success value, or null if this is an [Err].
  T? get valueOrNull => switch (this) {
    Ok<T>(value: final v) => v,
    Err<T>() => null,
  };

  /// Returns the error, or null if this is an [Ok].
  AppError? get errorOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(error: final e) => e,
  };

  /// Transforms the success value, leaving an error untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(value: final v) => Result.ok(transform(v)),
    Err<T>(error: final e) => Result.err(e),
  };

  /// Runs [onOk] or [onErr] depending on the outcome, returning whatever
  /// they return.
  R fold<R>(R Function(T value) onOk, R Function(AppError error) onErr) =>
      switch (this) {
        Ok<T>(value: final v) => onOk(v),
        Err<T>(error: final e) => onErr(e),
      };
}

final class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final AppError error;
  const Err(this.error);
}

/// The taxonomy of errors surfaced to the UI. Every layer that can fail
/// (network, crypto, storage) maps its own error types into one of these,
/// so screens only ever need to branch on [AppErrorKind].
enum AppErrorKind {
  /// No network connectivity, or the server did not respond in time.
  network,

  /// The server rejected the request as invalid (4xx other than auth).
  invalidRequest,

  /// Authentication failed: wrong credentials, expired/invalid session.
  unauthorized,

  /// The caller is not permitted to do this (e.g. disabled account).
  forbidden,

  /// The requested resource does not exist.
  notFound,

  /// The request conflicts with current state (e.g. quota reached).
  conflict,

  /// The resource is gone (e.g. an expired or already-used invite).
  gone,

  /// A cryptographic operation failed (wrong password, corrupted data,
  /// tampering detected).
  crypto,

  /// The server's TLS certificate did not match the pinned fingerprint
  /// (or, before any pin exists, is not trusted by the system's CA
  /// store) - see core/net/certificate_fingerprint.dart.
  certificateMismatch,

  /// A local storage operation failed (database, filesystem).
  storage,

  /// An error that does not fit any of the above.
  unknown,
}

class AppError implements Exception {
  final AppErrorKind kind;
  final String message;
  final Object? cause;

  const AppError(this.kind, this.message, {this.cause});

  factory AppError.network(String message, {Object? cause}) =>
      AppError(AppErrorKind.network, message, cause: cause);
  factory AppError.invalidRequest(String message, {Object? cause}) =>
      AppError(AppErrorKind.invalidRequest, message, cause: cause);
  factory AppError.unauthorized(String message, {Object? cause}) =>
      AppError(AppErrorKind.unauthorized, message, cause: cause);
  factory AppError.forbidden(String message, {Object? cause}) =>
      AppError(AppErrorKind.forbidden, message, cause: cause);
  factory AppError.notFound(String message, {Object? cause}) =>
      AppError(AppErrorKind.notFound, message, cause: cause);
  factory AppError.conflict(String message, {Object? cause}) =>
      AppError(AppErrorKind.conflict, message, cause: cause);
  factory AppError.gone(String message, {Object? cause}) =>
      AppError(AppErrorKind.gone, message, cause: cause);
  factory AppError.crypto(String message, {Object? cause}) =>
      AppError(AppErrorKind.crypto, message, cause: cause);
  factory AppError.certificateMismatch(String message, {Object? cause}) =>
      AppError(AppErrorKind.certificateMismatch, message, cause: cause);
  factory AppError.storage(String message, {Object? cause}) =>
      AppError(AppErrorKind.storage, message, cause: cause);
  factory AppError.unknown(String message, {Object? cause}) =>
      AppError(AppErrorKind.unknown, message, cause: cause);

  @override
  String toString() => 'AppError(${kind.name}): $message';
}
