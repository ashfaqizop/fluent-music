import 'package:app/design_system/settings/appearance_settings.dart';
import 'package:database/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/painting.dart' show Color;

/// Persists [AppearanceSettings] to the single-row `AppSettings` table
/// (Masterdoc §11, §16), added in Phase 3.
class SettingsRepository {
  /// Creates a repository backed by [AppDatabase].
  SettingsRepository(this._database);

  final AppDatabase _database;

  /// Loads the persisted [AppearanceSettings], or the defaults if no row
  /// has been written yet.
  Future<AppearanceSettings> load() async {
    final row = await (_database.select(
      _database.appSettings,
    )..where((t) => t.id.equals(0))).getSingleOrNull();
    if (row == null) return const AppearanceSettings();

    return AppearanceSettings(
      densityMode: DensityMode.values.byName(row.densityMode),
      backdropMode: BackdropMode.values.byName(row.backdropMode),
      accentMode: AccentMode.values.byName(row.accentMode),
      customAccentColor: row.customAccentColor == null
          ? null
          : Color(row.customAccentColor!),
      motionLevel: MotionLevel.values.byName(row.motionLevel),
    );
  }

  /// Persists [settings], upserting the single settings row.
  Future<void> save(AppearanceSettings settings) {
    return _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            densityMode: Value(settings.densityMode.name),
            backdropMode: Value(settings.backdropMode.name),
            accentMode: Value(settings.accentMode.name),
            customAccentColor: Value(settings.customAccentColor?.toARGB32()),
            motionLevel: Value(settings.motionLevel.name),
          ),
        );
  }
}
