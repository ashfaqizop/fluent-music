# Testing Strategy

Per Masterdoc §19: pragmatic-but-strong on the fragile/critical layers, light on UI.

## Layers and expected coverage

| Layer | Package(s) | Test depth |
|---|---|---|
| Domain types (Result, errors) | `core` | Hard unit tests |
| InnerTube client | `innertube_client` | Hard unit tests (request building, client identities) — real coverage grows in P1 |
| Extraction / fallback chain | `extraction` | Hard unit tests, including failure-path coverage (§6.8) — grows in P1 |
| Remote config | `remote_config` | Hard unit tests (parsing, signature verification, fallback-to-embedded behavior) — grows in P1 |
| Database | `database` | Hard unit tests against a real in-memory SQLite instance (`NativeDatabase.memory()`), not mocks |
| Audio engine | `audio_engine` | Unit tests against the `AudioEngine` interface with fakes; real media_kit integration tested manually + via the CI smoke test once P2 lands |
| Media integration | `media_integration` | Light unit tests on data shapes; platform-channel-backed behavior (SMTC, tray) is manually verified on the reference laptop, not unit tested |
| UI (`app/`) | `app` | Widget tests on key surfaces; light relative to domain layers |
| End-to-end | — | A CI integration smoke test that actually resolves + plays a track lands in P1, per §19 |

## Running tests

```powershell
# Pure-Dart packages
melos run test:dart --no-select

# Flutter packages (audio_engine, media_integration, app)
melos run test:flutter --no-select

# Both
melos run test --no-select
```

`--no-select` skips melos's interactive "which package?" prompt (needed here since every `test:*` script's `packageFilters` can match more than one package) — always pass it in CI/scripted contexts.

## Notable Phase 0 setup detail

`packages/database` tests open a real `NativeDatabase.memory()` (pure Dart, no Flutter) rather than mocking Drift. This works out of the box because Dart's native-assets build hooks (stable as of the `^3.9.0` SDK this workspace targets) auto-provision the `sqlite3` native library — no manual DLL bundling needed for pure-Dart tests.
