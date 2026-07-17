import 'package:innertube_client/src/client_identity.dart';

/// `WEB_REMIX` — the YouTube Music web client identity, used for
/// search/browse (Masterdoc §6.2). This is the identity YT Music's own web
/// player uses, so it has full access to music-specific browse surfaces
/// (home feed, artist/album pages) that general-purpose YouTube clients
/// don't expose.
///
/// The `apiKey`/`clientVersion` values below are the widely-published
/// InnerTube web constants used by numerous open-source YouTube/YT-Music
/// clients (e.g. ytmusicapi, NewPipe) as of the Masterdoc's 2026-07-16
/// baseline. These values drift as YouTube ships new web client builds —
/// that's exactly what `RemoteConfig.identityOverrides['WEB_REMIX']` exists
/// to patch without an app rebuild (see `docs/extraction.md`).
const webRemixIdentity = ClientIdentity(
  name: 'WEB_REMIX',
  clientName: 'WEB_REMIX',
  clientNameId: 67,
  clientVersion: '1.20250310.01.00',
  apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
  userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
);

/// All client identities `innertube_client` knows how to build a request
/// context for, keyed by [ClientIdentity.name].
const Map<String, ClientIdentity> knownClientIdentities = {
  'WEB_REMIX': webRemixIdentity,
};
