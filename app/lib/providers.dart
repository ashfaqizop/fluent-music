/// Plain (non-codegen) Riverpod providers wiring Phase 2's audio stack.
///
/// Every provider here throws if read before `main()` overrides it with a
/// concrete instance — construction is async (opening the database,
/// fetching remote config, initializing native runtimes), so it all happens
/// once up front in `main()` rather than lazily inside a provider.
library;

import 'package:app/playback_coordinator.dart';
import 'package:app/services/settings_repository.dart';
import 'package:app/services/track_resolver.dart';
import 'package:audio_engine/audio_engine.dart';
import 'package:database/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_integration/media_integration.dart';

/// The app's Drift database, overridden with a real file-backed instance.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

/// The InnerTube search + stream-resolution surface.
final trackResolverProvider = Provider<TrackResolver>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

/// The disk cache wrapping resolved stream URLs.
final playbackCacheProvider = Provider<PlaybackCache>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

/// The `media_kit`-backed audio engine.
final audioEngineProvider = Provider<AudioEngine>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

/// The SMTC-backed media transport controller.
final mediaTransportControllerProvider = Provider<MediaTransportController>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

/// Wires [audioEngineProvider] and [mediaTransportControllerProvider]
/// together and persists/restores queue state.
final playbackCoordinatorProvider = Provider<PlaybackCoordinator>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

/// Persists/loads Phase 3's appearance settings (density, backdrop, accent,
/// motion) — see `design_system/settings/appearance_settings_controller.dart`.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('overridden in main()'),
);
