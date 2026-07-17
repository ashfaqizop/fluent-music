import 'dart:async';
import 'dart:collection';

/// Caps how many requests may be in flight to a given host at once
/// (Masterdoc §6.9 — "per-host concurrency caps").
///
/// One gate instance tracks independent limits per host: work queued for
/// `music.youtube.com` never blocks work for a different host.
final class HostConcurrencyGate {
  /// Creates a gate allowing at most [maxConcurrentPerHost] concurrent
  /// in-flight tasks per host.
  HostConcurrencyGate({required this.maxConcurrentPerHost});

  /// The maximum number of concurrent tasks permitted per host.
  final int maxConcurrentPerHost;

  final _activeByHost = <String, int>{};
  final _waitersByHost = <String, Queue<Completer<void>>>{};

  /// Runs [task] for [host], waiting for a free slot first if the host is
  /// already at [maxConcurrentPerHost] concurrent tasks.
  Future<T> run<T>(String host, Future<T> Function() task) async {
    await _acquire(host);
    try {
      return await task();
    } finally {
      _release(host);
    }
  }

  Future<void> _acquire(String host) {
    final active = _activeByHost[host] ?? 0;
    if (active < maxConcurrentPerHost) {
      _activeByHost[host] = active + 1;
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _waitersByHost.putIfAbsent(host, Queue<Completer<void>>.new).add(completer);
    return completer.future;
  }

  void _release(String host) {
    final waiters = _waitersByHost[host];
    if (waiters != null && waiters.isNotEmpty) {
      final next = waiters.removeFirst();
      next.complete();
      return;
    }
    final active = _activeByHost[host] ?? 1;
    _activeByHost[host] = active - 1;
  }
}
