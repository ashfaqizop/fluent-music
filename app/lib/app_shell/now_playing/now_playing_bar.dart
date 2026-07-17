import 'package:app/app_shell/now_playing/now_playing_full.dart';
import 'package:app/design_system/density/density_tokens.dart';
import 'package:app/design_system/motion/motion_tokens.dart';
import 'package:app/design_system/settings/appearance_settings_controller.dart';
import 'package:app/providers.dart';
import 'package:audio_engine/audio_engine.dart' hide RepeatMode;
import 'package:audio_engine/audio_engine.dart' as engine show RepeatMode;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as fsi;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hero tag shared with [NowPlayingFull] for the shared-element album-art
/// transition (Masterdoc §11.7).
const nowPlayingArtHeroTag = 'now-playing-art';

/// The persistent bottom now-playing bar (Masterdoc §11.4): Spotify-style —
/// art, title/artist, transport controls, seek, and queue/lyrics/volume
/// affordances. Tapping the art or title expands into [NowPlayingFull].
class NowPlayingBar extends ConsumerWidget {
  /// Creates the now-playing bar.
  const NowPlayingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioEngine = ref.watch(audioEngineProvider);
    final motion = MotionTokens.resolve(
      context,
      ref.watch(appearanceSettingsProvider),
    );

    return StreamBuilder<QueueTrack?>(
      stream: audioEngine.currentTrackStream,
      initialData: audioEngine.currentTrack,
      builder: (context, snapshot) {
        final track = snapshot.data;
        return AnimatedContainer(
          duration: motion.standard,
          curve: motion.curve,
          height: track == null ? 0 : 92,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(),
          child: track == null
              ? const SizedBox.shrink()
              : RepaintBoundary(
                  child: _NowPlayingBarContent(
                    track: track,
                    audioEngine: audioEngine,
                  ),
                ),
        );
      },
    );
  }
}

class _NowPlayingBarContent extends ConsumerWidget {
  const _NowPlayingBarContent({required this.track, required this.audioEngine});

  final QueueTrack track;
  final AudioEngine audioEngine;

  void _expand(BuildContext context) {
    Navigator.of(context).push(NowPlayingFull.route());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final density = ref.watch(densityTokensProvider);

    return Acrylic(
      luminosityAlpha: 0.9,
      blurAmount: 20,
      tint: theme.micaBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SeekLine(audioEngine: audioEngine),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: density.pagePadding.horizontal / 2,
              ),
              child: Row(
                children: [
                  _ArtAndTitle(
                    track: track,
                    density: density,
                    onTap: () => _expand(context),
                  ),
                  const Spacer(),
                  _TransportControls(audioEngine: audioEngine),
                  const Spacer(),
                  _SecondaryControls(
                    audioEngine: audioEngine,
                    onExpand: () => _expand(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtAndTitle extends StatefulWidget {
  const _ArtAndTitle({
    required this.track,
    required this.density,
    required this.onTap,
  });

  final QueueTrack track;
  final DensityTokens density;
  final VoidCallback onTap;

  @override
  State<_ArtAndTitle> createState() => _ArtAndTitleState();
}

class _ArtAndTitleState extends State<_ArtAndTitle> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final art = widget.track.artworkUri;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovering ? 1.02 : 1,
          duration: const Duration(milliseconds: 150),
          child: SizedBox(
            width: 260,
            child: Row(
              children: [
                Hero(
                  tag: nowPlayingArtHeroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      widget.density.cardRadius / 2,
                    ),
                    child: art == null
                        ? Container(
                            width: widget.density.coverArtSize,
                            height: widget.density.coverArtSize,
                            color: theme.resources.subtleFillColorSecondary,
                            child: const Icon(
                              fsi.FluentIcons.music_note_2_20_regular,
                            ),
                          )
                        : Image.network(
                            art.toString(),
                            width: widget.density.coverArtSize,
                            height: widget.density.coverArtSize,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.bodyStrong,
                      ),
                      Text(
                        widget.track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.audioEngine});

  final AudioEngine audioEngine;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(fsi.FluentIcons.previous_20_filled),
          onPressed: audioEngine.previous,
        ),
        const SizedBox(width: 4),
        StreamBuilder<PlaybackState>(
          stream: audioEngine.stateStream,
          initialData: PlaybackState.idle,
          builder: (context, snapshot) {
            final playing = snapshot.data == PlaybackState.playing;
            return IconButton(
              icon: Icon(
                playing
                    ? fsi.FluentIcons.pause_20_filled
                    : fsi.FluentIcons.play_20_filled,
                size: 22,
              ),
              onPressed: playing ? audioEngine.pause : audioEngine.play,
            );
          },
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(fsi.FluentIcons.next_20_filled),
          onPressed: audioEngine.next,
        ),
      ],
    );
  }
}

class _SecondaryControls extends StatelessWidget {
  const _SecondaryControls({required this.audioEngine, required this.onExpand});

  final AudioEngine audioEngine;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RepeatButton(audioEngine: audioEngine),
        IconButton(
          icon: const Icon(fsi.FluentIcons.list_20_regular),
          onPressed: () => _showQueueFlyout(context, audioEngine),
        ),
        IconButton(
          icon: const Icon(fsi.FluentIcons.text_bullet_list_square_20_regular),
          onPressed: () => _showLyricsPlaceholder(context),
        ),
        _VolumeButton(audioEngine: audioEngine),
        IconButton(
          icon: const Icon(fsi.FluentIcons.chevron_up_20_regular),
          onPressed: onExpand,
        ),
      ],
    );
  }

  void _showQueueFlyout(BuildContext context, AudioEngine audioEngine) {
    showFluentPopup(
      context: context,
      builder: (context) => SizedBox(
        width: 320,
        height: 360,
        child: StreamBuilder<List<QueueTrack>>(
          stream: audioEngine.queueStream,
          initialData: audioEngine.queue,
          builder: (context, snapshot) {
            final queue = snapshot.data ?? const [];
            if (queue.isEmpty) {
              return const Center(child: Text('Queue is empty'));
            }
            return ReorderableListView.builder(
              itemCount: queue.length,
              onReorder: audioEngine.reorder,
              itemBuilder: (context, index) {
                final item = queue[index];
                final isCurrent = identical(item, audioEngine.currentTrack);
                return ListTile(
                  key: ValueKey(item),
                  title: Text(
                    item.title,
                    style: isCurrent
                        ? const TextStyle(fontWeight: FontWeight.bold)
                        : null,
                  ),
                  subtitle: Text(item.artist),
                  onPressed: () => audioEngine.jumpTo(index),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showLyricsPlaceholder(BuildContext context) {
    showFluentPopup(
      context: context,
      builder: (context) => const SizedBox(
        width: 260,
        height: 120,
        child: Center(
          child: Text('Synced lyrics arrive in a later phase (§10, §20 P8).'),
        ),
      ),
    );
  }
}

class _RepeatButton extends StatefulWidget {
  const _RepeatButton({required this.audioEngine});

  final AudioEngine audioEngine;

  @override
  State<_RepeatButton> createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<_RepeatButton> {
  @override
  Widget build(BuildContext context) {
    final mode = widget.audioEngine.repeatMode;
    return IconButton(
      icon: Icon(switch (mode) {
        engine.RepeatMode.off => fsi.FluentIcons.arrow_repeat_all_20_regular,
        engine.RepeatMode.all => fsi.FluentIcons.arrow_repeat_all_20_filled,
        engine.RepeatMode.one => fsi.FluentIcons.arrow_repeat_1_20_filled,
      }),
      onPressed: () async {
        final next = switch (mode) {
          engine.RepeatMode.off => engine.RepeatMode.all,
          engine.RepeatMode.all => engine.RepeatMode.one,
          engine.RepeatMode.one => engine.RepeatMode.off,
        };
        await widget.audioEngine.setRepeatMode(next);
        if (mounted) setState(() {});
      },
    );
  }
}

class _VolumeButton extends StatelessWidget {
  const _VolumeButton({required this.audioEngine});

  final AudioEngine audioEngine;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(fsi.FluentIcons.speaker_2_20_regular),
      onPressed: () => showFluentPopup(
        context: context,
        builder: (context) => SizedBox(
          width: 160,
          child: StreamBuilder<double>(
            stream: audioEngine.volumeStream,
            initialData: audioEngine.volume,
            builder: (context, snapshot) => Slider(
              value: snapshot.data ?? audioEngine.volume,
              onChanged: audioEngine.setVolume,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeekLine extends StatelessWidget {
  const _SeekLine({required this.audioEngine});

  final AudioEngine audioEngine;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audioEngine.positionStream,
      initialData: Duration.zero,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: audioEngine.durationStream,
          initialData: Duration.zero,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;
            final progress = duration.inMilliseconds > 0
                ? position.inMilliseconds / duration.inMilliseconds * 100
                : 0.0;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final box = context.findRenderObject()! as RenderBox;
                final ratio = (details.localPosition.dx / box.size.width).clamp(
                  0.0,
                  1.0,
                );
                if (duration.inMilliseconds > 0) {
                  audioEngine.seek(
                    Duration(
                      milliseconds: (duration.inMilliseconds * ratio).round(),
                    ),
                  );
                }
              },
              child: SizedBox(
                height: 3,
                child: ProgressBar(value: progress.clamp(0, 100)),
              ),
            );
          },
        );
      },
    );
  }
}

/// A small popup used for queue/lyrics/volume affordances, styled as a
/// Fluent flyout, anchored to the bottom-right above the now-playing bar.
void showFluentPopup({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (dialogContext) => Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 24, bottom: 110),
        child: FlyoutContent(child: Builder(builder: builder)),
      ),
    ),
  );
}
