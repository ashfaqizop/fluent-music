import 'package:flutter/material.dart' show Brightness, ColorScheme;
import 'package:flutter/painting.dart';

/// Extracts a dark-legible tint from track artwork (Masterdoc §11.5) using
/// Flutter's built-in `ColorScheme.fromImageProvider` — deliberately not
/// the `palette_generator` package, which is discontinued upstream (see
/// `docs/deviations.md` if this needs revisiting).
///
/// Caches by artwork URI so scrolling/re-renders don't re-extract from the
/// same image repeatedly, and clamps the extracted color's luminance so it
/// stays "tasteful and legible" over the dark base per §11.5, rather than
/// using Material's raw scheme colors directly.
class DynamicColorEngine {
  final _cache = <String, Color>{};

  /// Resolves a tasteful background tint for the artwork at [artworkUri],
  /// or [fallback] if [artworkUri] is `null` or extraction fails.
  Future<Color> tintFor(Uri? artworkUri, {required Color fallback}) async {
    if (artworkUri == null) return fallback;
    final key = artworkUri.toString();
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: NetworkImage(key),
        brightness: Brightness.dark,
      );
      final tint = _clampForDarkBase(scheme.primary);
      _cache[key] = tint;
      return tint;
    } on Exception {
      // Network failure, decode failure, unsupported format, etc. — the
      // now-playing surface falls back to a flat dark base rather than
      // failing loudly for a purely decorative tint (§15.3 doesn't apply
      // to non-critical cosmetic degradation).
      return fallback;
    }
  }

  /// Darkens/desaturates [color] just enough to stay legible as a
  /// background wash behind light text on the dark base theme.
  Color _clampForDarkBase(Color color) {
    final hsl = HSLColor.fromColor(color);
    final clamped = hsl.withLightness(hsl.lightness.clamp(0.12, 0.32));
    return clamped.toColor();
  }
}
