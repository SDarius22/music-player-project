# Data Model: Mobile Hash-Free Playback Sources

## QueuedSongIdentity

Logical identity retained by queue, playlist, and restore state.

- `identity`: Existing stable song/file identity; never replaced by local-source selection.
- `displayMetadata`: Existing title/artist/album/duration projection.
- `remoteAsset`: Existing remote asset/hash reference when available.
- `queuePosition`: Existing queue ordering state.

Invariant: selecting, rejecting, or invalidating a local source does not change `identity` or `queuePosition`.

## PlaybackSource

Ephemeral selection for one playback load.

- `kind`: `local` or `remote`.
- `uriOrAsset`: Local URI/path or remote asset reference.
- `sourceKey`: Required for local sources.
- `matchStrength`: `exact-source`, `exact-content`, `exact-resolved`, `metadata`, `remote`, or `none`.
- `reason`: Diagnostic outcome, safe to log without private media content.

State transitions: `unresolved -> exact local | remote | ambiguous | unavailable`; a failed local source may transition to `remote` without changing `QueuedSongIdentity`.

## LocalTrackRecord

Existing persisted `LocalTrack` record with lifecycle semantics.

- `sourceKey`: Stable source identifier, unique and indexed.
- `sourceUri`: Current filesystem path or content URI.
- `potentialIdentityKey`: Conservative metadata key.
- `contentHash`: Optional known local content identity; invalidated on source change.
- `resolvedSongHash`: Optional known remote association; invalidated on source change.
- `fileSize`: Optional observed size.
- `modifiedAt`: Optional observed modification timestamp.
- `available`: Whether the source was present in the last completed scan.
- `supportsRandomAccess`: Whether verified range reads may be attempted.
- Existing metadata and listening statistics: updated only when changed and preserved across source invalidation.

Migration/lifecycle rule: no new persisted field is planned. On existing records, the first rediscovery establishes missing snapshot values without hashing. If URI or comparable available snapshot values differ, clear only `contentHash` and `resolvedSongHash`, retain metadata/statistics, and persist the changed record. If implementation proves Android provider revision cannot be represented by existing fields, stop and propose a separate schema migration before editing generated ObjectBox artifacts.

## SourceSnapshot

Transient scan/read comparison value.

- `sourceKey`
- `sourceUri`
- `size` (nullable)
- `modifiedAt` (nullable)
- `providerRevision` (nullable, platform-observed only; not a fingerprint)
- `supportsRandomAccess`

Equality is conservative: a known differing value means changed; absent values do not prove unchanged unless the platform contract supplies a stable provider revision.

## VerifiedRange

Transient result accepted by playback/cache code.

- `offset`: `chunkIndex * manifest.chunkSize`.
- `length`: min(chunk size, remaining manifest bytes).
- `bytes`: Exact requested length, except a valid final chunk.
- `sha256`: Must equal the existing manifest hash at `chunkIndex`.
- `sourceStable`: Must remain true across the read.

No field changes the server manifest or introduces a second digest protocol.
