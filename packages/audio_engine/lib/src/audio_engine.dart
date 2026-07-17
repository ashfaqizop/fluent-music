import 'package:audio_engine/src/queue_track.dart';
import 'package:core/core.dart';

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

/// Repeat behavior for the playback queue (Masterdoc §7).
enum RepeatMode {
  /// Stop after the last track; no looping.
  off,

  /// Loop the whole queue once the last track finishes.
  all,

  /// Loop the current track indefinitely.
  one,
}

/// Wraps `media_kit` behind a single interface the rest of the app depends
/// on (Masterdoc §7), keeping UI decoupled from the concrete audio backend.
///
/// Owns the full queue model (play-next/add-to-queue, reorder, clear,
/// shuffle, repeat), gapless playback with next-track prefetch, and the
/// reactive streams UI/SMTC/Discord RPC consume.
abstract interface class AudioEngine {
  /// Emits the current [PlaybackState] whenever it changes.
  Stream<PlaybackState> get stateStream;

  /// Emits the current playback position of the current track.
  Stream<Duration> get positionStream;

  /// Emits the duration of the current track once known.
  Stream<Duration> get durationStream;

  /// Emits whether the engine is currently buffering.
  Stream<bool> get bufferingStream;

  /// Emits the currently playing/paused [QueueTrack], or `null` if none.
  Stream<QueueTrack?> get currentTrackStream;

  /// Emits a snapshot of the full queue whenever its contents change.
  Stream<List<QueueTrack>> get queueStream;

  /// Emits a typed failure whenever the underlying player reports an error.
  Stream<AppFailure> get errorStream;

  /// Emits the current volume (`0.0`-`100.0`) whenever it changes.
  Stream<double> get volumeStream;

  /// The queue's contents, most-recently-known snapshot.
  List<QueueTrack> get queue;

  /// The current volume, `0.0`-`100.0`.
  double get volume;

  /// The currently playing/paused track, or `null` if the queue is empty.
  QueueTrack? get currentTrack;

  /// Whether shuffle is currently enabled.
  bool get shuffleEnabled;

  /// The current repeat mode.
  RepeatMode get repeatMode;

  /// Replaces the queue with [tracks] and starts playing from [startIndex].
  ///
  /// Pass `play: false` to load without starting playback (used to restore
  /// a persisted queue+position on app start without surprising the user
  /// with sudden audio).
  Future<void> loadQueue(
    List<QueueTrack> tracks, {
    int startIndex = 0,
    bool play = true,
  });

  /// Inserts [track] immediately after the current track.
  Future<void> playNext(QueueTrack track);

  /// Appends [track] to the end of the queue.
  Future<void> addToQueue(QueueTrack track);

  /// Removes the queue item at [index].
  Future<void> removeAt(int index);

  /// Moves the queue item at [oldIndex] to [newIndex].
  Future<void> reorder(int oldIndex, int newIndex);

  /// Empties the queue and stops playback.
  Future<void> clearQueue();

  /// Skips to the next track, per shuffle/repeat rules.
  Future<void> next();

  /// Skips to the previous track.
  Future<void> previous();

  /// Jumps directly to the queue item at [index].
  Future<void> jumpTo(int index);

  /// Enables/disables shuffle.
  Future<void> setShuffle(bool enabled);

  /// Sets the repeat mode.
  Future<void> setRepeatMode(RepeatMode mode);

  /// Sets playback volume, `0.0`-`100.0`.
  Future<void> setVolume(double volume);

  /// Sets playback speed; `1.0` is normal speed.
  Future<void> setSpeed(double speed);

  /// Resumes or starts playback of the current track.
  Future<void> play();

  /// Pauses playback, retaining the current position.
  Future<void> pause();

  /// Seeks the current track to [position].
  Future<void> seek(Duration position);

  /// Releases the underlying player and any held resources.
  Future<void> dispose();
}
