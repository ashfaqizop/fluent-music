import 'dart:io';

import 'package:audio_engine/audio_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('playback_cache_test');
  });

  tearDown(() async {
    // Windows sometimes briefly holds a handle open (AV scan, etc.) right
    // after a test writes a file; retry a couple of times rather than
    // failing the test over unrelated cleanup flakiness.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  test('wrap returns the network URL on first resolve and caches it', () async {
    var fetchCount = 0;
    final cache = await PlaybackCache.open(tempDir);
    final wrapped = cache.wrap('track-1', () async {
      fetchCount++;
      return Uri.parse('https://example.com/track-1.opus');
    });

    final uri = await wrapped();
    expect(uri, Uri.parse('https://example.com/track-1.opus'));
    expect(fetchCount, 1);

    // Give the fire-and-forget background populate a moment to finish.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('wrap serves a cached local file on the second call', () async {
    final cacheFile = File('${tempDir.path}/track-1.audio')
      ..writeAsBytesSync([1, 2, 3]);
    await File('${tempDir.path}/index.json').writeAsString('''
[
  {
    "trackId": "track-1",
    "filePath": "${cacheFile.path.replaceAll(r'\', r'\\')}",
    "sizeBytes": 3,
    "lastAccessed": "${DateTime.now().toIso8601String()}"
  }
]
''');
    final cache = await PlaybackCache.open(tempDir);
    var resolveCalled = false;
    final wrapped = cache.wrap('track-1', () async {
      resolveCalled = true;
      return Uri.parse('https://example.com/track-1.opus');
    });

    final uri = await wrapped();
    expect(uri, cacheFile.uri);
    expect(resolveCalled, isFalse);
  });

  test('a stale index entry (missing file) falls back to network', () async {
    await File('${tempDir.path}/index.json').writeAsString('''
[
  {
    "trackId": "track-1",
    "filePath": "${tempDir.path}/missing.audio",
    "sizeBytes": 3,
    "lastAccessed": "${DateTime.now().toIso8601String()}"
  }
]
''');
    final cache = await PlaybackCache.open(tempDir);
    final wrapped = cache.wrap(
      'track-1',
      () async => Uri.parse('https://example.com/track-1.opus'),
    );

    final uri = await wrapped();
    expect(uri, Uri.parse('https://example.com/track-1.opus'));
  });

  test('open tolerates a corrupt index file', () async {
    await File('${tempDir.path}/index.json').writeAsString('not json');
    final cache = await PlaybackCache.open(tempDir);
    expect(cache.totalBytes, 0);
  });
}
