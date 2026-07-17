/// Verifies the signature on a fetched remote-config payload against the
/// public key shipped in-app (Masterdoc §6.5).
///
/// Real signature verification (and the shipped public key) lands in
/// Phase 1 — this stub keeps the interface stable from Phase 0 onward.
///
// A single-method interface is intentional here: it's a swappable
// verification strategy, not a namespace for related operations.
// ignore: one_member_abstracts
abstract interface class RemoteConfigVerifier {
  /// Returns whether [signature] is a valid signature of [payload].
  bool verify({required List<int> payload, required List<int> signature});
}
