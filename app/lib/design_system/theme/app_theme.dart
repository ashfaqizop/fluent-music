import 'package:app/design_system/typography/app_typography.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Builds the app's single dark-only [FluentThemeData] (Masterdoc §11.5:
/// "Dark only. No light mode."), applying [accentColor] (resolved by the
/// caller from either the Windows system accent or a user-picked custom
/// color — see `AccentMode`) and [appFontFamily] throughout.
FluentThemeData buildAppTheme({required Color accentColor}) {
  return FluentThemeData(
    brightness: Brightness.dark,
    accentColor: accentColor.toAccentColor(),
    typography: buildAppTypography(),
    fontFamily: appFontFamily,
  );
}
