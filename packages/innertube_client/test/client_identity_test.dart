import 'package:innertube_client/innertube_client.dart';
import 'package:test/test.dart';

void main() {
  test('ClientIdentity exposes its fields and a readable toString', () {
    const identity = ClientIdentity(
      name: 'WEB_REMIX',
      clientName: '67',
      clientVersion: '1.20260101.00.00',
    );

    expect(identity.name, 'WEB_REMIX');
    expect(identity.toString(), contains('WEB_REMIX'));
  });
}
