# Fluent Music — Masterdoc

**The single authoritative specification and source of truth for building Fluent Music.**

> A premium, native-feeling, high-performance, open-source **YouTube Music client for Windows**, built in Flutter, talking directly to YouTube's private **InnerTube** API. Music-only. Ultra-polished custom Fluent UI. Built by **Claude Code under human supervision**.

---

## 0. Document Control

| Field | Value |
|---|---|
| Product name | **Fluent Music** |
| Repository | `ashfaqizop/fluent-music` |
| Author / maintainer | ashfaqizop (`ashfaqizop@gmail.com`) — sole author |
| License | **GPLv3** |
| Platform | **Windows only** (Windows 10 & 11, x64). No mobile/web/macOS/Linux. |
| Build model | Generated and maintained by Claude Code, gated by phase-by-phase human approval |
| Spec baseline date | 2026-07-16 (technical landscape verified as of this date) |
| Doc status | Authoritative. This is the source of truth. Sub-docs are generated *from* this. |

### 0.1 How Claude Code must use this document

1. This `Masterdoc.md` is the **source of truth**. Read it fully before every phase.
2. Build strictly **phase by phase** (§20). Do not start a later phase before the current phase's **Definition of Done (DoD)** is met and the human has approved the gate.
3. At each phase, **generate/refresh the in-repo sub-docs** it references (`/docs/*.md`) so documentation always matches code.
4. Each phase **must emit a runnable portable build** (a zipped folder with `fluent_music.exe`) so the human can copy it to old test hardware and verify (see §0.3 and §17).
5. Obey the **Deviation Protocol** (§0.2). The doc is authoritative but not blind.

### 0.2 Deviation Protocol (authoritative-but-not-blind)

The masterdoc reflects the world as of the baseline date. Reality (YouTube changes, deprecated packages, better approaches) will drift. When Claude Code finds that a spec here **conflicts with reality or is miscalibrated against the actual project**, it must:

1. **Stop** at the conflicting point — do not silently code around it, and do not blindly follow a spec that is now wrong.
2. **Log** the issue in `/docs/deviations.md` (date, what the doc says, what reality is, evidence/source).
3. **Propose** a concrete correction with rationale and trade-offs.
4. **Proceed** with the correction *only after* it is recorded, and surface it to the human at the next gate.
5. Never let uncorrected drift accumulate. A wrong spec that was followed anyway is a defect.

### 0.3 Supervision workflow

- **Phase-gate approval.** At each phase DoD, Claude Code pauses, produces the portable build + a phase report (what was built, how to test, known issues, deviations), and waits for explicit human approval before the next phase.
- **Human hardware testing.** The human develops on modern hardware but validates on a **2012-era reference laptop** (Core i3-3110M, 4 GB DDR3, HDD, Intel HD 4000). Every phase gate therefore ships a **portable `.exe` build** the human copies to that laptop to confirm the performance target still holds (§14). Performance is validated *continuously*, not only at the end.

---

## 1. Vision & Guiding Principles

Fluent Music exists to be the YouTube Music client that **feels native, premium, and fast** on Windows — the opposite of the heavy Electron/webview wrappers. It talks to InnerTube directly (no embedded browser), caches and prefetches aggressively, and wraps it in a custom, lush, dark Fluent interface.

**Principles (in priority order):**

1. **Premium feel** — Apple-Music-grade polish, custom-designed content surfaces, lush motion, dynamic color.
2. **Native Windows** — Fluent chrome, Mica/Acrylic, SMTC, media keys, tray, toast, accent color. It should feel *made for* Windows.
3. **Performance** — buttery on modern hardware *and* on a 2012 i3/4 GB/HDD laptop. Low RAM, fast cold start, no jank.
4. **Quality** — Opus-first audio, highest available bitrate, gapless, correct metadata.
5. **Open source** — GPLv3, clean, documented, contributor-friendly, no telemetry-by-default.
6. **Longevity** — designed to survive YouTube's constant changes via remote self-healing config, layered fallbacks, and a diagnostics surface.

**Design north stars:** the polish of **Apple Music**, the ergonomics of **Spotify**, the content model of **YouTube Music**, expressed through a **customized Fluent** design language that is unmistakably a native Windows app.

---

## 2. Non-Goals (explicitly forbidden — do not build)

Claude Code must **not** spend effort on any of these:

- ❌ **Video playback.** Audio only. (Video *entities* may be used as audio sources — §6.6 — but never rendered.)
- ❌ **Non-Windows platforms.** No Android, iOS, web, macOS, or Linux targets.
- ❌ **Podcasts / non-music content.** Music only.
- ❌ **Ads or telemetry-by-default.** No ad surfaces. Crash reporting is strictly opt-in (§15.4).
- ❌ **Bundling copyrighted assets.** No shipped album art, lyrics dumps, fonts without proper license, or Google/YouTube trademarks as if endorsed.
- ❌ **A separate always-on-top mini-player window.** Deliberately excluded (deemed power-hungry / low value).
- ❌ **Pushing edits back to the user's YouTube account** for synced-playlist edits — local edits stay local (§9.4, §11.6).
- ❌ **Uploads to YT Music library** (OAuth can't do it; out of scope for V1).

---

## 3. Technical Landscape Snapshot (verified 2026-07-16)

This section records *why* the pinned stack was chosen. If any of these change, invoke the Deviation Protocol.

- **Flutter stable is 3.44.x**, solid Windows desktop support. Impeller on Windows is **preview-only** (Direct3D backend in progress); **default renderer on Windows is still Skia** → ship on Skia, warm up shaders, keep Impeller-Windows behind an opt-in flag.
- **media_kit** (libmpv, `^1.2.x`) is the correct audio engine: GPU-accelerated, gapless via mpv, native Opus/AAC, 24 reactive streams. HD 4000 supports the required Direct3D 11.
- **fluent_ui** (`^4.13.x`, Flutter Favorite) provides native Fluent controls, `NavigationView`, `TitleBar`; **flutter_acrylic** for Mica/Acrylic; **window_manager** for custom chrome.
- **youtube_explode_dart** (maintained, last update ~May 2026) works for stream extraction *today* but breaks periodically. YouTube deployed **SABR streaming** + **PO Tokens (Proof-of-Origin / GVS tokens)** through 2025–2026; InnerTube client identities die in waves (e.g. Sept 2025: Android VR, Android TV, iOS TV, iOS Music all broke at once). yt-dlp (gold standard) now often needs an external JS runtime + PO token. **Conclusion: extraction must be layered, parallel-raced, remote-updatable, and self-healing** (§6).
- **smtc_windows** (KRTirtho) provides the Windows media overlay; **requires the Rust toolchain (rustup)** to build.
- **LRCLIB** is the go-to free synced-lyrics source (no auth, anonymous); YT Music also serves native timed lyrics via InnerTube.
- **dart_discord_presence** (pure-Dart, win32, updated 2026-03) provides Discord Rich Presence incl. progress bar — no extra Rust needed.
- **NSIS** (chosen over MSIX) for installer + a portable ZIP edition, distributed via **GitHub Releases**; unsigned initially (SmartScreen warning accepted), removable later via Azure Trusted Signing.

---

## 4. Pinned Technology Stack

> Claude Code must resolve exact latest-compatible versions at P0 and record them in `/docs/stack.md` with a lockfile. Versions below are floors, not ceilings. If a package is dead/broken, invoke the Deviation Protocol.

| Concern | Choice | Notes |
|---|---|---|
| Framework | Flutter **3.44.x stable**, Dart 3.x | Windows x64 |
| Renderer | **Skia** (default) + shader warm-up | Impeller-Windows behind experimental flag |
| UI kit | **fluent_ui** + **flutter_acrylic** + **window_manager** | Fluent chrome; custom content on top |
| Icons | **fluentui_system_icons** | Plus custom marks where needed |
| Typography | **Plus Jakarta Sans** (bundled, license-checked) | Brand typeface |
| State / DI | **Riverpod** (with codegen) | Feature-scoped providers |
| Audio | **media_kit** (`media_kit`, `media_kit_libs_audio`, `media_kit_native_event_loop`) | libmpv; gapless, EQ, crossfade |
| Database | **Drift** (SQLite) | WAL mode; migrations; relational library |
| InnerTube / extraction | **Custom Dart InnerTube client** + **youtube_explode_dart** (stream URLs) + optional **yt-dlp.exe** fallback | Core of the app (§6) |
| Media controls | **smtc_windows** (needs rustup) | SMTC overlay + media keys |
| Global hotkeys | **hotkey_manager** (or equivalent) | Media keys when unfocused |
| Tray | **tray_manager** | Tray icon + menu |
| Notifications | Windows toast (**local_notifier** or equivalent) | Track-change toast (toggleable) |
| Discord RPC | **dart_discord_presence** (primary), `flutter_discord_rpc` (alt) | Progress bar via timestamps |
| Lyrics | Custom LRCLIB client + InnerTube lyrics | Synced + plain |
| Secure key store | **Windows DPAPI / Credential Manager** (via FFI or `flutter_secure_storage`) | Download encryption keys (§8.3) |
| Scrobbling | **Last.fm** API client (custom) | Opt-in |
| HTTP | **dio** (interceptors, retry, backoff) | Rate-limit hygiene |
| Packaging | **NSIS** installer + portable ZIP | GitHub Releases |
| Repo mgmt | **melos** monorepo | Multi-package |
| Lints | **very_good_analysis** (or `flutter_lints`+) | Enforced in CI |

---

## 5. Architecture

### 5.1 Pattern

**Feature-first + layered.** Each feature owns `presentation / domain / data`. Cross-cutting concerns live in shared packages. The fragile InnerTube/extraction layer is isolated behind **interfaces** so it can be swapped without touching UI. Riverpod provides DI and state; UI depends on domain abstractions, never on concrete network/db types.

### 5.2 Monorepo layout (melos)

```
fluent-music/
├─ Masterdoc.md                  # this file (source of truth)
├─ melos.yaml
├─ docs/                         # generated & maintained by Claude Code
│  ├─ architecture.md
│  ├─ extraction.md              # the extraction layer, client identities, remote config
│  ├─ stack.md                   # pinned versions + lockfile notes
│  ├─ phases.md                  # living phase tracker + DoD checklists
│  ├─ deviations.md              # Deviation Protocol log
│  ├─ remote-config.md           # schema + signing + how to push a fix
│  ├─ testing.md
│  ├─ security-privacy.md
│  └─ setup.md                   # dev environment + secrets
├─ scripts/
│  ├─ setup-dev.ps1              # provisions Flutter, VS C++ workload, rustup, NSIS
│  └─ make-portable.ps1          # produces the portable .exe build for a phase gate
├─ packages/
│  ├─ core/                      # Result types, logging, errors, utils, constants
│  ├─ innertube_client/          # pure-Dart InnerTube: request builder, client identities, endpoints
│  ├─ extraction/               # stream resolution, fallback chain, PO-token slot, yt-dlp adapter
│  ├─ audio_engine/             # media_kit wrapper: queue, gapless, crossfade, EQ, normalization
│  ├─ database/                 # Drift schema, DAOs, migrations, encrypted-download store
│  ├─ media_integration/        # SMTC, media keys, tray, toast, Discord RPC, startup
│  └─ remote_config/            # signed-config fetch/verify/apply, self-healing
└─ app/                          # the Flutter application (UI, features, Riverpod wiring)
   └─ lib/
      ├─ features/               # feature-first: home/ explore/ search/ artist/ album/
      │                          #   library/ playlists/ now_playing/ lyrics/ downloads/
      │                          #   settings/ onboarding/ auth/ diagnostics/
      ├─ design_system/          # theme, dynamic color, density, motion, typography, shared widgets
      ├─ app_shell/              # window chrome, navigation, layout scaffolding
      └─ main.dart
```

Pure-Dart packages (`core`, `innertube_client`, `extraction`, `database`, `remote_config`, most of `audio_engine`) must be **unit-testable without Flutter**.

### 5.3 Error / result modeling

- Use **typed results** — sealed classes / `Result<T, E>` (e.g. `sealed class ExtractionResult`) rather than throwing across layers. This makes the **fail-loud-but-graceful** philosophy (§15.3) structural, not incidental.
- Domain errors are explicit enums/sealed types carrying enough context for the diagnostics surface and logs.
- Only truly exceptional/unrecoverable conditions throw; everything expected is a typed result.

---

## 6. The Extraction Layer (the heart — build for survival)

> This is the single highest-risk, highest-value subsystem. Isolate it, test it hardest, and make it remotely fixable. Detailed design lives in `/docs/extraction.md`.

### 6.1 Responsibilities

- Talk to **InnerTube** for browse/search/home/artist/album/playlist/lyrics/radio surfaces.
- Resolve a playable **audio stream URL** for a given track (Opus preferred, AAC fallback).
- Survive YouTube changes with **layered fallbacks**, **remote config**, and **diagnostics**.

### 6.2 Client-identity strategy

- Maintain a **pool of InnerTube client identities** (e.g. TV/embedded, Web/WEB_REMIX, iOS, Android VR, and additional layers beyond these) with their required context, headers, and params.
- The **active set, order, and params are driven by remote config** (§6.5) so identities can be added/removed/reordered without an app update.
- **Parallel race with tunable stagger:** by default, fire the candidate clients **in parallel** and take the first that returns a usable stream (fastest load). Expose a **stagger/throttle** knob (delay between launches, max concurrency) so we can dial back toward sequential if YouTube pushes back on request volume. Default = parallel; safe fallback = staggered.
- **Add "few more layers"** beyond the standard clients (per author intent): include as many viable client identities as are known-good, all participating in the race per remote-config ordering.

### 6.3 Fallback chain (per playback attempt)

Ordered, each layer tried per remote-config policy; first success wins:

1. Pure-Dart InnerTube + **youtube_explode_dart** stream resolution across the racing client identities.
2. Alternate client identities / params from remote config.
3. **PO-token-assisted** resolution via the pluggable provider slot (§6.4) — *experimental in V1, default off*.
4. **yt-dlp.exe** adapter (§6.7) — *opt-in fallback, default off* — last resort, most robust.
5. Typed failure → §6.8 behavior.

### 6.4 PO Token provider (pluggable slot; experimental V1)

- Architect a **`PoTokenProvider` interface** from day one, even though the default implementation is **off/no-op** in V1.
- Allow a user to point at their **own local PO-token provider** (bgutil/YTubic-style) via settings. Support GVS/session token injection where a client identity requires it.
- Mark this an **experimental feature** in the UI. Never block core playback on it.

### 6.5 Remote self-healing config (day-one, core)

- On launch (and periodically), fetch a small **signed JSON** hosted on the GitHub repo/Releases describing: active client identities + order + context/params, race stagger defaults, PO-token policy, extraction tweaks, and a config schema version.
- **Verify the signature** (public key shipped in-app) before applying; fall back to the last-known-good/embedded config on failure. Cache it locally.
- When YouTube breaks something, the author updates **that file** and every user self-heals within hours — **no reinstall**. Document the push procedure in `/docs/remote-config.md`.
- Config is **additive and safe**: a malformed/incompatible config never bricks playback; the app degrades to embedded defaults and surfaces it in diagnostics.

### 6.6 Songs vs. video entities

- YT Music has official "song" entities and "video" entities. **Extract and play audio from both** (some tracks exist only as videos).
- **Never render video.** Always resolve to an **audio-only** stream. Prefer the song/audio version when both exist; otherwise use the video's audio track.

### 6.7 yt-dlp adapter (opt-in fallback)

- Optionally bundle/download **yt-dlp.exe** as a last-resort extraction backend (it self-updates and is the most aggressively-maintained extractor alive).
- **Default off.** When enabled, invoke as an external process behind the `extraction` interface; parse its JSON output; never expose its internals to the UI. Adds ~30 MB — keep it optional.

### 6.8 Failure behavior (hybrid, fail-loud)

- Per author decision, playback failure handling is **hybrid**: attempt the full fallback chain and quality step-downs first; if a track is still unplayable, **communicate clearly (fail loud)** *and* keep the session moving (offer/skip to next per setting).
- Provide a consistent typed failure that carries which layers were tried and why, feeding the diagnostics surface (§15.5) and logs.

### 6.9 Rate-limit & bot-detection hygiene (first-class)

- Realistic request pacing, **caching to minimize calls**, rotating **visitor IDs**, honoring **backoff/Retry-After**, exponential backoff with jitter, and per-host concurrency caps. Implement via dio interceptors in `core`/`extraction`. Protects against soft-bans.

---

## 7. Audio Engine

Wraps **media_kit** behind an `AudioEngine` interface in `packages/audio_engine`.

- **Formats:** Opus preferred, AAC fallback on error. Default to **highest available** bitrate; quality selector (Low/Med/High) in settings.
- **Gapless** playback (native mpv). **Crossfade** between tracks — configurable seconds, default off, user-toggle + duration slider.
- **Queue:** full model — play-next vs. add-to-queue, reorder (drag-drop), clear, save-queue-as-playlist, up-next view, history. Shuffle (true + smart) and repeat (off/all/one).
- **Prefetch:** pre-buffer the **next** track for instant transitions. Prefetch depth is **reduced in Low-Spec mode** (§13) and tunable.
- **Equalizer:** 10-band graphic EQ via mpv audio filters, with presets (Bass Boost, Vocal, Flat, etc.) + custom. Fully controllable from Settings.
- **Loudness normalization:** ReplayGain-style volume leveling (mpv `af` loudnorm/replaygain), toggleable.
- **Playback speed** control.
- **Playback caching:** cache streamed (non-downloaded) audio temporarily so replaying a recent song doesn't re-fetch. **Size-limited** (default ~2 GB, configurable). HDD-friendly writes (§13).
- **Radio/autoplay:** when the queue ends, auto-continue with a **YT Music "radio"** (endless related tracks based on the last song). Toggleable.
- **Resume:** remember queue + exact position across restarts.
- Exposes reactive streams (position, duration, buffering, track, state, errors) for UI, SMTC, and Discord RPC.

---

## 8. Data Layer, Downloads & Encryption

### 8.1 Database (Drift / SQLite)

- Relational schema for: tracks, artists, albums, playlists (synced + local), likes/library, play history, downloads, cache index, settings, accounts, lyrics cache, remote-config cache.
- **WAL mode** and HDD-friendly access patterns (§13). Automatic **migrations** on version upgrade so users never lose library/downloads/playlists.

### 8.2 Downloads

- **Raw storage** of the streamed Opus/M4A (no re-encode; best quality/speed) with embedded metadata + artwork. A **transcode fallback path** exists for cases where raw isn't viable.
- **Default to highest** download quality, with a **quality slider** (independent of stream quality).
- **Parallel downloads in batches** with a **queue + progress**, pause/resume, cancel, delete, "re-download if source changed."
- **Auto-download**: "make available offline" toggles for liked songs and specific playlists.
- **Downloads view:** storage used, per-item status/progress, management actions.
- **Location:** a **hidden, obfuscated app-managed folder** (not user-browsable), DB-tracked. (No Explorer-visible library tree — per author decision.)

### 8.3 Encryption (hidden + obfuscated + encrypted)

- Encrypt **audio + metadata + artwork** for downloads.
- **Keys derived per-install** and stored in **Windows DPAPI / Credential Manager**, tied to the user's Windows account → copied files can't be played on another PC/account.
- **Playback of encrypted files:** primary path is a **local decrypting proxy** — an in-process localhost server streams decrypted bytes to media_kit so **plaintext never hits disk**. Fallback path: **decrypt-to-temp** on play (simpler; transient temp file), used only if the proxy path fails. Obfuscate filenames/structure in the managed folder.

---

## 9. Authentication

### 9.1 Modes

- **Anonymous** — fully usable with zero login (search, play, radio, local playlists, local likes).
- **Signed-in** — personalized Home, your playlists, likes, library, subscriptions, recently played, saved albums (all of it).

### 9.2 Primary: OAuth (TV/device flow)

- In-app **device-code** screen ("go to google.com/device, enter CODE").
- Ship a **built-in installed/TV OAuth client ID/secret** (treated by Google as non-confidential for installed clients) so users just click "sign in." Handle the Nov-2024 requirement (client id/secret + YouTube Data API). Store tokens via secure storage; auto-refresh.

### 9.3 Fallback: cookie/header import

- Guided **cookie-import** screen (browser session headers) for when OAuth is unavailable or insufficient. Valid ~2 years. Fullest library access.

### 9.4 Multi-account

- Support **multiple signed-in accounts** with switching. Each account's library/state is namespaced in the DB.
- **Relogin UX:** when a session expires or is rejected, surface a clear, non-blocking re-login prompt (part of the fail-loud philosophy).

### 9.5 Playlist sync semantics (local-only edits)

- Signed-in users see their real YT Music playlists. **Editing a synced playlist stays local** — it creates a **local fork/override** that diverges from the account copy; changes are **never pushed back** to YouTube. The UI must make the "local override" state explicit so divergence is never confusing.

---

## 10. Feature Catalogue (all in V1)

Search: songs, albums, artists, playlists, community/public playlists — all searchable; **autocomplete/suggestions** as you type; local **search history**.

Home: full **personalized YT Music Home** (mixes, listen-again, moods, charts) when signed in; graceful charts/explore fallback when logged-out or degraded.

Explore: charts, moods/genres, new releases.

Artist pages: **full experience** — top songs, albums, singles, related artists, bio, "shuffle artist."

Album pages: **full** — tracklist, play/shuffle, add-to-library, download-whole-album.

Library: liked songs, your playlists, subscribed artists, uploaded music (read), recently played, saved albums. **Sort** (recently-added / alphabetical / artist / most-played) and **filter** (e.g. downloaded-only).

Playlists: synced + **purely-local** playlists (created in-app, never uploaded), clearly distinguished. Create, rename, reorder (drag-drop), remove tracks, delete. Edits to synced = local-only (§9.5).

Likes / "add to library": mirror YT Music like/library; also works in **anonymous** mode (stored locally).

Import/Export: import playlists from CSV/JSON/M3U; export library/playlists to file for backup (portability — good open-source citizenship).

Play history & recently played: tracked locally, with a history view; feeds "listen again."

Lyrics: **synced** (karaoke line-highlight, auto-scroll, tap-line-to-seek) on full-screen now-playing; plain fallback; lyrics-only mode + larger-typography option; cached with downloads for offline. Source order: **YT Music native → LRCLIB synced → plain → none.**

Radio/autoplay: YT-Music-style endless radio when queue ends (§7).

Discord Rich Presence: album art + song + artist + **progress bar**; toggle; **private-session** toggle to hide what's playing; optional "listen"/deep-link button; graceful when Discord isn't running.

Scrobbling: **Last.fm** integration (opt-in).

Notifications & tray: Windows **toast on track change** (art + title, **toggleable** — off-able for those who find it noisy); **tray icon** with right-click mini-controls + hover preview.

Queue management: play-next / add-to-queue, reorderable up-next, save-as-playlist, clear, history; shuffle (true/smart) + repeat (off/all/one).

Keyboard: full control (space=play/pause, arrows=seek/volume, Ctrl+F=search, Ctrl+L=lyrics, N/P=next/prev, etc.), discoverable cheat-sheet (Ctrl+/), **all rebindable**.

---

## 11. UI / UX Design System

### 11.1 Position on the Fluent↔custom spectrum

**Fluent window chrome + navigation, but custom-designed content areas** (player, cards, now-playing) for Apple-Music-grade polish. Not strict-fluent-everywhere; not fully-custom. Fluent for the frame; custom for the content.

### 11.2 Window chrome

- Custom owner-drawn **title bar** (integrated search + window buttons, Spotify-like) via `window_manager` + `fluent_ui` `TitleBar`.
- **Backdrop:** offer **both Mica and Acrylic** as a user choice. (Both are GPU-costly on weak hardware → auto-flattened in Low-Spec mode, §13.)

### 11.3 Navigation

- **Hybrid** navigation: left Fluent **NavigationPane** (Home / Explore / Library / Settings …) combined with contextual top elements where it improves flow. Persistent access to search and the now-playing bar.

### 11.4 Now-Playing experience (hybrid)

- **Persistent bottom bar** (Spotify-style: art, title/artist, controls, seek, queue/lyrics/volume affordances) that **expands into a full-screen now-playing** view (Apple-Music-style: big art, dynamic-color background, synced lyrics, queue). Both, integrated. **No separate mini-player window** (§2).

### 11.5 Theming

- **Dark only.** No light mode.
- **Dynamic color extracted from track artwork** tints the now-playing surface/backgrounds (premium, Apple-Music/Material-You-like). Must be tasteful and legible on dark.
- **Toggleable accent color** (custom or follow Windows accent), always over a dark base.
- Architect a **theming engine** capable of art-driven dynamic theming now and user-swappable themes later (long-term), but ship **dark-only** in V1.

### 11.6 Density

- **Three toggleable density modes:** **Hybrid**, **Apple-Music (spacious)**, **Power-User (compact/dense)**. Fully controllable from Settings.

### 11.7 Motion

- **Lush + animated** — shared-element album-art transitions, blur/opacity fades, springy micro-interactions. But: **respect Windows "reduce motion"** and **auto-tone-down in Low-Spec mode**. Use `RepaintBoundary`, const widgets, cheap shaders; precompile/warm-up shaders to avoid first-run jank on Skia.

### 11.8 Typography & icons

- **Plus Jakarta Sans** as the brand typeface (bundled, license verified).
- **Fluent System Icons**, plus custom marks where brand identity needs it.
- Art & color: dominant-color extraction from artwork drives dynamic theming (§11.5).

---

## 12. Windows Integrations

- **SMTC** (System Media Transport Controls) overlay with art, title/artist, play/pause/next/prev, **seek**, and timeline — via `smtc_windows` (needs rustup at build).
- **Global media keys** — respond even when unfocused (global hotkeys). Plus custom rebindable global hotkeys.
- **System tray** — icon, right-click mini-controls, hover preview, show/hide window.
- **Taskbar thumbnail buttons** (play/pause/next/prev).
- **Toast on track change** — toggleable.
- **Close-to-tray vs. quit** — configurable; keep playing when closed-to-tray.
- **Launch-on-Windows-startup** — optional.
- **Resume** queue + position across restarts.

---

## 13. Low-Spec / "Potato" Mode

**Target reference hardware: Intel Core i3-3110M, 4 GB DDR3, HDD, Intel HD 4000 (2012).** Fluent Music must run **buttery smooth** on this.

- **Auto-detect** low hardware and enable Low-Spec mode; **user can override** (turn it off if their old hardware handles full mode fine, or force it on).
- In Low-Spec mode: **disable Acrylic/Mica** (flat surfaces), **reduce animation count/duration**, **lower artwork resolution** + aggressive image cache, **reduce prefetch depth**, **cap memory**, and use **HDD-friendly sequential IO** + **SQLite WAL**.
- **Full mode must still be lean enough to run on the reference laptop** — just prettier. The difference between modes is polish cost, not "works vs. doesn't."
- HDD specifics: batch/sequential writes for cache & downloads; avoid random-IO storms; lazy image decode; bounded concurrent disk ops.
- Everything Low-Spec toggles is also exposed individually in Settings (§16) so the user can hand-tune.

---

## 14. Performance Budget (testable targets)

Hold Claude Code to these; validate on the reference laptop at each phase gate:

| Metric | Modern hardware | Reference i3/4GB/HDD |
|---|---|---|
| Cold start | ≤ ~2 s | as fast as feasible; no multi-second freeze |
| Idle memory | < 150 MB | keep tight; well under Electron-class 300 MB+ |
| Scrolling | 60 fps min (120 on high-refresh) | smooth 60 fps in Low-Spec mode |
| Track start (cached) | near-instant (prefetch) | responsive |
| First-run jank | none (shader warm-up) | none |

Each phase's portable build is copied to the reference laptop and must not regress these.

---

## 15. Reliability & Longevity

### 15.1 Remote self-healing config — §6.5 (core, day-one).
### 15.2 yt-dlp fallback layer — §6.7 (opt-in).
### 15.3 Fail-loud-but-graceful — global philosophy: never fail silently. Surface degraded/blocked/rate-limited/expired states clearly (e.g. "personalized Home unavailable — showing charts"), keep the app usable, and provide relogin/retry affordances. Applies everywhere, not just playback.
### 15.4 Telemetry — **zero telemetry by default.** **Local-only logs** the user can view/export to attach to a GitHub issue, **plus opt-in anonymous crash reporting** (clearly consented, self-hosted or privacy-respecting). Never phone home without opt-in.
### 15.5 In-app diagnostics — a Diagnostics screen: which extraction client succeeded, current remote-config version, cache/DB health, "test playback" button, "copy debug info for bug report."
### 15.6 Graceful degradation — consistent "degraded but working" behavior with clear messaging (part of fail-loud).
### 15.7 Rate-limit hygiene — §6.9.

---

## 16. Settings (everything is controllable from Settings)

Full Fluent settings area. Sections (non-exhaustive; **any behavior in this doc must be reachable from Settings**):

Playback (crossfade, gapless, speed, radio/autoplay, resume, skip-on-fail behavior) · Audio/EQ (10-band EQ + presets, loudness normalization, quality selector) · Downloads (quality slider, parallel/batch settings, auto-download toggles, storage) · Appearance/Theme (Mica/Acrylic choice, dynamic color, accent color, density mode) · Motion (animation level, respect reduce-motion) · Account(s) (sign-in, multi-account switch, cookie import, private session) · Network/Extraction (client-race stagger, PO-token provider slot [experimental], yt-dlp fallback toggle, remote-config status) · Performance (Low-Spec mode auto/on/off + individual toggles, prefetch depth, cache size) · Hotkeys (all rebindable + cheat-sheet) · Storage/Cache (sizes, clear) · Updates (channel: Stable/Beta, auto-check, delta) · Privacy/Logs (local logs view/export, opt-in crash reporting, Discord private session) · Discord RPC · Scrobbling (Last.fm) · Lyrics (source order, size, lyrics-only) · Offline (auto/manual) · About (version, license, credits, diagnostics link).

---

## 17. Onboarding (first-run)

Short first-run flow: choose **anonymous vs. sign-in** → pick **theme/accent/density** → set **download folder & quality** → **hardware-detect for Low-Spec mode** (with override) → into Home. Skippable to sensible defaults.

---

## 18. Accessibility & Localization

- **Accessibility matters a lot** (author priority): screen-reader labels, full keyboard-only navigation, **respect Windows reduce-motion** (auto-tones lush animations), adjustable text scaling, high-contrast awareness, visible focus.
- **i18n:** English-only content in V1, but **architected for translation** — all user-facing strings externalized/extractable (e.g. `flutter gen-l10n`/ARB), community-translatable later. (Bengali and others can be added post-V1.)

---

## 19. Engineering Standards

- **Result/typed-error modeling** (§5.3) — no throwing across layers for expected failures.
- **Testing (pragmatic-but-strong on the fragile/critical layers):** hard unit tests for `innertube_client`, `extraction`, parsing, `database`, `remote_config`; widget tests for key UI; a CI **integration smoke test that actually resolves + plays a track**. UI tested lightly, fragile layers tested hard. Details in `/docs/testing.md`.
- **Lints:** `very_good_analysis` (or `flutter_lints`+) enforced in CI; **format-on-commit**; **conventional commits**; `CONTRIBUTING.md`.
- **Dependencies:** established/popular packages for audio/UI/db core; **custom code for the fragile InnerTube layer**. Justify each new dependency in `/docs/stack.md`.
- **Docs output:** maintain `/docs/*` (architecture, extraction, remote-config, testing, security-privacy, setup, deviations, phases), inline API docs, and a README with screenshots. Docs are refreshed **every phase** so they never lag code.

---

## 20. Phased Roadmap (build order + Definition of Done)

**V1 = all phases P0–P10 complete, working, debugged, tested, and polished.** No MVP; but build in this order. Each phase: (a) meets its DoD, (b) refreshes relevant `/docs`, (c) **emits a portable `.exe` build** (`scripts/make-portable.ps1`) for reference-laptop testing, (d) produces a phase report, (e) **pauses for human approval** before the next phase (§0.3). Deviations logged (§0.2).

### P0 — Scaffold, dev-env, CI
Monorepo (melos), package skeletons, `core` (Result/logging/errors), lints, `setup-dev.ps1` (Flutter 3.44.x, VS C++ workload, **rustup**, NSIS), `make-portable.ps1`, GitHub Actions (build Windows, run tests, produce portable artifact), base `/docs`.
**DoD:** clean `flutter build windows` in CI; empty app window launches; portable zip produced; docs scaffolded.

### P1 — InnerTube + extraction core
`innertube_client` (client-identity pool, request builder, search/browse endpoints), `extraction` (stream resolution via youtube_explode_dart, **parallel-race + fallback chain**, PO-token *interface* [off], yt-dlp adapter *stub* [off]), `remote_config` (signed fetch/verify/apply + embedded default), rate-limit hygiene. CLI/test harness: **search → resolve → play a track's audio** headless.
**DoD:** given a query, returns results and **resolves a playable audio URL** across racing clients; remote config verified+applied; unit + integration smoke tests green.

### P2 — Audio engine + core system integration
`audio_engine` (media_kit: play/pause/seek/volume, **queue**, **gapless**, prefetch, resume), **SMTC**, **global media keys**, playback cache.
**DoD:** full queue playback with gapless, working SMTC overlay + media keys, resume across restart; smooth on reference laptop.

### P3 — UI shell + design system
App shell: custom title bar + window_manager, hybrid navigation, **dark-only theme**, **dynamic color engine**, **3 density modes**, motion system + shader warm-up, Plus Jakarta Sans, Mica/Acrylic choice, persistent now-playing bottom bar + full-screen now-playing scaffold.
**DoD:** navigable shell, dynamic color from art, density switch, lush motion that respects reduce-motion; passes perf budget on reference laptop.

### P4 — Content surfaces
Home (personalized + fallback), Explore/charts, **Search** (autocomplete + history), **Artist** (full), **Album** (full).
**DoD:** all surfaces populate from InnerTube, degrade gracefully, feel premium.

### P5 — Library, playlists, likes, history
Library (sort/filter), synced + **local playlists** (local-fork semantics), likes/add-to-library (works anonymous), play history, import/export.
**DoD:** create/edit local + synced (local-only) playlists, like/library in both modes, history + import/export working.

### P6 — Authentication
OAuth device flow (built-in client), cookie-import fallback, **multi-account** switching, relogin UX, personalized data wired in.
**DoD:** sign in via OAuth and via cookies, switch accounts, personalized Home/library load, expiry → clean relogin.

### P7 — Downloads, offline, encryption
Raw+fallback storage, **parallel batch downloads** + queue/progress, hidden/obfuscated managed folder, **encryption (audio+metadata+art) with DPAPI keys**, **decrypting-proxy playback** (+ decrypt-to-temp fallback), auto-download toggles, offline mode (auto + manual), Downloads view.
**DoD:** download → play offline from encrypted store with no plaintext on disk; auto/manual offline; copying files to another PC fails to play.

### P8 — Lyrics, EQ, crossfade, Discord, scrobbling, notifications, tray, hotkeys
Synced/plain lyrics (YT→LRCLIB→plain), 10-band EQ + presets + normalization, crossfade, **Discord RPC (progress bar + private session)**, Last.fm scrobbling, toast on track change (toggle), tray + taskbar buttons, startup toggle, **rebindable hotkeys + cheat-sheet**, radio/autoplay.
**DoD:** all features functional and settings-controllable; nothing forced-on that should be optional.

### P9 — Low-Spec mode + performance hardening
Hardware auto-detect + override, Acrylic/Mica auto-flatten, animation/artwork/prefetch scaling, HDD-friendly IO, memory caps, individual perf toggles, full perf pass on reference laptop.
**DoD:** meets §14 budget on the i3/4GB/HDD laptop in both modes; no jank.

### P10 — Updater, packaging, diagnostics, polish, release
**NSIS installer + portable ZIP** via GitHub Releases, in-app **update check** (Stable + Beta channels, delta = changed-assets + full-installer fallback), migrations verified, **Diagnostics screen**, local logs + opt-in crash reporting, onboarding, accessibility pass, i18n extraction, README/screenshots, GPLv3 + disclaimer, final polish.
**DoD:** signed-off installable + portable V1 that is complete, tested, debugged, and polished on both modern and reference hardware.

---

## 21. Build Environment, CI/CD, Packaging, Updates

- **Dev env (`scripts/setup-dev.ps1`):** Flutter 3.44.x stable, Visual Studio **Desktop development with C++** workload, **rustup** (for smtc_windows / any flutter_rust_bridge deps), **NSIS**, plus `flutter pub get` + `build_runner`. Reproducible on any machine/CI.
- **CI (GitHub Actions, `windows-latest`):** checkout → flutter-action (3.44.x) → pub get → build_runner codegen → analyze/lint → test (incl. integration smoke) → `flutter build windows --release` → package (NSIS + portable zip) → upload artifact; on tag → `action-gh-release`.
- **Packaging:** **NSIS** installer (`makensis` script) + **portable ZIP** (bundle folder). Unsigned initially (SmartScreen warning accepted); Azure Trusted Signing later.
- **Updater:** in-app check against GitHub Releases API; channels **Stable + optional Beta**; **delta = download only changed assets with full-installer fallback** (bsdiff-style binary patching is a later enhancement); one-click download + apply.
- **Migrations:** DB/settings auto-migrate on update; never lose user data.

---

## 22. Secrets Handling (open repo)

- No real secrets in the repo. **Placeholders + `.env`/secrets pattern**; real values (OAuth client id/secret, signing cert, Last.fm key, remote-config signing) injected at build via **GitHub Actions secrets**; documented in `/docs/setup.md`.
- The **remote-config signing public key** ships in-app; the **private key never touches the repo**.
- Installed/TV OAuth client secret is treated as non-confidential per Google's model but still injected via CI, not committed.

---

## 23. Security & Privacy

- Download encryption + DPAPI-bound keys (§8.3); decrypting-proxy playback.
- No telemetry by default; local logs; opt-in anonymous crash reporting only (§15.4).
- Discord **private session** + toast/RPC toggles for presence privacy.
- Secure token storage for accounts; clean sign-out wipes namespaced data.
- Documented in `/docs/security-privacy.md`.

---

## 24. Legal / Repo Posture

- **License: GPLv3** (copyleft — keeps forks open).
- README disclaimer: educational/personal use; **not affiliated with or endorsed by YouTube/Google**; users responsible for complying with YouTube ToS; InnerTube is unofficial/reverse-engineered and may break.
- No bundled Google API keys beyond the installed OAuth client; no bundled copyrighted assets; verify the Plus Jakarta Sans license before bundling.
- `CONTRIBUTING.md`, issue templates (with "copy debug info" guidance), `SECURITY.md`.

---

## 25. Appendix A — Key Design Decisions (quick reference)

- Music-only; audio-only playback (incl. from video entities); never render video.
- Windows-only; no MVP but phased to a full V1.
- Extraction: custom InnerTube + youtube_explode_dart + optional yt-dlp; **parallel-raced clients + remote self-healing signed config** = longevity backbone.
- PO-token provider slot present but **experimental/off** in V1.
- Audio: media_kit/libmpv; Opus-first/AAC-fallback; highest quality default; gapless + crossfade + EQ + normalization + radio.
- Downloads: raw+fallback, parallel/batch, hidden/obfuscated/**encrypted** (DPAPI), decrypting-proxy playback.
- Auth: OAuth (built-in client) + cookie fallback; multi-account; synced-playlist edits **stay local**.
- UI: Fluent chrome + custom premium content; **dark-only** + art-driven dynamic color + toggle accent; Mica/Acrylic choice; **3 density modes**; **lush motion**; Plus Jakarta Sans.
- Windows: SMTC, media keys, tray, taskbar buttons, toast (toggle), startup, close-to-tray, resume. **No mini-player.**
- Discord RPC (progress bar + private session), Last.fm scrobbling, LRCLIB+native synced lyrics.
- **Low-Spec/Potato mode** (auto + override) targeting a 2012 i3/4GB/HDD laptop; full mode also runs there.
- Reliability: fail-loud-but-graceful everywhere, diagnostics, rate-limit hygiene, local logs + opt-in crash reporting.
- Engineering: melos monorepo, feature-first + layered, Riverpod, Drift, typed results, strong tests on fragile layers, very_good_analysis, conventional commits.
- Delivery: GitHub Actions → NSIS + portable → GitHub Releases; in-app updater (Stable/Beta, delta+full fallback); unsigned initially.

## 26. Appendix B — Open Risks

- YouTube extraction breakage (mitigated by remote config, layered/parallel clients, yt-dlp fallback, diagnostics).
- PO-token/SABR escalation (mitigated by pluggable provider slot; may need to graduate from experimental).
- Impeller-Windows maturity (on Skia now; revisit when stable).
- NSIS delta-update complexity (ship changed-assets+full-installer first; bsdiff later).
- SmartScreen friction while unsigned (accepted; Azure Trusted Signing later).
- fluent_ui single-maintainer risk (isolate UI on design_system abstractions).

---

*End of Masterdoc. This file is authoritative. When reality and this document disagree, follow the Deviation Protocol (§0.2), log it, correct it, and keep the doc in sync.*
