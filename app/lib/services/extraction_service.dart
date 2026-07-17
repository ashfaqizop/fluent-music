import 'dart:io';
import 'dart:math';

import 'package:app/services/track_resolver.dart';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:extraction/extraction.dart';
import 'package:http/http.dart' as http;
import 'package:innertube_client/innertube_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:remote_config/remote_config.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

/// Thrown by [ExtractionService.resolveStream] when no fallback-chain layer
/// could resolve a playable stream. Caught by `audio_engine`'s `on
/// Exception` handlers around track resolution.
final class StreamResolutionException implements Exception {
  /// Creates an exception wrapping the terminal [failure].
  const StreamResolutionException(this.failure);

  /// The terminal failure from [ExtractionOrchestrator.resolve].
  final AppFailure failure;

  @override
  String toString() => 'StreamResolutionException: $failure';
}

/// Owns `app/`'s wiring of `innertube_client` + `extraction` +
/// `remote_config` — the same recipe as `packages/extraction/bin/smoke.dart`
/// — behind a small surface the rest of the app depends on.
///
/// `audio_engine` never depends on `extraction`/`innertube_client` directly
/// (`docs/architecture.md`'s layering rule); this service is what bridges
/// the two, handing `audio_engine`'s queue lazy resolver callbacks bound to
/// [resolveStream]. Implements [TrackResolver] so callers can depend on
/// that instead and substitute a fake in tests.
final class ExtractionService implements TrackResolver {
  ExtractionService._({
    required InnerTubeClient innerTubeClient,
    required ExtractionOrchestrator orchestrator,
    required RemoteConfig config,
  }) : _innerTubeClient = innerTubeClient,
       _orchestrator = orchestrator,
       _config = config;

  final InnerTubeClient _innerTubeClient;
  final ExtractionOrchestrator _orchestrator;
  final RemoteConfig _config;

  /// Builds an [ExtractionService], fetching and verifying the signed
  /// remote config once up front (falling back to embedded defaults on
  /// failure — see [RemoteConfigFetcher.fetchAndApply]).
  static Future<ExtractionService> create() async {
    final concurrencyGate = HostConcurrencyGate(maxConcurrentPerHost: 4);
    const backoffPolicy = BackoffPolicy(
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

    final supportDir = await getApplicationSupportDirectory();
    final config = await RemoteConfigFetcher(
      dio: dio,
      verifier: Ed25519RemoteConfigVerifier(),
      cache: RemoteConfigCache(Directory('${supportDir.path}/remote_config')),
    ).fetchAndApply();

    final innerTubeClient = InnerTubeClient(
      dio: dio,
      identity: webRemixIdentity,
      remoteConfig: config,
      visitorData: visitorIdRotator.current(),
    );

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

    return ExtractionService._(
      innerTubeClient: innerTubeClient,
      orchestrator: orchestrator,
      config: config,
    );
  }

  @override
  Future<Result<List<SearchResultItem>, InnerTubeFailure>> search(
    String query,
  ) => _innerTubeClient.search(query);

  /// Resolves a playable audio stream URL for [videoId], or throws
  /// [StreamResolutionException] if every fallback-chain layer failed.
  @override
  Future<Uri> resolveStream(String videoId) async {
    final result = await _orchestrator.resolve(
      videoId: videoId,
      config: _config,
    );
    return switch (result) {
      ExtractionSuccess(:final streamUrl) => streamUrl,
      ExtractionFailure(:final failure) => throw StreamResolutionException(
        failure,
      ),
    };
  }
}

final class _NoOpPoTokenProvider implements PoTokenProvider {
  const _NoOpPoTokenProvider();

  @override
  Future<String?> fetchToken({required String videoId}) async => null;
}
