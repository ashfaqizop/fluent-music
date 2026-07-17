# The Extraction Layer

> Home for the extraction subsystem design (Masterdoc §6 — "the single highest-risk, highest-value subsystem"). Written at Phase 1 (P1), which built this layer for the first time; Phase 0 only had placeholder types.

## 1. Purpose & scope

Given a search query, resolve real InnerTube results and turn a chosen video ID into a playable audio-only stream URL, surviving YouTube's constant changes via layered fallbacks and remote self-healing config (§6.1). Two packages split the responsibility:

- **`innertube_client`** — a genuinely custom Dart client hitting YT Music's InnerTube `search`/`browse` surfaces directly (`music.youtube.com/youtubei/v1/*`).
- **`extraction`** — resolves a playable stream URL for a given video ID, using `youtube_explode_dart` for the actual stream-manifest work, wrapped in our own parallel-race + fallback-chain orchestration.

## 2. Why two client-identity catalogs, not one

Masterdoc §6.2 describes "a pool of InnerTube client identities" as a single concept. Reality, verified against the installed `youtube_explode_dart` 3.1.0 source, is that search/browse and stream resolution are different InnerTube surfaces reached through different code paths with different supported client sets:

- `innertube_client` builds its own request context and can use **any** identity, including `WEB_REMIX` — the real identity YT Music's own web player uses for search/browse, and the only one with full access to music-specific surfaces (home feed, artist/album pages) that general-purpose YouTube clients don't expose.
- `extraction` resolves streams via `youtube_explode_dart`'s `StreamClient.getManifest(videoId, {ytClients})`, which only accepts its own `YoutubeApiClient` catalog: `.ios`, `.android`, `.androidSdkless`, `.androidMusic`, `.androidVr`, `.safari` (WEB), `.tv` (TVHTML5), `.mediaConnect`, `.mweb`. **There is no `WEB_REMIX` constant in this version of the library.**

`packages/extraction/lib/src/client_identity_mapping.dart` maps remote-config identity names to this second catalog. `WEB_REMIX` has no mapping and is silently filtered out of the stream-resolution race (logged at `fine`) — it's still the right identity for `innertube_client`'s search/browse. This is logged as a deviation (`docs/deviations.md`) since the Masterdoc's wording implies one unified pool.

| Remote-config identity name | `innertube_client` (search/browse) | `extraction` stream-resolution mapping |
|---|---|---|
| `WEB_REMIX` | ✅ primary identity | — (no equivalent) |
| `ANDROID_MUSIC` | not used | `YoutubeApiClient.androidMusic` |
| `IOS` | not used | `YoutubeApiClient.ios` |
| `ANDROID_VR` | not used | `YoutubeApiClient.androidVr` |
| `TV` | not used | `YoutubeApiClient.tv` |
| `ANDROID` | not used | `YoutubeApiClient.androidSdkless` |
| `WEB` | not used | `YoutubeApiClient.safari` |
| `MWEB` | not used | `YoutubeApiClient.mweb` |

## 3. Parallel race & stagger (`ClientRaceLayer`)

For a given video ID, the layer:

1. Takes `RemoteConfig.clientIdentityOrder`, removes anything in `disabledIdentities`, and maps each name to a `YoutubeApiClient` (dropping unmappable names like `WEB_REMIX`).
2. Launches one `getManifest(videoId, ytClients: [client])` call per identity, each delayed by `raceStaggerMs * index` (so `raceStaggerMs: 0` — the default — means fully parallel), capped at `maxConcurrentRaceLanes` lanes if that's set above zero, each wrapped in a `raceLaneTimeoutMs` timeout.
3. The first lane to produce a non-empty best-audio pick (via `pickBestAudio`, §4 below) wins; its stream URL becomes the layer's result.

**Caveat, deliberate:** Dart futures aren't cancellable. Lanes that lose the race are left to run to completion and their results are simply discarded — cancelling in-flight HTTP requests mid-race buys little here, since `getManifest` calls are typically fast relative to the timeout/stagger windows involved. This is documented in `ClientRaceLayer`'s doc comment, not a bug.

## 4. Songs vs. video / codec preference (`pickBestAudio`, §6.6)

Prefers any stream whose `audioCodec` contains `opus` (native to libmpv, no transcode) over AAC/other codecs; ties within the same codec family are broken by highest bitrate. Returns `null` on an empty candidate list, at which point the layer treats it as a failed attempt (§6.6's "otherwise use the video's audio track" fallback is naturally covered since `youtube_explode_dart`'s manifest already includes muxed-video audio tracks in some cases — no separate code path was needed for Phase 1).

## 5. Fallback chain

| Order | Layer | Behavior in Phase 1 |
|---|---|---|
| 1 | `client_race` (`ClientRaceLayer`) | Real: parallel race across remote-config-ordered, mappable identities. |
| 2 | `alternate_identity` (`AlternateIdentityLayer`) | Real, but **sequential** (not raced) — a cheap long-tail safety net over identities the app knows about (`client_identity_mapping.dart`'s full catalog) that remote config hasn't promoted into `clientIdentityOrder` yet. A second identical race would be redundant with layer 1, so this is an extension of the Masterdoc's literal §6.3-step-2 wording — logged in `docs/deviations.md`. |
| 3 | `po_token` (`PoTokenLayer`) | Interface-only: always returns `AttemptSkipped`, regardless of `RemoteConfig.poTokenEnabled`. Proves the `PoTokenProvider` slot is wired end-to-end without a real implementation (§6.4 — "experimental in V1, default off"). |
| 4 | `yt_dlp` (`YtDlpLayer`) | Stub: always returns `AttemptSkipped`, never spawns a process. §6.7 — "opt-in fallback, default off." |

`ExtractionOrchestrator.resolve()` runs these in order, appending every attempted layer's name to `layersTried` regardless of outcome (success, skip, or failure), and returns on the first `AttemptSuccess`. If every layer skips or fails, it returns `ExtractionFailure(failure: <last real failure, or UnknownFailure>, layersTried: [...])` — matching the existing Phase-0 `ExtractionResult` shape with no changes needed to it.

## 6. PO-token & yt-dlp status

Both are wired into the chain but inert in Phase 1, exactly per the roadmap ("PO-token *interface* [off]", "yt-dlp adapter *stub* [off]"). Turning either on is future work — a real `PoTokenProvider` implementation, or a real `Process.run('yt-dlp.exe', ...)` adapter parsing JSON output — neither of which exists yet.

## 7. Failure behavior & diagnostics feed (§6.8)

Every layer's attempt (success/skip/failure) is recorded in order. A terminal `ExtractionFailure` carries the last real failure plus the full `layersTried` list, giving a future Diagnostics screen (§15.5, Phase 10) everything it needs to show "which extraction client succeeded" or, on failure, exactly what was tried.

## 8. Rate-limit hygiene (§6.9)

Shared policy primitives live in `core` (`BackoffPolicy`, `HostConcurrencyGate`, `VisitorIdRotator`) — transport-agnostic, no HTTP dependency, since `core` must stay dio/http-free. Each transport wires them in differently:

- **`innertube_client`** (dio): `InnerTubeRateLimitInterceptor` — injects the current visitor id into the **request body's** `context.client.visitorData` field (InnerTube expects this in the JSON payload, not an HTTP header), and retries 429/5xx responses with `BackoffPolicy`-computed delays (honoring a server `Retry-After` when present), capped at a small fixed attempt count.
- **`extraction`** (`package:http`, via `youtube_explode_dart`): `RateLimitedHttpClient` wraps a plain `http.Client` with `HostConcurrencyGate` + minimum inter-request spacing per host.

**Deliberate asymmetry:** `RateLimitedHttpClient` does **not** add its own retry-with-backoff loop. `youtube_explode_dart`'s `StreamClient.getManifest` already retries each client attempt internally (verified in its `lib/src/retry.dart`, up to 5 attempts with its own delay). Stacking a second independent backoff loop underneath it would multiply worst-case latency for no benefit — so `extraction`'s wrapper only owns proactive pacing (concurrency cap + minimum spacing), not reactive retry.

## 9. Remote-config-driven tuning

| `RemoteConfig` field | Controls |
|---|---|
| `clientIdentityOrder` | Which identities race, and in what order. |
| `disabledIdentities` | Temporarily pull an identity out of the race without editing `clientIdentityOrder`. |
| `identityOverrides[name].clientVersion` | Patch a stale `clientVersion` (innertube_client) without an app update. |
| `identityOverrides[name].priority` | Reorder an identity within the race without editing `clientIdentityOrder`. |
| `raceStaggerMs` | Delay between staggered lane launches (`0` = fully parallel). |
| `maxConcurrentRaceLanes` | Cap on simultaneous race lanes (`0` = unlimited). |
| `raceLaneTimeoutMs` | Per-lane timeout. |
| `rateLimit.*` | Backoff base/max/jitter, per-host concurrency cap, minimum request interval. |
| `poTokenEnabled` | Reserved for a future real PO-token implementation (no effect yet). |
| `refreshIntervalMinutes` | How often the app re-fetches remote config in the background. |

See `docs/remote-config.md` for the fetch/verify/apply/cache mechanics.

## 10. CLI / smoke harness

`packages/extraction/bin/smoke.dart` — a headless, pure-Dart script proving the whole P1 chain end-to-end:

```
dart run packages/extraction/bin/smoke.dart ["search query"]
```

Steps: fetch+apply remote config → InnerTube search → pick a song (falling back to a video entity, §6.6) → run the extraction orchestrator → on success, issue an HTTP range request against the resolved URL to confirm it's genuinely fetchable audio content. Exits `0` on success, `1` with diagnostic output on failure.

**Deviation, logged:** the Masterdoc's P1 DoD says "...play a track's audio." `audio_engine`'s `media_kit` wiring is explicitly Phase 2 scope (still interface-only as of P1) — so "play" here means confirming the resolved URL serves real audio bytes via an HTTP range fetch, not real mpv playback. Real audible playback is P2's job.

CI runs this on every build as a non-blocking step (`continue-on-error: true` + a `::warning::` annotation on failure) — it depends on live, unversioned YouTube behavior outside repo control, so failing it shouldn't block unrelated PRs, but it should still be visible on every run.

## 11. Known Phase 1 scope cuts

- Search result parsing covers song/video rows only — album/artist/playlist rendering is Phase 4 content-surface work.
- `browse()` on `InnerTubeClient` is a thin, unparsed passthrough — a foundation for Phase 4, not a finished feature.
- `WEB_REMIX`'s `apiKey`/`clientVersion` are the widely-published InnerTube web constants as of the Masterdoc's 2026-07-16 baseline; they drift as YouTube ships new web builds. That's exactly what `identityOverrides['WEB_REMIX']` exists to patch without a rebuild — see `packages/innertube_client/lib/src/client_identities.dart`.
- No real PO-token or yt-dlp implementation yet (by design, per the roadmap).
