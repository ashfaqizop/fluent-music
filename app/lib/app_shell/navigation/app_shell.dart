import 'package:app/app_shell/now_playing/now_playing_bar.dart';
import 'package:app/app_shell/settings/settings_screen.dart';
import 'package:app/app_shell/window/custom_title_bar.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as fsi;

/// The app's root shell (Masterdoc §11.3): a hybrid Fluent
/// [NavigationView] (Home / Explore / Library / Settings) with a persistent
/// now-playing bar docked below it, spanning the full window width like a
/// Spotify-style player bar.
///
/// Home/Explore/Library are placeholder "coming soon" screens in this
/// phase — real content surfaces are Phase 4 scope (§20 P4). Only the
/// shell, chrome, and now-playing surfaces are real here.
class AppShell extends StatefulWidget {
  /// Creates the app shell.
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: NavigationView(
            titleBar: const CustomTitleBar(),
            pane: NavigationPane(
              selected: _selectedIndex,
              onChanged: (index) => setState(() => _selectedIndex = index),
              items: [
                PaneItem(
                  icon: const Icon(fsi.FluentIcons.home_20_regular),
                  title: const Text('Home'),
                  body: const _ComingSoonScreen(
                    title: 'Home',
                    description:
                        'Your personalized mixes and picks arrive in '
                        'Phase 4 (§20 P4).',
                  ),
                ),
                PaneItem(
                  icon: const Icon(
                    fsi.FluentIcons.compass_northwest_20_regular,
                  ),
                  title: const Text('Explore'),
                  body: const _ComingSoonScreen(
                    title: 'Explore',
                    description:
                        'Charts, moods, and new releases arrive in Phase 4 '
                        '(§20 P4).',
                  ),
                ),
                PaneItem(
                  icon: const Icon(fsi.FluentIcons.library_20_regular),
                  title: const Text('Library'),
                  body: const _ComingSoonScreen(
                    title: 'Library',
                    description:
                        'Liked songs, playlists, and history arrive in '
                        'Phase 5 (§20 P5).',
                  ),
                ),
              ],
              footerItems: [
                PaneItem(
                  icon: const Icon(fsi.FluentIcons.settings_20_regular),
                  title: const Text('Settings'),
                  body: const SettingsScreen(),
                ),
              ],
            ),
          ),
        ),
        const NowPlayingBar(),
      ],
    );
  }
}

class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ScaffoldPage(
      header: PageHeader(title: Text(title)),
      content: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                fsi.FluentIcons.sparkle_20_regular,
                size: 40,
                color: theme.resources.textFillColorSecondary,
              ),
              const SizedBox(height: 16),
              Text(description, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
