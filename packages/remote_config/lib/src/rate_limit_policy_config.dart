/// Remotely-tunable rate-limit hygiene parameters (Masterdoc §6.9), so the
/// author can dial pacing back if YouTube pushes back on request volume
/// without shipping a new app version.
final class RateLimitPolicyConfig {
  /// Creates a rate-limit policy configuration.
  const RateLimitPolicyConfig({
    required this.minRequestIntervalMs,
    required this.maxConcurrencyPerHost,
    required this.backoffBaseMs,
    required this.backoffMaxMs,
    required this.backoffJitterRatio,
  });

  /// Creates a policy from its JSON representation, tolerating missing
  /// fields by falling back to [embeddedDefault]'s values for each one.
  factory RateLimitPolicyConfig.fromJson(Map<String, dynamic> json) {
    return RateLimitPolicyConfig(
      minRequestIntervalMs:
          (json['minRequestIntervalMs'] as num?)?.toInt() ??
          embeddedDefault.minRequestIntervalMs,
      maxConcurrencyPerHost:
          (json['maxConcurrencyPerHost'] as num?)?.toInt() ??
          embeddedDefault.maxConcurrencyPerHost,
      backoffBaseMs:
          (json['backoffBaseMs'] as num?)?.toInt() ??
          embeddedDefault.backoffBaseMs,
      backoffMaxMs:
          (json['backoffMaxMs'] as num?)?.toInt() ??
          embeddedDefault.backoffMaxMs,
      backoffJitterRatio:
          (json['backoffJitterRatio'] as num?)?.toDouble() ??
          embeddedDefault.backoffJitterRatio,
    );
  }

  /// The safe, always-available default used when no field is overridden.
  static const embeddedDefault = RateLimitPolicyConfig(
    minRequestIntervalMs: 150,
    maxConcurrencyPerHost: 4,
    backoffBaseMs: 500,
    backoffMaxMs: 20000,
    backoffJitterRatio: 0.3,
  );

  /// Minimum spacing between consecutive requests to the same host.
  final int minRequestIntervalMs;

  /// Maximum concurrent in-flight requests per host.
  final int maxConcurrencyPerHost;

  /// Base delay (before jitter) for the first retry.
  final int backoffBaseMs;

  /// Cap on the computed backoff delay, regardless of attempt count.
  final int backoffMaxMs;

  /// Fraction (0.0–1.0) of the computed delay to randomize by.
  final double backoffJitterRatio;

  /// Converts this policy to its JSON representation.
  Map<String, dynamic> toJson() => {
    'minRequestIntervalMs': minRequestIntervalMs,
    'maxConcurrencyPerHost': maxConcurrencyPerHost,
    'backoffBaseMs': backoffBaseMs,
    'backoffMaxMs': backoffMaxMs,
    'backoffJitterRatio': backoffJitterRatio,
  };
}
