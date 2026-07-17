/// Failures specific to talking to InnerTube (Masterdoc §6.1).
///
/// `core`'s `AppFailure` hierarchy is `sealed` to its own
/// library, so per its own doc comment ("feature packages... define their
/// own sealed hierarchies alongside it") this is a standalone sealed
/// hierarchy rather than a subclass — it gives the diagnostics surface
/// (§15.5) richer context than a bare network/unknown failure would.
sealed class InnerTubeFailure {
  const InnerTubeFailure(this.message, {this.cause});

  /// A human-readable description of what went wrong.
  final String message;

  /// The underlying exception/error that triggered this failure, if any.
  final Object? cause;

  @override
  // Debug/log-only representation; mirrors core's AppFailure.toString().
  // ignore: no_runtimetype_tostring
  String toString() => '$runtimeType: $message';
}

/// InnerTube responded with a non-2xx HTTP status.
final class InnerTubeHttpFailure extends InnerTubeFailure {
  /// Creates a failure for an unexpected [statusCode] response.
  InnerTubeHttpFailure(this.statusCode, {Object? cause})
    : super('InnerTube request failed with HTTP $statusCode', cause: cause);

  /// The HTTP status code InnerTube responded with.
  final int statusCode;
}

/// InnerTube's response body couldn't be parsed into the expected shape
/// (YouTube frequently reshuffles its renderer tree without notice).
final class InnerTubeParseFailure extends InnerTubeFailure {
  /// Creates a failure carrying a [rawSnippet] of the unparseable response,
  /// for diagnostics/bug reports.
  InnerTubeParseFailure(this.rawSnippet, {Object? cause})
    : super('Failed to parse InnerTube response', cause: cause);

  /// A short snippet of the raw response body that failed to parse.
  final String rawSnippet;
}
