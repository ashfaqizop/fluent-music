import 'dart:async';

import 'package:app/services/track_resolver.dart';
import 'package:audio_engine/audio_engine.dart';
import 'package:database/database.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:innertube_client/innertube_client.dart';
import 'package:media_integration/media_integration.dart';

/// Wires [AudioEngine] and [MediaTransportController] together and persists
/// queue/position/shuffle/repeat/volume so playback resumes across restarts
/// (Masterdoc §7, §12).
final class PlaybackCoordinator {
  /// Creates a coordinator. Call [restore] once after construction to load
  /// any persisted queue, and [dispose] on app shutdown.
  PlaybackCoordinator({
    required this.audioEngine,
    required this.transportController,
    required this.database,
    required this.trackResolver,
    required this.playbackCache,
  }) {
    _commandsSub = transportController.commands.listen(_onCommand);
    _currentTrackSub = audioEngine.currentTrackStream.listen(
      (_) => unawaited(_pushNowPlaying()),
    );
    _stateSub = audioEngine.stateStream.listen((state) {
      unawaited(
        transportController.updatePlaybackStatus(
          isPlaying: state == PlaybackState.playing,
        ),
      );
    });
    _positionSub = audioEngine.positionStream.listen((position) {
      _lastPosition = position;
      unawaited(
        transportController.updatePlaybackPosition(position, _lastDuration),
      );
      _persistSoon();
    });
    _durationSub = audioEngine.durationStream.listen((d) => _lastDuration = d);
    _queueSub = audioEngine.queueStream.listen((_) => _persistSoon());
  }

  /// The audio engine driving playback.
  final AudioEngine audioEngine;

  /// The SMTC transport controller.
  final MediaTransportController transportController;

  /// The app database, for queue/session persistence.
  final AppDatabase database;

  /// Search + stream resolution.
  final TrackResolver trackResolver;

  /// Disk cache wrapping resolved stream URLs.
  final PlaybackCache playbackCache;

  late final StreamSubscription<MediaTransportCommand> _commandsSub;
  late final StreamSubscription<QueueTrack?> _currentTrackSub;
  late final StreamSubscription<PlaybackState> _stateSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<List<QueueTrack>> _queueSub;

  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  Timer? _persistDebounce;

  /// Enqueues [item]: starts playing it immediately if the queue is empty,
  /// otherwise appends it to the end.
  Future<void> enqueue(SearchResultItem item) {
    final track = _toQueueTrack(item);
    return audioEngine.currentTrack == null
        ? audioEngine.loadQueue([track])
        : audioEngine.addToQueue(track);
  }

  /// Loads the last-persisted queue/position/shuffle/repeat/volume, if any.
  /// Restores paused — the user presses play, rather than being surprised
  /// by sudden audio on launch.
  Future<void> restore() async {
    final rows = await (database.select(
      database.queueItems,
    )..orderBy([(t) => OrderingTerm(expression: t.position)])).get();
    if (rows.isEmpty) return;

    final tracks = rows.map(_toQueueTrackFromRow).toList();
    final session = await (database.select(
      database.playbackSession,
    )..where((t) => t.id.equals(0))).getSingleOrNull();

    final startIndex = (session?.currentQueuePosition ?? 0).clamp(
      0,
      tracks.length - 1,
    );
    await audioEngine.loadQueue(tracks, startIndex: startIndex, play: false);
    if (session == null) return;

    await audioEngine.seek(Duration(milliseconds: session.positionMs));
    await audioEngine.setShuffle(session.shuffleEnabled);
    await audioEngine.setRepeatMode(
      RepeatMode.values.byName(session.repeatMode),
    );
    await audioEngine.setVolume(session.volume);
  }

  /// Cancels all subscriptions and flushes pending persistence.
  Future<void> dispose() async {
    _persistDebounce?.cancel();
    await _persistNow();
    await _commandsSub.cancel();
    await _currentTrackSub.cancel();
    await _stateSub.cancel();
    await _positionSub.cancel();
    await _durationSub.cancel();
    await _queueSub.cancel();
  }

  QueueTrack _toQueueTrack(SearchResultItem item) => QueueTrack(
    id: item.videoId,
    title: item.title,
    artist: item.artist,
    album: item.album,
    resolveStreamUri: playbackCache.wrap(
      item.videoId,
      () => trackResolver.resolveStream(item.videoId),
    ),
  );

  QueueTrack _toQueueTrackFromRow(QueueItemRow row) => QueueTrack(
    id: row.trackId,
    title: row.title,
    artist: row.artist,
    album: row.album,
    artworkUri: row.artworkUri == null ? null : Uri.parse(row.artworkUri!),
    duration: row.durationMs == null
        ? null
        : Duration(milliseconds: row.durationMs!),
    resolveStreamUri: playbackCache.wrap(
      row.trackId,
      () => trackResolver.resolveStream(row.trackId),
    ),
  );

  Future<void> _onCommand(MediaTransportCommand command) async {
    switch (command) {
      case MediaTransportCommand.play:
        await audioEngine.play();
      case MediaTransportCommand.pause:
        await audioEngine.pause();
      case MediaTransportCommand.next:
        await audioEngine.next();
      case MediaTransportCommand.previous:
        await audioEngine.previous();
      case MediaTransportCommand.seek:
      // Never emitted by SmtcMediaTransportController in this
      // smtc_windows version — see docs/deviations.md.
    }
  }

  Future<void> _pushNowPlaying() async {
    final track = audioEngine.currentTrack;
    if (track == null) return;
    await transportController.updateNowPlaying(
      NowPlayingInfo(
        title: track.title,
        artist: track.artist,
        artworkUri: track.artworkUri,
      ),
    );
  }

  void _persistSoon() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(seconds: 3), () {
      unawaited(_persistNow());
    });
  }

  Future<void> _persistNow() async {
    final queue = audioEngine.queue;
    final current = audioEngine.currentTrack;
    var currentIndex = -1;
    for (var i = 0; i < queue.length; i++) {
      if (identical(queue[i], current)) {
        currentIndex = i;
        break;
      }
    }

    await database.transaction(() async {
      await database.delete(database.queueItems).go();
      if (queue.isNotEmpty) {
        await database.batch((batch) {
          batch.insertAll(database.queueItems, [
            for (var i = 0; i < queue.length; i++)
              QueueItemsCompanion.insert(
                position: i,
                trackId: queue[i].id,
                title: queue[i].title,
                artist: queue[i].artist,
                album: Value(queue[i].album),
                artworkUri: Value(queue[i].artworkUri?.toString()),
                durationMs: Value(queue[i].duration?.inMilliseconds),
              ),
          ]);
        });
      }
      await database
          .into(database.playbackSession)
          .insertOnConflictUpdate(
            PlaybackSessionCompanion.insert(
              currentQueuePosition: Value(
                currentIndex == -1 ? null : currentIndex,
              ),
              positionMs: Value(_lastPosition.inMilliseconds),
              shuffleEnabled: Value(audioEngine.shuffleEnabled),
              repeatMode: Value(audioEngine.repeatMode.name),
              volume: Value(audioEngine.volume),
            ),
          );
    });
  }
}
