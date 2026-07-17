# Phase Tracker

Living checklist for Masterdoc §20. Each phase updates its own row/checklist when it lands; DoD text is copied from the Masterdoc so this file is self-contained.

| Phase | Status | DoD summary |
|---|---|---|
| P0 — Scaffold, dev-env, CI | ✅ Done (2026-07-17) | Clean `flutter build windows` in CI; empty app window launches; portable zip produced; docs scaffolded |
| P1 — InnerTube + extraction core | ⬜ Not started | Search → resolve → play a track's audio headless; remote config verified+applied |
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
