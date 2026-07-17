import 'package:drift/drift.dart';

/// Single-row table persisting the design-system-level appearance settings
/// introduced in Phase 3 (Masterdoc §11, §16): density mode, backdrop
/// choice, accent color mode, and motion level. Full Settings coverage
/// (§16's whole catalogue) accretes across later phases; this table is the
/// seed later phases append columns/tables to, not the final shape.
@DataClassName('AppSettingsRow')
class AppSettings extends Table {
  /// Always `0` — this table only ever holds one row (same rationale as
  /// `PlaybackSession.id`: a rowid-alias `INTEGER PRIMARY KEY` ignores SQL
  /// `DEFAULT` on insert, so the client default forces every upsert onto
  /// the same row instead of inserting a new one).
  IntColumn get id => integer().clientDefault(() => 0)();

  /// The density mode, stored as `DensityMode.name`
  /// (`hybrid`/`spacious`/`compact`). Default: `hybrid` (§11.6).
  TextColumn get densityMode => text().withDefault(const Constant('hybrid'))();

  /// The window backdrop choice, stored as `BackdropMode.name`
  /// (`mica`/`acrylic`/`none`). Default: `mica` (§11.2).
  TextColumn get backdropMode => text().withDefault(const Constant('mica'))();

  /// The accent color mode, stored as `AccentMode.name`
  /// (`windows`/`custom`). Default: `windows` (§11.5).
  TextColumn get accentMode => text().withDefault(const Constant('windows'))();

  /// The custom accent color, as an ARGB integer, used only when
  /// [accentMode] is `custom`.
  IntColumn get customAccentColor => integer().nullable()();

  /// The motion level, stored as `MotionLevel.name` (`full`/`reduced`).
  /// Default: `full` — Windows' own "reduce motion" signal
  /// (`MediaQuery.disableAnimationsOf`) is honored independently of this
  /// user-facing override (§11.7).
  TextColumn get motionLevel => text().withDefault(const Constant('full'))();

  @override
  Set<Column> get primaryKey => {id};
}
