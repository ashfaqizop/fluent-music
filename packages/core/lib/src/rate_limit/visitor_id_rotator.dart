import 'dart:convert';
import 'dart:math';

/// Generates and periodically rotates an InnerTube `visitorData`-style
/// identifier (Masterdoc §6.9 — "rotating visitor IDs").
///
/// Rotation is keyed off request count rather than wall-clock time so that
/// behavior is deterministic in tests (no fake clock needed) and predictable
/// under bursty traffic.
final class VisitorIdRotator {
  /// Creates a rotator that generates a fresh id every [rotateEveryRequests]
  /// requests (must be >= 1).
  VisitorIdRotator({this.rotateEveryRequests = 50, Random? random})
    : assert(rotateEveryRequests >= 1, 'rotateEveryRequests must be >= 1'),
      _random = random ?? Random.secure(),
      _current = _generate(random ?? Random.secure());

  /// How many requests may be sent under one visitor id before it rotates.
  final int rotateEveryRequests;

  final Random _random;
  String _current;
  int _requestsSinceRotation = 0;

  /// The visitor id currently in use.
  String current() => _current;

  /// Records that a request was just sent under the [current] id, rotating
  /// to a new id once [rotateEveryRequests] has been reached.
  void noteRequestSent() {
    _requestsSinceRotation++;
    if (_requestsSinceRotation >= rotateEveryRequests) {
      rotateNow();
    }
  }

  /// Forces an immediate rotation to a new visitor id.
  void rotateNow() {
    _current = _generate(_random);
    _requestsSinceRotation = 0;
  }

  static String _generate(Random random) {
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
