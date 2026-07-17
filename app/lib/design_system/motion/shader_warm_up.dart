import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';

/// Pre-compiles the shell's actual draw operations (rounded surfaces,
/// blur/acrylic backdrop, gradients, text) during binding startup instead
/// of mid-animation, per Masterdoc §11.7/§14's "no first-run jank."
///
/// Registered via `PaintingBinding.shaderWarmUp` in `main()`, before
/// `WidgetsFlutterBinding.ensureInitialized()` runs.
class AppShaderWarmUp extends ShaderWarmUp {
  /// Creates the app's shader warm-up routine.
  const AppShaderWarmUp();

  @override
  Size get size => const Size(300, 300);

  @override
  Future<void> warmUpOnCanvas(Canvas canvas) async {
    final bounds = Offset.zero & size;

    // Rounded surfaces (cards, buttons, now-playing bar).
    final surfacePaint = Paint()..color = const Color(0xFF1F1F1F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(12)),
      surfacePaint,
    );

    // Blur (Acrylic backdrop, art-shadow, hover glow).
    canvas
      ..saveLayer(
        bounds,
        Paint()..imageFilter = ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      )
      ..drawRect(bounds, Paint()..color = const Color(0x33FFFFFF))
      ..restore();

    // Gradient (dynamic-color-tinted now-playing background).
    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2B2B44), Color(0xFF14141F)],
      ).createShader(bounds);
    canvas.drawRect(bounds, gradientPaint);

    // Text (Plus Jakarta Sans, the typeface used across the whole shell).
    final paragraphBuilder =
        ParagraphBuilder(
            ParagraphStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16),
          )
          ..pushStyle(TextStyle(color: const Color(0xFFFFFFFF)).getTextStyle())
          ..addText('Fluent Music');
    final paragraph = paragraphBuilder.build()
      ..layout(ParagraphConstraints(width: size.width));
    canvas.drawParagraph(paragraph, Offset.zero);
  }
}
