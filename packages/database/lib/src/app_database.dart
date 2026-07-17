import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// The root Drift/SQLite database (Masterdoc §8.1). Empty scaffold for
/// Phase 0, proving the codegen pipeline works end to end; tables for
/// tracks, artists, albums, playlists, likes, history, downloads, cache
/// index, settings, accounts, lyrics cache, and remote-config cache land
/// incrementally as their owning phases build them out.
@DriftDatabase()
class AppDatabase extends _$AppDatabase {
  /// Opens the database against [executor] (e.g. `NativeDatabase`).
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
