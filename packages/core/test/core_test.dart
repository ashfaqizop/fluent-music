import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('Ok carries a value', () {
      const result = Result<int, String>.ok(42);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.when(ok: (v) => v, err: (_) => -1), 42);
      expect(result.valueOrNull, 42);
      expect(result.errorOrNull, isNull);
    });

    test('Err carries an error', () {
      const result = Result<int, String>.err('failed');
      expect(result.isErr, isTrue);
      expect(result.when(ok: (_) => -1, err: (e) => e), 'failed');
      expect(result.valueOrNull, isNull);
      expect(result.errorOrNull, 'failed');
    });
  });

  group('AppFailure', () {
    test('toString includes the concrete type and message', () {
      const failure = NetworkFailure('timed out');
      expect(failure.toString(), contains('NetworkFailure'));
      expect(failure.toString(), contains('timed out'));
    });
  });
}
