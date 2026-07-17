import 'package:extraction/extraction.dart';
import 'package:remote_config/remote_config.dart';
import 'package:test/test.dart';

final class _NoOpPoTokenProvider implements PoTokenProvider {
  const _NoOpPoTokenProvider();

  @override
  Future<String?> fetchToken({required String videoId}) async => null;
}

void main() {
  group('PoTokenLayer', () {
    test('always skips regardless of poTokenEnabled', () async {
      final layer = const PoTokenLayer(_NoOpPoTokenProvider());

      final withEnabled = await layer.tryResolve(
        videoId: 'abc',
        config: const RemoteConfig(
          schemaVersion: 2,
          clientIdentityOrder: ['WEB_REMIX'],
          raceStaggerMs: 0,
          poTokenEnabled: true,
        ),
      );
      final withDisabled = await layer.tryResolve(
        videoId: 'abc',
        config: RemoteConfig.embeddedDefault,
      );

      expect(withEnabled, isA<AttemptSkipped>());
      expect(withDisabled, isA<AttemptSkipped>());
    });
  });
}
