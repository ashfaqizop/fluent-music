import 'dart:math';

import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('BackoffPolicy', () {
    const policy = BackoffPolicy(
      baseDelay: Duration(milliseconds: 500),
      maxDelay: Duration(seconds: 20),
      jitterRatio: 0.3,
    );

    test('grows exponentially with attempt number, before jitter', () {
      // jitterRatio: 0 isolates the exponential curve from randomization.
      const noJitter = BackoffPolicy(
        baseDelay: Duration(milliseconds: 500),
        maxDelay: Duration(seconds: 20),
        jitterRatio: 0,
      );

      expect(noJitter.delayForAttempt(0), const Duration(milliseconds: 500));
      expect(noJitter.delayForAttempt(1), const Duration(milliseconds: 1000));
      expect(noJitter.delayForAttempt(2), const Duration(milliseconds: 2000));
    });

    test('caps at maxDelay for large attempt numbers', () {
      final delay = policy.delayForAttempt(20, random: Random(1));
      expect(
        delay.inMicroseconds,
        lessThanOrEqualTo(policy.maxDelay.inMicroseconds),
      );
    });

    test('jitter stays within the configured ratio of the capped delay', () {
      final rng = Random(42);
      for (var attempt = 0; attempt < 10; attempt++) {
        final delay = policy.delayForAttempt(attempt, random: rng);
        expect(delay.inMicroseconds, greaterThanOrEqualTo(0));
        expect(
          delay.inMicroseconds,
          lessThanOrEqualTo(policy.maxDelay.inMicroseconds),
        );
      }
    });

    test('an explicit retryAfter always wins over the computed backoff', () {
      final delay = policy.delayForAttempt(
        5,
        retryAfter: const Duration(seconds: 2),
        random: Random(1),
      );
      expect(delay, const Duration(seconds: 2));
    });
  });
}
