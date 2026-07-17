/// Base type for domain/typed errors carried through `Result`s.
///
/// Feature packages (e.g. `extraction`, `innertube_client`, `remote_config`)
/// use this — or define their own sealed hierarchies alongside it — to
/// carry enough context for the diagnostics surface (§15.5) and local logs
/// (§15.4).
sealed class AppFailure {
  const AppFailure(this.message, {this.cause});

  /// A human-readable description of what went wrong.
  final String message;

  /// The underlying exception/error that triggered this failure, if any.
  final Object? cause;

  @override
  // Debug/log-only representation; class names are not obfuscated in this
  // app's release builds (no --obfuscate in the packaging scripts).
  // ignore: no_runtimetype_tostring
  String toString() => '$runtimeType: $message';
}

/// An unexpected failure that doesn't fit a more specific category.
final class UnknownFailure extends AppFailure {
  /// Creates an unknown failure with [message] and optional [cause].
  const UnknownFailure(super.message, {super.cause});
}

/// A failure caused by a network request (timeout, DNS, HTTP error, etc.).
final class NetworkFailure extends AppFailure {
  /// Creates a network failure with [message] and optional [cause].
  const NetworkFailure(super.message, {super.cause});
}

/// A failure surfaced by a code path that is intentionally not yet
/// implemented (used by Phase 0 skeletons ahead of their owning phase).
final class NotImplementedFailure extends AppFailure {
  /// Creates a not-implemented failure with [message] and optional [cause].
  const NotImplementedFailure(super.message, {super.cause});
}
