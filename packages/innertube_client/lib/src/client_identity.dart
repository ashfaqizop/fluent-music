/// Describes one InnerTube client identity (e.g. WEB_REMIX, ANDROID_VR)
/// eligible to participate in the parallel client race (Masterdoc §6.2).
///
/// This is a structural placeholder for Phase 0: it lets the package
/// compile and be unit-tested. The real identity pool, request-context
/// builder, and remote-config-driven ordering land in Phase 1 (§20, P1).
final class ClientIdentity {
  /// Creates a client identity with its InnerTube context fields.
  const ClientIdentity({
    required this.name,
    required this.clientName,
    required this.clientVersion,
  });

  /// Human-readable identifier, e.g. `"WEB_REMIX"`.
  final String name;

  /// The InnerTube `clientName` context field.
  final String clientName;

  /// The InnerTube `clientVersion` context field.
  final String clientVersion;

  @override
  String toString() => 'ClientIdentity($name, $clientName/$clientVersion)';
}
