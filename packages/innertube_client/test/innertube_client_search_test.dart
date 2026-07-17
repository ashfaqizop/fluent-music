import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:innertube_client/innertube_client.dart';
import 'package:test/test.dart';

/// A fake [HttpClientAdapter] returning a fixed [body] with a 200 status,
/// regardless of the request — enough to unit-test [InnerTubeClient]
/// without hitting the network.
final class _FixedResponseAdapter implements HttpClientAdapter {
  _FixedResponseAdapter(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(HttpClientAdapter adapter) {
  final dio = Dio();
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('InnerTubeClient.search', () {
    test('parses song and video rows from a canned search response', () async {
      final fixture = File(
        'test/fixtures/search_response.json',
      ).readAsStringSync();

      final client = InnerTubeClient(
        dio: _dioWith(_FixedResponseAdapter(fixture)),
        identity: webRemixIdentity,
      );

      final result = await client.search('test query');
      expect(result.isOk, isTrue);

      final items = result.valueOrNull!;
      expect(items, hasLength(2));

      final song = items.firstWhere((i) => i.videoId == 'song123');
      expect(song.title, 'Test Song Title');
      expect(song.artist, 'Test Artist');
      expect(song.album, 'Test Album');
      expect(song.durationText, '3:45');
      expect(song.isVideoEntity, isFalse);

      final video = items.firstWhere((i) => i.videoId == 'video456');
      expect(video.title, 'Test Video Title');
      expect(video.artist, 'Some Channel');
      expect(video.isVideoEntity, isTrue);
    });
  });
}
