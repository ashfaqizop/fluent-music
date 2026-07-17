import 'package:innertube_client/src/models/search_result_item.dart';

/// Parses `musicResponsiveListItemRenderer` rows out of a YT Music search
/// response into [SearchResultItem]s (Phase 1 scope: song/video rows only —
/// album/artist/playlist rows are deferred to Phase 4).
///
/// Deliberately walks the *entire* response tree looking for renderer rows
/// by key, rather than a fixed `contents[0].tabs[0]....` path. YouTube
/// reshuffles InnerTube's renderer tree without notice (this is exactly the
/// kind of fragility Masterdoc §6 calls out) — a tolerant, path-independent
/// walk survives far more of that churn than a strict path would.
List<SearchResultItem> parseSearchResults(Map<String, dynamic> response) {
  final results = <SearchResultItem>[];
  _collectRenderers(response, results);
  return results;
}

void _collectRenderers(Object? node, List<SearchResultItem> out) {
  switch (node) {
    case Map<String, dynamic> map:
      final renderer = map['musicResponsiveListItemRenderer'];
      if (renderer is Map<String, dynamic>) {
        final item = _parseRow(renderer);
        if (item != null) out.add(item);
      }
      for (final value in map.values) {
        _collectRenderers(value, out);
      }
    case List<dynamic> list:
      for (final value in list) {
        _collectRenderers(value, out);
      }
    default:
      return;
  }
}

SearchResultItem? _parseRow(Map<String, dynamic> renderer) {
  final videoId = _extractVideoId(renderer);
  if (videoId == null) return null;

  final flexColumns = renderer['flexColumns'];
  if (flexColumns is! List) return null;

  final title = _flexColumnText(flexColumns, 0);
  if (title == null || title.isEmpty) return null;

  final subtitleParts = _flexColumnRuns(flexColumns, 1);
  final isVideoEntity =
      subtitleParts.isNotEmpty && subtitleParts.first == 'Video';

  return SearchResultItem(
    videoId: videoId,
    title: title,
    artist: subtitleParts.length > 1 ? subtitleParts[1] : '',
    album: subtitleParts.length > 2 ? subtitleParts[2] : null,
    durationText: subtitleParts.isNotEmpty ? subtitleParts.last : null,
    isVideoEntity: isVideoEntity,
  );
}

String? _extractVideoId(Map<String, dynamic> renderer) {
  final overlayVideoId = _digString(renderer, [
    'overlay',
    'musicItemThumbnailOverlayRenderer',
    'content',
    'musicPlayButtonRenderer',
    'playNavigationEndpoint',
    'watchEndpoint',
    'videoId',
  ]);
  if (overlayVideoId != null) return overlayVideoId;

  final flexColumns = renderer['flexColumns'];
  if (flexColumns is List && flexColumns.isNotEmpty) {
    final runs = _rawRuns(flexColumns, 0);
    for (final run in runs) {
      final videoId = _digString(run, [
        'navigationEndpoint',
        'watchEndpoint',
        'videoId',
      ]);
      if (videoId != null) return videoId;
    }
  }
  return null;
}

List<Map<String, dynamic>> _rawRuns(List<dynamic> flexColumns, int index) {
  if (index >= flexColumns.length) return const [];
  final column = flexColumns[index];
  if (column is! Map<String, dynamic>) return const [];
  final runs = _dig(column, [
    'musicResponsiveListItemFlexColumnRenderer',
    'text',
    'runs',
  ]);
  if (runs is! List) return const [];
  return runs.whereType<Map<String, dynamic>>().toList();
}

String _runText(Map<String, dynamic> run) {
  final text = run['text'];
  return text is String ? text : '';
}

String? _flexColumnText(List<dynamic> flexColumns, int index) {
  final runs = _rawRuns(flexColumns, index);
  if (runs.isEmpty) return null;
  return runs.map(_runText).join();
}

List<String> _flexColumnRuns(List<dynamic> flexColumns, int index) {
  final runs = _rawRuns(flexColumns, index);
  final joined = runs.map(_runText).join();
  return joined
      .split('•')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

Object? _dig(Map<String, dynamic> map, List<String> path) {
  Object? current = map;
  for (final key in path) {
    if (current is! Map<String, dynamic>) return null;
    current = current[key];
  }
  return current;
}

String? _digString(Map<String, dynamic> map, List<String> path) {
  final value = _dig(map, path);
  return value is String ? value : null;
}
