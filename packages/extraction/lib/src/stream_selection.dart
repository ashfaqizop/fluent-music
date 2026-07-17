import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Picks the best audio-only stream from [candidates] (Masterdoc §6.6):
/// Opus is preferred (native to media_kit/libmpv, no transcode needed),
/// falling back to AAC; ties within the same codec family are broken by
/// highest bitrate. Returns `null` if [candidates] is empty — the caller
/// then decides whether to fall back to a muxed stream's audio track.
AudioOnlyStreamInfo? pickBestAudio(Iterable<AudioOnlyStreamInfo> candidates) {
  final list = candidates.toList();
  if (list.isEmpty) return null;

  final opus = list.where(_isOpus).toList();
  final pool = opus.isNotEmpty ? opus : list;

  return pool.reduce(
    (best, candidate) =>
        candidate.bitrate.bitsPerSecond > best.bitrate.bitsPerSecond
        ? candidate
        : best,
  );
}

bool _isOpus(AudioOnlyStreamInfo stream) =>
    stream.audioCodec.toLowerCase().contains('opus');
