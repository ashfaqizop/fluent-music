/// A remote-config-driven tweak to one InnerTube client identity's context,
/// applied without an app update (Masterdoc §6.5 — "active client identities
/// + order + context/params").
final class ClientIdentityOverride {
  /// Creates an override for a single client identity.
  const ClientIdentityOverride({this.clientVersion, this.priority});

  /// Creates an override from its JSON representation. Unknown/missing
  /// fields are tolerated (never throws) per §6.5's "additive and safe"
  /// contract.
  factory ClientIdentityOverride.fromJson(Map<String, dynamic> json) {
    return ClientIdentityOverride(
      clientVersion: json['clientVersion'] as String?,
      priority: (json['priority'] as num?)?.toInt(),
    );
  }

  /// Replaces the identity's `clientVersion` context field, e.g. to patch a
  /// stale version string when YouTube starts rejecting it, without
  /// requiring a new app release.
  final String? clientVersion;

  /// Reorders the identity within the race without editing the owning
  /// config's `clientIdentityOrder` itself. Lower values race earlier;
  /// `null` leaves the identity at its position in `clientIdentityOrder`.
  final int? priority;

  /// Converts this override to its JSON representation.
  Map<String, dynamic> toJson() => {
    if (clientVersion != null) 'clientVersion': clientVersion,
    if (priority != null) 'priority': priority,
  };
}
