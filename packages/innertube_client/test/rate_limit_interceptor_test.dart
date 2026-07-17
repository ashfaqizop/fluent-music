import 'dart:math';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:innertube_client/innertube_client.dart';
import 'package:test/test.dart';

/// An adapter that fails with [failStatusCode] the first [failTimes] calls,
/// then succeeds with a 200 — used to verify the interceptor actually
/// retries and eventually succeeds.
final class _FlakyAdapter implements HttpClientAdapter {
  _FlakyAdapter({required this.failTimes});

  final int failTimes;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (calls <= failTimes) {
      return ResponseBody.fromString('{}', 429);
    }
    return ResponseBody.fromString('{"ok":true}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('InnerTubeRateLimitInterceptor', () {
    test('retries a 429 up to maxRetries and then succeeds', () async {
      final dio = Dio();
      final adapter = _FlakyAdapter(failTimes: 2);
      dio.httpClientAdapter = adapter;

      final delays = <Duration>[];
      dio.interceptors.add(
        InnerTubeRateLimitInterceptor(
          dio: dio,
          backoffPolicy: const BackoffPolicy(
            baseDelay: Duration(milliseconds: 1),
            maxDelay: Duration(milliseconds: 10),
            jitterRatio: 0,
          ),
          concurrencyGate: HostConcurrencyGate(maxConcurrentPerHost: 4),
          visitorIdRotator: VisitorIdRotator(random: Random(1)),
          maxRetries: 3,
          delay: (d) async => delays.add(d),
        ),
      );

      final response = await dio.get<String>('https://example.com/search');
      expect(response.statusCode, 200);
      expect(adapter.calls, 3);
      expect(delays, hasLength(2));
    });

    test('gives up after maxRetries and surfaces the failure', () async {
      final dio = Dio();
      final adapter = _FlakyAdapter(failTimes: 100);
      dio.httpClientAdapter = adapter;

      dio.interceptors.add(
        InnerTubeRateLimitInterceptor(
          dio: dio,
          backoffPolicy: const BackoffPolicy(
            baseDelay: Duration(milliseconds: 1),
            maxDelay: Duration(milliseconds: 10),
            jitterRatio: 0,
          ),
          concurrencyGate: HostConcurrencyGate(maxConcurrentPerHost: 4),
          visitorIdRotator: VisitorIdRotator(random: Random(2)),
          maxRetries: 2,
          delay: (_) async {},
        ),
      );

      await expectLater(
        dio.get<String>('https://example.com/search'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, 3);
    });

    test('injects a rotating visitorData into the request body', () async {
      final dio = Dio();
      Map<String, dynamic>? capturedBody;
      final adapter = _CapturingAdapter((body) => capturedBody = body);
      dio.httpClientAdapter = adapter;

      dio.interceptors.add(
        InnerTubeRateLimitInterceptor(
          dio: dio,
          backoffPolicy: const BackoffPolicy(
            baseDelay: Duration(milliseconds: 1),
            maxDelay: Duration(milliseconds: 10),
            jitterRatio: 0,
          ),
          concurrencyGate: HostConcurrencyGate(maxConcurrentPerHost: 4),
          visitorIdRotator: VisitorIdRotator(random: Random(3)),
        ),
      );

      await dio.post<String>(
        'https://example.com/search',
        data: {
          'context': {
            'client': {'clientName': 'WEB_REMIX'},
          },
        },
      );

      final client = capturedBody!['context']['client'] as Map<String, dynamic>;
      expect(client['visitorData'], isNotNull);
    });
  });
}

final class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.onBody);

  final void Function(Map<String, dynamic>) onBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data;
    if (data is Map<String, dynamic>) onBody(data);
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}
