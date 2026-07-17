import 'dart:async';

import 'package:media_integration/src/media_transport_controller.dart';
import 'package:media_integration/src/now_playing_info.dart';
import 'package:smtc_windows/smtc_windows.dart';

/// [MediaTransportController] backed by the Windows SMTC overlay via
/// `smtc_windows` (Masterdoc §12).
///
/// Hardware media keys are covered for free: Windows delivers media-key
/// presses to the app holding the foreground SMTC session through the same
/// [SMTCWindows.buttonPressStream] used for the overlay's own buttons, so
/// no separate `hotkey_manager` registration is needed here — see
/// `docs/deviations.md` for the reference-laptop fallback plan if that
/// turns out to be unreliable while the window is unfocused/minimized.
final class SmtcMediaTransportController implements MediaTransportController {
  /// Creates a controller and its underlying [SMTCWindows] session.
  ///
  /// Callers must call [initializeRuntime] once at process start (before
  /// constructing this) — it wires up `smtc_windows`'s Rust bridge.
  SmtcMediaTransportController({SMTCWindows? smtc})
    : _smtc =
          smtc ??
          SMTCWindows(
            config: const SMTCConfig(
              playEnabled: true,
              pauseEnabled: true,
              nextEnabled: true,
              prevEnabled: true,
              stopEnabled: false,
              fastForwardEnabled: false,
              rewindEnabled: false,
            ),
          ) {
    _buttonSub = _smtc.buttonPressStream.listen((button) {
      final command = _commandFor(button);
      if (command != null) _commandsController.add(command);
    });
  }

  /// Initializes `smtc_windows`'s Rust bridge. Call once at process start,
  /// before constructing any [SmtcMediaTransportController].
  static Future<void> initializeRuntime() => SMTCWindows.initialize();

  final SMTCWindows _smtc;
  final _commandsController =
      StreamController<MediaTransportCommand>.broadcast();
  late final StreamSubscription<PressedButton> _buttonSub;

  @override
  Stream<MediaTransportCommand> get commands => _commandsController.stream;

  @override
  Future<void> updateNowPlaying(NowPlayingInfo info) => _smtc.updateMetadata(
    MusicMetadata(
      title: info.title,
      artist: info.artist,
      thumbnail: info.artworkUri?.toString(),
    ),
  );

  @override
  Future<void> updatePlaybackPosition(Duration position, Duration duration) =>
      _smtc.updateTimeline(
        PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: duration.inMilliseconds,
          positionMs: position.inMilliseconds,
        ),
      );

  @override
  Future<void> updatePlaybackStatus({required bool isPlaying}) =>
      _smtc.setPlaybackStatus(
        isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused,
      );

  @override
  Future<void> dispose() async {
    await _buttonSub.cancel();
    await _commandsController.close();
    await _smtc.dispose();
  }

  MediaTransportCommand? _commandFor(PressedButton button) => switch (button) {
    PressedButton.play => MediaTransportCommand.play,
    PressedButton.pause => MediaTransportCommand.pause,
    PressedButton.next => MediaTransportCommand.next,
    PressedButton.previous => MediaTransportCommand.previous,
    _ => null,
  };
}
