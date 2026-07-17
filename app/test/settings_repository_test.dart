import 'package:app/design_system/settings/appearance_settings.dart';
import 'package:app/services/settings_repository.dart';
import 'package:database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('load() returns defaults when no row has been saved', () async {
    final repository = SettingsRepository(database);

    final settings = await repository.load();

    expect(settings.densityMode, DensityMode.hybrid);
    expect(settings.backdropMode, BackdropMode.mica);
    expect(settings.accentMode, AccentMode.windows);
    expect(settings.motionLevel, MotionLevel.full);
    expect(settings.customAccentColor, null);
  });

  test('save() then load() round-trips every field', () async {
    final repository = SettingsRepository(database);
    const settings = AppearanceSettings(
      densityMode: DensityMode.compact,
      backdropMode: BackdropMode.acrylic,
      accentMode: AccentMode.custom,
      customAccentColor: Color(0xFFAABBCC),
      motionLevel: MotionLevel.reduced,
    );

    await repository.save(settings);
    final loaded = await repository.load();

    expect(loaded.densityMode, DensityMode.compact);
    expect(loaded.backdropMode, BackdropMode.acrylic);
    expect(loaded.accentMode, AccentMode.custom);
    expect(loaded.customAccentColor, const Color(0xFFAABBCC));
    expect(loaded.motionLevel, MotionLevel.reduced);
  });

  test('save() twice keeps a single row (upsert, not insert)', () async {
    final repository = SettingsRepository(database);

    await repository.save(
      const AppearanceSettings(densityMode: DensityMode.spacious),
    );
    await repository.save(
      const AppearanceSettings(densityMode: DensityMode.compact),
    );

    final rows = await database.select(database.appSettings).get();
    expect(rows, hasLength(1));
    expect(rows.single.densityMode, 'compact');
  });
}
