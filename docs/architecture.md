# Architecture

> Generated at Phase 0 (§20, P0); refreshed at Phase 2 (§20, P2) and Phase 3 (§20, P3). Reflects what actually exists in the repo today; refresh every phase per §0.1.

## Pattern

Feature-first + layered, per Masterdoc §5.1. Each feature (once P4+ adds them under `app/lib/features/`) owns `presentation / domain / data`. Cross-cutting concerns live in shared packages under `packages/`. The fragile InnerTube/extraction layer is isolated behind interfaces so it can be swapped without touching UI. Riverpod provides DI/state; UI depends on domain abstractions, never on concrete network/db types.

## Monorepo layout

```
fluent-music/
├─ Masterdoc.md                  # source of truth
├─ pubspec.yaml                  # workspace root (Dart/Flutter native pub workspaces) + melos config
├─ analysis_options.yaml         # shared very_good_analysis config
├─ docs/                         # this directory
├─ scripts/
│  ├─ setup-dev.ps1              # idempotent dev-env check/provision
│  └─ make-portable.ps1          # builds + zips the portable phase-gate release
├─ packages/
│  ├─ core/                      # Result/error types, logging, constants, rate-limit primitives (pure Dart)
│  ├─ innertube_client/          # Real InnerTube search/browse client + rate-limit interceptor (pure Dart)
│  ├─ extraction/                # Parallel-race fallback chain, stream selection, PO-token/yt-dlp stubs (pure Dart)
│  ├─ audio_engine/               # AudioEngine + MediaKitPlayerEngine, QueueController, PlaybackCache (Flutter)
│  ├─ database/                  # Drift AppDatabase: queue_items + playback_session + app_settings tables (pure Dart, sqlite3 native)
│  ├─ media_integration/         # SmtcMediaTransportController (Flutter; smtc_windows/Rust)
│  └─ remote_config/              # Signed fetch/verify/apply/cache, Ed25519 signing (pure Dart)
└─ app/                          # the Flutter application
   ├─ assets/
   │  ├─ branding/               # logo assets, mirrored from repo-root assets/branding/ so Flutter can bundle them
   │  └─ fonts/PlusJakartaSans/  # bundled OFL-1.1 static weights (Regular/Medium/SemiBold/Bold) + OFL.txt
   ├─ bin/
   │  └─ smoke_playback.dart     # P2 headless smoke test: search -> resolve -> real media_kit playback
   └─ lib/
      ├─ features/               # empty; feature-first surfaces from P4 onward
      ├─ design_system/          # Phase 3: theme, typography, dynamic color, density, motion, appearance settings
      │  ├─ typography/app_typography.dart      # Plus Jakarta Sans Typography builder
      │  ├─ theme/app_theme.dart                # dark-only FluentThemeData builder (accent color in)
      │  ├─ color/dynamic_color_engine.dart      # ColorScheme.fromImageProvider-based artwork tint, cached + clamped
      │  ├─ density/density_tokens.dart          # DensityTokens (hybrid/spacious/compact) + densityTokensProvider
      │  ├─ motion/motion_tokens.dart            # MotionTokens (OS reduce-motion + user override)
      │  ├─ motion/shader_warm_up.dart           # AppShaderWarmUp, registered pre-binding-init in main()
      │  └─ settings/                            # AppearanceSettings model + Notifier + Riverpod provider
      ├─ app_shell/              # Phase 3: window chrome, navigation, now-playing, settings screen
      │  ├─ window/custom_title_bar.dart         # owner-drawn TitleBar: wordmark, AutoSuggestBox search, caption buttons
      │  ├─ window/backdrop.dart                 # flutter_acrylic Window.initialize()/setEffect() wrapper
      │  ├─ navigation/app_shell.dart             # NavigationView (Home/Explore/Library/Settings) + docked NowPlayingBar
      │  ├─ now_playing/now_playing_bar.dart      # persistent bottom bar (art/transport/seek/queue/lyrics/volume)
      │  ├─ now_playing/now_playing_full.dart     # full-screen now-playing (Hero art, dynamic-color background)
      │  └─ settings/settings_screen.dart         # Appearance settings section (seed for later §16 sections)
      ├─ services/
      │  ├─ track_resolver.dart      # TrackResolver interface (search + resolveStream)
      │  ├─ extraction_service.dart  # concrete TrackResolver: owns extraction/innertube_client/remote_config wiring
      │  └─ settings_repository.dart # Phase 3: AppearanceSettings <-> AppSettings table persistence
      ├─ providers.dart          # plain Riverpod providers, overridden with real instances in main()
      ├─ playback_coordinator.dart  # wires AudioEngine <-> MediaTransportController, persists/restores queue
      └─ main.dart                # async bootstrap (shader warm-up/media_kit/SMTC/db/extraction/acrylic/accent) + FluentApp -> AppShell
```

## Package dependency direction

`app` → feature packages (`extraction`, `audio_engine`, `database`, `media_integration`, `remote_config`, `innertube_client`) → `core`. No package below `app` depends on Flutter unless it genuinely needs the Flutter SDK (`audio_engine`, `media_integration`); `core`, `innertube_client`, `extraction`, `database`, `remote_config` are pure Dart and unit-testable without Flutter, per §5.2's requirement.

As of Phase 1, `innertube_client` and `extraction` both also depend on `remote_config` (for the `RemoteConfig` type driving identity ordering/overrides/rate-limit tuning) — this is a legitimate new edge, not a layering violation: `remote_config` sits below both, has no dependents above them, and stays pure Dart.

**Phase 2 confirms the sibling-packages-don't-depend-on-each-other rule for `audio_engine`.** `audio_engine`'s queue never touches `extraction`/`innertube_client` types — `QueueTrack` instead carries an app-supplied lazy `resolveStreamUri` closure. `app/lib/services/extraction_service.dart` is what actually owns the `ExtractionOrchestrator`/`RemoteConfig` wiring (the same recipe as `packages/extraction/bin/smoke.dart`) and binds it into that closure when constructing `QueueTrack`s. `audio_engine` and `app` depend on `TrackResolver` (`app/lib/services/track_resolver.dart`), an interface `ExtractionService` implements, purely so `PlaybackCoordinator` and the debug screen are testable with a fake instead of live network/remote-config I/O.

`audio_engine`'s playback cache (`PlaybackCache`) is deliberately self-contained — a JSON sidecar index on disk, not a `database` table — so `audio_engine` doesn't gain a `database` dependency either. Masterdoc §8.1 lists a "cache index" among the database's eventual tables; revisit if a later phase (e.g. P7's Downloads view) needs a unified view of streamed-cache and downloaded-file usage. See `docs/deviations.md`.

`media_integration` is now referenced by `app/` — SMTC lands in Phase 2 as planned. Its `smtc_windows` dependency (Rust, via `flutter_rust_bridge`) now enters `app`'s Windows build graph, so CI provisions a Rust toolchain before building (see `.github/workflows/ci.yml`). Hardware media keys are covered by the same SMTC session (`SMTCWindows.buttonPressStream`) rather than a separate `hotkey_manager` registration — `hotkey_manager` remains declared for Phase 8's user-rebindable custom hotkeys. Tray/toast/Discord RPC are still P8.

`app`'s persistence (resume-across-restart) lives in `app/lib/playback_coordinator.dart`, not inside `audio_engine` or `media_integration` — it reads `AudioEngine`'s reactive streams and writes to two new `database` tables (`queue_items`, `playback_session`; schema v2), and restores them into `AudioEngine.loadQueue` on startup. This keeps both `audio_engine` and `media_integration` free of a `database` dependency, consistent with the sibling-independence rule above.

**Phase 3 adds `app/lib/design_system/` and `app/lib/app_shell/`**, the real UI shell replacing Phase 2's `debug_playback_screen.dart` (deleted). `design_system` owns everything content-agnostic — theme/typography/dynamic-color/density/motion/appearance-settings — and `app_shell` owns window chrome, navigation, and the now-playing surfaces, consuming `design_system` and the existing `audioEngineProvider`/`playbackCoordinatorProvider` (no new abstractions were needed in `audio_engine` or `media_integration`; the Phase 2 interfaces already covered everything the UI needs). A new single-row `AppSettings` table (schema v3) persists the density/backdrop/accent/motion choices `design_system/settings/appearance_settings_controller.dart` exposes as a Riverpod `Notifier`; `app/lib/services/settings_repository.dart` is the `database` ↔ `AppearanceSettings` bridge, mirroring `extraction_service.dart`'s role as the bridge for `TrackResolver`. Dynamic color extraction reuses Flutter's built-in `ColorScheme.fromImageProvider` rather than adding a third-party palette package (the well-known `palette_generator` is discontinued upstream) — no new dependency needed there. `system_theme` (same maintainer as `fluent_ui`) was added to read the real Windows accent color for the "follow Windows accent" option. Navigation destinations beyond Settings are placeholder "coming soon" screens — real content surfaces are Phase 4 scope.

## Workspace tooling

This monorepo uses Dart/Flutter's native **pub workspaces** (`workspace:` field in the root `pubspec.yaml`, `resolution: workspace` in each member's `pubspec.yaml`) combined with **melos 7.x** for scripted commands (`analyze`, `format-check`, `test:dart`, `test:flutter`, `test`). melos's own config lives under the `melos:` key in the root `pubspec.yaml` (not a separate `melos.yaml` — that was melos's pre-7.0 convention and is no longer read). See `docs/stack.md` for why.

## Error modeling

Per §5.3: typed results (`Result<T, E>` in `packages/core`) instead of throwing for expected/recoverable failures. `AppFailure` (also in `core`) is the shared sealed base for generic failures; feature packages define their own sealed result types where richer context is needed (e.g. `ExtractionResult` in `packages/extraction`, carrying which fallback layers were tried per §6.8).
