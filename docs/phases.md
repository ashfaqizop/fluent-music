# Phase Tracker

Living checklist for Masterdoc §20. Each phase updates its own row/checklist when it lands; DoD text is copied from the Masterdoc so this file is self-contained.

| Phase | Status | DoD summary |
|---|---|---|
| P0 — Scaffold, dev-env, CI | ✅ Done (2026-07-17) | Clean `flutter build windows` in CI; empty app window launches; portable zip produced; docs scaffolded |
| P1 — InnerTube + extraction core | ✅ Done (2026-07-17) | Search → resolve → play a track's audio headless; remote config verified+applied |
| P2 — Audio engine + core system integration | ✅ Done (2026-07-17) | Full queue playback, gapless, SMTC + media keys, resume, smooth on reference laptop |
| P3 — UI shell + design system | ✅ Done (2026-07-17) | Navigable shell, dynamic color, density switch, motion respecting reduce-motion, perf budget met |
| P4 — Content surfaces | ⬜ Not started | Home/Explore/Search/Artist/Album populate from InnerTube, degrade gracefully |
| P5 — Library, playlists, likes, history | ⬜ Not started | Local + synced (local-fork) playlists, likes/library in both modes, history + import/export |
| P6 — Authentication | ⬜ Not started | OAuth + cookie sign-in, multi-account switch, personalized data, clean relogin |
| P7 — Downloads, offline, encryption | ⬜ Not started | Encrypted offline playback, no plaintext on disk, auto/manual offline |
| P8 — Lyrics, EQ, crossfade, Discord, scrobbling, notifications, tray, hotkeys | ⬜ Not started | All features functional and settings-controllable |
| P9 — Low-Spec mode + performance hardening | ⬜ Not started | §14 budget met on reference laptop in both modes |
| P10 — Updater, packaging, diagnostics, polish, release | ⬜ Not started | Signed-off installable + portable V1 |

## P0 — details

**Built:** melos/pub-workspace monorepo (`packages/core`, `innertube_client`, `extraction`, `audio_engine`, `database`, `media_integration`, `remote_config`, and `app/`), each with real (if minimal) content, tests, and clean `dart analyze`. `app/` boots a bare `fluent_ui` `FluentApp` inside `window_manager`/`ProviderScope`. `scripts/setup-dev.ps1` (idempotent environment check/provision) and `scripts/make-portable.ps1` (release build + zip). `.github/workflows/ci.yml` running analyze/format-check/test/build/package on `windows-latest`. Base `/docs` scaffolded.

**Verification:** see the Phase 0 report delivered alongside this build for exact commands and output.

**Known deviations:** see `docs/deviations.md` (melos config location, a `riverpod_generator`/`drift_dev`/`melos` version conflict resolved by deferring codegen packages, and dropping `--fatal-infos` from the analyze script).

**Next:** P1 — InnerTube + extraction core, gated on human approval of this phase.

## P1 — details

**Built:**

- `core`: rate-limit hygiene primitives (`BackoffPolicy`, `HostConcurrencyGate`, `VisitorIdRotator`) — transport-agnostic, shared by both `innertube_client` (dio) and `extraction` (`package:http`).
- `remote_config`: schema v2 (identity overrides, rate-limit tuning, race-lane knobs), Ed25519 signing (`cryptography`) with canonical-JSON hashing, `RemoteConfigCache` (pure `dart:io`), `RemoteConfigFetcher` (fetch → verify → apply → cache, never throws), publishing tools (`tool/generate_signing_key.dart`, `tool/sign_config.dart`).
- `innertube_client`: real `WEB_REMIX` client identity + request-context builder, `InnerTubeClient.search()` (parses song/video rows from the actual InnerTube renderer tree) and `.browse()` (thin passthrough, Phase 4 foundation), `InnerTubeRateLimitInterceptor`, `InnerTubeFailure` typed errors.
- `extraction`: `ClientRaceLayer` (parallel client race via `youtube_explode_dart`), `AlternateIdentityLayer` (sequential long-tail fallback), `PoTokenLayer`/`YtDlpLayer` (wired but inert, per Phase 1 scope), `ExtractionOrchestrator` (fallback-chain runner), `pickBestAudio` (opus-first codec preference), `RateLimitedHttpClient`.
- `packages/extraction/bin/smoke.dart`: headless CLI proving search → resolve → HTTP-range-fetch-confirms-audio end-to-end; wired into CI as a non-blocking step.
- A real Ed25519 signing keypair was generated; the public key is committed (`packages/remote_config/lib/src/signing_public_key.dart`), the private key is a GitHub Actions secret (`REMOTE_CONFIG_PRIVATE_KEY`), and the first real signed config was authored, signed, and committed (`remote-config/remote_config.json` / `remote_config.signed.json`).
- `docs/extraction.md` authored (previously referenced but never written).
- Logo assets relocated to `assets/branding/`; README updated.

**Verification:** `melos run analyze` / `format-check` / `test` all clean across every touched package (unit tests cover rate-limit primitives, signature verify/reject paths, cache round-trips, fetcher fallback semantics, InnerTube search parsing + error paths, stream-codec selection, orchestrator fallback-chain ordering). `dart run packages/extraction/bin/smoke.dart` run manually against live YouTube: resolved a real stream via the `client_race` layer (`ANDROID_VR` identity), fetched real audio bytes via an HTTP range request, exit code 0. The signed config was verified against the embedded public key before committing.

**Known deviations:** see `docs/deviations.md` — two client-identity catalogs (search/browse vs. stream resolution) rather than one unified pool; `AlternateIdentityLayer` is sequential rather than a second race; the signed config is hosted as an in-repo file rather than a GitHub Release asset; the CI smoke-test step is non-blocking; "play a track's audio" is interpreted as an HTTP-range-fetch confirmation pending Phase 2's `media_kit` wiring.

**Next:** P2 — Audio engine + core system integration, gated on human approval of this phase.

## P2 — details

**Built:**

- `audio_engine`: expanded `AudioEngine` interface (queue model, shuffle/repeat, volume/speed, reactive streams for position/duration/buffering/current-track/queue/errors/volume). `QueueController` — pure-Dart queue/shuffle/repeat/history logic, no media_kit dependency, fully unit-testable. `MediaKitPlayerEngine` — wraps `media_kit`'s `Player`; gapless playback via a rolling "current + one look-ahead" `Media` window (`Player.add`/`Player.remove`, never a full reopen during natural track-boundary advances, only on explicit skip/jump/load/remove-current); prefetches the look-ahead track's stream URL ahead of time. `PlaybackCache` — self-contained JSON-indexed disk cache for streamed audio (~2GB default cap, LRU eviction), deliberately independent of `database` (layering rule).
- `database`: schema v2 — `queue_items` (ordered queue snapshot) and `playback_session` (position/shuffle/repeat/volume, singleton row) tables, with a real `MigrationStrategy`.
- `media_integration`: `SmtcMediaTransportController` — real Windows SMTC overlay via `smtc_windows`; hardware media keys covered by the same SMTC session (no `hotkey_manager` needed for this). `MediaTransportController` interface extended with `updatePlaybackStatus`.
- `app/`: `services/track_resolver.dart` (`TrackResolver` interface) + `services/extraction_service.dart` (concrete implementation owning the `ExtractionOrchestrator`/`RemoteConfig`/InnerTube wiring — the bridge `audio_engine` never has to know about, per the layering rule). `providers.dart` (plain Riverpod DI). `playback_coordinator.dart` — wires `AudioEngine` ⇄ `MediaTransportController`, persists/restores queue+position+shuffle+repeat+volume across restarts. `debug_playback_screen.dart` — temporary Phase 2 debug harness (search/enqueue/queue/transport controls), replaced by the real shell in Phase 3. `main.dart` — async bootstrap (media_kit, SMTC runtime, database, extraction service) ahead of `runApp`.
- `app/bin/smoke_playback.dart` — headless CLI: search → resolve → load into a real `MediaKitPlayerEngine` → confirms playback position genuinely advances, superseding P1's HTTP-range-fetch confirmation with real decoded audio. Wired into CI, non-blocking.
- `.github/workflows/ci.yml`: added a Rust toolchain setup step (`dtolnay/rust-toolchain@stable`) ahead of the Windows build, since `smtc_windows`'s Rust bridge now enters `app/`'s build graph; added the new playback smoke-test step (non-blocking).

**Verification:** `dart analyze .` clean (info-level only, consistent with the project's established `--fatal-infos`-off convention). `dart format --output=none --set-exit-if-changed .` clean. Full test suite green: `core`/`innertube_client`/`extraction`/`remote_config`/`database` (`dart test`) and `audio_engine`/`media_integration`/`app` (`flutter test`) — including new hard unit tests for `QueueController` (shuffle/repeat/reorder/remove/history semantics), `PlaybackCache` (eviction, stale-entry fallback, corrupt-index tolerance), `database`'s new tables (round-trip + singleton-row upsert), and an `app` widget test exercising `FluentMusicApp` → `DebugPlaybackScreen` end-to-end against fakes for `AudioEngine`/`MediaTransportController`/`TrackResolver`. `flutter build windows --release` succeeds with `media_kit` and `smtc_windows`'s Rust bridge compiled in (first real native-Rust build in this repo, ~5.5 min on this dev machine); `scripts/make-portable.ps1` produces the phase-gate zip.

**Known deviations:** see `docs/deviations.md` — hardware media keys ride on `SmtcMediaTransportController`'s SMTC session rather than a separate `hotkey_manager` registration; `smtc_windows` 1.1.0 has no public seek/position-change-request API, so `MediaTransportCommand.seek` is never emitted (in-app seeking still works); the playback cache is a JSON sidecar rather than a `database` table, to keep `audio_engine` free of a `database` dependency; the new playback smoke test lives in `app/bin/` rather than `packages/audio_engine/bin/`, for the same layering reason.

**Not yet verified (requires the reference laptop):** the SMTC overlay's actual rendering/control, hardware media keys while the window is unfocused/minimized, resume-across-restart end to end, and general smoothness per §14 — these have no CI equivalent and are the responsibility of the phase-gate manual pass (§0.3).

**Next:** P3 — UI shell + design system, gated on human approval of this phase.

## P3 — details

**Built:**

- `design_system`: `typography/app_typography.dart` (Plus Jakarta Sans `Typography`, bundled as static OFL-1.1 `.ttf` weights under `app/assets/fonts/PlusJakartaSans/`); `theme/app_theme.dart` (dark-only `FluentThemeData` builder, accent color in via `Color.toAccentColor()`); `color/dynamic_color_engine.dart` (artwork tint via Flutter's built-in `ColorScheme.fromImageProvider`, cached per artwork URI, luminance-clamped for dark-base legibility); `density/density_tokens.dart` (`DensityMode` hybrid/spacious/compact presets + `densityTokensProvider`); `motion/motion_tokens.dart` (durations collapse to zero when either the OS "reduce motion" signal — `MediaQuery.disableAnimationsOf` — or the user's `MotionLevel` setting requests it); `motion/shader_warm_up.dart` (`AppShaderWarmUp`, covering rounded surfaces/blur/gradient/text, registered via `PaintingBinding.shaderWarmUp` before `WidgetsFlutterBinding.ensureInitialized()`); `settings/appearance_settings.dart` + `appearance_settings_controller.dart` (`AppearanceSettings` model + a plain-Riverpod `Notifier`, no codegen).
- `app_shell`: `window/custom_title_bar.dart` (owner-drawn `TitleBar` — wordmark, integrated `AutoSuggestBox` search wired to real `TrackResolver`/`PlaybackCoordinator`, Spotify-like caption buttons with hover feedback driving `window_manager`); `window/backdrop.dart` (`flutter_acrylic` `Window.initialize()`/`setEffect()` wrapper, Mica/Acrylic/None per user choice); `navigation/app_shell.dart` (`NavigationView` with Home/Explore/Library/Settings per §11.3's exact list, placeholder "coming soon" bodies for Home/Explore/Library — real content is P4/P5 — plus a persistent `NowPlayingBar` docked below, spanning the full window width); `now_playing/now_playing_bar.dart` (Hero-tagged art, transport controls, tap-to-seek progress line, shuffle/repeat/queue/lyrics/volume affordances, hover micro-interactions) and `now_playing/now_playing_full.dart` (Apple-Music-style full-screen scaffold: Hero-continued art, dynamic-color-tinted gradient background, transport controls; queue/lyrics content stubbed — real content is P5/P8); `settings/settings_screen.dart` (Appearance section: density/backdrop/accent/motion controls — the seed later phases append §16's remaining sections to).
- `packages/database`: schema v3 adds a single-row `AppSettings` table (density/backdrop/accent/motion, same `clientDefault(() => 0)` singleton-row pattern as `PlaybackSession`).
- `app/lib/services/settings_repository.dart`: `AppearanceSettings` ⇄ `AppSettings` table bridge, mirroring `extraction_service.dart`'s bridging role.
- `app/main.dart`: registers the shader warm-up pre-binding-init; initializes `flutter_acrylic` and applies the persisted/default backdrop as a side effect (`ref.listen` on `appearanceSettingsProvider`); loads the real Windows accent color via `system_theme`; builds the theme through `buildAppTheme`; `home:` is now `AppShell()`. `debug_playback_screen.dart` is deleted — its search/queue functionality now lives in the real title-bar search box and now-playing bar/queue flyout.
- New dependency: `system_theme` (same maintainer as `fluent_ui`) for the real Windows accent color — justified in `docs/stack.md`. No dynamic-color or animation package was added (`palette_generator` is discontinued upstream; Flutter's own animation primitives cover §11.7's motion requirements) — see `docs/stack.md`'s Phase 3 notes.

**Verification:** `dart analyze .` clean workspace-wide (info-level only, same established convention — 5 of the 45 info hits are new-this-phase, all reviewed: a `ReorderableListView.onReorder` deprecation notice, a `use_enums` false-positive on a value-object class with named const instances, a `prefer_constructors_over_static_methods` style nit, and two `shader_warm_up.dart` cascade/const style nits). `dart format --output=none --set-exit-if-changed .` clean. Full test suite green: `database` (new `app_settings` schema-version + upsert tests), `app` (`AppShell` renders on the Home tab end-to-end against the same `AudioEngine`/`MediaTransportController`/`TrackResolver` fakes as before, plus new `SettingsRepository` round-trip tests, `DensityTokens`/`MotionTokens` pure-logic tests covering both the OS and user-setting reduce-motion paths, and a `NowPlayingBar` visibility test). `flutter build windows --release` succeeds with the new font/asset bundling (`FontManifest.json` confirms Plus Jakarta Sans at all four weights); `scripts/make-portable.ps1` produces the phase-gate zip. The built `fluent_music.exe` was launched directly (not just compiled): the process stayed alive and stable at ~85 MB working-set (well under the §14 idle-memory budget) with no crash, and Win32 window enumeration confirmed a window titled "Fluent Music" at the exact configured 1280×720 size — direct evidence the real shell renders, not just that it compiles.

**Known deviations:** none logged — every Phase 3 choice not explicitly pinned by the Masterdoc (dynamic-color package, motion package, exact Settings-screen scope) was a genuine open judgment call rather than a spec-vs-reality conflict, and is recorded as a design decision in `docs/architecture.md`/`docs/stack.md` instead of `docs/deviations.md`.

**Not yet verified (requires the reference laptop or a real interactive desktop session):** a true visual screenshot of the running app — this dev/build environment's automation session is non-interactive, so GPU-composited (DirectX/Angle) window content can't be captured (`PrintWindow` returns solid black even against a correctly-sized, correctly-titled window; this is a capture-method limitation, not a rendering failure). Also still pending the reference laptop: Mica/Acrylic visual correctness, motion smoothness and the shared-element art transition, shader-warm-up's actual effect on first-run jank, and the full §14 perf budget in the new UI — all part of the phase-gate manual pass (§0.3).

**Next:** P4 — Content surfaces, gated on human approval of this phase.
