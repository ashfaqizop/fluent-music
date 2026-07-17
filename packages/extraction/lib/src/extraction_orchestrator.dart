import 'package:core/core.dart';
import 'package:extraction/src/extraction_layer.dart';
import 'package:extraction/src/extraction_result.dart';
import 'package:remote_config/remote_config.dart';

/// Runs the extraction fallback chain (Masterdoc §6.3): tries each
/// [layers] entry in order, returning the first [AttemptSuccess], or an
/// [ExtractionFailure] carrying every layer name that was actually invoked
/// (whether it succeeded, self-skipped, or failed) once all are exhausted.
final class ExtractionOrchestrator {
  /// Creates an orchestrator running [layers] in order.
  const ExtractionOrchestrator({required this.layers});

  /// The fallback chain, in the order layers are attempted.
  final List<ExtractionLayer> layers;

  /// Resolves a playable audio stream for [videoId] using [config] to drive
  /// identity ordering, stagger, timeouts, and per-layer enablement.
  Future<ExtractionResult> resolve({
    required String videoId,
    required RemoteConfig config,
  }) async {
    final tried = <String>[];
    AppFailure? lastFailure;

    for (final layer in layers) {
      tried.add(layer.name);
      final attempt = await layer.tryResolve(videoId: videoId, config: config);

      switch (attempt) {
        case AttemptSuccess(:final streamUrl):
          return ExtractionSuccess(streamUrl: streamUrl, layerUsed: layer.name);
        case AttemptSkipped():
          continue;
        case AttemptFailed(:final failure):
          lastFailure = failure;
      }
    }

    return ExtractionFailure(
      failure:
          lastFailure ??
          const UnknownFailure('no extraction layer produced a result'),
      layersTried: tried,
    );
  }
}
