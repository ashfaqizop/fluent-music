// Headless integration smoke test (Masterdoc §20, P2 DoD): search -> resolve
// -> load into a real media_kit `Player` -> confirm playback position
// actually advances.
//
// This supersedes P1's HTTP-range-fetch confirmation (see
// packages/extraction/bin/smoke.dart and docs/deviations.md) with genuine
// decoded playback through the same `MediaKitPlayerEngine` the app uses.
//
// Lives in `app/`, not `packages/audio_engine`, so audio_engine's own
// pubspec never gains an `extraction`/`innertube_client` dependency (the
// layering rule in docs/architecture.md) — only this throwaway CLI script
// needs both sides wired together.
//
// Usage: dart run app/bin/smoke_playback.dart ["search query"]
//
// A CLI tool's whole purpose is to print to stdout, so `avoid_print` is
// blanket-disabled for this file rather than justified line by line.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:app/services/extraction_service.dart';
import 'package:audio_engine/audio_engine.dart';
import 'package:core/core.dart';
import 'package:media_kit/media_kit.dart';

Future<void> main(List<String> args) async {
  AppLogger.init();
  final query = args.isNotEmpty ? args.first : 'Never Gonna Give You Up';

  try {
    MediaKit.ensureInitialized();
  } on Object catch (error) {
    print(
      'SKIPPED: media_kit could not initialize its native library in this '
      'environment ($error). This is expected outside a `flutter build '
      'windows` output tree — real playback is verified on the reference '
      'laptop per the Phase 2 report.',
    );
    exit(0);
  }

  print('Building extraction service (fetches signed remote config)...');
  final extractionService = await ExtractionService.create();

  print('Searching for "$query"...');
  final searchResult = await extractionService.search(query);
  final results = switch (searchResult) {
    Ok(:final value) => value,
    Err(:final error) => _fail('search failed: $error'),
  };
  if (results.isEmpty) _fail('search returned no results for "$query"');

  final chosen = results.firstWhere(
    (r) => !r.isVideoEntity,
    orElse: () => results.first,
  );
  print('  chosen: ${chosen.title} by ${chosen.artist} (${chosen.videoId})');

  print('Loading into MediaKitPlayerEngine...');
  final engine = MediaKitPlayerEngine();
  final track = QueueTrack(
    id: chosen.videoId,
    title: chosen.title,
    artist: chosen.artist,
    resolveStreamUri: () => extractionService.resolveStream(chosen.videoId),
  );

  final positions = <Duration>[];
  final sub = engine.positionStream.listen(positions.add);

  await engine.loadQueue([track]);
  print('  waiting for playback to advance...');
  await Future<void>.delayed(const Duration(seconds: 6));

  await sub.cancel();
  await engine.dispose();

  if (positions.isEmpty || positions.last <= Duration.zero) {
    _fail(
      'playback position never advanced (got $positions) — media_kit did '
      'not actually decode/play audio',
    );
  }

  print('  position advanced to ${positions.last}. Smoke test passed.');
  exit(0);
}

Never _fail(String message) {
  print('FAILED: $message');
  exit(1);
}
