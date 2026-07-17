import 'package:extraction/src/extraction_layer.dart';
import 'package:extraction/src/po_token_provider.dart';
import 'package:remote_config/remote_config.dart';

/// Layer 3 (Masterdoc §6.3 step 3, §6.4): the PO-token-assisted resolution
/// slot.
///
/// Phase 1 scope is explicitly "PO-token *interface* [off]" — this layer is
/// wired into the fallback chain end-to-end (so the interface slot is
/// proven to work), but always self-skips rather than attempting real
/// token-assisted resolution. A real implementation plugging in a
/// [PoTokenProvider] is future work; `config.poTokenEnabled` is accepted
/// here only so the layer's signature already matches what that future
/// implementation will read.
final class PoTokenLayer implements ExtractionLayer {
  /// Creates a layer wrapping [provider] (currently unused — see class doc).
  const PoTokenLayer(this.provider);

  /// The pluggable PO-token provider slot (§6.4).
  final PoTokenProvider provider;

  @override
  String get name => 'po_token';

  @override
  Future<ExtractionAttempt> tryResolve({
    required String videoId,
    required RemoteConfig config,
  }) async {
    return const AttemptSkipped(
      'PO-token layer is interface-only in Phase 1 — no implementation yet',
    );
  }
}
