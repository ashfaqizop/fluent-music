import 'dart:async';
import 'dart:io';

import 'package:app/app_shell/navigation/app_shell.dart';
import 'package:app/app_shell/window/backdrop.dart';
import 'package:app/design_system/motion/shader_warm_up.dart';
import 'package:app/design_system/settings/appearance_settings.dart';
import 'package:app/design_system/settings/appearance_settings_controller.dart';
import 'package:app/design_system/theme/app_theme.dart';
import 'package:app/playback_coordinator.dart';
import 'package:app/providers.dart';
import 'package:app/services/extraction_service.dart';
import 'package:app/services/settings_repository.dart';
import 'package:audio_engine/audio_engine.dart';
import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:drift/native.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_integration/media_integration.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  // Must be set before `ensureInitialized()` runs binding startup, per
  // §11.7/§14's "no first-run jank" (Flutter's shader-warm-up mechanism).
  PaintingBinding.shaderWarmUp = const AppShaderWarmUp();
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();
  await windowManager.ensureInitialized();
  await WindowBackdrop.initialize();

  SystemTheme.fallbackColor = const Color(0xFF3D8BFF);
  await SystemTheme.accentColor.load();

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
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(database),
        ),
      ],
      child: const FluentMusicApp(),
    ),
  );
}

/// The Fluent Music application root widget.
class FluentMusicApp extends ConsumerStatefulWidget {
  /// Creates the application root widget.
  const FluentMusicApp({super.key});

  @override
  ConsumerState<FluentMusicApp> createState() => _FluentMusicAppState();
}

class _FluentMusicAppState extends ConsumerState<FluentMusicApp> {
  @override
  void initState() {
    super.initState();
    // Applies the initial window backdrop (§11.2); `build`'s `ref.listen`
    // covers every change after this.
    unawaited(
      WindowBackdrop.apply(ref.read(appearanceSettingsProvider).backdropMode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appearanceSettingsProvider);

    ref.listen<BackdropMode>(
      appearanceSettingsProvider.select((s) => s.backdropMode),
      (previous, next) => unawaited(WindowBackdrop.apply(next)),
    );

    final accentColor = settings.accentMode == AccentMode.custom
        ? (settings.customAccentColor ?? SystemTheme.accentColor.accent)
        : SystemTheme.accentColor.accent;

    return FluentApp(
      title: 'Fluent Music',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: buildAppTheme(accentColor: accentColor),
      home: const AppShell(),
    );
  }
}
