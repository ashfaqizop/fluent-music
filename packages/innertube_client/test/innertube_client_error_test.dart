import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:innertube_client/innertube_client.dart';
import 'package:test/test.dart';

final class _FixedResponseAdapter implements HttpClientAdapter {
  _FixedResponseAdapter(this.body, this.statusCode);

  final String body;
  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(HttpClientAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('InnerTubeClient error paths', () {
    test('a non-200 response returns a Result.err, never throws', () async {
      final client = InnerTubeClient(
        dio: _dioWith(_FixedResponseAdapter('{"error": "nope"}', 403)),
        identity: webRemixIdentity,
      );

      final result = await client.search('anything');
      expect(result.isErr, isTrue);
      expect(result.errorOrNull, isA<InnerTubeHttpFailure>());
      expect((result.errorOrNull! as InnerTubeHttpFailure).statusCode, 403);
    });

    test('malformed JSON returns a Result.err, never throws', () async {
      final client = InnerTubeClient(
        dio: _dioWith(_FixedResponseAdapter('not valid json at all', 200)),
        identity: webRemixIdentity,
      );

      final result = await client.search('anything');
      expect(result.isErr, isTrue);
    });
  });
}
