import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:http/http.dart' as http;

/// Default cap on total cached bytes (Masterdoc §7's "~2 GB, configurable").
const defaultPlaybackCacheMaxBytes = 2 * 1024 * 1024 * 1024;

/// Disk cache for streamed (non-downloaded) audio, so replaying a recently
/// streamed track doesn't re-fetch it (Masterdoc §7).
///
/// Deliberately self-contained (a JSON sidecar index, not a `database`
/// table) rather than depending on `packages/database` — `audio_engine`
/// stays a standalone, independently testable package per the layering
/// rule in `docs/architecture.md`; nothing above it needs a unified view
/// of this index in Phase 2. Revisit if a later phase (e.g. P7's Downloads
/// view) needs streamed-cache and downloaded-file usage in one place.
///
/// Populates eagerly: the first time a track's stream URL is resolved (as
/// the current or look-ahead track), a background fetch caches the full
/// file — not only after it finishes playing — since the look-ahead
/// prefetch already implies the user is about to hear it.
final class PlaybackCache {
  PlaybackCache._(this._dir, this._maxBytes, this._index);

  final Directory _dir;
  final int _maxBytes;
  final Map<String, _CacheEntry> _index;
  final _log = AppLogger('PlaybackCache');
  final _inFlight = <String>{};

  /// Opens (creating if necessary) a cache rooted at [dir], loading its
  /// existing index. [maxBytes] caps total cached size; oldest-accessed
  /// entries are evicted first once exceeded.
  static Future<PlaybackCache> open(
    Directory dir, {
    int maxBytes = defaultPlaybackCacheMaxBytes,
  }) async {
    await dir.create(recursive: true);
    final indexFile = File('${dir.path}/index.json');
    final index = <String, _CacheEntry>{};
    if (indexFile.existsSync()) {
      try {
        final raw = jsonDecode(await indexFile.readAsString()) as List;
        for (final entry in raw) {
          final map = entry as Map<String, dynamic>;
          index[map['trackId'] as String] = _CacheEntry(
            filePath: map['filePath'] as String,
            sizeBytes: map['sizeBytes'] as int,
            lastAccessed: DateTime.parse(map['lastAccessed'] as String),
          );
        }
      } on FormatException {
        // Corrupt index; start fresh rather than failing cache opening.
      }
    }
    return PlaybackCache._(dir, maxBytes, index);
  }

  /// Wraps a track's raw [resolve] callback: returns a cached local file
  /// URI when present, otherwise returns the network URL immediately and
  /// kicks off a background fetch to populate the cache for next time.
  Future<Uri> Function() wrap(String trackId, Future<Uri> Function() resolve) {
    return () async {
      final cached = _index[trackId];
      if (cached != null) {
        final file = File(cached.filePath);
        if (file.existsSync()) {
          _index[trackId] = cached.copyWith(lastAccessed: DateTime.now());
          unawaited(_saveIndex());
          return file.uri;
        }
        _index.remove(trackId);
      }
      final uri = await resolve();
      unawaited(_populate(trackId, uri));
      return uri;
    };
  }

  /// Current total cached size in bytes.
  int get totalBytes => _index.values.fold(0, (sum, e) => sum + e.sizeBytes);

  Future<void> _populate(String trackId, Uri sourceUri) async {
    if (!_inFlight.add(trackId)) return;
    try {
      final response = await http.get(sourceUri);
      if (response.statusCode != 200 && response.statusCode != 206) return;
      final file = File('${_dir.path}/$trackId.audio');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      _index[trackId] = _CacheEntry(
        filePath: file.path,
        sizeBytes: response.bodyBytes.length,
        lastAccessed: DateTime.now(),
      );
      await _evictIfNeeded();
      await _saveIndex();
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to cache track "$trackId"', error, stackTrace);
    } finally {
      _inFlight.remove(trackId);
    }
  }

  Future<void> _evictIfNeeded() async {
    if (totalBytes <= _maxBytes) return;
    final byOldest = _index.entries.toList()
      ..sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));
    for (final entry in byOldest) {
      if (totalBytes <= _maxBytes) break;
      final file = File(entry.value.filePath);
      if (file.existsSync()) await file.delete();
      _index.remove(entry.key);
    }
  }

  Future<void> _saveIndex() async {
    final indexFile = File('${_dir.path}/index.json');
    final raw = _index.entries
        .map(
          (e) => {
            'trackId': e.key,
            'filePath': e.value.filePath,
            'sizeBytes': e.value.sizeBytes,
            'lastAccessed': e.value.lastAccessed.toIso8601String(),
          },
        )
        .toList();
    await indexFile.writeAsString(jsonEncode(raw));
  }
}

final class _CacheEntry {
  const _CacheEntry({
    required this.filePath,
    required this.sizeBytes,
    required this.lastAccessed,
  });

  final String filePath;
  final int sizeBytes;
  final DateTime lastAccessed;

  _CacheEntry copyWith({DateTime? lastAccessed}) => _CacheEntry(
    filePath: filePath,
    sizeBytes: sizeBytes,
    lastAccessed: lastAccessed ?? this.lastAccessed,
  );
}
