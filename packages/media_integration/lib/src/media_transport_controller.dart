import 'package:media_integration/src/now_playing_info.dart';

/// Drives the Windows SMTC overlay and responds to global media keys
/// (Masterdoc §12). Backed by `smtc_windows` (requires rustup at build).
///
/// Phase 2's `SmtcMediaTransportController` implementation covers hardware
/// media keys through the same SMTC session rather than a separate
/// `hotkey_manager` registration — see `docs/deviations.md`.
abstract interface class MediaTransportController {
  /// Pushes updated track metadata to the SMTC overlay.
  Future<void> updateNowPlaying(NowPlayingInfo info);

  /// Updates the SMTC timeline to [position] out of [duration].
  Future<void> updatePlaybackPosition(Duration position, Duration duration);

  /// Updates whether the SMTC overlay shows a playing or paused state
  /// (which icon it renders for its own play/pause button).
  Future<void> updatePlaybackStatus({required bool isPlaying});

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
  ///
  /// `smtc_windows` 1.1.0 does not expose the SMTC scrubber's
  /// position-change-request event through its public API (only
  /// `buttonPressStream`, covering play/pause/next/previous) — so no
  /// current [MediaTransportController] implementation actually emits
  /// this. Kept in the enum for forward-compatibility with a future
  /// package version or an alternate transport.
  seek,
}
