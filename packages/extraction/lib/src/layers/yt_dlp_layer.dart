import 'package:extraction/src/extraction_layer.dart';
import 'package:remote_config/remote_config.dart';

/// Layer 4 (Masterdoc §6.3 step 4, §6.7): the yt-dlp.exe last-resort
/// fallback.
///
/// Phase 1 scope is explicitly "yt-dlp adapter *stub* [off]" — this layer
/// is wired into the fallback chain, but never actually invokes a process;
/// it always self-skips. A real implementation (spawning `yt-dlp.exe`,
/// parsing its JSON output) is future, opt-in work.
final class YtDlpLayer implements ExtractionLayer {
  /// Creates a layer. [enabled] is accepted now so the constructor already
  /// matches the shape a real implementation will need, but it has no
  /// effect yet — this layer always skips in Phase 1.
  const YtDlpLayer({this.enabled = false});

  /// Whether the yt-dlp fallback is enabled (currently has no effect).
  final bool enabled;

  @override
  String get name => 'yt_dlp';

  @override
  Future<ExtractionAttempt> tryResolve({
    required String videoId,
    required RemoteConfig config,
  }) async {
    return const AttemptSkipped(
      'yt-dlp adapter is opt-in and off by default (stub, Phase 1 scope)',
    );
  }
}
