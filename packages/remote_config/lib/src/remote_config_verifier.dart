import 'package:cryptography/cryptography.dart';
import 'package:remote_config/src/signing_public_key.dart';

/// Verifies the signature on a fetched remote-config payload against the
/// public key shipped in-app (Masterdoc §6.5).
///
/// This synchronous interface is kept for callers that have already
/// computed a verification result (e.g. tests); the real signature scheme
/// (Ed25519, asynchronous) is [AsyncRemoteConfigVerifier] /
/// [Ed25519RemoteConfigVerifier] below.
// A single-method interface is intentional here: it's a swappable
// verification strategy, not a namespace for related operations.
// ignore: one_member_abstracts
abstract interface class RemoteConfigVerifier {
  /// Returns whether [signature] is a valid signature of [payload].
  bool verify({required List<int> payload, required List<int> signature});
}

/// Verifies the signature on a fetched remote-config payload using an
/// asynchronous cryptographic backend (Masterdoc §6.5, §22).
///
/// This is the real entry point used by `RemoteConfigFetcher` — signature
/// verification with `package:cryptography` is inherently `Future`-based, so
/// rather than force the Phase-0 [RemoteConfigVerifier] stub (whose doc
/// comment never committed to being synchronous) into an awkward sync
/// shape, this is a small, explicit extension of it.
// ignore: one_member_abstracts
abstract interface class AsyncRemoteConfigVerifier {
  /// Returns whether [signature] is a valid signature of [payload].
  Future<bool> verify({
    required List<int> payload,
    required List<int> signature,
  });
}

/// The production [AsyncRemoteConfigVerifier]: Ed25519 signature
/// verification against [RemoteConfigSigningKey.publicKeyBytes] (or an
/// injected key, for tests).
final class Ed25519RemoteConfigVerifier implements AsyncRemoteConfigVerifier {
  /// Creates a verifier for [publicKeyBytes], defaulting to the real
  /// shipped public key.
  Ed25519RemoteConfigVerifier({List<int>? publicKeyBytes})
    : _publicKey = SimplePublicKey(
        publicKeyBytes ?? RemoteConfigSigningKey.publicKeyBytes,
        type: KeyPairType.ed25519,
      );

  final SimplePublicKey _publicKey;
  final _algorithm = Ed25519();

  @override
  Future<bool> verify({
    required List<int> payload,
    required List<int> signature,
  }) {
    return _algorithm.verify(
      payload,
      signature: Signature(signature, publicKey: _publicKey),
    );
  }
}
