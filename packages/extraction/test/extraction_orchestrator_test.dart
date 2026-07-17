import 'package:core/core.dart';
import 'package:extraction/extraction.dart';
import 'package:remote_config/remote_config.dart';
import 'package:test/test.dart';

final class _FakeLayer implements ExtractionLayer {
  _FakeLayer(this.name, this.attempt);

  @override
  final String name;
  final ExtractionAttempt attempt;
  var invoked = false;

  @override
  Future<ExtractionAttempt> tryResolve({
    required String videoId,
    required RemoteConfig config,
  }) async {
    invoked = true;
    return attempt;
  }
}

void main() {
  group('ExtractionOrchestrator', () {
    test('returns the first success and never invokes later layers', () async {
      final skip = _FakeLayer('skip', const AttemptSkipped('nope'));
      final success = _FakeLayer(
        'success',
        AttemptSuccess(Uri.parse('https://example.invalid/a.opus')),
      );
      final neverReached = _FakeLayer(
        'never',
        AttemptSuccess(Uri.parse('https://example.invalid/b.opus')),
      );

      final orchestrator = ExtractionOrchestrator(
        layers: [skip, success, neverReached],
      );

      final result = await orchestrator.resolve(
        videoId: 'abc',
        config: RemoteConfig.embeddedDefault,
      );

      expect(result, isA<ExtractionSuccess>());
      expect(
        (result as ExtractionSuccess).streamUrl,
        Uri.parse('https://example.invalid/a.opus'),
      );
      expect(result.layerUsed, 'success');
      expect(skip.invoked, isTrue);
      expect(success.invoked, isTrue);
      expect(neverReached.invoked, isFalse);
    });

    test(
      'aggregates layersTried in order when every layer fails/skips',
      () async {
        final skip = _FakeLayer('skip', const AttemptSkipped('nope'));
        final fail = _FakeLayer(
          'fail',
          const AttemptFailed(NetworkFailure('boom')),
        );

        final orchestrator = ExtractionOrchestrator(layers: [skip, fail]);
        final result = await orchestrator.resolve(
          videoId: 'abc',
          config: RemoteConfig.embeddedDefault,
        );

        expect(result, isA<ExtractionFailure>());
        final failure = result as ExtractionFailure;
        expect(failure.layersTried, ['skip', 'fail']);
        expect(failure.failure, isA<NetworkFailure>());
      },
    );

    test('an all-skipped chain still returns a well-formed failure', () async {
      final skip1 = _FakeLayer('a', const AttemptSkipped('x'));
      final skip2 = _FakeLayer('b', const AttemptSkipped('y'));

      final orchestrator = ExtractionOrchestrator(layers: [skip1, skip2]);
      final result = await orchestrator.resolve(
        videoId: 'abc',
        config: RemoteConfig.embeddedDefault,
      );

      expect(result, isA<ExtractionFailure>());
      expect((result as ExtractionFailure).layersTried, ['a', 'b']);
    });
  });
}
