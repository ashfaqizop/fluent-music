import 'package:innertube_client/innertube_client.dart';
import 'package:remote_config/remote_config.dart';
import 'package:test/test.dart';

void main() {
  group('buildContext', () {
    test('builds the base InnerTube context from the identity', () {
      final context = buildContext(webRemixIdentity, visitorData: 'abc123');

      final client = context['context']['client'] as Map<String, dynamic>;
      expect(client['clientName'], 'WEB_REMIX');
      expect(client['clientVersion'], webRemixIdentity.clientVersion);
      expect(client['hl'], 'en');
      expect(client['gl'], 'US');
      expect(client['visitorData'], 'abc123');
    });

    test('omits visitorData when none is supplied', () {
      final context = buildContext(webRemixIdentity);
      final client = context['context']['client'] as Map<String, dynamic>;
      expect(client.containsKey('visitorData'), isFalse);
    });

    test('a remote-config identityOverride replaces clientVersion', () {
      const config = RemoteConfig(
        schemaVersion: 2,
        clientIdentityOrder: ['WEB_REMIX'],
        raceStaggerMs: 0,
        poTokenEnabled: false,
        identityOverrides: {
          'WEB_REMIX': ClientIdentityOverride(clientVersion: '9.99.99'),
        },
      );

      final context = buildContext(webRemixIdentity, remoteConfig: config);
      final client = context['context']['client'] as Map<String, dynamic>;
      expect(client['clientVersion'], '9.99.99');
    });

    test('extraContext fields are merged into context.client', () {
      const identity = ClientIdentity(
        name: 'TEST',
        clientName: 'TEST',
        clientVersion: '1.0',
        extraContext: {'deviceMake': 'Google'},
      );

      final context = buildContext(identity);
      final client = context['context']['client'] as Map<String, dynamic>;
      expect(client['deviceMake'], 'Google');
    });
  });
}
