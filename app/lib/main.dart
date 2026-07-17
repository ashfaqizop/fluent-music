import 'dart:io';

import 'package:app/debug_playback_screen.dart';
import 'package:app/playback_coordinator.dart';
import 'package:app/providers.dart';
import 'package:app/services/extraction_service.dart';
import 'package:audio_engine/audio_engine.dart';
import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:drift/native.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_integration/media_integration.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();
  await windowManager.ensureInitialized();

  MediaKit.ensureInitialized();
  await SmtcMediaTransportController.initializeRuntime();

  final supportDir = await getApplicationSupportDirectory();
  final database = AppDatabase(
    NativeDatabase(File('${supportDir.path}/fluent_music.sqlite')),
  );
  final extractionService = await ExtractionService.create();
  final playbackCache = await PlaybackCache.open(
    Directory('${supportDir.path}/playback_cache'),
  );
  final audioEngine = MediaKitPlayerEngine();
  final transportController = SmtcMediaTransportController();
  final coordinator = PlaybackCoordinator(
    audioEngine: audioEngine,
    transportController: transportController,
    database: database,
    trackResolver: extractionService,
    playbackCache: playbackCache,
  );
  await coordinator.restore();

  const windowOptions = WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(960, 600),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        trackResolverProvider.overrideWithValue(extractionService),
        playbackCacheProvider.overrideWithValue(playbackCache),
        audioEngineProvider.overrideWithValue(audioEngine),
        mediaTransportControllerProvider.overrideWithValue(transportController),
        playbackCoordinatorProvider.overrideWithValue(coordinator),
      ],
      child: const FluentMusicApp(),
    ),
  );
}

/// The Fluent Music application root widget.
class FluentMusicApp extends StatelessWidget {
  /// Creates the application root widget.
  const FluentMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'Fluent Music',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.blue,
      ),
      home: const DebugPlaybackScreen(),
    );
  }
}
