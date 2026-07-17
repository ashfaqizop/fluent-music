import 'package:flutter_test/flutter_test.dart';
import 'package:media_integration/media_integration.dart';

void main() {
  test('NowPlayingInfo carries title/artist/optional artwork', () {
    const info = NowPlayingInfo(title: 'Song', artist: 'Artist');
    expect(info.title, 'Song');
    expect(info.artworkUri, isNull);
  });
}
