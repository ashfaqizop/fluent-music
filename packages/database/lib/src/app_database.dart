import 'package:database/src/tables/app_settings_table.dart';
import 'package:database/src/tables/playback_session_table.dart';
import 'package:database/src/tables/queue_items_table.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// The root Drift/SQLite database (Masterdoc §8.1). Tables for tracks,
/// artists, albums, playlists, likes, history, downloads, accounts, lyrics
/// cache, and remote-config cache land incrementally as their owning phases
/// build them out; Phase 2 adds queue/playback-session persistence for
/// resume-across-restart (§7, §12), Phase 3 adds the design-system
/// appearance settings seed (§11, §16).
@DriftDatabase(tables: [QueueItems, PlaybackSession, AppSettings])
class AppDatabase extends _$AppDatabase {
  /// Opens the database against [executor] (e.g. `NativeDatabase`).
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(queueItems);
        await migrator.createTable(playbackSession);
      }
      if (from < 3) {
        await migrator.createTable(appSettings);
      }
    },
  );
}
