import 'package:core/core.dart';
import 'package:http/http.dart' as http;

/// Wraps a `package:http` [http.Client] with proactive rate-limit hygiene
/// (Masterdoc §6.9): per-host concurrency capping and minimum inter-request
/// spacing.
///
/// Deliberately does **not** add its own retry-with-backoff loop.
/// `youtube_explode_dart`'s `StreamClient.getManifest` already retries each
/// client attempt internally (verified in its `lib/src/retry.dart`, up to 5
/// attempts). Stacking a second independent retry loop underneath it would
/// multiply worst-case latency for no benefit — see `docs/extraction.md`.
final class RateLimitedHttpClient extends http.BaseClient {
  /// Creates a client that paces requests made via [inner] through [gate],
  /// waiting at least [minInterval] between consecutive requests to the
  /// same host.
  RateLimitedHttpClient(
    this._inner, {
    required this.gate,
    this.minInterval = const Duration(milliseconds: 150),
  });

  final http.Client _inner;

  /// Caps concurrent in-flight requests per host.
  final HostConcurrencyGate gate;

  /// Minimum spacing between consecutive requests to the same host.
  final Duration minInterval;

  final _lastRequestByHost = <String, DateTime>{};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final host = request.url.host;
    return gate.run(host, () async {
      final last = _lastRequestByHost[host];
      if (last != null) {
        final elapsed = DateTime.now().difference(last);
        if (elapsed < minInterval) {
          await Future<void>.delayed(minInterval - elapsed);
        }
      }
      _lastRequestByHost[host] = DateTime.now();
      return _inner.send(request);
    });
  }

  @override
  void close() => _inner.close();
}
