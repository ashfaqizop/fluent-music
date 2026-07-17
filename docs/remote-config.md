# Remote Config

Signed, self-healing remote configuration (Masterdoc §6.5, §20 P1). Implemented at Phase 1 — this document now describes the real, shipped mechanism.

## Purpose

Extraction self-healing: a small, signed JSON payload describing the active InnerTube client identities, their order, race-stagger defaults, PO-token policy, rate-limit tuning, and a schema version. When YouTube breaks something, the author updates this file and every user self-heals within hours — no reinstall.

## Schema (v2)

`packages/remote_config/lib/src/remote_config.dart`:

| Field | Type | Meaning |
|---|---|---|
| `schemaVersion` | int | Parsing/compatibility version. |
| `clientIdentityOrder` | `List<String>` | Client identities eligible for the race, in priority order. |
| `raceStaggerMs` | int | Delay between staggered race-lane launches (`0` = fully parallel). |
| `poTokenEnabled` | bool | Whether the experimental PO-token slot is enabled (no real effect yet — §6.4). |
| `disabledIdentities` | `Set<String>` | Identity names to skip without removing them from `clientIdentityOrder`. |
| `identityOverrides` | `Map<String, ClientIdentityOverride>` | Per-identity `clientVersion`/`priority` patches. |
| `maxConcurrentRaceLanes` | int | Cap on simultaneous race lanes (`0` = unlimited). |
| `raceLaneTimeoutMs` | int | Per-lane timeout, ms. |
| `rateLimit` | `RateLimitPolicyConfig` | `minRequestIntervalMs`, `maxConcurrencyPerHost`, `backoffBaseMs`, `backoffMaxMs`, `backoffJitterRatio`. |
| `refreshIntervalMinutes` | int | Background re-fetch interval. |

`RemoteConfig.fromJson` is additive and safe: unknown fields are ignored, missing fields fall back to `RemoteConfig.embeddedDefault`'s values, and it never throws — a malformed/incompatible payload is rejected by the *caller* (signature/schema checks upstream in `RemoteConfigFetcher`), not by parsing itself. A schema-v1-shaped payload (the Phase-0 shape) still parses, synthesizing safe defaults for every v2-only field.

## Signing scheme

**Ed25519** via `package:cryptography` (pure-Dart, no native/FFI dependency — keeps `remote_config` buildable/testable without extra native toolchain setup). `crypto` (hash-only, already a Phase-0 dependency) can't do asymmetric signatures, so it's now repurposed for a cheap SHA-256 "did the payload change" short-circuit in the local cache rather than dropped.

- `canonical_json.dart` recursively sorts JSON object keys before encoding, so the signer and verifier always hash identical bytes regardless of source `Map` iteration order.
- `signing_public_key.dart` ships the **public** key (32 bytes, safe to commit) as `RemoteConfigSigningKey.publicKeyBytes`.
- `Ed25519RemoteConfigVerifier` (implements `AsyncRemoteConfigVerifier` — a small async-first sibling to the Phase-0 `RemoteConfigVerifier` sync interface, since `package:cryptography`'s verification is inherently `Future`-based) verifies a payload+signature pair against that public key.

### Key generation & custody (§22 — private key never in the repo)

1. `dart run packages/remote_config/tool/generate_signing_key.dart` generates a fresh Ed25519 keypair and prints both halves.
2. The **public** key bytes are pasted into `signing_public_key.dart` and committed.
3. The **private** key (base64) is stored as the `REMOTE_CONFIG_PRIVATE_KEY` GitHub Actions secret (`gh secret set REMOTE_CONFIG_PRIVATE_KEY --repo ashfaqizop/fluent-music`) and never written to any file in the repo or working tree.

This has already been done for the real production keypair as part of Phase 1 — the public key in `signing_public_key.dart` is real, and `REMOTE_CONFIG_PRIVATE_KEY` is set on the repo.

### Publishing an updated config

1. Edit the plaintext payload at `remote-config/remote_config.json`.
2. Sign it: `dart run packages/remote_config/tool/sign_config.dart --in remote-config/remote_config.json --private-key-b64 "$REMOTE_CONFIG_PRIVATE_KEY" --out remote-config/remote_config.signed.json`.
3. Commit `remote-config/remote_config.signed.json` (the signed artifact is public by design — only the private key is secret) and merge to `main`.
4. The app fetches from a `main`-pinned `raw.githubusercontent.com` URL (`RemoteConfigFetcher.defaultRemoteConfigUrl`), so the fix is live for every user as soon as the merge lands — no reinstall, no release.

**Hosting choice, logged as a deviation:** the Masterdoc says "hosted on the GitHub repo/Releases" (offering both). This implementation uses an **in-repo file** (`remote-config/remote_config.signed.json`) rather than a GitHub Release asset — simpler to publish for a solo maintainer (one `git push` vs. round-tripping the Releases API), and git history gives a free audit trail of every config change. See `docs/deviations.md`.

## Fetch / verify / apply / cache

`RemoteConfigFetcher.fetchAndApply()`:

1. GET the signed envelope JSON from the pinned URL.
2. Canonicalize the `payload` and verify `signature` against the shipped public key.
3. On success: parse via `RemoteConfig.fromJson`, cache it (`RemoteConfigCache`, a pure `dart:io` file store — Flutter-free so it stays unit-testable; the real app will inject a `path_provider` app-support directory, tests/CLI use a temp directory), and return it.
4. On **any** failure (network error, malformed envelope, bad signature) — falls back to the last cached config (`RemoteConfigCache.readLastKnownGood()`), or to `RemoteConfig.embeddedDefault` if no cache exists yet. **Never throws.** This is the concrete mechanism behind §6.5's "a malformed/incompatible config never bricks playback."

## Verification

The full chain (generate key → sign → verify) was manually exercised during Phase 1: a real keypair was generated, the public key embedded, the private key pushed as a GitHub secret, `remote-config/remote_config.json` authored and signed, and the resulting signed artifact verified against the embedded public key. `packages/extraction/bin/smoke.dart` exercises `fetchAndApply()` against the real pinned URL on every run.
