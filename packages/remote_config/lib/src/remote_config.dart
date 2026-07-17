/// The signed, remotely-fetched configuration that drives extraction
/// self-healing (Masterdoc §6.5): active client identities, race stagger,
/// PO-token policy, and a schema version.
///
/// This is the data shape only; fetching/verifying/applying a real signed
/// JSON payload lands in Phase 1 (§20, P1).
final class RemoteConfig {
  /// Creates a remote-config snapshot.
  const RemoteConfig({
    required this.schemaVersion,
    required this.clientIdentityOrder,
    required this.raceStaggerMs,
    required this.poTokenEnabled,
  });

  /// The config schema version, for forward/backward-compatible parsing.
  final int schemaVersion;

  /// Client identities eligible for the parallel race, in priority order.
  final List<String> clientIdentityOrder;

  /// Delay between staggered client-race launches, in milliseconds
  /// (`0` means fully parallel — see §6.2).
  final int raceStaggerMs;

  /// Whether the experimental PO-token provider slot is enabled (§6.4).
  final bool poTokenEnabled;

  /// The embedded, always-available default used when no signed config has
  /// been fetched yet, or the fetched one fails verification (§6.5) — the
  /// app must never brick on a malformed/incompatible remote config.
  static const RemoteConfig embeddedDefault = RemoteConfig(
    schemaVersion: 1,
    clientIdentityOrder: ['WEB_REMIX'],
    raceStaggerMs: 0,
    poTokenEnabled: false,
  );
}
