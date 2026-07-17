import 'dart:async';

import 'package:app/providers.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as fsi;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innertube_client/innertube_client.dart';
import 'package:window_manager/window_manager.dart';

/// The custom owner-drawn title bar (Masterdoc §11.2): app wordmark,
/// integrated search (§11.3's "persistent access to search"), and
/// Spotify-like window buttons — replacing the OS chrome entirely since
/// `main.dart` opens the window with `TitleBarStyle.hidden`.
class CustomTitleBar extends StatelessWidget {
  /// Creates the custom title bar.
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return TitleBar(
      height: 44,
      icon: Image.asset('assets/branding/only-icon-logo.png', height: 20),
      title: const Text('Fluent Music'),
      isBackButtonVisible: false,
      content: const Center(
        child: SizedBox(width: 420, child: _TitleBarSearchBox()),
      ),
      captionControls: const _WindowCaptionControls(),
      onDragStarted: () => unawaited(windowManager.startDragging()),
      onDoubleTap: () => unawaited(_toggleMaximize()),
    );
  }

  static Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }
}

class _TitleBarSearchBox extends ConsumerStatefulWidget {
  const _TitleBarSearchBox();

  @override
  ConsumerState<_TitleBarSearchBox> createState() => _TitleBarSearchBoxState();
}

class _TitleBarSearchBoxState extends ConsumerState<_TitleBarSearchBox> {
  Timer? _debounce;
  List<AutoSuggestBoxItem<SearchResultItem>> _items = [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String text, TextChangedReason reason) {
    if (reason != TextChangedReason.userInput) return;
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _items = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  Future<void> _search(String query) async {
    final result = await ref.read(trackResolverProvider).search(query);
    if (!mounted) return;
    setState(() {
      _items = result.when(
        ok: (results) => [
          for (final item in results)
            AutoSuggestBoxItem<SearchResultItem>(
              value: item,
              label: '${item.title} — ${item.artist}',
            ),
        ],
        err: (_) => [],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.read(playbackCoordinatorProvider);
    return AutoSuggestBox<SearchResultItem>(
      items: _items,
      placeholder: 'Search songs, artists, albums',
      leadingIcon: const Icon(fsi.FluentIcons.search_20_regular, size: 16),
      onChanged: _onChanged,
      onSelected: (item) {
        final track = item.value;
        if (track != null) unawaited(coordinator.enqueue(track));
      },
    );
  }
}

class _WindowCaptionControls extends StatefulWidget {
  const _WindowCaptionControls();

  @override
  State<_WindowCaptionControls> createState() => _WindowCaptionControlsState();
}

class _WindowCaptionControlsState extends State<_WindowCaptionControls>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_syncMaximized());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (!mounted) return;
    setState(() => _maximized = maximized);
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CaptionButton(
          icon: fsi.FluentIcons.subtract_20_regular,
          onPressed: windowManager.minimize,
        ),
        _CaptionButton(
          icon: _maximized
              ? fsi.FluentIcons.square_multiple_20_regular
              : fsi.FluentIcons.square_20_regular,
          onPressed: () => _maximized
              ? windowManager.unmaximize()
              : windowManager.maximize(),
        ),
        _CaptionButton(
          icon: fsi.FluentIcons.dismiss_20_regular,
          hoverColor: Colors.red,
          onPressed: windowManager.close,
        ),
      ],
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.onPressed,
    this.hoverColor,
  });

  final IconData icon;
  final Future<void> Function() onPressed;
  final Color? hoverColor;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () => unawaited(widget.onPressed()),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 44,
          color: _hovering
              ? (widget.hoverColor ?? theme.resources.subtleFillColorSecondary)
              : Colors.transparent,
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 16),
        ),
      ),
    );
  }
}
