import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(960, 600),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: FluentMusicApp()));
}

/// The Fluent Music application root widget.
class FluentMusicApp extends StatelessWidget {
  /// Creates the application root widget.
  const FluentMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'Fluent Music',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.blue,
      ),
      home: const _EmptyShell(),
    );
  }
}

/// Placeholder window content for Phase 0 — the real app shell (custom
/// title bar, hybrid navigation, dynamic color, now-playing bar) is built
/// in Phase 3 (Masterdoc §20, P3).
class _EmptyShell extends StatelessWidget {
  const _EmptyShell();

  @override
  Widget build(BuildContext context) {
    return const ScaffoldPage(
      content: Center(child: Text('Fluent Music — Phase 0 scaffold')),
    );
  }
}
