import 'dart:math';

import 'package:audio_engine/audio_engine.dart';
import 'package:flutter_test/flutter_test.dart';

QueueTrack _track(String id) => QueueTrack(
  id: id,
  title: id,
  artist: 'Artist',
  resolveStreamUri: () async => Uri.parse('https://example.com/$id'),
);

void main() {
  group('load / advance / retreat', () {
    test('load starts at startIndex', () {
      final q = QueueController();
      q.load([_track('a'), _track('b'), _track('c')], startIndex: 1);
      expect(q.currentTrack?.id, 'b');
      expect(q.currentIndex, 1);
    });

    test('advance walks forward and stops at the end when repeat is off', () {
      final q = QueueController()..load([_track('a'), _track('b')]);
      expect(q.advance()?.id, 'b');
      expect(q.advance(), isNull);
      expect(q.currentTrack?.id, 'b');
    });

    test('advance wraps to the start when repeat is all', () {
      final q = QueueController()
        ..load([_track('a'), _track('b')])
        ..setRepeatMode(RepeatMode.all);
      q.advance();
      expect(q.advance()?.id, 'a');
    });

    test('advance stays put when repeat is one', () {
      final q = QueueController()
        ..load([_track('a'), _track('b')])
        ..setRepeatMode(RepeatMode.one);
      expect(q.advance()?.id, 'a');
      expect(q.advance()?.id, 'a');
    });

    test('retreat walks backward and stays at the first track', () {
      final q = QueueController()..load([_track('a'), _track('b')]);
      q.advance();
      expect(q.retreat()?.id, 'a');
      expect(q.retreat()?.id, 'a');
    });

    test('peekNext previews without mutating state', () {
      final q = QueueController()..load([_track('a'), _track('b')]);
      expect(q.peekNext()?.id, 'b');
      expect(q.currentTrack?.id, 'a');
    });
  });

  group('mutation', () {
    test('playNext inserts immediately after current', () {
      final q = QueueController()..load([_track('a'), _track('b')]);
      q.playNext(_track('x'));
      expect(q.queue.map((t) => t.id), ['a', 'x', 'b']);
    });

    test('addToQueue appends to the end', () {
      final q = QueueController()..load([_track('a')]);
      q.addToQueue(_track('x'));
      expect(q.queue.map((t) => t.id), ['a', 'x']);
    });

    test('removeAt of the current track promotes the next track', () {
      final q = QueueController()
        ..load([_track('a'), _track('b'), _track('c')]);
      q.removeAt(0);
      expect(q.currentTrack?.id, 'b');
      expect(q.queue.map((t) => t.id), ['b', 'c']);
    });

    test('removeAt of the last track when it was current falls back', () {
      final q = QueueController()
        ..load([_track('a'), _track('b')], startIndex: 1);
      q.removeAt(1);
      expect(q.currentTrack?.id, 'a');
    });

    test('removeAt of a non-current track keeps current unchanged', () {
      final q = QueueController()
        ..load([_track('a'), _track('b'), _track('c')]);
      q.removeAt(2);
      expect(q.currentTrack?.id, 'a');
      expect(q.queue.map((t) => t.id), ['a', 'b']);
    });

    test('reorder never changes which track is current', () {
      final q = QueueController()
        ..load([_track('a'), _track('b'), _track('c')]);
      q.reorder(0, 2);
      expect(q.currentTrack?.id, 'a');
      expect(q.queue.map((t) => t.id), ['b', 'a', 'c']);
    });

    test('clear empties the queue', () {
      final q = QueueController()..load([_track('a')]);
      q.clear();
      expect(q.queue, isEmpty);
      expect(q.currentTrack, isNull);
    });

    test('jumpTo moves directly to an index', () {
      final q = QueueController()
        ..load([_track('a'), _track('b'), _track('c')]);
      q.jumpTo(2);
      expect(q.currentTrack?.id, 'c');
    });
  });

  group('shuffle', () {
    test('shuffle keeps the current track first in play order', () {
      final q = QueueController(random: Random(42))
        ..load([_track('a'), _track('b'), _track('c'), _track('d')])
        ..setShuffle(true);
      expect(q.currentTrack?.id, 'a');
      // Every track should still be reachable exactly once via advance().
      final seen = <String>{q.currentTrack!.id};
      while (true) {
        final next = q.advance();
        if (next == null) break;
        seen.add(next.id);
      }
      expect(seen, {'a', 'b', 'c', 'd'});
    });

    test('disabling shuffle restores original order', () {
      final q = QueueController(random: Random(1))
        ..load([_track('a'), _track('b'), _track('c')])
        ..setShuffle(true)
        ..setShuffle(false);
      expect(q.advance()?.id, 'b');
      expect(q.advance()?.id, 'c');
    });
  });

  test('empty queue operations are no-ops, not crashes', () {
    final q = QueueController();
    expect(q.advance(), isNull);
    expect(q.retreat(), isNull);
    expect(q.peekNext(), isNull);
    q
      ..removeAt(0)
      ..reorder(0, 1)
      ..jumpTo(0);
    expect(q.queue, isEmpty);
  });
}
