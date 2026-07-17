import 'package:remote_config/remote_config.dart';
import 'package:test/test.dart';

void main() {
  test('embeddedDefault is a safe, non-empty fallback', () {
    const config = RemoteConfig.embeddedDefault;

    expect(config.schemaVersion, greaterThan(0));
    expect(config.clientIdentityOrder, isNotEmpty);
    expect(config.poTokenEnabled, isFalse);
    expect(config.disabledIdentities, isEmpty);
    expect(config.identityOverrides, isEmpty);
  });

  group('RemoteConfig.fromJson / toJson', () {
    test('round-trips a full payload', () {
      const original = RemoteConfig(
        schemaVersion: 2,
        clientIdentityOrder: ['WEB_REMIX', 'IOS'],
        raceStaggerMs: 50,
        poTokenEnabled: true,
        disabledIdentities: {'TV'},
        identityOverrides: {
          'IOS': ClientIdentityOverride(clientVersion: '20.10.4', priority: 1),
        },
        maxConcurrentRaceLanes: 3,
        raceLaneTimeoutMs: 5000,
        rateLimit: RateLimitPolicyConfig(
          minRequestIntervalMs: 200,
          maxConcurrencyPerHost: 2,
          backoffBaseMs: 750,
          backoffMaxMs: 15000,
          backoffJitterRatio: 0.2,
        ),
        refreshIntervalMinutes: 60,
      );

      final restored = RemoteConfig.fromJson(original.toJson());

      expect(restored.schemaVersion, original.schemaVersion);
      expect(restored.clientIdentityOrder, original.clientIdentityOrder);
      expect(restored.raceStaggerMs, original.raceStaggerMs);
      expect(restored.poTokenEnabled, original.poTokenEnabled);
      expect(restored.disabledIdentities, original.disabledIdentities);
      expect(restored.identityOverrides['IOS']?.clientVersion, '20.10.4');
      expect(restored.identityOverrides['IOS']?.priority, 1);
      expect(restored.maxConcurrentRaceLanes, original.maxConcurrentRaceLanes);
      expect(restored.raceLaneTimeoutMs, original.raceLaneTimeoutMs);
      expect(
        restored.rateLimit.minRequestIntervalMs,
        original.rateLimit.minRequestIntervalMs,
      );
      expect(restored.refreshIntervalMinutes, original.refreshIntervalMinutes);
    });

    test('ignores unknown fields instead of throwing', () {
      final json = {
        ...RemoteConfig.embeddedDefault.toJson(),
        'somethingNew': 'ignored',
      };
      expect(() => RemoteConfig.fromJson(json), returnsNormally);
    });

    test(
      'a schema-v1-shaped payload synthesizes safe defaults for new fields',
      () {
        final v1Payload = {
          'schemaVersion': 1,
          'clientIdentityOrder': ['WEB_REMIX'],
          'raceStaggerMs': 0,
          'poTokenEnabled': false,
        };

        final config = RemoteConfig.fromJson(v1Payload);

        expect(config.schemaVersion, 1);
        expect(config.clientIdentityOrder, ['WEB_REMIX']);
        expect(config.disabledIdentities, isEmpty);
        expect(config.identityOverrides, isEmpty);
        expect(
          config.maxConcurrentRaceLanes,
          RemoteConfig.embeddedDefault.maxConcurrentRaceLanes,
        );
        expect(
          config.rateLimit.minRequestIntervalMs,
          RateLimitPolicyConfig.embeddedDefault.minRequestIntervalMs,
        );
      },
    );

    test('missing fields entirely fall back to embeddedDefault values', () {
      final config = RemoteConfig.fromJson(<String, dynamic>{});
      expect(config.schemaVersion, RemoteConfig.embeddedDefault.schemaVersion);
      expect(
        config.clientIdentityOrder,
        RemoteConfig.embeddedDefault.clientIdentityOrder,
      );
    });
  });
}
