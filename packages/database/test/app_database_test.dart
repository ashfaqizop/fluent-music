import 'package:database/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  test(
    'AppDatabase opens an in-memory instance with schemaVersion 2',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, 2);
    },
  );

  test('queue items and playback session round-trip', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.batch((batch) {
      batch.insertAll(db.queueItems, [
        QueueItemsCompanion.insert(
          position: 0,
          trackId: 'a',
          title: 'Song A',
          artist: 'Artist A',
        ),
        QueueItemsCompanion.insert(
          position: 1,
          trackId: 'b',
          title: 'Song B',
          artist: 'Artist B',
          album: const Value('Album B'),
        ),
      ]);
    });
    await db
        .into(db.playbackSession)
        .insertOnConflictUpdate(
          PlaybackSessionCompanion.insert(
            currentQueuePosition: const Value(1),
            positionMs: const Value(42000),
            shuffleEnabled: const Value(true),
            repeatMode: const Value('all'),
            volume: const Value(80),
          ),
        );

    final items = await db.select(db.queueItems).get();
    expect(items.map((r) => r.trackId), ['a', 'b']);
    expect(items.last.album, 'Album B');

    final session = await (db.select(
      db.playbackSession,
    )..where((t) => t.id.equals(0))).getSingle();
    expect(session.currentQueuePosition, 1);
    expect(session.positionMs, 42000);
    expect(session.shuffleEnabled, isTrue);
    expect(session.repeatMode, 'all');
    expect(session.volume, 80);
  });

  test('playback session upsert replaces the single row', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    Future<void> upsert(int positionMs) => db
        .into(db.playbackSession)
        .insertOnConflictUpdate(
          PlaybackSessionCompanion.insert(positionMs: Value(positionMs)),
        );

    await upsert(1000);
    await upsert(2000);

    final rows = await db.select(db.playbackSession).get();
    expect(rows, hasLength(1));
    expect(rows.single.positionMs, 2000);
  });
}
