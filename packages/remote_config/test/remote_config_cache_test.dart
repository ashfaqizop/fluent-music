import 'dart:io';

import 'package:remote_config/remote_config.dart';
import 'package:test/test.dart';

void main() {
  group('RemoteConfigCache', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('remote_config_cache_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test(
      'readLastKnownGood returns null when nothing has been written',
      () async {
        final cache = RemoteConfigCache(tempDir);
        expect(await cache.readLastKnownGood(), isNull);
        expect(await cache.readPayloadHash(), isNull);
      },
    );

    test('write then readLastKnownGood round-trips the config', () async {
      final cache = RemoteConfigCache(tempDir);
      const config = RemoteConfig(
        schemaVersion: 2,
        clientIdentityOrder: ['WEB_REMIX', 'IOS'],
        raceStaggerMs: 25,
        poTokenEnabled: false,
      );

      await cache.write(config, rawPayloadBytes: 'payload-bytes'.codeUnits);
      final restored = await cache.readLastKnownGood();

      expect(restored, isNotNull);
      expect(restored!.schemaVersion, 2);
      expect(restored.clientIdentityOrder, ['WEB_REMIX', 'IOS']);
      expect(restored.raceStaggerMs, 25);
    });

    test('readPayloadHash returns the hash of what was last written', () async {
      final cache = RemoteConfigCache(tempDir);
      await cache.write(
        RemoteConfig.embeddedDefault,
        rawPayloadBytes: 'v1'.codeUnits,
      );
      final hashA = await cache.readPayloadHash();

      await cache.write(
        RemoteConfig.embeddedDefault,
        rawPayloadBytes: 'v2'.codeUnits,
      );
      final hashB = await cache.readPayloadHash();

      expect(hashA, isNotNull);
      expect(hashB, isNotNull);
      expect(hashA, isNot(hashB));
    });

    test('a corrupt cache file is treated as no cache, not an error', () async {
      final cache = RemoteConfigCache(tempDir);
      await File(
        '${tempDir.path}${Platform.pathSeparator}remote_config_cache.json',
      ).writeAsString('not valid json');

      expect(await cache.readLastKnownGood(), isNull);
    });
  });
}
