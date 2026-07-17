# Remote Config

> Stub written at Phase 0. Fetch/verify/apply lands in Phase 1 (Masterdoc §6.5, §20 P1) — this records the intended shape so `packages/remote_config`'s Phase 0 skeleton (`RemoteConfig`, `RemoteConfigVerifier`) has a spec to implement against.

## Purpose

Extraction self-healing (§6.5): a small, signed JSON payload hosted on the GitHub repo/Releases that describes the active InnerTube client identities, their order, race-stagger defaults, PO-token policy, and a schema version. When YouTube breaks something, the author updates this file and every user self-heals within hours — no reinstall.

## Current Phase 0 shape (`packages/remote_config`)

- `RemoteConfig` — data class: `schemaVersion`, `clientIdentityOrder`, `raceStaggerMs`, `poTokenEnabled`. Has a `RemoteConfig.embeddedDefault` constant — the safe fallback the app ships with and falls back to on any verification failure.
- `RemoteConfigVerifier` — interface: `verify({payload, signature}) -> bool`. No implementation yet.

## Planned for Phase 1

- JSON schema + versioning strategy (additive-only; unknown fields ignored, not fatal).
- The actual signing scheme (asymmetric; public key shipped in-app, private key never in the repo — §22) and `RemoteConfigVerifier` implementation.
- Fetch-on-launch + periodic refresh via `dio`, with local caching so the app works offline using the last-known-good config.
- The push procedure for the author: how to publish an updated signed config to GitHub Releases and what to verify before publishing (this section should be filled in with concrete steps once the signing tooling exists).
- Failure semantics: malformed/incompatible config must never brick playback — always degrade to `RemoteConfig.embeddedDefault` and surface the degradation via the diagnostics surface (§15.5).
