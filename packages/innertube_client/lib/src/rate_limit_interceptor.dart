import 'package:core/core.dart';
import 'package:dio/dio.dart';

/// Applies rate-limit hygiene (Masterdoc §6.9) to InnerTube requests made
/// through dio: per-host concurrency capping, visitor-id rotation (injected
/// into the JSON request body's `context.client.visitorData` — InnerTube
/// expects this in the payload, not an HTTP header), and retry-with-backoff
/// on 429/5xx responses.
///
/// Retrying requires re-issuing the request through the owning [Dio]
/// instance, so this interceptor is constructed with a reference to it and
/// then added via `dio.interceptors.add(...)` — no circular dependency,
/// since the `Dio` object already exists at that point.
final class InnerTubeRateLimitInterceptor extends Interceptor {
  /// Creates an interceptor wired to [backoffPolicy]/[concurrencyGate]/
  /// [visitorIdRotator], retrying failed requests through [dio]. [maxRetries]
  /// caps how many times one request will be retried after a 429/5xx before
  /// giving up. [delay] is injectable so tests can avoid real wall-clock
  /// waits.
  InnerTubeRateLimitInterceptor({
    required this.dio,
    required this.backoffPolicy,
    required this.concurrencyGate,
    required this.visitorIdRotator,
    this.maxRetries = 3,
    Future<void> Function(Duration)? delay,
  }) : _delay = delay ?? Future<void>.delayed;

  /// The `Dio` instance this interceptor retries requests through.
  final Dio dio;

  /// Computes retry delays for 429/5xx responses.
  final BackoffPolicy backoffPolicy;

  /// Caps concurrent in-flight requests per host.
  final HostConcurrencyGate concurrencyGate;

  /// Rotates the visitor id injected into request bodies.
  final VisitorIdRotator visitorIdRotator;

  /// Maximum retry attempts per request.
  final int maxRetries;

  final Future<void> Function(Duration) _delay;

  static const _attemptKey = 'innerTubeRateLimitAttempt';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final data = options.data;
    if (data is Map<String, dynamic>) {
      final context = data['context'];
      if (context is Map<String, dynamic> &&
          context['client'] is Map<String, dynamic>) {
        (context['client'] as Map<String, dynamic>)['visitorData'] =
            visitorIdRotator.current();
      }
    }
    visitorIdRotator.noteRequestSent();
    handler.next(options);
  }

  @override
  // Retrying requires awaiting a delay and re-issuing the request before
  // resolving/forwarding the error — an async override of dio's `void
  // onError` is the documented pattern for this (dio discards the Future).
  // ignore: avoid_void_async
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final isRetryable =
        statusCode == 429 || (statusCode != null && statusCode >= 500);
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;

    if (!isRetryable || attempt >= maxRetries) {
      handler.next(err);
      return;
    }

    final retryAfterHeader = err.response?.headers.value('retry-after');
    final retryAfter = retryAfterHeader != null
        ? Duration(seconds: int.tryParse(retryAfterHeader) ?? 0)
        : null;

    await concurrencyGate.run(err.requestOptions.uri.host, () async {
      await _delay(
        backoffPolicy.delayForAttempt(attempt + 1, retryAfter: retryAfter),
      );
    });

    try {
      final retryOptions = err.requestOptions.copyWith(
        extra: {...err.requestOptions.extra, _attemptKey: attempt + 1},
      );
      final response = await dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
