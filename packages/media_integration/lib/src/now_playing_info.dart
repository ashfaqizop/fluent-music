/// Track metadata shared across SMTC, tray, toast, and Discord RPC surfaces
/// (Masterdoc §12, §16). A single shape avoids each integration re-deriving
/// it from the playback layer independently.
final class NowPlayingInfo {
  /// Creates the shared now-playing metadata shape.
  const NowPlayingInfo({
    required this.title,
    required this.artist,
    this.artworkUri,
  });

  /// The track title.
  final String title;

  /// The track's primary artist.
  final String artist;

  /// Artwork URL, if available.
  final Uri? artworkUri;
}
