import 'package:remote_config/remote_config.dart';
import 'package:test/test.dart';

void main() {
  group('canonicalize', () {
    test('produces identical output regardless of key insertion order', () {
      final a = {'b': 1, 'a': 2, 'c': 3};
      final b = {'c': 3, 'a': 2, 'b': 1};

      expect(canonicalize(a), canonicalize(b));
    });

    test('sorts keys recursively in nested maps', () {
      final a = {
        'outer': {'z': 1, 'y': 2},
      };
      final b = {
        'outer': {'y': 2, 'z': 1},
      };

      expect(canonicalize(a), canonicalize(b));
    });

    test('preserves list order (lists are not reordered)', () {
      final withOrder = {
        'items': [3, 1, 2],
      };
      expect(canonicalize(withOrder), contains('[3,1,2]'));
    });
  });
}
