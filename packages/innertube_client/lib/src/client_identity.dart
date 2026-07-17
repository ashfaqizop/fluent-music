/// Describes one InnerTube client identity (e.g. WEB_REMIX, ANDROID_VR)
/// eligible to participate in the parallel client race (Masterdoc §6.2).
final class ClientIdentity {
  /// Creates a client identity with its InnerTube context fields.
  const ClientIdentity({
    required this.name,
    required this.clientName,
    required this.clientVersion,
    this.clientNameId,
    this.apiKey,
    this.baseUrl = 'https://music.youtube.com',
    this.userAgent,
    this.hl = 'en',
    this.gl = 'US',
    this.extraContext = const {},
  });

  /// Human-readable identifier, e.g. `"WEB_REMIX"`.
  final String name;

  /// The InnerTube `clientName` context field.
  final String clientName;

  /// The InnerTube `clientVersion` context field.
  final String clientVersion;

  /// InnerTube's numeric client-name id (e.g. `67` for `WEB_REMIX`), used in
  /// some endpoints/headers alongside the string [clientName].
  final int? clientNameId;

  /// The InnerTube API key sent as the `key` query parameter.
  final String? apiKey;

  /// The InnerTube host this identity talks to, e.g.
  /// `https://music.youtube.com`.
  final String baseUrl;

  /// The `User-Agent` header this identity presents, if any.
  final String? userAgent;

  /// The InnerTube `hl` (host language) context field.
  final String hl;

  /// The InnerTube `gl` (geo location) context field.
  final String gl;

  /// Additional device-specific `context.client` fields this identity needs
  /// (e.g. `androidSdkVersion`, `deviceMake`), merged in verbatim.
  final Map<String, dynamic> extraContext;

  @override
  String toString() => 'ClientIdentity($name, $clientName/$clientVersion)';
}
