import 'dart:async';

import 'package:audio_engine/audio_engine.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal [AudioEngine] fake driven by a real [QueueController], proving
/// the interface is implementable end-to-end without `media_kit`.
class _FakeAudioEngine implements AudioEngine {
  final _queue = QueueController();
  final _stateController = StreamController<PlaybackState>.broadcast();
  final _currentTrackController = StreamController<QueueTrack?>.broadcast();
  final _queueSnapshotController =
      StreamController<List<QueueTrack>>.broadcast();

  @override
  Stream<PlaybackState> get stateStream => _stateController.stream;

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<Duration> get durationStream => const Stream.empty();

  @override
  Stream<bool> get bufferingStream => const Stream.empty();

  @override
  Stream<QueueTrack?> get currentTrackStream => _currentTrackController.stream;

  @override
  Stream<List<QueueTrack>> get queueStream => _queueSnapshotController.stream;

  @override
  Stream<AppFailure> get errorStream => const Stream.empty();

  @override
  Stream<double> get volumeStream => const Stream.empty();

  @override
  List<QueueTrack> get queue => _queue.queue;

  @override
  double get volume => _volume;

  double _volume = 100;

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
    _emit();
    if (play) _stateController.add(PlaybackState.playing);
  }

  @override
  Future<void> playNext(QueueTrack track) async {
    _queue.playNext(track);
    _emit();
  }

  @override
  Future<void> addToQueue(QueueTrack track) async {
    _queue.addToQueue(track);
    _emit();
  }

  @override
  Future<void> removeAt(int index) async {
    _queue.removeAt(index);
    _emit();
  }

  @override
  Future<void> reorder(int oldIndex, int newIndex) async {
    _queue.reorder(oldIndex, newIndex);
    _emit();
  }

  @override
  Future<void> clearQueue() async {
    _queue.clear();
    _emit();
  }

  @override
  Future<void> next() async {
    _queue.advance();
    _emit();
  }

  @override
  Future<void> previous() async {
    _queue.retreat();
    _emit();
  }

  @override
  Future<void> jumpTo(int index) async {
    _queue.jumpTo(index);
    _emit();
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    _queue.setShuffle(enabled);
    _emit();
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    _queue.setRepeatMode(mode);
    _emit();
  }

  @override
  Future<void> setVolume(double volume) async => _volume = volume;

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> play() async => _stateController.add(PlaybackState.playing);

  @override
  Future<void> pause() async => _stateController.add(PlaybackState.paused);

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _currentTrackController.close();
    await _queueSnapshotController.close();
  }

  void _emit() {
    _queueSnapshotController.add(_queue.queue);
    _currentTrackController.add(_queue.currentTrack);
  }
}

QueueTrack _track(String id) => QueueTrack(
  id: id,
  title: id,
  artist: 'Artist',
  resolveStreamUri: () async => Uri.parse('https://example.com/$id'),
);

void main() {
  test('AudioEngine implementations emit state on play/pause', () async {
    final engine = _FakeAudioEngine();
    addTearDown(engine.dispose);

    final states = <PlaybackState>[];
    final sub = engine.stateStream.listen(states.add);

    await engine.play();
    await engine.pause();
    await Future<void>.delayed(Duration.zero);

    expect(states, [PlaybackState.playing, PlaybackState.paused]);
    await sub.cancel();
  });

  test('loadQueue + next/previous drive currentTrack', () async {
    final engine = _FakeAudioEngine();
    addTearDown(engine.dispose);

    await engine.loadQueue([_track('a'), _track('b'), _track('c')]);
    expect(engine.currentTrack?.id, 'a');

    await engine.next();
    expect(engine.currentTrack?.id, 'b');

    await engine.previous();
    expect(engine.currentTrack?.id, 'a');
  });
}
