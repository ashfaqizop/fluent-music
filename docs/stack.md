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
| dio | 5.10.0 | innertube_client, remote_config | HTTP client |
| youtube_explode_dart | 3.1.0 | extraction | Stream resolution (§6.3, layer 1) |
| crypto | 3.0.7 | remote_config | Signature verification (§6.5) |
| smtc_windows | 1.1.0 | media_integration | SMTC overlay; requires rustup at build. Declared but not yet wired into `app/` (§ deviations) |
| tray_manager | 0.5.3 | media_integration | System tray |
| hotkey_manager | 0.2.3 | media_integration | Global media keys/hotkeys |
| local_notifier | 0.1.6 | media_integration | Toast notifications |
| dart_discord_presence | 1.2.0 | media_integration | Discord Rich Presence |
| logging | 1.3.0 | core | `AppLogger` wrapper |
| meta | 1.18.0 | core | Annotations |
| very_good_analysis | 7.0.0 | workspace (dev) | Lint ruleset, `--fatal-infos` intentionally **not** used in CI — see `docs/deviations.md` |
| melos | 7.8.1 | workspace (dev) | Monorepo tooling |

## Tooling versions (this machine, at Phase 0)

- Flutter 3.44.6 stable / Dart 3.12.2
- Visual Studio 2026 Community, Desktop development with C++ workload
- rustup (present; not yet exercised by CI since `media_integration` isn't linked into `app/`'s build graph)
- git 2.54, gh CLI 2.95

## Why `resolution: workspace` instead of a `packages:`-glob `melos.yaml`

Melos 7+ dropped the standalone `melos.yaml` + glob-based `packages:` config in favor of Dart/Flutter's native pub workspaces: the root `pubspec.yaml` declares `workspace: [...]` member paths, each member sets `resolution: workspace`, and melos-specific config (scripts, repository) moves under a `melos:` key inside that same root `pubspec.yaml`. `melos` itself must be a `dev_dependency` of the root `pubspec.yaml` for melos to detect the workspace root at all (its `cli_launcher`-based local-installation detection is how it finds the root). This is a real behavior change from older melos tutorials/examples still circulating — see `docs/deviations.md`.
