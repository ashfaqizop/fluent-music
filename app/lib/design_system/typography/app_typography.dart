import 'package:fluent_ui/fluent_ui.dart';

/// The brand typeface (Masterdoc §11.8), bundled under
/// `assets/fonts/PlusJakartaSans/` (OFL-1.1 licensed — see the bundled
/// `OFL.txt`) and declared in `app/pubspec.yaml`'s `fonts:` block.
const String appFontFamily = 'Plus Jakarta Sans';

/// Builds a [Typography] using [appFontFamily] across every fluent_ui text
/// style, layered onto fluent_ui's own dark-mode sizing/weights so line
/// heights and hierarchy stay consistent with the rest of the Fluent
/// design language.
Typography buildAppTypography() {
  final base = Typography.fromBrightness(brightness: Brightness.dark);
  return base.apply(fontFamily: appFontFamily);
}
