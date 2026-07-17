import 'dart:async';

import 'package:audio_engine/src/audio_engine.dart';
import 'package:audio_engine/src/queue_controller.dart';
import 'package:audio_engine/src/queue_track.dart';
import 'package:core/core.dart';
import 'package:media_kit/media_kit.dart';

/// [AudioEngine] backed by `media_kit` (libmpv), the pinned audio backend
/// (Masterdoc §7).
///
/// Callers must call `MediaKit.ensureInitialized()` once at process start
/// (in `app/lib/main.dart`, or the smoke test's `main()`) before
/// constructing this class.
///
/// Gapless playback works by keeping media_kit's own playlist as a rolling
/// "current + one look-ahead" window rather than pre-loading the whole
/// queue: stream URLs are lazily resolved and short-lived (§6), so the
/// queue's true shape lives in [QueueController] and only the next couple
/// of tracks are ever materialized into real, playable [Media] objects.
/// When mpv's own playlist index advances past a natural track boundary,
/// [QueueController.advance] is called to keep the two in sync and the
/// look-ahead slot is topped up via [Player.add] — never a full reopen —
/// so the currently-playing audio is never interrupted.
final class MediaKitPlayerEngine implements AudioEngine {
  /// Creates a player engine. [player] is injectable for tests; production
  /// code should leave it as the default `Player()`.
  MediaKitPlayerEngine({Player? player, QueueController? queueController})
    : _player = player ?? Player(),
      _queue = queueController ?? QueueController() {
    _playingSub = _player.stream.playing.listen((playing) {
      _lastPlaying = playing;
      _pushState();
    });
    _bufferingSub = _player.stream.buffering.listen((buffering) {
      _lastBuffering = buffering;
      _pushState();
    });
    _errorSub = _player.stream.error.listen((message) {
      _errorController.add(UnknownFailure(message));
      _stateController.add(PlaybackState.error);
    });
    _playlistSub = _player.stream.playlist.listen(_onPlaylistEvent);
  }

  final Player _player;
  final QueueController _queue;
  final _log = AppLogger('MediaKitPlayerEngine');

  final _stateController = StreamController<PlaybackState>.broadcast();
  final _currentTrackController = StreamController<QueueTrack?>.broadcast();
  final _queueSnapshotController =
      StreamController<List<QueueTrack>>.broadcast();
  final _errorController = StreamController<AppFailure>.broadcast();

  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<bool> _bufferingSub;
  late final StreamSubscription<String> _errorSub;
  late final StreamSubscription<Playlist> _playlistSub;

  bool _lastPlaying = false;
  bool _lastBuffering = false;

  /// The last mpv playlist index we accounted for, so [_onPlaylistEvent]
  /// only reacts to genuine forward advances (not to our own [Player.add]
  /// calls, which don't move the index).
  int _lastMkIndex = 0;

  /// The track currently materialized in mpv's look-ahead slot, so
  /// [_resyncLookahead] can no-op when it's already correct.
  QueueTrack? _mkLookaheadTrack;

  @override
  Stream<PlaybackState> get stateStream => _stateController.stream;

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Stream<bool> get bufferingStream => _player.stream.buffering;

  @override
  Stream<QueueTrack?> get currentTrackStream => _currentTrackController.stream;

  @override
  Stream<List<QueueTrack>> get queueStream => _queueSnapshotController.stream;

  @override
  Stream<AppFailure> get errorStream => _errorController.stream;

  @override
  Stream<double> get volumeStream => _player.stream.volume;

  @override
  List<QueueTrack> get queue => _queue.queue;

  @override
  double get volume => _player.state.volume;

  @override
  QueueTrack? get currentTrack => _queue.currentTrack;

  @override
  bool get shuffleEnabled => _queue.shuffleEnabled;

  @override
  RepeatMode get repeatMode => _queue.repeatMode;

  @override
  Future<void> loadQueue(
    List<QueueTrack> tracks, {
    int startIndex = 0,
    bool play = true,
  }) async {
    _queue.load(tracks, startIndex: startIndex);
    _emitQueueSnapshot();
    await _openCurrentWindow(play: play);
  }

  @override
  Future<void> playNext(QueueTrack track) async {
    final hadCurrent = _queue.currentTrack != null;
    _queue.playNext(track);
    _emitQueueSnapshot();
    if (!hadCurrent) {
      await _openCurrentWindow(play: false);
    } else {
      await _resyncLookahead();
    }
  }

  @override
  Future<void> addToQueue(QueueTrack track) async {
    final hadCurrent = _queue.currentTrack != null;
    _queue.addToQueue(track);
    _emitQueueSnapshot();
    if (!hadCurrent) {
      await _openCurrentWindow(play: false);
    } else {
      await _resyncLookahead();
    }
  }

  @override
  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _queue.queue.length) return;
    final wasCurrent = identical(_queue.queue[index], _queue.currentTrack);
    final wasPlaying = _player.state.playing;
    _queue.removeAt(index);
    _emitQueueSnapshot();
    if (wasCurrent) {
      await _openCurrentWindow(play: wasPlaying);
    } else {
      await _resyncLookahead();
    }
  }

  @override
  Future<void> reorder(int oldIndex, int newIndex) async {
    _queue.reorder(oldIndex, newIndex);
    _emitQueueSnapshot();
    await _resyncLookahead();
  }

  @override
  Future<void> clearQueue() async {
    _queue.clear();
    _emitQueueSnapshot();
    await _player.stop();
    _mkLookaheadTrack = null;
    _lastMkIndex = 0;
  }

  @override
  Future<void> next() async {
    final wasPlaying = _player.state.playing;
    _queue.advance();
    _emitQueueSnapshot();
    await _openCurrentWindow(play: wasPlaying);
  }

  @override
  Future<void> previous() async {
    final wasPlaying = _player.state.playing;
    _queue.retreat();
    _emitQueueSnapshot();
    await _openCurrentWindow(play: wasPlaying);
  }

  @override
  Future<void> jumpTo(int index) async {
    final wasPlaying = _player.state.playing;
    _queue.jumpTo(index);
    _emitQueueSnapshot();
    await _openCurrentWindow(play: wasPlaying);
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    _queue.setShuffle(enabled);
    _emitQueueSnapshot();
    await _resyncLookahead();
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    _queue.setRepeatMode(mode);
    _emitQueueSnapshot();
    await _resyncLookahead();
  }

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0, 100).toDouble());

  @override
  Future<void> setSpeed(double speed) => _player.setRate(speed);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() async {
    await _playingSub.cancel();
    await _bufferingSub.cancel();
    await _errorSub.cancel();
    await _playlistSub.cancel();
    await _stateController.close();
    await _currentTrackController.close();
    await _queueSnapshotController.close();
    await _errorController.close();
    await _player.dispose();
  }

  Future<void> _onPlaylistEvent(Playlist event) async {
    if (event.index <= _lastMkIndex) return;
    final steps = event.index - _lastMkIndex;
    for (var i = 0; i < steps; i++) {
      _queue.advance();
    }
    _lastMkIndex = event.index;
    _emitQueueSnapshot();
    await _resyncLookahead();
  }

  /// Opens exactly the current track in mpv (a fresh single-item playlist)
  /// and starts/resumes playback per [play]. Used for every operation that
  /// changes *which* track is current (skip/jump/load/remove-current) —
  /// unlike [_resyncLookahead], this necessarily interrupts audio, since
  /// the currently-audible track is what's changing.
  Future<void> _openCurrentWindow({required bool play}) async {
    final current = _queue.currentTrack;
    _mkLookaheadTrack = null;
    _lastMkIndex = 0;
    if (current == null) {
      await _player.stop();
      return;
    }
    try {
      final uri = await current.resolveStreamUri();
      await _player.open(Playlist([_mediaFor(current, uri)]), play: play);
      await _resyncLookahead();
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to resolve/open "${current.title}"',
        error,
        stackTrace,
      );
      _errorController.add(
        UnknownFailure('Could not play "${current.title}"', cause: error),
      );
      _stateController.add(PlaybackState.error);
    }
  }

  /// Ensures mpv's playlist has exactly one look-ahead item queued beyond
  /// the currently playing track, appended via [Player.add] so playback in
  /// progress is never disturbed. A no-op if the look-ahead is already
  /// correct (e.g. an `addToQueue` call that didn't change what's next).
  Future<void> _resyncLookahead() async {
    final desired = _queue.peekNext();
    if (identical(desired, _mkLookaheadTrack)) return;
    final playlist = _player.state.playlist;
    for (var i = playlist.medias.length - 1; i > playlist.index; i--) {
      await _player.remove(i);
    }
    _mkLookaheadTrack = null;
    if (desired == null) return;
    try {
      final uri = await desired.resolveStreamUri();
      await _player.add(_mediaFor(desired, uri));
      _mkLookaheadTrack = desired;
    } on Exception catch (error, stackTrace) {
      // A failed look-ahead resolve shouldn't interrupt current playback;
      // it's retried on the next queue mutation or track boundary.
      _log.warning('Failed to prefetch "${desired.title}"', error, stackTrace);
    }
  }

  Media _mediaFor(QueueTrack track, Uri uri) =>
      Media(uri.toString(), extras: {'trackId': track.id});

  void _pushState() {
    if (_queue.currentTrack == null) {
      _stateController.add(PlaybackState.idle);
    } else if (_lastBuffering) {
      _stateController.add(PlaybackState.buffering);
    } else {
      _stateController.add(
        _lastPlaying ? PlaybackState.playing : PlaybackState.paused,
      );
    }
  }

  void _emitQueueSnapshot() {
    _queueSnapshotController.add(_queue.queue);
    _currentTrackController.add(_queue.currentTrack);
  }
}
