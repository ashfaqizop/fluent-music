import 'package:extraction/extraction.dart';
import 'package:test/test.dart';

void main() {
  group('mapToStreamClient', () {
    test('maps known identity names to a YoutubeApiClient', () {
      expect(mapToStreamClient('IOS'), isNotNull);
      expect(mapToStreamClient('ANDROID_MUSIC'), isNotNull);
      expect(mapToStreamClient('ANDROID_VR'), isNotNull);
      expect(mapToStreamClient('TV'), isNotNull);
    });

    test('WEB_REMIX has no stream-resolution mapping', () {
      // Verified against youtube_explode_dart 3.1.0's source: no WEB_REMIX
      // constant exists there, even though it's the correct identity for
      // innertube_client's search/browse (see docs/deviations.md).
      expect(mapToStreamClient('WEB_REMIX'), isNull);
    });

    test('an unrecognized name returns null rather than throwing', () {
      expect(mapToStreamClient('SOME_MADE_UP_IDENTITY'), isNull);
    });
  });
}
