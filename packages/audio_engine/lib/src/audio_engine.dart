/// Coarse playback state exposed by [AudioEngine] as a reactive stream.
enum PlaybackState {
  /// No track loaded.
  idle,

  /// A track is loaded but buffering before playback can start/resume.
  buffering,

  /// A track is actively playing.
  playing,

  /// A track is loaded and paused.
  paused,

  /// Playback failed (see the diagnostics surface for details, §15.5).
  error,
}

/// Wraps `media_kit` behind a single interface the rest of the app depends
/// on (Masterdoc §7), keeping UI decoupled from the concrete audio backend.
///
/// This is the stable contract other layers can already code against; the
/// real media_kit-backed queue/gapless/prefetch/EQ implementation lands in
/// Phase 2 (§20, P2).
abstract interface class AudioEngine {
  /// Emits the current [PlaybackState] whenever it changes.
  Stream<PlaybackState> get stateStream;

  /// Resumes or starts playback of the current track.
  Future<void> play();

  /// Pauses playback, retaining the current position.
  Future<void> pause();

  /// Seeks the current track to [position].
  Future<void> seek(Duration position);

  /// Releases the underlying player and any held resources.
  Future<void> dispose();
}
