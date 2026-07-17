import 'dart:async';

import 'package:app/app_shell/now_playing/now_playing_bar.dart';
import 'package:app/providers.dart';
import 'package:app/services/settings_repository.dart';
import 'package:audio_engine/audio_engine.dart';
import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:drift/native.dart';
import 'package:fluent_ui/fluent_ui.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  double get volume => 100;
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
  }

  @override
  Future<void> playNext(QueueTrack track) async {}
  @override
  Future<void> addToQueue(QueueTrack track) async {}
  @override
  Future<void> removeAt(int index) async {}
  @override
  Future<void> reorder(int oldIndex, int newIndex) async {}
  @override
  Future<void> clearQueue() async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> jumpTo(int index) async {}
  @override
  Future<void> setShuffle(bool enabled) async {}
  @override
  Future<void> setRepeatMode(RepeatMode mode) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
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

void main() {
  testWidgets(
    'NowPlayingBar is collapsed when the queue is empty and shows the '
    'track once one is loaded (Masterdoc §11.4)',
    (tester) async {
      final audioEngine = _FakeAudioEngine();
      addTearDown(audioEngine.dispose);
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioEngineProvider.overrideWithValue(audioEngine),
            settingsRepositoryProvider.overrideWithValue(
              SettingsRepository(database),
            ),
          ],
          child: const FluentApp(home: ScaffoldPage(content: NowPlayingBar())),
        ),
      );
      await tester.pump();

      expect(find.byType(NowPlayingBar), findsOneWidget);
      expect(find.text('Test Track'), findsNothing);

      await audioEngine.loadQueue([
        QueueTrack(
          id: 'abc',
          title: 'Test Track',
          artist: 'Test Artist',
          resolveStreamUri: () async => Uri.parse('https://example.com'),
        ),
      ], play: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Test Track'), findsOneWidget);
      expect(find.text('Test Artist'), findsOneWidget);
    },
  );
}
