# Deviation Protocol Log

Per Masterdoc §0.2: when a spec conflicts with reality, stop, log it here (date, what the doc says, what reality is, evidence), propose a correction, and proceed only after logging. This file is the running record — never let uncorrected drift accumulate.

---

## 2026-07-17 — melos config location has moved (melos 7+)

**What the doc implies:** Masterdoc §5.2 lists a `melos.yaml` file at the repo root as part of the monorepo layout (standard for melos tutorials/examples up through melos 6.x).

**What reality is:** The current melos release (8.2.2 on pub.dev at time of writing; this repo pins the workspace-resolved 7.8.1) requires melos config to live under a `melos:` key inside the root `pubspec.yaml`, with workspace members declared via Dart/Flutter's native `workspace:` field (not melos's own `packages:` glob). A standalone `melos.yaml` is silently ignored — running `melos bootstrap` against one just fails with "Your current directory does not appear to be within a Melos workspace." melos must also be a `dev_dependency` of the root `pubspec.yaml` (its `cli_launcher` local-installation detection is how it locates the workspace root at all).

**Correction applied:** No `melos.yaml` file. Workspace members and melos scripts both live in the root `pubspec.yaml` (see `docs/stack.md` for the "why"). `docs/architecture.md`'s monorepo layout reflects this.

**Trade-off:** None significant — this is strictly the current supported configuration surface for melos; there was no working alternative that matched the Masterdoc's literal `melos.yaml` description.

---

## 2026-07-17 — `melos` + `riverpod_generator` + `drift_dev` version conflict

**What the doc implies:** §4 pins Riverpod "with codegen" and Drift, without flagging any interaction between them.

**What reality is:** Resolving the full workspace with `melos` (which requires `cli_util ^0.5.0`) alongside `riverpod_generator` and `drift_dev` (whose transitive `analyzer`/`build`/`cli_util` version ranges do not have a mutually satisfiable combination as of the packages available 2026-07-17) produces an unsolvable pub dependency graph. `drift_dev` alone resolves fine; the conflict specifically needs all three (`melos`, `riverpod_generator`, `drift_dev`) in one resolution, which pub workspaces force since there's a single shared lockfile.

**Correction applied:** Deferred `riverpod_generator` and `riverpod_annotation` — Phase 0 doesn't write any `@riverpod`-annotated code (the app only needs a bare `ProviderScope`), so there's nothing for the codegen packages to generate yet. `flutter_riverpod` (runtime) is kept. Re-add `riverpod_generator`/`riverpod_annotation` in whichever phase first defines a generated provider, and re-check this conflict at that point — the ecosystem may have moved (newer `drift_dev` releases have already been trending toward newer `analyzer` majors).

**Trade-off:** None for Phase 0 (no codegen-based providers exist yet). Future phases must re-verify this resolves cleanly before relying on `@riverpod` codegen.

---

## 2026-07-17 — `--fatal-infos` dropped from the analyze script

**What the doc implies:** §19 says "very_good_analysis (or flutter_lints+) enforced in CI" without specifying `--fatal-infos`.

**What reality is:** `very_good_analysis` is deliberately strict at the info level, including `public_member_api_docs` (dartdoc required on every public member) and stylistic preferences like `unnecessary_library_directive`. Running with `--fatal-infos` treats every one of these as a build failure.

**Correction applied:** All Phase 0 public APIs were in fact given dartdoc comments (the info-level issues were fixed, not suppressed) — `melos run analyze` is fully clean (`dart analyze .`, no `--fatal-infos`). The flag itself is left off the CI script so that future phases aren't blocked by every single missing-doc info during fast iteration; `dart analyze` still fails the build on real errors/warnings. This is a deliberate strictness choice, not a masterdoc requirement — revisit if the team wants `--fatal-infos` enforced in CI too.

**Trade-off:** Slightly less strict than maximal; real defects (errors/warnings) still fail CI either way.

---

## 2026-07-17 — two client-identity catalogs, not one unified pool

**What the doc implies:** Masterdoc §6.2 describes "a pool of InnerTube client identities" that participate in the parallel race, as a single concept shared across the extraction layer.

**What reality is:** `innertube_client` (search/browse) and `extraction` (stream resolution) hit different InnerTube surfaces through different code paths. `innertube_client` builds its own request context and can use any identity, including `WEB_REMIX` (the real identity YT Music's web player uses for search/browse). `extraction` resolves streams via `youtube_explode_dart` 3.1.0's `StreamClient.getManifest(videoId, {ytClients})`, which only accepts that library's own `YoutubeApiClient` catalog (`.ios`, `.android`, `.androidSdkless`, `.androidMusic`, `.androidVr`, `.safari`, `.tv`, `.mediaConnect`, `.mweb`) — verified by reading the installed package source. **There is no `WEB_REMIX` constant in this catalog.**

**Correction applied:** `packages/extraction/lib/src/client_identity_mapping.dart` maps remote-config identity names to `YoutubeApiClient` consts; `WEB_REMIX` has no mapping and is filtered out of the stream-resolution race only (logged at `fine`) — it remains the identity `innertube_client` uses for search/browse. See `docs/extraction.md` §2 for the full mapping table.

**Trade-off:** None significant — this reflects how the two libraries actually work; forcing a single catalog would mean either losing `WEB_REMIX` for search/browse (degrading it) or pretending `youtube_explode_dart` supports an identity it doesn't.

---

## 2026-07-17 — `AlternateIdentityLayer` is sequential, not a second race

**What the doc implies:** Masterdoc §6.3 step 2 says the fallback chain's second layer is "alternate client identities / params from remote config," implying another race-like attempt.

**What reality is:** Layer 1 (`ClientRaceLayer`) already races every identity remote config has promoted into `clientIdentityOrder`. A second identical parallel race over the same pool would be redundant.

**Correction applied:** Layer 2 (`AlternateIdentityLayer`) is instead a **sequential**, cheap long-tail safety net over identities the app knows about (`client_identity_mapping.dart`'s full catalog) that remote config hasn't promoted into `clientIdentityOrder` yet — a different, complementary role rather than a duplicate race.

**Trade-off:** None significant — this preserves the spirit of "try alternates from remote config" while avoiding pointless duplicate work.

---

## 2026-07-17 — signed remote config hosted as an in-repo file, not a GitHub Release asset

**What the doc implies:** Masterdoc §6.5 says the signed config is "hosted on the GitHub repo/Releases" (offering both options).

**What reality is:** Either works; a GitHub Release asset requires round-tripping the Releases API (create/find a release, upload an asset, get its URL) for every publish, while an in-repo file just needs a commit.

**Correction applied:** The signed config lives at `remote-config/remote_config.signed.json` in the repo, fetched via a `main`-pinned `raw.githubusercontent.com` URL. §22 only requires the **private** signing key stay out of the repo — the signed artifact itself is meant to be public, so committing it is fine, and git history gives a free audit trail of every published config change.

**Trade-off:** None significant for a solo maintainer; a GitHub Release would give versioned rollback "for free" via release tags, which this approach doesn't — revisit if that becomes valuable.

---

## 2026-07-17 — the P1 integration smoke test is CI-non-blocking

**What the doc implies:** Masterdoc §19 asks for "a CI integration smoke test that actually resolves + plays a track," implying it gates the build like other tests.

**What reality is:** This test depends on live, unversioned third-party behavior (YouTube) outside repo control — geo-blocking, soft rate-limiting, or an upstream extraction break could fail it independent of code quality, since it makes real network calls.

**Correction applied:** `packages/extraction/bin/smoke.dart` runs on every CI build (so regressions are caught immediately) but is marked `continue-on-error: true` with a visible `::warning::` annotation on failure. All real unit tests — including extraction/innertube_client/remote_config's own hard failure-path tests — remain fully hard-blocking; only this one live-network step is relaxed.

**Trade-off:** A real extraction break could land without turning CI red. Mitigated by the warning annotation being visible on every run, and by remote config's whole purpose being to fix exactly this kind of break without a code change.

---

## 2026-07-17 — "play a track's audio" interpreted as an HTTP range-fetch confirmation

**What the doc implies:** Masterdoc §20's P1 DoD says the CLI/test harness must "search → resolve → play a track's audio" headless.

**What reality is:** `audio_engine`'s `media_kit` wiring is explicitly Phase 2 scope (§20 P2) — as of Phase 1 it's still an interface-only stub with no libmpv integration. There is no audio-playback capability to call yet.

**Correction applied:** `packages/extraction/bin/smoke.dart` interprets "play" as confirming the resolved stream URL is genuinely fetchable, byte-serving audio content — it issues an HTTP range request (`bytes=0-65535`) against the resolved URL and checks for a `200`/`206` response with a non-empty body. Real audible playback via `media_kit` is Phase 2's job and will get its own, stronger smoke test then.

**Trade-off:** None significant — this is the only capability available at this point in the roadmap, and it does genuinely prove the resolved URL is playable content, just not through an actual audio pipeline yet.
