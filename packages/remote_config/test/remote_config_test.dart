import 'package:remote_config/remote_config.dart';
import 'package:test/test.dart';

void main() {
  test('embeddedDefault is a safe, non-empty fallback', () {
    const config = RemoteConfig.embeddedDefault;

    expect(config.schemaVersion, greaterThan(0));
    expect(config.clientIdentityOrder, isNotEmpty);
    expect(config.poTokenEnabled, isFalse);
  });
}
