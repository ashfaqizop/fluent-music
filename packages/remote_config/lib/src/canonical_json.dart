import 'dart:convert';

/// Encodes [value] as canonical JSON: object keys are recursively sorted
/// before encoding, so signing and verifying always hash identical bytes
/// regardless of the source `Map`'s iteration order (Dart's `jsonEncode`
/// makes no such guarantee on its own).
String canonicalize(Object? value) => jsonEncode(_sortKeys(value));

Object? _sortKeys(Object? value) {
  return switch (value) {
    Map<String, dynamic> map => {
      for (final key in map.keys.toList()..sort()) key: _sortKeys(map[key]),
    },
    List<dynamic> list => list.map(_sortKeys).toList(),
    _ => value,
  };
}
