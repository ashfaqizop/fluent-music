import 'package:extraction/extraction.dart';
import 'package:remote_config/remote_config.dart';
import 'package:test/test.dart';

void main() {
  group('YtDlpLayer', () {
    test('always skips and never touches enabled', () async {
      const layer = YtDlpLayer(enabled: true);

      final result = await layer.tryResolve(
        videoId: 'abc',
        config: RemoteConfig.embeddedDefault,
      );

      expect(result, isA<AttemptSkipped>());
    });

    test('the default constructor is off', () {
      const layer = YtDlpLayer();
      expect(layer.enabled, isFalse);
    });
  });
}
