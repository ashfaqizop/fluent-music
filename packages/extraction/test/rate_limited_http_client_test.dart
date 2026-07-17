import 'dart:async';

import 'package:core/core.dart';
import 'package:extraction/extraction.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('RateLimitedHttpClient', () {
    test('caps concurrent in-flight requests per host', () async {
      var active = 0;
      var maxObserved = 0;

      final mock = MockClient((request) async {
        active++;
        maxObserved = active > maxObserved ? active : maxObserved;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        active--;
        return http.Response('ok', 200);
      });

      final client = RateLimitedHttpClient(
        mock,
        gate: HostConcurrencyGate(maxConcurrentPerHost: 2),
        minInterval: Duration.zero,
      );

      await Future.wait([
        for (var i = 0; i < 5; i++) client.get(Uri.parse('https://a.example')),
      ]);

      expect(maxObserved, lessThanOrEqualTo(2));
    });

    test('paces consecutive requests to the same host', () async {
      final timestamps = <DateTime>[];
      final mock = MockClient((request) async {
        timestamps.add(DateTime.now());
        return http.Response('ok', 200);
      });

      final client = RateLimitedHttpClient(
        mock,
        gate: HostConcurrencyGate(maxConcurrentPerHost: 4),
        minInterval: const Duration(milliseconds: 50),
      );

      await client.get(Uri.parse('https://a.example'));
      await client.get(Uri.parse('https://a.example'));

      expect(
        timestamps[1].difference(timestamps[0]).inMilliseconds,
        greaterThanOrEqualTo(45),
      );
    });
  });
}
