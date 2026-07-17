import 'package:remote_config/src/client_identity_override.dart';
import 'package:remote_config/src/rate_limit_policy_config.dart';

/// The signed, remotely-fetched configuration that drives extraction
/// self-healing (Masterdoc §6.5): active client identities, race stagger,
/// PO-token policy, rate-limit tuning, and a schema version.
final class RemoteConfig {
  /// Creates a remote-config snapshot.
  const RemoteConfig({
    required this.schemaVersion,
    required this.clientIdentityOrder,
    required this.raceStaggerMs,
    required this.poTokenEnabled,
    this.disabledIdentities = const {},
    this.identityOverrides = const {},
    this.maxConcurrentRaceLanes = 0,
    this.raceLaneTimeoutMs = 8000,
    this.rateLimit = RateLimitPolicyConfig.embeddedDefault,
    this.refreshIntervalMinutes = 180,
  });

  /// Creates a config from its signed-payload JSON representation.
  ///
  /// Additive and safe (§6.5): unknown fields are ignored, missing fields
  /// fall back to [embeddedDefault]'s values, and this never throws — a
  /// malformed/incompatible payload should be rejected by the *caller*
  /// (e.g. signature/schema checks upstream), not crash parsing itself.
  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    final schemaVersion =
        (json['schemaVersion'] as num?)?.toInt() ??
        embeddedDefault.schemaVersion;

    final rawOrder = json['clientIdentityOrder'];
    final clientIdentityOrder = rawOrder is List
        ? rawOrder.whereType<String>().toList()
        : embeddedDefault.clientIdentityOrder;

    final rawDisabled = json['disabledIdentities'];
    final disabledIdentities = rawDisabled is List
        ? rawDisabled.whereType<String>().toSet()
        : embeddedDefault.disabledIdentities;

    final rawOverrides = json['identityOverrides'];
    final identityOverrides = <String, ClientIdentityOverride>{
      if (rawOverrides is Map)
        for (final entry in rawOverrides.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key as String: ClientIdentityOverride.fromJson(
              entry.value as Map<String, dynamic>,
            ),
    };

    final rawRateLimit = json['rateLimit'];
    final rateLimit = rawRateLimit is Map<String, dynamic>
        ? RateLimitPolicyConfig.fromJson(rawRateLimit)
        : embeddedDefault.rateLimit;

    return RemoteConfig(
      schemaVersion: schemaVersion,
      clientIdentityOrder: clientIdentityOrder,
      raceStaggerMs:
          (json['raceStaggerMs'] as num?)?.toInt() ??
          embeddedDefault.raceStaggerMs,
      poTokenEnabled:
          json['poTokenEnabled'] as bool? ?? embeddedDefault.poTokenEnabled,
      disabledIdentities: disabledIdentities,
      identityOverrides: identityOverrides,
      maxConcurrentRaceLanes:
          (json['maxConcurrentRaceLanes'] as num?)?.toInt() ??
          embeddedDefault.maxConcurrentRaceLanes,
      raceLaneTimeoutMs:
          (json['raceLaneTimeoutMs'] as num?)?.toInt() ??
          embeddedDefault.raceLaneTimeoutMs,
      rateLimit: rateLimit,
      refreshIntervalMinutes:
          (json['refreshIntervalMinutes'] as num?)?.toInt() ??
          embeddedDefault.refreshIntervalMinutes,
    );
  }

  /// The embedded, always-available default used when no signed config has
  /// been fetched yet, or the fetched one fails verification (§6.5) — the
  /// app must never brick on a malformed/incompatible remote config.
  static const RemoteConfig embeddedDefault = RemoteConfig(
    schemaVersion: 2,
    clientIdentityOrder: [
      'WEB_REMIX',
      'ANDROID_MUSIC',
      'IOS',
      'ANDROID_VR',
      'TV',
    ],
    raceStaggerMs: 0,
    poTokenEnabled: false,
  );

  /// The config schema version, for forward/backward-compatible parsing.
  final int schemaVersion;

  /// Client identities eligible for the parallel race, in priority order.
  final List<String> clientIdentityOrder;

  /// Delay between staggered client-race launches, in milliseconds
  /// (`0` means fully parallel — see §6.2).
  final int raceStaggerMs;

  /// Whether the experimental PO-token provider slot is enabled (§6.4).
  final bool poTokenEnabled;

  /// Identity names to skip without removing them from
  /// [clientIdentityOrder] (e.g. a temporary block due to a known outage).
  final Set<String> disabledIdentities;

  /// Per-identity context/param overrides, keyed by identity name (§6.5).
  final Map<String, ClientIdentityOverride> identityOverrides;

  /// Maximum number of client-race lanes to run concurrently. `0` means
  /// unlimited (fully parallel, subject only to [raceStaggerMs]).
  final int maxConcurrentRaceLanes;

  /// Per-lane timeout for a single client-race attempt, in milliseconds.
  final int raceLaneTimeoutMs;

  /// Rate-limit hygiene tuning (§6.9).
  final RateLimitPolicyConfig rateLimit;

  /// How often (in minutes) the app should re-fetch this config in the
  /// background, in addition to fetching it on launch.
  final int refreshIntervalMinutes;

  /// Converts this config to its JSON representation (the payload half of
  /// the signed envelope — see `docs/remote-config.md`).
  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'clientIdentityOrder': clientIdentityOrder,
    'raceStaggerMs': raceStaggerMs,
    'poTokenEnabled': poTokenEnabled,
    'disabledIdentities': disabledIdentities.toList(),
    'identityOverrides': {
      for (final entry in identityOverrides.entries)
        entry.key: entry.value.toJson(),
    },
    'maxConcurrentRaceLanes': maxConcurrentRaceLanes,
    'raceLaneTimeoutMs': raceLaneTimeoutMs,
    'rateLimit': rateLimit.toJson(),
    'refreshIntervalMinutes': refreshIntervalMinutes,
  };
}
