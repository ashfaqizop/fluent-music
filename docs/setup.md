# Dev Environment Setup

## Requirements

- Flutter 3.44.x stable (Windows desktop enabled)
- Visual Studio with the **Desktop development with C++** workload
- [rustup](https://rustup.rs/) (required to build `smtc_windows`'s native Rust bridge, once P2/P8 wire it in)
- [NSIS](https://nsis.sourceforge.io/Download) (`makensis` on PATH) — for the installer build, from P10 onward
- Git

## Quick check / provision

```powershell
./scripts/setup-dev.ps1
```

Idempotent: checks each tool and only installs what's missing (via `winget` where possible). Safe to re-run any time. It also runs `flutter pub get` and code generation at the workspace root to bootstrap all packages.

## Manual bootstrap (if you skip the script)

```powershell
dart pub global activate melos
flutter pub get
dart run melos exec --depends-on=build_runner -- dart run build_runner build
```

`melos` must be activated globally (or resolved locally via the workspace, which `flutter pub get` above does) for `melos run <script>` to work — see `docs/stack.md` for why melos config lives in the root `pubspec.yaml` rather than a separate `melos.yaml`.

The `build_runner` step regenerates Drift's `*.g.dart` output (e.g. `packages/database/lib/src/app_database.g.dart`). Generated files are gitignored — every fresh checkout (including CI) must run this step before `analyze`/`test`/`build` will succeed.

If `melos` isn't found after activation, add `%LOCALAPPDATA%\Pub\Cache\bin` to your `PATH` (that's where `dart pub global activate` installs the executable).

## Common commands

```powershell
melos run analyze --no-select        # dart analyze across all packages
melos run format-check --no-select   # dart format --set-exit-if-changed
melos run test --no-select           # all tests (pure-Dart, then Flutter)
./scripts/make-portable.ps1          # release build + portable zip under dist/
```

`--no-select` is required whenever a script's `packageFilters` can match more than one package — otherwise melos prompts interactively for which package to run in, which hangs in non-interactive shells.

## Secrets

Building, testing, and running Phase 1's extraction layer requires **zero secrets** — search/resolve work fine against the embedded `RemoteConfig.embeddedDefault` even with no remote-config fetch at all, and `packages/extraction/bin/smoke.dart` runs unauthenticated against public InnerTube/YouTube endpoints.

One secret exists at the repo level, needed only to *publish* an updated remote config (not to build/test/run the app):

| Secret | Used by | Purpose |
|---|---|---|
| `REMOTE_CONFIG_PRIVATE_KEY` | `packages/remote_config/tool/sign_config.dart` (run manually by the maintainer) | Ed25519 private key signing `remote-config/remote_config.json` → `remote_config.signed.json`. Never read by the app or by CI's build/test/smoke steps. |

Later phases (OAuth client — P6, Last.fm API key — P8) will document their local-dev secret setup here when they land (§22).
