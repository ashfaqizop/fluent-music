import 'package:core/core.dart';
import 'package:extraction/extraction.dart';
import 'package:test/test.dart';

void main() {
  test('ExtractionSuccess carries a resolved stream URL', () {
    final result = ExtractionSuccess(
      streamUrl: Uri.parse('https://example.invalid/stream.opus'),
      layerUsed: 'youtube_explode_dart',
    );

    expect(result, isA<ExtractionResult>());
    expect(result.streamUrl.scheme, 'https');
  });

  test('ExtractionFailure carries the failure and tried layers', () {
    const failure = NetworkFailure('all layers exhausted');
    const result = ExtractionFailure(
      failure: failure,
      layersTried: ['web_remix', 'ios'],
    );

    expect(result.layersTried, hasLength(2));
    expect(result.failure, isA<AppFailure>());
  });
}
