import 'dart:async';
import 'dart:io';

import 'package:app/main.dart';
import 'package:app/playback_coordinator.dart';
import 'package:app/providers.dart';
import 'package:app/services/settings_repository.dart';
import 'package:app/services/track_resolver.dart';
import 'package:audio_engine/audio_engine.dart';
import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:innertube_client/innertube_client.dart';
import 'package:media_integration/media_integration.dart';

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
  Future<void> setVolume(double volume) async {}
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

class _FakeMediaTransportController implements MediaTransportController {
  @override
  Stream<MediaTransportCommand> get commands => const Stream.empty();
  @override
  Future<void> updateNowPlaying(NowPlayingInfo info) async {}
  @override
  Future<void> updatePlaybackPosition(
    Duration position,
    Duration duration,
  ) async {}
  @override
  Future<void> updatePlaybackStatus({required bool isPlaying}) async {}
  @override
  Future<void> dispose() async {}
}

class _FakeTrackResolver implements TrackResolver {
  @override
  Future<Result<List<SearchResultItem>, InnerTubeFailure>> search(
    String query,
  ) async => const Result.ok([]);

  @override
  Future<Uri> resolveStream(String videoId) async =>
      Uri.parse('https://example.com/$videoId');
}

void main() {
  // Real dart:io async calls (Directory.createTemp, File I/O) must not run
  // inside a testWidgets body: flutter_test's widget-test zone doesn't pump
  // real async-I/O completions the way a plain `test()` zone does, and the
  // await silently never resolves. Do that setup in setUp/tearDown instead,
  // which run in the normal (non-widget-test) zone.
  late Directory tempDir;
  late AppDatabase database;
  late PlaybackCache playbackCache;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('fluent_music_widget_test');
    playbackCache = await PlaybackCache.open(
      Directory('${tempDir.path}/playback_cache'),
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  testWidgets('FluentMusicApp renders the app shell on the Home tab', (
    WidgetTester tester,
  ) async {
    const windowManagerChannel = MethodChannel('window_manager');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowManagerChannel,
      (call) async => call.method == 'isMaximized' ? false : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        windowManagerChannel,
        null,
      ),
    );

    final audioEngine = _FakeAudioEngine();
    addTearDown(audioEngine.dispose);
    final transportController = _FakeMediaTransportController();
    final trackResolver = _FakeTrackResolver();

    final coordinator = PlaybackCoordinator(
      audioEngine: audioEngine,
      transportController: transportController,
      database: database,
      trackResolver: trackResolver,
      playbackCache: playbackCache,
    );
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          trackResolverProvider.overrideWithValue(trackResolver),
          playbackCacheProvider.overrideWithValue(playbackCache),
          audioEngineProvider.overrideWithValue(audioEngine),
          mediaTransportControllerProvider.overrideWithValue(
            transportController,
          ),
          playbackCoordinatorProvider.overrideWithValue(coordinator),
          settingsRepositoryProvider.overrideWithValue(
            SettingsRepository(database),
          ),
        ],
        child: const FluentMusicApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Fluent Music'), findsOneWidget);
    expect(find.textContaining('Phase 4'), findsOneWidget);
  });
}
