# Phase Tracker

Living checklist for Masterdoc §20. Each phase updates its own row/checklist when it lands; DoD text is copied from the Masterdoc so this file is self-contained.

| Phase | Status | DoD summary |
|---|---|---|
| P0 — Scaffold, dev-env, CI | ✅ Done (2026-07-17) | Clean `flutter build windows` in CI; empty app window launches; portable zip produced; docs scaffolded |
| P1 — InnerTube + extraction core | ✅ Done (2026-07-17) | Search → resolve → play a track's audio headless; remote config verified+applied |
| P2 — Audio engine + core system integration | ⬜ Not started | Full queue playback, gapless, SMTC + media keys, resume, smooth on reference laptop |
| P3 — UI shell + design system | ⬜ Not started | Navigable shell, dynamic color, density switch, motion respecting reduce-motion, perf budget met |
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
