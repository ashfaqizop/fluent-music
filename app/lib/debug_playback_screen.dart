import 'package:app/playback_coordinator.dart';
import 'package:app/providers.dart';
import 'package:audio_engine/audio_engine.dart';
import 'package:core/core.dart';
import 'package:fluent_ui/fluent_ui.dart' hide RepeatMode;
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as fsi;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innertube_client/innertube_client.dart';

/// Temporary Phase 2 debug harness: search, queue, and transport controls
/// wired directly to [audioEngineProvider]/[playbackCoordinatorProvider].
///
/// Phase 3 (Masterdoc §20, P3) builds the real app shell and replaces this
/// screen entirely — it exists only so a human can exercise "full queue
/// playback... SMTC overlay + media keys... resume across restart" at the
/// Phase 2 gate, since no real UI exists yet.
class DebugPlaybackScreen extends ConsumerStatefulWidget {
  /// Creates the debug playback screen.
  const DebugPlaybackScreen({super.key});

  @override
  ConsumerState<DebugPlaybackScreen> createState() =>
      _DebugPlaybackScreenState();
}

class _DebugPlaybackScreenState extends ConsumerState<DebugPlaybackScreen> {
  final _searchController = TextEditingController();
  final _log = AppLogger('DebugPlaybackScreen');
  List<SearchResultItem> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    final result = await ref.read(trackResolverProvider).search(query);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = result.when(
        ok: (items) => items,
        err: (error) {
          _log.warning('Search failed: $error');
          return [];
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final audioEngine = ref.watch(audioEngineProvider);
    final coordinator = ref.watch(playbackCoordinatorProvider);

    return ScaffoldPage(
      header: const PageHeader(
        title: Text('Fluent Music — Phase 2 debug harness'),
      ),
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildSearchColumn(coordinator)),
            const SizedBox(width: 16),
            Expanded(child: _buildQueueColumn(audioEngine)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchColumn(PlaybackCoordinator coordinator) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextBox(
                controller: _searchController,
                placeholder: 'Search songs...',
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            Button(
              onPressed: _searching ? null : _search,
              child: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_searching) const ProgressRing(),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final item = _results[index];
              return ListTile(
                title: Text(item.title),
                subtitle: Text(item.artist),
                trailing: const Icon(FluentIcons.add),
                onPressed: () => coordinator.enqueue(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQueueColumn(AudioEngine audioEngine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TransportBar(audioEngine: audioEngine),
        const SizedBox(height: 12),
        const Text('Queue', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: StreamBuilder<List<QueueTrack>>(
            stream: audioEngine.queueStream,
            initialData: audioEngine.queue,
            builder: (context, snapshot) {
              final queue = snapshot.data ?? const [];
              return ReorderableListView.builder(
                itemCount: queue.length,
                onReorder: (oldIndex, newIndex) =>
                    audioEngine.reorder(oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final track = queue[index];
                  final isCurrent = identical(track, audioEngine.currentTrack);
                  return ListTile(
                    key: ValueKey(track),
                    title: Text(
                      track.title,
                      style: isCurrent
                          ? const TextStyle(fontWeight: FontWeight.bold)
                          : null,
                    ),
                    subtitle: Text(track.artist),
                    trailing: IconButton(
                      icon: const Icon(FluentIcons.chrome_close),
                      onPressed: () => audioEngine.removeAt(index),
                    ),
                    onPressed: () => audioEngine.jumpTo(index),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TransportBar extends StatelessWidget {
  const _TransportBar({required this.audioEngine});

  final AudioEngine audioEngine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QueueTrack?>(
          stream: audioEngine.currentTrackStream,
          initialData: audioEngine.currentTrack,
          builder: (context, snapshot) {
            final track = snapshot.data;
            return Text(
              track == null
                  ? 'Nothing playing'
                  : '${track.title} — ${track.artist}',
              style: FluentTheme.of(context).typography.subtitle,
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(FluentIcons.previous),
              onPressed: audioEngine.previous,
            ),
            StreamBuilder<PlaybackState>(
              stream: audioEngine.stateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data == PlaybackState.playing;
                return IconButton(
                  icon: Icon(playing ? FluentIcons.pause : FluentIcons.play),
                  onPressed: playing ? audioEngine.pause : audioEngine.play,
                );
              },
            ),
            IconButton(
              icon: const Icon(FluentIcons.next),
              onPressed: audioEngine.next,
            ),
            const SizedBox(width: 16),
            ToggleButton(
              checked: audioEngine.shuffleEnabled,
              onChanged: audioEngine.setShuffle,
              child: const Icon(fsi.FluentIcons.arrow_shuffle_20_regular),
            ),
            const SizedBox(width: 8),
            _RepeatModeButton(audioEngine: audioEngine),
          ],
        ),
        StreamBuilder<Duration>(
          stream: audioEngine.positionStream,
          initialData: Duration.zero,
          builder: (context, positionSnapshot) {
            return StreamBuilder<Duration>(
              stream: audioEngine.durationStream,
              initialData: Duration.zero,
              builder: (context, durationSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;
                final duration = durationSnapshot.data ?? Duration.zero;
                final max = duration.inMilliseconds > 0
                    ? duration.inMilliseconds.toDouble()
                    : 1.0;
                return Slider(
                  value: position.inMilliseconds
                      .clamp(0, max.toInt())
                      .toDouble(),
                  max: max,
                  onChanged: (value) =>
                      audioEngine.seek(Duration(milliseconds: value.toInt())),
                );
              },
            );
          },
        ),
        Row(
          children: [
            const Icon(FluentIcons.volume3),
            Expanded(
              child: Slider(
                value: audioEngine.volume,
                onChanged: audioEngine.setVolume,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RepeatModeButton extends StatelessWidget {
  const _RepeatModeButton({required this.audioEngine});

  final AudioEngine audioEngine;

  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: () {
        final next = switch (audioEngine.repeatMode) {
          RepeatMode.off => RepeatMode.all,
          RepeatMode.all => RepeatMode.one,
          RepeatMode.one => RepeatMode.off,
        };
        audioEngine.setRepeatMode(next);
      },
      child: Text('Repeat: ${audioEngine.repeatMode.name}'),
    );
  }
}
