/// One song/video result row from an InnerTube search response.
///
/// Phase 1 scopes search parsing to song/video rows only — artist/album/
/// playlist result rendering is deferred to Phase 4's content-surface work,
/// since Phase 1's DoD only needs "search → resolve → play a track."
final class SearchResultItem {
  /// Creates a search result item.
  const SearchResultItem({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.isVideoEntity,
    this.album,
    this.durationText,
  });

  /// The YouTube video id, used to resolve a playable stream (§6).
  final String videoId;

  /// The track/video title.
  final String title;

  /// The primary artist/channel name.
  final String artist;

  /// The album name, if this result carries one (song entities usually do;
  /// video entities usually don't).
  final String? album;

  /// The displayed duration, e.g. `"3:45"`.
  final String? durationText;

  /// Whether this result is a YouTube "video" entity rather than a YT Music
  /// "song" entity (§6.6) — used to prefer song entities when both exist.
  final bool isVideoEntity;

  @override
  String toString() =>
      'SearchResultItem($videoId, "$title" by $artist, '
      'video: $isVideoEntity)';
}
