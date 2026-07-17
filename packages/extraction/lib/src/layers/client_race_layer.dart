import 'dart:async';

import 'package:core/core.dart';
import 'package:extraction/src/client_identity_mapping.dart';
import 'package:extraction/src/extraction_layer.dart';
import 'package:extraction/src/stream_selection.dart';
import 'package:remote_config/remote_config.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Layer 1 (Masterdoc §6.3): races the remote-config-ordered, enabled
/// client identities in parallel (with an optional stagger), taking the
/// first lane that produces a usable audio-only stream.
///
/// Dart futures aren't cancellable — lanes that lose the race are left to
/// run to completion and their results simply ignored. This is a
/// deliberate, documented simplification (see `docs/extraction.md`), not an
/// oversight: cancelling in-flight HTTP requests mid-flight buys little
/// here since `getManifest` calls are typically fast relative to the
/// stagger/timeout windows involved.
final class ClientRaceLayer implements ExtractionLayer {
  /// Creates a layer that resolves streams via [youtubeExplode].
  ClientRaceLayer(this.youtubeExplode);

  /// The `youtube_explode_dart` instance used for stream resolution.
  final YoutubeExplode youtubeExplode;

  @override
  String get name => 'client_race';

  @override
  Future<ExtractionAttempt> tryResolve({
    required String videoId,
    required RemoteConfig config,
  }) async {
    final enabled = config.clientIdentityOrder
        .where((name) => !config.disabledIdentities.contains(name))
        .toList();

    final lanes = <MapEntry<String, YoutubeApiClient>>[
      for (final name in enabled)
        if (mapToStreamClient(name) case final client?) MapEntry(name, client),
    ];

    if (lanes.isEmpty) {
      return const AttemptSkipped('no mappable client identities to race');
    }

    final laneCount = config.maxConcurrentRaceLanes > 0
        ? config.maxConcurrentRaceLanes
        : lanes.length;
    final activeLanes = lanes.take(laneCount).toList();

    final completer = Completer<ExtractionAttempt>();
    var remaining = activeLanes.length;

    for (var i = 0; i < activeLanes.length; i++) {
      final lane = activeLanes[i];
      final launchDelay = Duration(milliseconds: config.raceStaggerMs * i);
      unawaited(
        Future<void>.delayed(launchDelay)
            .then((_) => _attemptLane(videoId, lane.value, config))
            .then((attempt) {
              remaining--;
              if (attempt is AttemptSuccess && !completer.isCompleted) {
                completer.complete(attempt);
              } else if (remaining == 0 && !completer.isCompleted) {
                completer.complete(
                  const AttemptFailed(
                    NetworkFailure('all client-race lanes failed'),
                  ),
                );
              }
            }),
      );
    }

    return completer.future;
  }

  Future<ExtractionAttempt> _attemptLane(
    String videoId,
    YoutubeApiClient client,
    RemoteConfig config,
  ) async {
    try {
      final manifest = await youtubeExplode.videos.streamsClient
          .getManifest(videoId, ytClients: [client])
          .timeout(Duration(milliseconds: config.raceLaneTimeoutMs));

      final best = pickBestAudio(manifest.audioOnly);
      if (best == null) {
        return const AttemptFailed(
          NetworkFailure('no audio-only stream in manifest'),
        );
      }
      return AttemptSuccess(best.url);
    } on TimeoutException {
      return const AttemptFailed(NetworkFailure('client-race lane timed out'));
    } on Exception catch (e) {
      return AttemptFailed(NetworkFailure('client-race lane failed', cause: e));
    }
  }
}
