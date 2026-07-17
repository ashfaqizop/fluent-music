import 'package:media_integration/src/now_playing_info.dart';

/// Drives the Windows SMTC overlay and responds to global media keys
/// (Masterdoc §12). Backed by `smtc_windows` (requires rustup at build).
///
/// This package is intentionally not yet referenced by `app/` in Phase 0 —
/// declaring the dependency here resolves it into the workspace lockfile
/// without pulling its native Rust bridge into the app's build graph until
/// whichever later phase wires it in (see `docs/deviations.md`).
abstract interface class MediaTransportController {
  /// Pushes updated track metadata to the SMTC overlay.
  Future<void> updateNowPlaying(NowPlayingInfo info);

  /// Updates the SMTC timeline to [position] out of [duration].
  Future<void> updatePlaybackPosition(Duration position, Duration duration);

  /// Emits commands received from SMTC or a global media key.
  Stream<MediaTransportCommand> get commands;

  /// Releases the underlying platform resources.
  Future<void> dispose();
}

/// A command received from SMTC or a global media key.
enum MediaTransportCommand {
  /// Resume playback.
  play,

  /// Pause playback.
  pause,

  /// Skip to the next track.
  next,

  /// Skip to the previous track.
  previous,

  /// Seek to a new position (carried separately by the caller).
  seek,
}
