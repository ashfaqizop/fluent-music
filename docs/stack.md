# Pinned Technology Stack

> Generated at Phase 0 by resolving the Masterdoc §4 floor versions against pub.dev (`flutter pub get` across the workspace) and reading the resulting `pubspec.lock`. Update this table whenever the lockfile changes meaningfully (major/minor bumps, new packages).

Constraints in each package's `pubspec.yaml` are intentionally left as `any` for third-party packages rather than hand-pinned floors — pub's workspace resolver picks the newest mutually-compatible set across all 8 packages, and that resolved set is recorded here. This avoids hand-guessing version numbers that may not exist or may not be mutually compatible (see `docs/deviations.md` for the one real conflict this surfaced).

Environment: Dart SDK `^3.9.0`, Flutter 3.44.6 stable.

| Package | Resolved version | Used by | Notes |
|---|---|---|---|
| fluent_ui | 4.16.0 | app | UI kit; §4 floor was `^4.13.x` |
| flutter_acrylic | 1.1.4 | app | Mica/Acrylic backdrop |
| window_manager | 0.5.2 | app | Custom chrome, frameless window |
| fluentui_system_icons | 1.1.273 | app | Icon set |
| flutter_riverpod | 3.3.2 | app | State/DI. `riverpod_generator`/`riverpod_annotation` are **not yet added** — see `docs/deviations.md`; no code uses `@riverpod` codegen yet, so they're deferred to whichever phase first needs it |
| media_kit | 1.2.6 | audio_engine | Audio engine (libmpv) |
| media_kit_libs_audio | 1.0.7 | audio_engine | Bundled audio-only native libs |
| media_kit_native_event_loop | 1.0.9 | audio_engine | Native event loop |
| drift | 2.34.2 | database | ORM/query builder |
| drift_dev | 2.34.0 | database (dev) | Codegen |
| sqlite3 | 3.4.0 | database | Native SQLite bindings; auto-provisioned via Dart's native-assets build hooks (no manual DLL step needed) |
| build_runner | 2.15.1 | database (dev) | Codegen runner |
| dio | 5.10.0 | innertube_client, remote_config, extraction (smoke harness) | HTTP client; now driving `InnerTubeRateLimitInterceptor` and `RemoteConfigFetcher` (Phase 1) |
| youtube_explode_dart | 3.1.0 | extraction | Stream resolution (§6.3, layer 1); now actually exercised via `ClientRaceLayer`/`AlternateIdentityLayer` (Phase 1) |
| crypto | 3.0.7 | remote_config | Repurposed at Phase 1 for a cheap SHA-256 cache-change short-circuit — real signature verification moved to `cryptography` (below), since `crypto` is hash-only and can't do asymmetric signatures |
| cryptography | 2.9.0 | remote_config | **New at Phase 1.** Pure-Dart Ed25519 sign/verify for the remote-config signing scheme (§6.5, §22). Chosen over `ed25519_edwards` for being more actively maintained/widely used — signing is security-critical, so an established library beats hand-rolled or niche crypto. No native/FFI dependency, so `remote_config` stays buildable without extra toolchain setup. |
| path | 1.9.1 | remote_config | **New at Phase 1.** Cross-platform-safe path joining for `RemoteConfigCache`'s file location; small, ubiquitous, non-controversial. |
| http | 1.6.0 | extraction | **New at Phase 1, as a direct dependency** (previously only transitive via `youtube_explode_dart`). `RateLimitedHttpClient` (production code, not test-only) wraps a plain `http.Client` for rate-limit hygiene around stream-manifest calls. |
| http_parser | 4.1.2 | extraction (dev) | **New at Phase 1.** `MediaType` construction in `stream_selection_test.dart`'s hand-built `AudioOnlyStreamInfo` fixtures. |
| smtc_windows | 1.1.0 | media_integration | SMTC overlay; requires rustup at build. **Wired into `app/` at Phase 2** via `SmtcMediaTransportController` — CI now provisions a Rust toolchain (see `docs/architecture.md`) |
| flutter_rust_bridge | 2.12.0 | media_integration (transitive, via smtc_windows) | Generated Rust bridge; `PlatformInt64` resolves to plain `int` on Windows/native (not `BigInt`, which is the web-only branch) |
| tray_manager | 0.5.3 | media_integration | System tray; still unused until Phase 8 |
| hotkey_manager | 0.2.3 | media_integration | Declared for Phase 8's user-rebindable custom hotkeys; **not used for Phase 2's hardware media keys**, which ride on `smtc_windows`'s SMTC session instead — see `docs/deviations.md` |
| local_notifier | 0.1.6 | media_integration | Toast notifications |
| dart_discord_presence | 1.2.0 | media_integration | Discord Rich Presence |
| logging | 1.3.0 | core | `AppLogger` wrapper |
| meta | 1.18.0 | core | Annotations |
| very_good_analysis | 7.0.0 | workspace (dev) | Lint ruleset, `--fatal-infos` intentionally **not** used in CI — see `docs/deviations.md` |
| melos | 7.8.1 | workspace (dev) | Monorepo tooling |
| path_provider | 2.1.6 | app | **New at Phase 2.** Real per-user app-support directory for the database file, remote-config cache, and playback cache (replacing the temp-dir paths used only by P1's headless `bin/smoke.dart`) |
| path_provider_windows | 2.3.0 | app (transitive) | Windows backend for `path_provider` |
| drift | 2.34.2 | app (transitive, direct for query-builder types) | **New direct dependency at Phase 2** — `playback_coordinator.dart` needs `Value`/`OrderingTerm` for queue/session persistence queries |
| system_theme | 3.3.0 | app | **New at Phase 3.** Reads the real Windows system accent color (`SystemTheme.accentColor.accent`) for the "follow Windows accent" option (§11.5). Chosen because it's maintained by the same author as `fluent_ui` and built specifically to feed `fluent_ui`'s `AccentColor` swatches — low integration risk, matches the project's existing single-maintainer exposure on `fluent_ui` itself. |

## Phase 3 notes — no new dependency for dynamic color or motion

- **Dynamic color from artwork** (§11.5) uses Flutter's own `ColorScheme.fromImageProvider` (`material.dart`) rather than adding `palette_generator` — that package is discontinued upstream (last real release predates this baseline; `palette_generator_master` is an unofficial community continuation). The built-in API covers the same need with zero added dependency risk.
- **Motion system** (§11.7 — shared-element transitions, micro-interactions, shader warm-up) is built entirely on Flutter's own animation primitives (`Hero`, `AnimatedContainer`/`AnimatedScale`/`AnimatedSwitcher`, `PageRouteBuilder`, `ShaderWarmUp`/`PaintingBinding.shaderWarmUp`) — no `flutter_animate` or similar package added. Revisit only if these prove insufficient in a later phase.
- **Typography**: Plus Jakarta Sans is bundled as static `.ttf` weights (Regular/Medium/SemiBold/Bold) fetched from the upstream OFL-1.1-licensed repo (`tokotype/PlusJakartaSans`) under `app/assets/fonts/PlusJakartaSans/`, with `OFL.txt` alongside — not `google_fonts`, which would either bundle the same files anyway or fetch over the network at runtime, and the app should stay fully offline-capable (§15.4's zero-telemetry-by-default spirit extends to not phoning a font CDN either).

## Tooling versions (this machine, at Phase 0)

- Flutter 3.44.6 stable / Dart 3.12.2
- Visual Studio 2026 Community, Desktop development with C++ workload
- rustup (present on this dev machine; CI now provisions its own via `dtolnay/rust-toolchain@stable` as of Phase 2, since `smtc_windows` is now linked into `app/`'s build graph)
- git 2.54, gh CLI 2.95

## Why `resolution: workspace` instead of a `packages:`-glob `melos.yaml`

Melos 7+ dropped the standalone `melos.yaml` + glob-based `packages:` config in favor of Dart/Flutter's native pub workspaces: the root `pubspec.yaml` declares `workspace: [...]` member paths, each member sets `resolution: workspace`, and melos-specific config (scripts, repository) moves under a `melos:` key inside that same root `pubspec.yaml`. `melos` itself must be a `dev_dependency` of the root `pubspec.yaml` for melos to detect the workspace root at all (its `cli_launcher`-based local-installation detection is how it finds the root). This is a real behavior change from older melos tutorials/examples still circulating — see `docs/deviations.md`.
