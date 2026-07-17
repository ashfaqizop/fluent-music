import 'package:core/core.dart';

/// Outcome of attempting to resolve a playable audio stream for a track
/// (Masterdoc §6.3). Carries which layers were tried so failures can feed
/// the diagnostics surface (§6.8, §15.5).
///
/// This is the shared typed-result shape; the real parallel-race fallback
/// chain that produces it lands in Phase 1 (§20, P1).
sealed class ExtractionResult {
  const ExtractionResult();
}

/// A resolved, playable audio stream.
final class ExtractionSuccess extends ExtractionResult {
  /// Creates a success carrying the resolved [streamUrl] and which
  /// [layerUsed] (client identity/fallback layer) produced it.
  const ExtractionSuccess({required this.streamUrl, required this.layerUsed});

  /// The resolved, directly playable audio stream URL.
  final Uri streamUrl;

  /// Which fallback-chain layer (§6.3) produced [streamUrl].
  final String layerUsed;
}

/// No layer in the fallback chain could resolve a playable stream.
final class ExtractionFailure extends ExtractionResult {
  /// Creates a failure carrying the terminal [failure] and every
  /// [layersTried] before giving up.
  const ExtractionFailure({required this.failure, required this.layersTried});

  /// The terminal failure, feeding fail-loud UX and diagnostics (§6.8).
  final AppFailure failure;

  /// Every fallback-chain layer attempted before failing.
  final List<String> layersTried;
}
