import 'dart:convert';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:remote_config/src/canonical_json.dart';
import 'package:remote_config/src/remote_config.dart';
import 'package:remote_config/src/remote_config_cache.dart';
import 'package:remote_config/src/remote_config_verifier.dart';

/// Default location of the signed remote-config envelope: an in-repo file
/// (not a GitHub Release asset — see `docs/deviations.md` for the
/// rationale), fetched via a `main`-pinned raw.githubusercontent.com URL.
final Uri defaultRemoteConfigUrl = Uri.parse(
  'https://raw.githubusercontent.com/ashfaqizop/fluent-music/main/'
  'remote-config/remote_config.signed.json',
);

/// Fetches, verifies, and applies the signed remote config (Masterdoc
/// §6.5), falling back to the local cache and then to
/// [RemoteConfig.embeddedDefault] on any failure. **Never throws** — this
/// is the concrete mechanism behind "a malformed/incompatible config never
/// bricks playback."
final class RemoteConfigFetcher {
  /// Creates a fetcher.
  RemoteConfigFetcher({
    required Dio dio,
    required AsyncRemoteConfigVerifier verifier,
    required RemoteConfigCache cache,
    Uri? url,
  }) : _dio = dio,
       _verifier = verifier,
       _cache = cache,
       _url = url ?? defaultRemoteConfigUrl,
       _log = AppLogger('RemoteConfigFetcher');

  final Dio _dio;
  final AsyncRemoteConfigVerifier _verifier;
  final RemoteConfigCache _cache;
  final Uri _url;
  final AppLogger _log;

  /// Fetches the signed config from [_url], verifies its signature,
  /// caches it, and returns it. On any failure (network error, malformed
  /// envelope, bad signature), falls back to the last cached config, or to
  /// [RemoteConfig.embeddedDefault] if no cache exists.
  Future<RemoteConfig> fetchAndApply() async {
    try {
      final response = await _dio.getUri<String>(
        _url,
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data;
      if (body == null) {
        return _fallback('empty response body');
      }

      final envelope = jsonDecode(body) as Map<String, dynamic>;
      final payload = envelope['payload'];
      final signatureB64 = envelope['signature'] as String?;
      if (payload is! Map<String, dynamic> || signatureB64 == null) {
        return _fallback('envelope missing payload/signature');
      }

      final canonicalBytes = utf8.encode(canonicalize(payload));
      final signature = base64.decode(signatureB64);

      final isValid = await _verifier.verify(
        payload: canonicalBytes,
        signature: signature,
      );
      if (!isValid) {
        return _fallback('signature verification failed');
      }

      final config = RemoteConfig.fromJson(payload);
      await _cache.write(config, rawPayloadBytes: canonicalBytes);
      _log.info(
        'Applied remote config from network (schemaVersion '
        '${config.schemaVersion}).',
      );
      return config;
    } on DioException catch (e) {
      return _fallback('network error: ${e.message}');
    } on FormatException catch (e) {
      return _fallback('malformed envelope: ${e.message}');
    }
  }

  Future<RemoteConfig> _fallback(String reason) async {
    _log.warning('Remote config fetch failed ($reason); falling back.');
    final cached = await _cache.readLastKnownGood();
    if (cached != null) {
      _log.info(
        'Applied remote config from local cache (schemaVersion '
        '${cached.schemaVersion}).',
      );
      return cached;
    }
    _log.info('Applied embedded default remote config.');
    return RemoteConfig.embeddedDefault;
  }
}
