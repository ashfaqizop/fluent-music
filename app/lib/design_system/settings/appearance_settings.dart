import 'package:flutter/painting.dart' show Color;

/// Density mode (Masterdoc §11.6). Controls spacing/sizing across the shell
/// via `DensityTokens` (`design_system/density/density_tokens.dart`).
enum DensityMode {
  /// Balanced spacing — the default (§11.6).
  hybrid,

  /// Apple-Music-style spacious layout.
  spacious,

  /// Power-user compact/dense layout.
  compact,
}

/// Window backdrop choice (Masterdoc §11.2).
enum BackdropMode {
  /// Windows 11 Mica material — the default.
  mica,

  /// Windows Acrylic (blurred, more translucent).
  acrylic,

  /// Flat surface, no composited backdrop (also the Low-Spec-mode target —
  /// §13 — though the Low-Spec auto-override itself is Phase 9 scope).
  none,
}

/// Accent color source (Masterdoc §11.5).
enum AccentMode {
  /// Follow the Windows system accent color — the default.
  windows,

  /// Use [AppearanceSettings.customAccentColor] instead.
  custom,
}

/// Motion level (Masterdoc §11.7). This is a user-facing override; the OS
/// "reduce motion" signal (`MediaQuery.disableAnimationsOf`) is always
/// honored independently, regardless of this setting.
enum MotionLevel {
  /// Full lush motion — the default.
  full,

  /// Reduced/minimal motion.
  reduced,
}

/// Phase 3's appearance settings (Masterdoc §11, §16), persisted via the
/// `AppSettings` Drift table (`packages/database`). Later phases append
/// further settings sections independently — this covers only what P3
/// introduces.
final class AppearanceSettings {
  /// Creates an appearance settings snapshot, defaulting to Masterdoc §11's
  /// stated defaults (hybrid density, Mica backdrop, Windows accent, full
  /// motion).
  const AppearanceSettings({
    this.densityMode = DensityMode.hybrid,
    this.backdropMode = BackdropMode.mica,
    this.accentMode = AccentMode.windows,
    this.customAccentColor,
    this.motionLevel = MotionLevel.full,
  });

  /// The current density mode.
  final DensityMode densityMode;

  /// The current window backdrop choice.
  final BackdropMode backdropMode;

  /// The current accent color source.
  final AccentMode accentMode;

  /// The user-picked custom accent color, used only when [accentMode] is
  /// [AccentMode.custom].
  final Color? customAccentColor;

  /// The current user-facing motion level.
  final MotionLevel motionLevel;

  /// Returns a copy with the given fields replaced.
  AppearanceSettings copyWith({
    DensityMode? densityMode,
    BackdropMode? backdropMode,
    AccentMode? accentMode,
    Color? customAccentColor,
    MotionLevel? motionLevel,
  }) {
    return AppearanceSettings(
      densityMode: densityMode ?? this.densityMode,
      backdropMode: backdropMode ?? this.backdropMode,
      accentMode: accentMode ?? this.accentMode,
      customAccentColor: customAccentColor ?? this.customAccentColor,
      motionLevel: motionLevel ?? this.motionLevel,
    );
  }
}
