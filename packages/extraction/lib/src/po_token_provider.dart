/// Pluggable slot for a Proof-of-Origin (PO) token provider (Masterdoc §6.4).
///
/// Architected from day one per spec even though V1 ships no default
/// implementation (off/no-op) — a user may point at their own local
/// bgutil/YTubic-style provider via settings. Experimental; never blocks
/// core playback.
///
// A single-method interface is intentional here: it's a pluggable
// implementation slot users swap out, not a namespace for related
// operations.
// ignore: one_member_abstracts
abstract interface class PoTokenProvider {
  /// Fetches a PO token for [videoId], or `null` if none is available.
  Future<String?> fetchToken({required String videoId});
}
