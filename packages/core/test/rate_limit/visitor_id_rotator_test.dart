import 'dart:math';

import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('VisitorIdRotator', () {
    test('current() is stable until the rotation threshold is reached', () {
      final rotator = VisitorIdRotator(
        rotateEveryRequests: 3,
        random: Random(1),
      );
      final first = rotator.current();

      rotator.noteRequestSent();
      expect(rotator.current(), first);

      rotator.noteRequestSent();
      expect(rotator.current(), first);

      // Third request crosses the threshold -> rotates.
      rotator.noteRequestSent();
      expect(rotator.current(), isNot(first));
    });

    test('rotateNow() rotates immediately regardless of request count', () {
      final rotator = VisitorIdRotator(
        rotateEveryRequests: 1000,
        random: Random(2),
      );
      final first = rotator.current();

      rotator.rotateNow();
      expect(rotator.current(), isNot(first));
    });

    test('generated ids are non-empty and url-safe', () {
      final rotator = VisitorIdRotator(random: Random(3));
      final id = rotator.current();
      expect(id, isNotEmpty);
      expect(id, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });
  });
}
