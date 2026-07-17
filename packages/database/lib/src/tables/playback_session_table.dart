import 'package:database/src/tables/queue_items_table.dart';
import 'package:drift/drift.dart';

/// Single-row table persisting the current playback session (position,
/// shuffle, repeat, volume) so it survives an app restart (Masterdoc §7,
/// §12). Always holds exactly one row, at [id] `0`.
@DataClassName('PlaybackSessionRow')
class PlaybackSession extends Table {
  /// Always `0` — this table only ever holds one row.
  ///
  /// Uses `clientDefault` rather than a SQL `DEFAULT`: `id` is a rowid-alias
  /// `INTEGER PRIMARY KEY`, and SQLite auto-assigns a fresh rowid whenever a
  /// value is omitted from the insert, ignoring `DEFAULT` — a client-side
  /// default forces `0` onto the wire explicitly so upserts always target
  /// the same row instead of silently inserting a new one each time.
  IntColumn get id => integer().clientDefault(() => 0)();

  /// The current track's position in [QueueItems]' ordering, or `null` if
  /// nothing was playing.
  IntColumn get currentQueuePosition => integer().nullable()();

  /// Playback position within the current track, in milliseconds.
  IntColumn get positionMs => integer().withDefault(const Constant(0))();

  /// Whether shuffle was enabled.
  BoolColumn get shuffleEnabled =>
      boolean().withDefault(const Constant(false))();

  /// The repeat mode, stored as `RepeatMode.name` (`off`/`all`/`one`).
  TextColumn get repeatMode => text().withDefault(const Constant('off'))();

  /// Playback volume, `0.0`-`100.0`.
  RealColumn get volume => real().withDefault(const Constant(100))();

  @override
  Set<Column> get primaryKey => {id};
}
