import 'package:drift/drift.dart';

/// A persisted snapshot of one queue slot, restored on app start so the
/// full playback queue survives a restart (Masterdoc §7, §12).
@DataClassName('QueueItemRow')
class QueueItems extends Table {
  /// Row id (unrelated to play order — see [position]).
  IntColumn get id => integer().autoIncrement()();

  /// Zero-based position in the queue's original (unshuffled) order.
  IntColumn get position => integer()();

  /// The track's stable id (e.g. a YouTube video id), used to rebuild a
  /// fresh stream resolver on restore.
  TextColumn get trackId => text()();

  /// The track title.
  TextColumn get title => text()();

  /// The primary artist.
  TextColumn get artist => text()();

  /// The album name, if known.
  TextColumn get album => text().nullable()();

  /// Artwork URI, if known.
  TextColumn get artworkUri => text().nullable()();

  /// The track's duration in milliseconds, if known.
  IntColumn get durationMs => integer().nullable()();
}
