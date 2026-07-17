import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:remote_config/remote_config.dart';
import 'package:test/test.dart';

/// A minimal fake [HttpClientAdapter] that always returns the same
/// [body]/[statusCode], regardless of the requested URL — enough to test
/// [RemoteConfigFetcher] without hitting the network.
final class _FixedResponseAdapter implements HttpClientAdapter {
  _FixedResponseAdapter(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(body, 200);
  }

  @override
  void close({bool force = false}) {}
}

final class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'simulated network failure',
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A verifier test double that returns a fixed result without touching the
/// real Ed25519 algorithm — [RemoteConfigFetcher]'s job is to react
/// correctly to a verifier's answer, not to re-test the algorithm itself
/// (that's covered in `ed25519_remote_config_verifier_test.dart`).
final class _FixedVerifier implements AsyncRemoteConfigVerifier {
  _FixedVerifier(this.result);
  final bool result;

  @override
  Future<bool> verify({
    required List<int> payload,
    required List<int> signature,
  }) async => result;
}

void main() {
  group('RemoteConfigFetcher', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'remote_config_fetcher_test',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Dio dioWith(HttpClientAdapter adapter) {
      final dio = Dio();
      dio.httpClientAdapter = adapter;
      return dio;
    }

    test('a validly-signed payload is applied and cached', () async {
      final envelope = jsonEncode({
        'payload': {
          'schemaVersion': 2,
          'clientIdentityOrder': ['WEB_REMIX'],
          'raceStaggerMs': 0,
          'poTokenEnabled': false,
        },
        'signature': base64.encode([1, 2, 3]),
      });

      final fetcher = RemoteConfigFetcher(
        dio: dioWith(_FixedResponseAdapter(envelope)),
        verifier: _FixedVerifier(true),
        cache: RemoteConfigCache(tempDir),
      );

      final config = await fetcher.fetchAndApply();
      expect(config.schemaVersion, 2);
      expect(config.clientIdentityOrder, ['WEB_REMIX']);

      final cache = RemoteConfigCache(tempDir);
      expect(await cache.readLastKnownGood(), isNotNull);
    });

    test(
      'a failed signature falls back to the cached last-known-good',
      () async {
        final cache = RemoteConfigCache(tempDir);
        const goodConfig = RemoteConfig(
          schemaVersion: 2,
          clientIdentityOrder: ['ANDROID_MUSIC'],
          raceStaggerMs: 0,
          poTokenEnabled: false,
        );
        await cache.write(goodConfig, rawPayloadBytes: 'good'.codeUnits);

        final tamperedEnvelope = jsonEncode({
          'payload': {
            'schemaVersion': 2,
            'clientIdentityOrder': ['MALICIOUS'],
          },
          'signature': base64.encode([9, 9, 9]),
        });

        final fetcher = RemoteConfigFetcher(
          dio: dioWith(_FixedResponseAdapter(tamperedEnvelope)),
          verifier: _FixedVerifier(false),
          cache: cache,
        );

        final config = await fetcher.fetchAndApply();
        expect(config.clientIdentityOrder, ['ANDROID_MUSIC']);
      },
    );

    test(
      'a network failure falls back to embeddedDefault with no cache',
      () async {
        final fetcher = RemoteConfigFetcher(
          dio: dioWith(_ThrowingAdapter()),
          verifier: _FixedVerifier(true),
          cache: RemoteConfigCache(tempDir),
        );

        final config = await fetcher.fetchAndApply();
        expect(
          config.schemaVersion,
          RemoteConfig.embeddedDefault.schemaVersion,
        );
        expect(
          config.clientIdentityOrder,
          RemoteConfig.embeddedDefault.clientIdentityOrder,
        );
      },
    );

    test('never throws, even on a malformed envelope', () async {
      final fetcher = RemoteConfigFetcher(
        dio: dioWith(_FixedResponseAdapter('not json at all')),
        verifier: _FixedVerifier(true),
        cache: RemoteConfigCache(tempDir),
      );

      expect(fetcher.fetchAndApply(), completes);
    });
  });
}
