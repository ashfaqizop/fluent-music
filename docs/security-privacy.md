# Security & Privacy

> Stub written at Phase 0, tracking Masterdoc §23. Filled in incrementally as the owning phases (P6 auth, P7 downloads/encryption, P10 diagnostics/logging) land.

## Principles (from §23)

- **No telemetry by default.** Local-only logs the user can view/export; opt-in anonymous crash reporting only (§15.4). Nothing phones home without explicit opt-in.
- **Download encryption.** Audio + metadata + artwork encrypted; keys derived per-install and stored in Windows DPAPI/Credential Manager, tied to the user's Windows account (§8.3). Planned for P7.
- **Decrypting-proxy playback.** Plaintext should never hit disk during playback of downloaded content; fallback to decrypt-to-temp only if the proxy path fails. Planned for P7.
- **Secure token storage.** OAuth/cookie session data stored via secure storage; clean sign-out wipes namespaced per-account data. Planned for P6.
- **Discord privacy.** Private-session toggle to hide what's playing; toast/RPC toggles are independent settings (§16). Planned for P8.
- **Remote config signing.** The remote-config public key ships in-app; the private key never touches the repo (§22, §6.5). Planned for P1.

## Current state (Phase 0)

No user data, network calls, credentials, or encryption paths exist yet — the app is a static shell. `AppLogger` (`packages/core`) writes to stdout only; no file sink, no remote sink, no opt-in crash reporting wired up yet (that lands with the Diagnostics screen in P10, §15.5).

## Secrets handling

No real secrets are committed to this repo (§22). CI does not yet reference any secrets (no OAuth client, no signing keys, no Last.fm key) — those get added via GitHub Actions secrets when the phases that need them (P1 remote-config signing, P6 OAuth, P8 Last.fm) land. See `docs/setup.md` for the local-dev equivalent once it's needed.
