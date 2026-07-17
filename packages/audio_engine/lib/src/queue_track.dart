/// A track queued for playback (Masterdoc §7).
///
/// `audio_engine` must not depend on `extraction`/`innertube_client`
/// (`docs/architecture.md`'s layering rule keeps sibling feature packages
/// independent), so it never sees a resolved stream URL up front. Instead
/// the caller supplies [resolveStreamUri], invoked lazily — and re-invoked
/// each time the engine needs this track's audio, since stream URLs are
/// short-lived — to obtain a playable URL.
final class QueueTrack {
  /// Creates a queued track.
  const QueueTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.resolveStreamUri,
    this.album,
    this.artworkUri,
    this.duration,
  });

  /// Stable identifier for this track (e.g. a YouTube video id), opaque to
  /// `audio_engine`.
  final String id;

  /// The track title, shown in the queue and pushed to SMTC.
  final String title;

  /// The primary artist, shown in the queue and pushed to SMTC.
  final String artist;

  /// The album name, if known.
  final String? album;

  /// Artwork URI, if known, pushed to SMTC.
  final Uri? artworkUri;

  /// The track's known duration, if available ahead of resolution.
  final Duration? duration;

  /// Lazily resolves a playable audio stream URL for this track.
  ///
  /// Called once when the track becomes the current or look-ahead track.
  /// May be called again later (e.g. after a cache miss on a stale URL).
  final Future<Uri> Function() resolveStreamUri;

  @override
  String toString() => 'QueueTrack($id, "$title" by $artist)';
}
