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
| Database | `database` | Hard unit tests against a real in-memory SQLite instance (`NativeDatabase.memory()`), not mocks. **Added P2:** `queue_items`/`playback_session` round-trip + single-row upsert tests |
| Audio engine | `audio_engine` | **Added P2.** `QueueController` (shuffle/repeat/reorder/remove/history — pure Dart, no media_kit) gets hard unit tests; `PlaybackCache` (LRU eviction, stale-entry fallback, corrupt-index tolerance) gets hard unit tests against a real temp-dir filesystem. `MediaKitPlayerEngine` itself (the real libmpv wiring) is not unit tested — real media_kit integration is verified manually on the reference laptop and via `app/bin/smoke_playback.dart` in CI |
| Media integration | `media_integration` | Light unit tests on data shapes; platform-channel-backed behavior (SMTC overlay, hardware media keys) is manually verified on the reference laptop, not unit tested — `SmtcMediaTransportController` constructs a real `SMTCWindows` session, which needs the Rust bridge loaded and a real Windows session |
| App wiring (`app/`) | `app` | **Added P2.** `PlaybackCoordinator` and `DebugPlaybackScreen` are tested with fakes for `AudioEngine`/`MediaTransportController`/`TrackResolver` (never real network, media_kit, or SMTC) — see `app/lib/services/track_resolver.dart`, the interface `ExtractionService` implements specifically so this is possible. Widget tests on key surfaces; light relative to domain layers |
| End-to-end | `extraction` (`bin/smoke.dart`) | Headless CLI: fetch+apply remote config → InnerTube search → extraction orchestrator → HTTP range-fetch confirms the resolved URL serves real audio bytes. Runs on every CI build but is non-blocking (`continue-on-error` + `::warning::` annotation) since it depends on live YouTube — see `docs/deviations.md`. |
| End-to-end (real playback) | `app` (`bin/smoke_playback.dart`) | **Added P2.** Headless CLI: search → resolve → load into a real `MediaKitPlayerEngine` → assert playback position actually advances over several seconds — supersedes P1's HTTP-range-fetch confirmation with genuine decoded audio. Lives in `app/` (not `packages/audio_engine`) so `audio_engine`'s own pubspec never gains an `extraction`/`innertube_client` dependency. Non-blocking in CI (`continue-on-error`) pending confirmation that libmpv can reliably initialize on a `windows-latest` runner outside a full `flutter build` output tree — see `docs/deviations.md`. SMTC overlay and hardware media keys have **no CI equivalent at all**; the reference-laptop manual pass is the only check for those. |

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

## Notable Phase 2 setup detail: real `dart:io` calls must not run inside `testWidgets`

`app/test/widget_test.dart` originally called `Directory.systemTemp.createTemp(...)` directly inside a `testWidgets(...)` body and hung indefinitely (no error, no timeout for over a minute, confirmed via `flutter test -r expanded` with step-by-step `print`s pinpointing the exact `await`). `flutter_test`'s widget-test zone doesn't pump real async-I/O completions the way a plain `test()` zone does, so an `await` on genuine `dart:io` work (temp-directory creation, file reads/writes — anything `PlaybackCache`/`AppDatabase` do) can silently never resolve. The fix: do that setup in `setUp`/`tearDown` (which run in the normal test zone), and keep the `testWidgets` body itself free of raw `dart:io` awaits — construct fakes and call `tester.pumpWidget` only. Any future widget test that needs a real temp directory, file, or database file should follow this pattern.
