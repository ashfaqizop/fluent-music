import 'dart:async';

import 'package:core/core.dart';
import 'package:extraction/src/client_identity_mapping.dart';
import 'package:extraction/src/extraction_layer.dart';
import 'package:extraction/src/stream_selection.dart';
import 'package:remote_config/remote_config.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Layer 2 (Masterdoc §6.3 step 2 — "alternate client identities/params
/// from remote config").
///
/// Layer 1 ([ClientRaceLayer]) already races every identity remote config
/// has promoted into `clientIdentityOrder`, so a second identical race
/// would be redundant. This layer is instead a **sequential**, cheap
/// long-tail safety net over identities the app *knows about* but remote
/// config hasn't enabled yet — an extension of the Masterdoc's literal
/// wording, logged in `docs/deviations.md`.
final class AlternateIdentityLayer implements ExtractionLayer {
  /// Creates a layer that resolves streams via [youtubeExplode].
  AlternateIdentityLayer(this.youtubeExplode);

  /// The `youtube_explode_dart` instance used for stream resolution.
  final YoutubeExplode youtubeExplode;

  @override
  String get name => 'alternate_identity';

  @override
  Future<ExtractionAttempt> tryResolve({
    required String videoId,
    required RemoteConfig config,
  }) async {
    final promoted = {
      ...config.clientIdentityOrder,
      ...config.disabledIdentities,
    };
    final candidates = streamClientMapping.entries.where(
      (e) => !promoted.contains(e.key),
    );

    if (candidates.isEmpty) {
      return const AttemptSkipped('no un-promoted identities to try');
    }

    for (final entry in candidates) {
      try {
        final manifest = await youtubeExplode.videos.streamsClient
            .getManifest(videoId, ytClients: [entry.value])
            .timeout(Duration(milliseconds: config.raceLaneTimeoutMs));

        final best = pickBestAudio(manifest.audioOnly);
        if (best != null) return AttemptSuccess(best.url);
      } on TimeoutException {
        continue;
      } on Exception {
        continue;
      }
    }

    return const AttemptFailed(
      NetworkFailure('no alternate identity produced a stream'),
    );
  }
}
