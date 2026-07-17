import 'dart:async' show unawaited;

import 'package:app/design_system/settings/appearance_settings.dart';
import 'package:app/providers.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns the live [AppearanceSettings], loading the persisted value on
/// construction and persisting every change back through
/// `SettingsRepository` (Masterdoc §11, §16).
class AppearanceSettingsController extends Notifier<AppearanceSettings> {
  @override
  AppearanceSettings build() {
    unawaited(_load());
    return const AppearanceSettings();
  }

  Future<void> _load() async {
    state = await ref.read(settingsRepositoryProvider).load();
  }

  /// Switches the density mode (§11.6).
  Future<void> setDensityMode(DensityMode mode) =>
      _update(state.copyWith(densityMode: mode));

  /// Switches the window backdrop (§11.2).
  Future<void> setBackdropMode(BackdropMode mode) =>
      _update(state.copyWith(backdropMode: mode));

  /// Switches the accent color source (§11.5).
  Future<void> setAccentMode(AccentMode mode) =>
      _update(state.copyWith(accentMode: mode));

  /// Sets the custom accent color, implicitly switching [AccentMode] to
  /// [AccentMode.custom].
  Future<void> setCustomAccentColor(Color color) => _update(
    state.copyWith(accentMode: AccentMode.custom, customAccentColor: color),
  );

  /// Switches the user-facing motion level (§11.7).
  Future<void> setMotionLevel(MotionLevel level) =>
      _update(state.copyWith(motionLevel: level));

  Future<void> _update(AppearanceSettings next) async {
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }
}

/// The live [AppearanceSettings].
final appearanceSettingsProvider =
    NotifierProvider<AppearanceSettingsController, AppearanceSettings>(
      AppearanceSettingsController.new,
    );
