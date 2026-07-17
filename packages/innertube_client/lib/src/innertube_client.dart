import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:innertube_client/src/client_identity.dart';
import 'package:innertube_client/src/innertube_failure.dart';
import 'package:innertube_client/src/models/search_result_item.dart';
import 'package:innertube_client/src/request_context.dart';
import 'package:innertube_client/src/search_response_parser.dart';
import 'package:remote_config/remote_config.dart';

/// Talks to YT Music's InnerTube `search`/`browse` endpoints for one client
/// identity (Masterdoc §6.1 — "browse/search/home/artist/album/playlist/
/// lyrics/radio surfaces").
///
/// Phase 1 scope: `search` is fully parsed (song/video rows); `browse` is a
/// thin, unparsed passthrough — a foundation for Phase 4's content-surface
/// work (home/artist/album), not a finished feature yet.
final class InnerTubeClient {
  /// Creates a client for [identity], using [dio] for transport.
  InnerTubeClient({
    required Dio dio,
    required ClientIdentity identity,
    RemoteConfig? remoteConfig,
    String? visitorData,
  }) : _dio = dio,
       _identity = identity,
       _remoteConfig = remoteConfig,
       _visitorData = visitorData;

  final Dio _dio;
  final ClientIdentity _identity;
  final RemoteConfig? _remoteConfig;
  final String? _visitorData;

  /// Searches YT Music for [query], returning parsed song/video results.
  Future<Result<List<SearchResultItem>, InnerTubeFailure>> search(
    String query,
  ) async {
    final body = {
      ...buildContext(
        _identity,
        visitorData: _visitorData,
        remoteConfig: _remoteConfig,
      ),
      'query': query,
    };

    final result = await _post('search', body);
    return result.when(
      ok: (json) => Result.ok(parseSearchResults(json)),
      err: Result.err,
    );
  }

  /// Fetches a raw (lightly-parsed) browse response for [browseId].
  ///
  /// This is a Phase-1 foundation only: it returns the decoded JSON as-is
  /// rather than mapping it to a domain model, since full home/artist/album
  /// rendering is Phase 4 scope.
  Future<Result<Map<String, dynamic>, InnerTubeFailure>> browse(
    String browseId, {
    Map<String, dynamic>? params,
  }) {
    final body = {
      ...buildContext(
        _identity,
        visitorData: _visitorData,
        remoteConfig: _remoteConfig,
      ),
      'browseId': browseId,
      if (params != null) ...params,
    };

    return _post('browse', body);
  }

  Future<Result<Map<String, dynamic>, InnerTubeFailure>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${_identity.baseUrl}/youtubei/v1/$endpoint',
        queryParameters: {
          if (_identity.apiKey != null) 'key': _identity.apiKey,
          'prettyPrint': 'false',
        },
        data: body,
        options: Options(
          headers: {
            if (_identity.userAgent != null) 'User-Agent': _identity.userAgent,
          },
        ),
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        return Result.err(InnerTubeHttpFailure(statusCode));
      }

      final data = response.data;
      if (data == null) {
        return Result.err(InnerTubeParseFailure('empty response body'));
      }
      return Result.ok(data);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode != null) {
        return Result.err(InnerTubeHttpFailure(statusCode, cause: e));
      }
      return Result.err(InnerTubeHttpFailure(0, cause: e));
    }
  }
}
