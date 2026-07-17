# Security & Privacy

> Stub written at Phase 0, tracking Masterdoc §23. Filled in incrementally as the owning phases (P6 auth, P7 downloads/encryption, P10 diagnostics/logging) land.

## Principles (from §23)

- **No telemetry by default.** Local-only logs the user can view/export; opt-in anonymous crash reporting only (§15.4). Nothing phones home without explicit opt-in.
- **Download encryption.** Audio + metadata + artwork encrypted; keys derived per-install and stored in Windows DPAPI/Credential Manager, tied to the user's Windows account (§8.3). Planned for P7.
- **Decrypting-proxy playback.** Plaintext should never hit disk during playback of downloaded content; fallback to decrypt-to-temp only if the proxy path fails. Planned for P7.
- **Secure token storage.** OAuth/cookie session data stored via secure storage; clean sign-out wipes namespaced per-account data. Planned for P6.
- **Discord privacy.** Private-session toggle to hide what's playing; toast/RPC toggles are independent settings (§16). Planned for P8.
- **Remote config signing.** The remote-config public key ships in-app; the private key never touches the repo (§22, §6.5). **Done — P1.** Ed25519 via `package:cryptography`; the real public key is committed in `packages/remote_config/lib/src/signing_public_key.dart`, the private key lives only as the `REMOTE_CONFIG_PRIVATE_KEY` GitHub Actions secret. See `docs/remote-config.md`.

## Current state (Phase 1)

- The app still makes no user-facing network calls (no UI wired up yet), but the extraction layer (`innertube_client`, `extraction`, `remote_config`) now makes real outbound requests: InnerTube search/browse, `youtube_explode_dart` stream resolution, and the remote-config fetch. All three are unauthenticated, anonymous requests — no user credentials or accounts exist yet (P6).
- `AppLogger` (`packages/core`) still writes to stdout only; no file sink, no remote sink, no opt-in crash reporting wired up yet (P10, §15.5). Extraction/InnerTube/remote-config failures are logged locally only.
- Rate-limit hygiene (§6.9) is implemented: per-host concurrency caps, backoff+jitter on 429/5xx, rotating visitor IDs — reduces the chance of soft-bans from the extraction layer's own request volume.

## Secrets handling

No real secrets are committed to this repo (§22). As of Phase 1, one secret exists: `REMOTE_CONFIG_PRIVATE_KEY` (the Ed25519 private signing key), stored as a GitHub Actions secret and used only by the manual publishing flow (`tool/sign_config.dart`) — it is never read by the app itself or by CI's build/test/smoke steps. Later phases will add more (OAuth client — P6, Last.fm API key — P8) via the same mechanism. See `docs/setup.md` for the local-dev equivalent.
