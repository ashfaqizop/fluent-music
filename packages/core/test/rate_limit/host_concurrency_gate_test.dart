import 'dart:async';

import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('HostConcurrencyGate', () {
    test(
      'never runs more than maxConcurrentPerHost tasks for one host',
      () async {
        final gate = HostConcurrencyGate(maxConcurrentPerHost: 2);
        var active = 0;
        var maxObserved = 0;
        final completers = List.generate(5, (_) => Completer<void>());

        final futures = [
          for (var i = 0; i < 5; i++)
            gate.run('a.example', () async {
              active++;
              maxObserved = active > maxObserved ? active : maxObserved;
              await completers[i].future;
              active--;
              return i;
            }),
        ];

        // Let the first wave of tasks start.
        await Future<void>.delayed(Duration.zero);
        expect(maxObserved, 2);

        for (final c in completers) {
          c.complete();
          await Future<void>.delayed(Duration.zero);
        }

        final results = await Future.wait(futures);
        expect(results, [0, 1, 2, 3, 4]);
        expect(maxObserved, 2);
      },
    );

    test('different hosts do not block each other', () async {
      final gate = HostConcurrencyGate(maxConcurrentPerHost: 1);
      final order = <String>[];
      final blockA = Completer<void>();

      final taskA = gate.run('a.example', () async {
        order.add('a-start');
        await blockA.future;
        order.add('a-end');
      });

      // Give task A a chance to acquire its slot before starting task B.
      await Future<void>.delayed(Duration.zero);

      final taskB = gate.run('b.example', () async {
        order.add('b-start');
        order.add('b-end');
      });

      await taskB;
      expect(order, ['a-start', 'b-start', 'b-end']);

      blockA.complete();
      await taskA;
      expect(order, ['a-start', 'b-start', 'b-end', 'a-end']);
    });
  });
}
