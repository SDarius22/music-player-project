# Research: Mobile Hash-Free Playback Sources

## Repository Findings

- `SongService.resolvePreferredLocalSource` currently returns a local `Song` projection and uses a first matching source-key, content-hash, resolved-song-hash, or potential-identity candidate.
- `AppAudioService._fullyFetchQueueSong` rejects a fetched song when its hash differs from the queued song, which conflates queue identity with source projection.
- `LocalTrackService.discover` updates URI, size, and modified time but does not invalidate persisted content/resolved identities when those values change.
- `LocalTrackService.readVerifiedPotentialChunk` supports ordinary files only and rejects non-`file` URI schemes before reading.
- `AndroidMusicScannerService` attempts `File(dataPath).stat()` for every item and saves every discovered record after metadata application.
- `AudioContentHasher` already isolates full hashing for upload; startup must not reuse it.
- Existing chunk tests establish the server-facing per-chunk SHA-256 behavior and must remain authoritative.

## Decisions

### Decision: Separate identity from source

**Decision**: Introduce a source-resolution value/interface rather than returning a replacement queued `Song` as the identity operation. `AppAudioService` keeps the queued song and passes the resolved local URI or remote source into playback construction.

**Rationale**: It removes the current hash-equality gate without allowing a local projection to mutate queue semantics.

**Alternatives considered**: Continue replacing queue entries with local projections; rejected because it makes source fallback and remote identity unstable.

### Decision: Exact-first conservative matching

**Decision**: Rank exact source key and exact known content/resolved identity first. Use title/artist/duration and available size only as conservative candidates, and return ambiguity instead of choosing the first candidate.

**Rationale**: Metadata is useful for imported-file association but is not proof of identity and can collide.

**Alternatives considered**: Generate a startup fingerprint or hash candidates; rejected by scope and startup latency constraints.

### Decision: Invalidate on observed source change

**Decision**: On rediscovery, compare source URI and available persisted size/modified metadata before applying new metadata. Clear `contentHash` and `resolvedSongHash` when the source changed, and clear reader rejection state for that source. Preserve user playback statistics.

**Rationale**: Existing persisted fields can represent the common lifecycle without a speculative fingerprint or mandatory ObjectBox schema change. Content-URI sources use URI/source-key continuity and platform-reported metadata when available.

**Alternatives considered**: Add a new fingerprint column; rejected because it creates a new identity protocol and is not required for this slice.

### Decision: Platform byte-reader boundary

**Decision**: Define a `LocalByteRangeReader` boundary with filesystem and Android content-URI implementations. It returns bytes plus a source-stability observation or a typed failure; `LocalTrackService` remains responsible for manifest validation and SHA-256 verification.

**Rationale**: Android scoped storage cannot be modeled as a Dart `File`, and the integrity policy must remain shared.

**Alternatives considered**: Copy every content URI to a temporary file; rejected because it adds startup I/O, storage pressure, and a second integrity path.

### Decision: No-op scan writes

**Decision**: Scanner compares the discovered source snapshot and metadata with the persisted record, applies metadata only when changed, and batches only changed/new records. Reconciliation remains the owner of missing-source availability updates.

**Rationale**: It makes unchanged scans measurable and avoids ObjectBox writes that do not change state.

**Alternatives considered**: Save every media item in batches; rejected because it is the reported warm-scan regression.

## Unresolved / Deferred

- Exact Android provider-level revision metadata and reliable random-access behavior require a real-device validation pass; the contract specifies capability and failure behavior without fabricating timing results.
- Whether a future ObjectBox migration should persist a provider revision token remains deferred until the Android bridge proves URI/size/modified metadata insufficient.
- iOS system-library integration and cloud logical-recording migration remain follow-up features.
