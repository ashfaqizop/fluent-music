import 'package:app/design_system/settings/appearance_settings.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart' show BuildContext, MediaQuery;

/// Duration/curve constants for one motion state (Masterdoc §11.7): "lush +
/// animated," but collapsed to near-zero when motion should be reduced.
final class MotionTokens {
  const MotionTokens._({required this.reduced});

  /// Whether motion should be minimized — true if either the OS "reduce
  /// motion" signal or the user's [MotionLevel] setting requests it.
  final bool reduced;

  /// Quick micro-interactions (hover/press feedback).
  Duration get fast =>
      reduced ? Duration.zero : const Duration(milliseconds: 120);

  /// Standard transitions (page/tab switches).
  Duration get standard =>
      reduced ? Duration.zero : const Duration(milliseconds: 250);

  /// Slow, deliberate transitions (now-playing bar → full-screen expand).
  Duration get slow =>
      reduced ? Duration.zero : const Duration(milliseconds: 420);

  /// The easing curve for [standard]/[slow] transitions.
  Curve get curve => reduced ? Curves.linear : Curves.easeOutCubic;

  /// Resolves [MotionTokens] from the OS "reduce motion" signal (Windows'
  /// "Show animations in Windows" setting, surfaced via
  /// `dart:ui.PlatformDispatcher.accessibilityFeatures` /
  /// [MediaQuery.disableAnimationsOf]) combined with the user's
  /// [AppearanceSettings.motionLevel] override — either one reducing
  /// motion is enough.
  static MotionTokens resolve(
    BuildContext context,
    AppearanceSettings settings,
  ) {
    final osReduced = MediaQuery.disableAnimationsOf(context);
    final userReduced = settings.motionLevel == MotionLevel.reduced;
    return MotionTokens._(reduced: osReduced || userReduced);
  }
}
