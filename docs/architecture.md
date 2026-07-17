# Architecture

> Generated at Phase 0 (§20, P0). Reflects what actually exists in the repo today; refresh every phase per §0.1.

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
│  ├─ core/                      # Result/error types, logging, constants (pure Dart)
│  ├─ innertube_client/          # InnerTube client-identity model (pure Dart)
│  ├─ extraction/                # ExtractionResult, PoTokenProvider slot (pure Dart)
│  ├─ audio_engine/               # AudioEngine interface (Flutter)
│  ├─ database/                  # Drift AppDatabase (pure Dart, sqlite3 native)
│  ├─ media_integration/         # SMTC/tray/media-key interfaces (Flutter)
│  └─ remote_config/              # RemoteConfig model + verifier interface (pure Dart)
└─ app/                          # the Flutter application
   └─ lib/
      ├─ features/               # empty in P0; feature-first surfaces from P4 onward
      ├─ design_system/          # empty in P0; theme/motion/density from P3
      ├─ app_shell/              # empty in P0; window chrome/nav from P3
      └─ main.dart                # Phase 0: bare FluentApp + window_manager + ProviderScope
```

## Package dependency direction

`app` → feature packages (`extraction`, `audio_engine`, `database`, `media_integration`, `remote_config`, `innertube_client`) → `core`. No package below `app` depends on Flutter unless it genuinely needs the Flutter SDK (`audio_engine`, `media_integration`); `core`, `innertube_client`, `extraction`, `database`, `remote_config` are pure Dart and unit-testable without Flutter, per §5.2's requirement.

`media_integration` is declared but **not yet referenced by `app/`** — its `smtc_windows` dependency (Rust, via `flutter_rust_bridge`) resolves into the workspace lockfile without pulling native Rust compilation into `app`'s build graph until whichever phase first wires it in (SMTC lands in P2; tray/hotkeys/Discord in P8).

## Workspace tooling

This monorepo uses Dart/Flutter's native **pub workspaces** (`workspace:` field in the root `pubspec.yaml`, `resolution: workspace` in each member's `pubspec.yaml`) combined with **melos 7.x** for scripted commands (`analyze`, `format-check`, `test:dart`, `test:flutter`, `test`). melos's own config lives under the `melos:` key in the root `pubspec.yaml` (not a separate `melos.yaml` — that was melos's pre-7.0 convention and is no longer read). See `docs/stack.md` for why.

## Error modeling

Per §5.3: typed results (`Result<T, E>` in `packages/core`) instead of throwing for expected/recoverable failures. `AppFailure` (also in `core`) is the shared sealed base for generic failures; feature packages define their own sealed result types where richer context is needed (e.g. `ExtractionResult` in `packages/extraction`, carrying which fallback layers were tried per §6.8).
