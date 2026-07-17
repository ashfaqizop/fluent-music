import 'package:app/app_shell/now_playing/now_playing_bar.dart';
import 'package:app/design_system/color/dynamic_color_engine.dart';
import 'package:app/design_system/settings/appearance_settings.dart';
import 'package:app/design_system/settings/appearance_settings_controller.dart';
import 'package:app/providers.dart';
import 'package:audio_engine/audio_engine.dart' hide RepeatMode;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as fsi;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _dynamicColorEngine = DynamicColorEngine();

/// The full-screen now-playing scaffold (Masterdoc §11.4): Apple-Music
/// style — big art (Hero-continued from [NowPlayingBar]), a dynamic-color
/// background tinted from the artwork (§11.5), transport controls, and
/// queue/lyrics affordances (stubbed here; real content lands P5/P8).
class NowPlayingFull extends ConsumerStatefulWidget {
  /// Creates the full-screen now-playing scaffold.
  const NowPlayingFull({super.key});

  /// Builds the [PageRoute] used to push this screen, with a motion-aware
  /// transition (§11.7) — collapses to an instant cut when reduced motion
  /// is requested.
  static Route<void> route() {
    return PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const NowPlayingFull(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final settings = ProviderScope.containerOf(
          context,
        ).read(appearanceSettingsProvider);
        if (MediaQuery.disableAnimationsOf(context) ||
            settings.motionLevel == MotionLevel.reduced) {
          return child;
        }
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  @override
  ConsumerState<NowPlayingFull> createState() => _NowPlayingFullState();
}

class _NowPlayingFullState extends ConsumerState<NowPlayingFull> {
  Color _background = const Color(0xFF14141F);

  @override
  Widget build(BuildContext context) {
    final audioEngine = ref.watch(audioEngineProvider);

    return StreamBuilder<QueueTrack?>(
      stream: audioEngine.currentTrackStream,
      initialData: audioEngine.currentTrack,
      builder: (context, snapshot) {
        final track = snapshot.data;
        if (track != null) _refreshBackground(track);

        return ScaffoldPage(
          padding: EdgeInsets.zero,
          content: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_background, const Color(0xFF0B0B10)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _CollapseBar(onCollapse: () => Navigator.of(context).pop()),
                  Expanded(
                    child: track == null
                        ? const Center(child: Text('Nothing playing'))
                        : _NowPlayingContent(
                            track: track,
                            audioEngine: audioEngine,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshBackground(QueueTrack track) async {
    final tint = await _dynamicColorEngine.tintFor(
      track.artworkUri,
      fallback: const Color(0xFF14141F),
    );
    if (mounted && tint != _background) setState(() => _background = tint);
  }
}

class _CollapseBar extends StatelessWidget {
  const _CollapseBar({required this.onCollapse});

  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(fsi.FluentIcons.chevron_down_20_regular),
            onPressed: onCollapse,
          ),
          const Spacer(),
          const Text('Now Playing'),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _NowPlayingContent extends StatelessWidget {
  const _NowPlayingContent({required this.track, required this.audioEngine});

  final QueueTrack track;
  final AudioEngine audioEngine;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final art = track.artworkUri;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: nowPlayingArtHeroTag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: art == null
                    ? Container(
                        width: 320,
                        height: 320,
                        color: theme.resources.subtleFillColorSecondary,
                        child: const Icon(
                          fsi.FluentIcons.music_note_2_20_regular,
                          size: 64,
                        ),
                      )
                    : Image.network(
                        art.toString(),
                        width: 320,
                        height: 320,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Text(track.title, style: theme.typography.titleLarge),
            const SizedBox(height: 4),
            Text(track.artist, style: theme.typography.subtitle),
            const SizedBox(height: 32),
            _FullSeekBar(audioEngine: audioEngine),
            const SizedBox(height: 16),
            _FullTransportControls(audioEngine: audioEngine),
            const SizedBox(height: 24),
            const Text(
              'Synced lyrics arrive in a later phase (§10, §20 P8).',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FullSeekBar extends StatelessWidget {
  const _FullSeekBar({required this.audioEngine});

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
            final max = duration.inMilliseconds > 0
                ? duration.inMilliseconds.toDouble()
                : 1.0;
            return Column(
              children: [
                Slider(
                  value: position.inMilliseconds
                      .clamp(0, max.toInt())
                      .toDouble(),
                  max: max,
                  onChanged: (value) =>
                      audioEngine.seek(Duration(milliseconds: value.toInt())),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(_format(position)), Text(_format(duration))],
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _FullTransportControls extends StatelessWidget {
  const _FullTransportControls({required this.audioEngine});

  final AudioEngine audioEngine;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(fsi.FluentIcons.arrow_shuffle_20_regular),
          onPressed: () => audioEngine.setShuffle(!audioEngine.shuffleEnabled),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(fsi.FluentIcons.previous_20_filled, size: 24),
          onPressed: audioEngine.previous,
        ),
        const SizedBox(width: 12),
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
                size: 32,
              ),
              onPressed: playing ? audioEngine.pause : audioEngine.play,
            );
          },
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(fsi.FluentIcons.next_20_filled, size: 24),
          onPressed: audioEngine.next,
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(fsi.FluentIcons.list_20_regular),
          onPressed: () {},
        ),
      ],
    );
  }
}
