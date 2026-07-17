import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Maps remote-config identity names to the `youtube_explode_dart`
/// [YoutubeApiClient] constants used to resolve stream URLs (Masterdoc
/// §6.2).
///
/// This is a *different* catalog than `innertube_client`'s search/browse
/// identities: stream resolution and search/browse hit different InnerTube
/// surfaces through different libraries with different supported client
/// sets. Notably, `WEB_REMIX` — the correct identity for YT Music
/// search/browse — has no equivalent here, because `youtube_explode_dart`
/// 3.1.0 exposes no `WEB_REMIX` stream-client constant (verified against
/// its installed source). Names with no mapping are simply filtered out of
/// the stream-resolution race; see `docs/deviations.md` and
/// `docs/extraction.md` for the full rationale.
final Map<String, YoutubeApiClient> streamClientMapping = {
  'ANDROID_MUSIC': YoutubeApiClient.androidMusic,
  'IOS': YoutubeApiClient.ios,
  'ANDROID_VR': YoutubeApiClient.androidVr,
  'TV': YoutubeApiClient.tv,
  'ANDROID': YoutubeApiClient.androidSdkless,
  'WEB': YoutubeApiClient.safari,
  'MWEB': YoutubeApiClient.mweb,
};

/// Resolves [name] to a [YoutubeApiClient], or `null` if this identity has
/// no stream-resolution equivalent (e.g. `WEB_REMIX`).
YoutubeApiClient? mapToStreamClient(String name) => streamClientMapping[name];
