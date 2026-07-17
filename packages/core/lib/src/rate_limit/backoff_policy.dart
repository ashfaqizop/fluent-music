import 'dart:math';

/// Computes retry delays for rate-limited/failing requests (Masterdoc §6.9):
/// exponential backoff with a cap, jitter, and deference to a server-supplied
/// `Retry-After` when one is present.
final class BackoffPolicy {
  /// Creates a backoff policy.
  ///
  /// [baseDelay] is the delay before the first retry; each subsequent retry
  /// doubles it, capped at [maxDelay]. [jitterRatio] (0.0–1.0) randomizes the
  /// computed delay by up to that fraction in either direction, so many
  /// concurrent clients don't retry in lockstep.
  const BackoffPolicy({
    required this.baseDelay,
    required this.maxDelay,
    required this.jitterRatio,
  });

  /// The delay before the first retry attempt.
  final Duration baseDelay;

  /// The maximum delay, regardless of attempt count.
  final Duration maxDelay;

  /// Fraction (0.0–1.0) of the computed delay to randomize by.
  final double jitterRatio;

  /// Returns the delay to wait before retry number [attempt] (1-indexed).
  ///
  /// If [retryAfter] is supplied (parsed from a `Retry-After` response
  /// header), it takes precedence over the computed backoff — the server is
  /// authoritative about how long to wait. Otherwise returns an exponential
  /// delay capped at [maxDelay], jittered using [random] (defaults to a new
  /// [Random], but tests should inject a seeded instance for determinism).
  Duration delayForAttempt(
    int attempt, {
    Duration? retryAfter,
    Random? random,
  }) {
    if (retryAfter != null) return retryAfter;

    final exponent = attempt.clamp(0, 62);
    final rawMicros = baseDelay.inMicroseconds * pow(2, exponent);
    final cappedMicros = min(
      rawMicros.toDouble(),
      maxDelay.inMicroseconds.toDouble(),
    );

    final rng = random ?? Random();
    final jitterSpread = cappedMicros * jitterRatio;
    final jitteredMicros =
        cappedMicros + (rng.nextDouble() * 2 - 1) * jitterSpread;

    final clampedMicros = jitteredMicros.clamp(
      0,
      maxDelay.inMicroseconds.toDouble(),
    );
    return Duration(microseconds: clampedMicros.round());
  }
}
