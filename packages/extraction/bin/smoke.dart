// Headless integration smoke test (Masterdoc §20, P1 DoD): search -> resolve
// -> confirm the resolved stream is genuinely fetchable audio content.
//
// `audio_engine`'s media_kit wiring is Phase 2 scope (still interface-only),
// so "play a track's audio" is interpreted here as an HTTP range-fetch
// confirmation rather than real mpv playback — see docs/deviations.md.
//
// Usage: dart run packages/extraction/bin/smoke.dart ["search query"]
//
// A CLI tool's whole purpose is to print to stdout, so `avoid_print` is
// blanket-disabled for this file rather than justified line by line.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:extraction/extraction.dart';
import 'package:http/http.dart' as http;
import 'package:innertube_client/innertube_client.dart';
import 'package:remote_config/remote_config.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

Future<void> main(List<String> args) async {
  AppLogger.init();
  final query = args.isNotEmpty ? args.first : 'Never Gonna Give You Up';

  final concurrencyGate = HostConcurrencyGate(maxConcurrentPerHost: 4);
  final backoffPolicy = const BackoffPolicy(
    baseDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 20),
    jitterRatio: 0.3,
  );
  final visitorIdRotator = VisitorIdRotator(random: Random.secure());

  final dio = Dio();
  dio.interceptors.add(
    InnerTubeRateLimitInterceptor(
      dio: dio,
      backoffPolicy: backoffPolicy,
      concurrencyGate: concurrencyGate,
      visitorIdRotator: visitorIdRotator,
    ),
  );

  print('Fetching remote config...');
  final tempDir = await Directory.systemTemp.createTemp('fluent_music_smoke');
  final config = await RemoteConfigFetcher(
    dio: dio,
    verifier: Ed25519RemoteConfigVerifier(),
    cache: RemoteConfigCache(tempDir),
  ).fetchAndApply();
  print(
    '  applied remote config: schemaVersion=${config.schemaVersion}, '
    'identities=${config.clientIdentityOrder}',
  );

  print('Searching for "$query"...');
  final innerTubeClient = InnerTubeClient(
    dio: dio,
    identity: webRemixIdentity,
    remoteConfig: config,
    visitorData: visitorIdRotator.current(),
  );
  final searchResult = await innerTubeClient.search(query);

  final results = switch (searchResult) {
    Ok(:final value) => value,
    Err(:final error) => _fail('search failed: $error'),
  };

  if (results.isEmpty) {
    _fail('search returned no results for "$query"');
  }

  final chosen = results.firstWhere(
    (r) => !r.isVideoEntity,
    orElse: () => results.first,
  );
  print('  chosen: ${chosen.title} by ${chosen.artist} (${chosen.videoId})');

  print('Resolving a playable audio stream...');
  final youtubeExplode = yt.YoutubeExplode(
    httpClient: yt.YoutubeHttpClient(
      RateLimitedHttpClient(http.Client(), gate: concurrencyGate),
    ),
  );

  final orchestrator = ExtractionOrchestrator(
    layers: [
      ClientRaceLayer(youtubeExplode),
      AlternateIdentityLayer(youtubeExplode),
      const PoTokenLayer(_NoOpPoTokenProvider()),
      const YtDlpLayer(),
    ],
  );

  final result = await orchestrator.resolve(
    videoId: chosen.videoId,
    config: config,
  );

  switch (result) {
    case ExtractionSuccess(:final streamUrl, :final layerUsed):
      print('  resolved via layer "$layerUsed": $streamUrl');
      await _confirmPlayable(streamUrl);
      print('Smoke test passed.');
      await tempDir.delete(recursive: true);
      // Other client-race lanes may still be in flight (they're left to
      // run to completion rather than cancelled — see ClientRaceLayer's
      // doc comment). Exiting immediately avoids waiting on them and the
      // confusing "client closed" log noise that follows if we `close()`
      // the shared http client out from under them instead.
      exit(0);
    case ExtractionFailure(:final failure, :final layersTried):
      print('  layers tried: $layersTried');
      await tempDir.delete(recursive: true);
      _fail('extraction failed: $failure');
  }
}

Future<void> _confirmPlayable(Uri streamUrl) async {
  final client = http.Client();
  try {
    final response = await client.get(
      streamUrl,
      headers: {'Range': 'bytes=0-65535'},
    );
    if (response.statusCode != 200 && response.statusCode != 206) {
      _fail('stream URL returned HTTP ${response.statusCode}');
    }
    if (response.bodyBytes.isEmpty) {
      _fail('stream URL returned an empty body');
    }
    print('  fetched ${response.bodyBytes.length} bytes successfully.');
  } finally {
    client.close();
  }
}

Never _fail(String message) {
  print('FAILED: $message');
  exit(1);
}

final class _NoOpPoTokenProvider implements PoTokenProvider {
  const _NoOpPoTokenProvider();

  @override
  Future<String?> fetchToken({required String videoId}) async => null;
}
