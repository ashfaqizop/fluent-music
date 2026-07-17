import 'package:core/core.dart';
import 'package:innertube_client/innertube_client.dart';

/// Search + stream-resolution surface `app/`'s UI and `PlaybackCoordinator`
/// depend on, kept separate from the concrete `ExtractionService` so both
/// are fakeable in tests without real network/remote-config I/O — the same
/// pattern `audio_engine`'s `AudioEngine` and `media_integration`'s
/// `MediaTransportController` interfaces already follow.
abstract interface class TrackResolver {
  /// Searches YT Music for [query].
  Future<Result<List<SearchResultItem>, InnerTubeFailure>> search(String query);

  /// Resolves a playable audio stream URL for [videoId].
  Future<Uri> resolveStream(String videoId);
}
