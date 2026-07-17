import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:remote_config/src/remote_config.dart';

/// Persists the last-known-good [RemoteConfig] to disk, so extraction can
/// still self-heal from the most recent verified config even if the app is
/// offline or the next fetch fails (Masterdoc §6.5).
///
/// Pure `dart:io` — no Flutter dependency, so this stays unit-testable
/// without the Flutter SDK (§5.2). The real app passes a `path_provider`
/// app-support directory; the CLI harness and tests pass a temp directory.
final class RemoteConfigCache {
  /// Creates a cache backed by [directory], which must already exist.
  const RemoteConfigCache(this.directory);

  /// The directory the cache file is stored in.
  final Directory directory;

  File get _file => File(p.join(directory.path, 'remote_config_cache.json'));

  /// Reads the last cached config, or `null` if none has ever been written
  /// (or the cached file is unreadable/corrupt — treated as "no cache").
  Future<RemoteConfig?> readLastKnownGood() async {
    if (!_file.existsSync()) return null;
    try {
      final raw = await _file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return RemoteConfig.fromJson(json['payload'] as Map<String, dynamic>);
    } on FormatException {
      return null;
    } on IOException {
      return null;
    }
  }

  /// Writes [config] as the new last-known-good cache entry, alongside a
  /// hash of [rawPayloadBytes] (the raw signed payload bytes) so a
  /// byte-identical refetch can be short-circuited without re-verifying.
  Future<void> write(
    RemoteConfig config, {
    required List<int> rawPayloadBytes,
  }) async {
    await directory.create(recursive: true);
    final envelope = {
      'payload': config.toJson(),
      'payloadHashSha256': sha256.convert(rawPayloadBytes).toString(),
    };
    await _file.writeAsString(jsonEncode(envelope));
  }

  /// Reads just the cached payload-hash, or `null` if no cache exists — used
  /// by the fetcher to skip re-verifying a byte-identical refetch.
  Future<String?> readPayloadHash() async {
    if (!_file.existsSync()) return null;
    try {
      final raw = await _file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json['payloadHashSha256'] as String?;
    } on FormatException {
      return null;
    } on IOException {
      return null;
    }
  }
}
