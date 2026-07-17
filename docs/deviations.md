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
