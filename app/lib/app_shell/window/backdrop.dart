import 'package:app/design_system/settings/appearance_settings.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

/// Applies the user's window backdrop choice (Masterdoc §11.2: "offer both
/// Mica and Acrylic as a user choice") via `flutter_acrylic`.
///
/// `BackdropMode.none` maps to [WindowEffect.disabled] — a flat surface,
/// also the target Low-Spec mode auto-flattens to (§13, Phase 9 scope).
class WindowBackdrop {
  const WindowBackdrop._();

  /// Must be called once, after `windowManager.ensureInitialized()` and
  /// before the first [apply] call.
  static Future<void> initialize() => Window.initialize();

  /// Applies [mode] to the current window.
  static Future<void> apply(BackdropMode mode) {
    final effect = switch (mode) {
      BackdropMode.mica => WindowEffect.mica,
      BackdropMode.acrylic => WindowEffect.acrylic,
      BackdropMode.none => WindowEffect.disabled,
    };
    return Window.setEffect(effect: effect);
  }
}
