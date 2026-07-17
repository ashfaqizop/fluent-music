/// A typed result carrying either a success value [T] or an error [E].
///
/// Used across all layers instead of throwing for expected/recoverable
/// failures, per the Masterdoc's fail-loud-but-graceful philosophy (§15.3).
sealed class Result<T, E> {
  const Result();

  /// Creates a successful result carrying [value].
  const factory Result.ok(T value) = Ok<T, E>;

  /// Creates a failed result carrying [error].
  const factory Result.err(E error) = Err<T, E>;

  /// Whether this is a successful [Ok] result.
  bool get isOk => this is Ok<T, E>;

  /// Whether this is a failed [Err] result.
  bool get isErr => this is Err<T, E>;

  /// Pattern-matches on the result, forcing both branches to be handled.
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  }) => switch (this) {
    Ok<T, E>(:final value) => ok(value),
    Err<T, E>(:final error) => err(error),
  };

  /// Returns the success value, or `null` if this is an [Err].
  T? get valueOrNull => switch (this) {
    Ok<T, E>(:final value) => value,
    Err<T, E>() => null,
  };

  /// Returns the error, or `null` if this is an [Ok].
  E? get errorOrNull => switch (this) {
    Ok<T, E>() => null,
    Err<T, E>(:final error) => error,
  };
}

/// A successful [Result] carrying a [value].
final class Ok<T, E> extends Result<T, E> {
  /// Creates a successful result carrying [value].
  const Ok(this.value);

  /// The success value.
  final T value;
}

/// A failed [Result] carrying an [error].
final class Err<T, E> extends Result<T, E> {
  /// Creates a failed result carrying [error].
  const Err(this.error);

  /// The error value.
  final E error;
}
