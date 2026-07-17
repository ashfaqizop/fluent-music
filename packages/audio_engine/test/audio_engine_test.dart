import 'dart:async';

import 'package:audio_engine/audio_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioEngine implements AudioEngine {
  final _controller = StreamController<PlaybackState>.broadcast();

  @override
  Stream<PlaybackState> get stateStream => _controller.stream;

  @override
  Future<void> play() async => _controller.add(PlaybackState.playing);

  @override
  Future<void> pause() async => _controller.add(PlaybackState.paused);

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> dispose() async => _controller.close();
}

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
}
