import 'package:extraction/extraction.dart';
import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

AudioOnlyStreamInfo _audio({
  required String codec,
  required int bitsPerSecond,
  String url = 'https://example.invalid/stream',
}) {
  return AudioOnlyStreamInfo(
    VideoId('dQw4w9WgXcQ'),
    0,
    Uri.parse(url),
    StreamContainer.webM,
    const FileSize(1024),
    Bitrate(bitsPerSecond),
    codec,
    '',
    const [],
    MediaType('audio', codec.contains('opus') ? 'webm' : 'mp4'),
    null,
  );
}

void main() {
  group('pickBestAudio', () {
    test('returns null for an empty candidate list', () {
      expect(pickBestAudio(const []), isNull);
    });

    test('prefers opus even over a higher-bitrate aac candidate', () {
      final opus = _audio(codec: 'opus', bitsPerSecond: 96000);
      final aac = _audio(codec: 'mp4a.40.2', bitsPerSecond: 256000);

      final best = pickBestAudio([aac, opus]);
      expect(best, same(opus));
    });

    test('breaks ties within the same codec family by highest bitrate', () {
      final low = _audio(codec: 'opus', bitsPerSecond: 64000);
      final high = _audio(codec: 'opus', bitsPerSecond: 160000);

      final best = pickBestAudio([low, high]);
      expect(best, same(high));
    });

    test('falls back to aac when no opus candidate exists', () {
      final aacLow = _audio(codec: 'mp4a.40.2', bitsPerSecond: 128000);
      final aacHigh = _audio(codec: 'mp4a.40.2', bitsPerSecond: 192000);

      final best = pickBestAudio([aacLow, aacHigh]);
      expect(best, same(aacHigh));
    });
  });
}
