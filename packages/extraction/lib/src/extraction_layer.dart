import 'package:core/core.dart';
import 'package:remote_config/remote_config.dart';

/// The outcome of one [ExtractionLayer]'s attempt to resolve a stream.
sealed class ExtractionAttempt {
  const ExtractionAttempt();
}

/// The layer resolved a playable stream URL.
final class AttemptSuccess extends ExtractionAttempt {
  /// Creates a success carrying the resolved [streamUrl].
  const AttemptSuccess(this.streamUrl);

  /// The resolved, directly playable audio stream URL.
  final Uri streamUrl;
}

/// The layer deliberately did not attempt resolution (e.g. it's disabled,
/// or has no mappable identities to try) — distinct from a failed attempt
/// so the orchestrator/diagnostics can tell "didn't try" from "tried and
/// failed."
final class AttemptSkipped extends ExtractionAttempt {
  /// Creates a skip carrying the human-readable [reason].
  const AttemptSkipped(this.reason);

  /// Why this layer was skipped.
  final String reason;
}

/// The layer attempted resolution and failed.
final class AttemptFailed extends ExtractionAttempt {
  /// Creates a failure carrying the underlying [failure].
  const AttemptFailed(this.failure);

  /// The underlying failure.
  final AppFailure failure;
}

/// One layer in the extraction fallback chain (Masterdoc §6.3).
// A single-method interface is intentional: each layer is a swappable
// resolution strategy, not a namespace for related operations.
// ignore: one_member_abstracts
abstract interface class ExtractionLayer {
  /// This layer's name, recorded in `ExtractionFailure.layersTried`.
  String get name;

  /// Attempts to resolve a playable stream for [videoId], honoring
  /// [config]'s tuning (identity order, stagger, timeouts, enabled flags).
  Future<ExtractionAttempt> tryResolve({
    required String videoId,
    required RemoteConfig config,
  });
}
