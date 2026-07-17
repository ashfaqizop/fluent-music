import 'dart:math';

import 'package:audio_engine/src/audio_engine.dart';
import 'package:audio_engine/src/queue_track.dart';

/// Pure ordering/shuffle/repeat logic for the playback queue, kept free of
/// `media_kit` so it is unit-testable without Flutter or a real player.
///
/// Tracks the "current" item by object identity rather than index, so
/// mutations (insert/remove/reorder) never have to reconcile a stale index.
final class QueueController {
  /// Creates an empty queue controller. [random] is injectable for
  /// deterministic shuffle tests.
  QueueController({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<QueueTrack> _queue = [];

  /// Shuffled play order, `_current` first, rest randomized. Empty when
  /// shuffle is off (play order is then just [_queue] itself).
  List<QueueTrack> _shuffleOrder = [];

  QueueTrack? _current;
  bool _shuffleEnabled = false;
  RepeatMode _repeatMode = RepeatMode.off;

  /// The queue's contents, in original (unshuffled) order.
  List<QueueTrack> get queue => List.unmodifiable(_queue);

  /// The currently playing/paused track, or `null` if the queue is empty.
  QueueTrack? get currentTrack => _current;

  /// The current track's index in [queue], or `null` if empty.
  int? get currentIndex => _current == null ? null : _queue.indexOf(_current!);

  /// Whether shuffle is enabled.
  bool get shuffleEnabled => _shuffleEnabled;

  /// The current repeat mode.
  RepeatMode get repeatMode => _repeatMode;

  List<QueueTrack> get _playOrder => _shuffleEnabled ? _shuffleOrder : _queue;

  /// Replaces the queue with [tracks], starting at [startIndex].
  void load(List<QueueTrack> tracks, {int startIndex = 0}) {
    _queue
      ..clear()
      ..addAll(tracks);
    _current = tracks.isEmpty
        ? null
        : tracks[startIndex.clamp(0, tracks.length - 1)];
    _regenerateShuffleOrder();
  }

  /// Inserts [track] immediately after the current track.
  void playNext(QueueTrack track) {
    final insertAt = _current == null ? 0 : _queue.indexOf(_current!) + 1;
    _queue.insert(insertAt, track);
    _current ??= track;
    _regenerateShuffleOrder();
  }

  /// Appends [track] to the end of the queue.
  void addToQueue(QueueTrack track) {
    _queue.add(track);
    _current ??= track;
    _regenerateShuffleOrder();
  }

  /// Removes the queue item at [index]. If it was the current track, the
  /// track that takes its place (or the new last track) becomes current.
  void removeAt(int index) {
    if (index < 0 || index >= _queue.length) return;
    final removed = _queue.removeAt(index);
    if (identical(removed, _current)) {
      _current = _queue.isEmpty
          ? null
          : _queue[index < _queue.length ? index : _queue.length - 1];
    }
    _regenerateShuffleOrder();
  }

  /// Moves the queue item at [oldIndex] to [newIndex]. Never changes which
  /// track is current.
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _queue.length ||
        newIndex < 0 ||
        newIndex > _queue.length ||
        oldIndex == newIndex) {
      return;
    }
    final track = _queue.removeAt(oldIndex);
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    _queue.insert(target, track);
    _regenerateShuffleOrder();
  }

  /// Empties the queue.
  void clear() {
    _queue.clear();
    _shuffleOrder = [];
    _current = null;
  }

  /// Jumps directly to the queue item at [index].
  void jumpTo(int index) {
    if (index < 0 || index >= _queue.length) return;
    _current = _queue[index];
  }

  /// Enables/disables shuffle, keeping the current track in place.
  void setShuffle(bool enabled) {
    _shuffleEnabled = enabled;
    _regenerateShuffleOrder();
  }

  /// Sets the repeat mode.
  void setRepeatMode(RepeatMode mode) => _repeatMode = mode;

  /// Advances to the next track per shuffle/repeat rules and returns it, or
  /// returns `null` (leaving [currentTrack] at the last track) if the queue
  /// has ended.
  QueueTrack? advance() {
    if (_queue.isEmpty) return null;
    if (_repeatMode == RepeatMode.one) return _current;
    final order = _playOrder;
    final i = _indexOfCurrent(order);
    if (i == -1) return _current = order.first;
    if (i + 1 < order.length) return _current = order[i + 1];
    if (_repeatMode == RepeatMode.all) return _current = order.first;
    return null;
  }

  /// The track [advance] would move to, without mutating state — used to
  /// resolve/prefetch the next stream ahead of time.
  QueueTrack? peekNext() {
    if (_queue.isEmpty) return null;
    if (_repeatMode == RepeatMode.one) return _current;
    final order = _playOrder;
    final i = _indexOfCurrent(order);
    if (i == -1) return order.isEmpty ? null : order.first;
    if (i + 1 < order.length) return order[i + 1];
    if (_repeatMode == RepeatMode.all) {
      return order.isEmpty ? null : order.first;
    }
    return null;
  }

  /// Moves to the previous track and returns it. Stays on the first track
  /// (rather than wrapping) when repeat is off, matching common player UX.
  QueueTrack? retreat() {
    if (_queue.isEmpty) return null;
    final order = _playOrder;
    final i = _indexOfCurrent(order);
    if (i > 0) return _current = order[i - 1];
    if (_repeatMode == RepeatMode.all && order.isNotEmpty) {
      return _current = order.last;
    }
    return _current;
  }

  int _indexOfCurrent(List<QueueTrack> order) =>
      _current == null ? -1 : order.indexOf(_current!);

  void _regenerateShuffleOrder() {
    if (!_shuffleEnabled) {
      _shuffleOrder = [];
      return;
    }
    final rest = _queue.where((t) => !identical(t, _current)).toList()
      ..shuffle(_random);
    _shuffleOrder = [if (_current != null) _current!, ...rest];
  }
}
