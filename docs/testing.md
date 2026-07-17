# Testing Strategy

Per Masterdoc §19: pragmatic-but-strong on the fragile/critical layers, light on UI.

## Layers and expected coverage

| Layer | Package(s) | Test depth |
|---|---|---|
| Domain types (Result, errors) | `core` | Hard unit tests |
| Rate-limit hygiene | `core` | Hard unit tests: `BackoffPolicy` (exponential+cap+jitter+`Retry-After` precedence), `HostConcurrencyGate` (per-host cap, independent hosts), `VisitorIdRotator` (request-count-based rotation) — added P1 |
| InnerTube client | `innertube_client` | Hard unit tests: request-context building (incl. remote-config overrides), search-response parsing against a canned fixture (song + video rows), HTTP/parse error paths (never throws), rate-limit interceptor retry/backoff/visitor-id-injection — added P1 |
| Extraction / fallback chain | `extraction` | Hard unit tests: codec/bitrate stream selection against real `AudioOnlyStreamInfo` fixtures, identity-name-to-`YoutubeApiClient` mapping, orchestrator fallback-chain ordering + `layersTried` population (fake layer doubles, no network), PO-token/yt-dlp stub layers (always skip), rate-limited http client concurrency/pacing — added P1 |
| Remote config | `remote_config` | Hard unit tests: schema v1/v2 parsing + round-trip + tolerant-of-unknown-fields, canonical-JSON key-order independence, Ed25519 accept/reject (tampered payload/signature/wrong key — three separate negative tests), cache round-trip + corrupt-file handling, fetcher fallback semantics (valid → applied+cached, tampered → last-known-good, network failure → embedded default, never throws) — added P1 |
| Database | `database` | Hard unit tests against a real in-memory SQLite instance (`NativeDatabase.memory()`), not mocks |
| Audio engine | `audio_engine` | Unit tests against the `AudioEngine` interface with fakes; real media_kit integration tested manually + via the CI smoke test once P2 lands |
| Media integration | `media_integration` | Light unit tests on data shapes; platform-channel-backed behavior (SMTC, tray) is manually verified on the reference laptop, not unit tested |
| UI (`app/`) | `app` | Widget tests on key surfaces; light relative to domain layers |
| End-to-end | `extraction` (`bin/smoke.dart`) | **Added P1.** Headless CLI: fetch+apply remote config → InnerTube search → extraction orchestrator → HTTP range-fetch confirms the resolved URL serves real audio bytes. Runs on every CI build but is non-blocking (`continue-on-error` + `::warning::` annotation) since it depends on live YouTube — see `docs/deviations.md`. Real audible playback via `media_kit` gets its own, stronger smoke test once P2 lands. |

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
