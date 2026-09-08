# Feature Specification: Mobile Hash-Free Playback Sources

**Feature ID**: `001-mobile-playback-sources` (existing branch retained)
**Created**: 2026-09-07
**Status**: Implemented; host checks passed, device and extended instrumentation gates pending
**Input**: User description: mobile startup must remain hash-free while separating queued song identity from the selected local or remote playback source.

## User Scenarios & Testing

### User Story 1 - Start Mobile Playback Without Startup Hashing (Priority: P1)

A listener opens the mobile app and starts a queued song. The queue keeps the stable song identity it was created with, while playback selects an available local source or the remote asset without replacing that queue identity.

**Why this priority**: Startup latency and correct queue continuity are the primary user-visible outcomes.

**Independent Test**: A unit and playback test can queue a remote song, provide a matching local candidate, and verify that playback uses the local source while queue identity, order, and persistence identity remain unchanged.

**Acceptance Scenarios**:

1. **Given** a queued song with a stable identity and no local source selected, **When** playback starts on mobile, **Then** no full-file hash is requested during startup and the player selects an eligible remote or local source.
2. **Given** a queued song and an exact local candidate, **When** the song is loaded, **Then** the exact local candidate ranks above metadata-only candidates and the queued song identity does not change.
3. **Given** a local candidate that is ambiguous by metadata, **When** playback resolves its source, **Then** it is not auto-selected and playback falls back to the remote asset or reports the existing recoverable playback failure.
4. **Given** local source selection fails, **When** playback retries or changes source, **Then** the queue entry and its remote identity remain unchanged.

### User Story 2 - Preserve Local Source Validity Across Scans (Priority: P1)

A listener rescans the device library. Unchanged files remain immediately usable without content hashing, while a changed, moved, or unavailable source cannot reuse persisted content identity or stale verified data.

**Why this priority**: Incorrect persisted identity can cause wrong-song playback or integrity failures after a file changes.

**Independent Test**: A local-track lifecycle test can run unchanged, changed-stat, changed-URI, unavailable, and restored-source transitions and verify identity invalidation and availability state.

**Acceptance Scenarios**:

1. **Given** a persisted local source with unchanged source metadata, **When** it is rediscovered, **Then** its content and resolved identities remain valid and no full hash is calculated.
2. **Given** a persisted local source whose URI, size, or available modification/revision metadata changed, **When** it is rediscovered, **Then** persisted content-linked identities and rejected-reader state are invalidated before the source is usable.
3. **Given** a source missing from a completed scan, **When** reconciliation runs, **Then** it becomes unavailable without changing the stable remote/queued song identity.
4. **Given** a source later reappears with a different source identity, **When** it is discovered, **Then** it is treated as a new source and is not automatically attached to the old content identity by metadata alone.

### User Story 3 - Read Android Content Sources Safely (Priority: P1)

A listener plays audio stored behind Android scoped-storage content URIs. Scanning avoids no-op writes and playback can read verified ranges through the platform source while preserving the existing chunk hash contract.

**Why this priority**: Android content URIs are a supported mobile source and cannot be handled safely as ordinary filesystem paths.

**Independent Test**: Android scanner and byte-reader tests can use fake media/query and source handles to verify unchanged scans, content URI range reads, mutation rejection, and exact chunk digests.

**Acceptance Scenarios**:

1. **Given** an unchanged Android media item, **When** a quick scan runs, **Then** metadata is not rewritten solely because it was rediscovered and the scan reports a no-op/unchanged result.
2. **Given** an Android content URI with random-access support, **When** a verified chunk is requested, **Then** the platform reader reads the exact offset and length and returns bytes only when their SHA-256 equals the existing manifest entry.
3. **Given** a content source that changes during a read or fails to support the requested range, **When** a verified chunk is requested, **Then** no bytes are accepted and the reader falls back safely.
4. **Given** any source type, **When** a verified chunk is returned, **Then** the existing chunk size, ordering, and server SHA-256 contract are unchanged.

### Edge Cases

- A source has no filesystem stat because it is a scoped-storage content URI.
- Size is available but modification time is absent or unstable.
- Two local candidates have identical conservative metadata but different source identities.
- A local source disappears between candidate selection and byte read.
- A queue entry has a remote identity but the server fetch returns a different logical record.
- A verified read returns a short final chunk; only the manifest-derived final length is accepted.
- Android permission is denied or revoked during scanning or playback.
- Imported files outside the Android media library remain supported; iOS system-library access is deferred.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST keep stable queued song identity separate from the selected playback source.
- **FR-002**: The system MUST resolve playback sources without performing full-file hashing during mobile startup, scan, queue restoration, or ordinary source selection.
- **FR-003**: The system MUST rank exact persisted local source identity and exact known content identity above conservative metadata candidates.
- **FR-004**: The system MUST refuse automatic substitution when conservative metadata produces more than one eligible candidate without an exact discriminator.
- **FR-005**: The system MUST preserve queue identity, order, and remote identity when a local source is selected, rejected, replaced, or invalidated.
- **FR-006**: The system MUST invalidate persisted local content and resolved-song identities when the source URI or available persisted source metadata indicates a changed source.
- **FR-007**: The system MUST preserve imported-file support and MUST NOT add iOS system-library access in this slice.
- **FR-008**: Android scanning MUST avoid persistence writes for unchanged records and MUST use source metadata appropriate to filesystem paths and content URIs.
- **FR-009**: Verified local range reads MUST support approved filesystem and Android content-URI sources, reject mutation or unsupported access, and validate each returned chunk against the existing manifest SHA-256.
- **FR-010**: The implementation MUST NOT introduce a new hashing protocol, speculative fingerprint, or change to the server chunk SHA-256 contract.
- **FR-011**: The implementation MUST provide unit tests for matching, lifecycle invalidation, no-op scans, URI range reads, mutation safety, and chunk integrity, plus coordinator-owned integration coverage for mobile playback.
- **FR-012**: The implementation MUST document measurable no-op scan and hash-free assertions; real-device timing results MUST remain explicitly pending until measured.

### Key Entities

- **Queued song identity**: Stable logical identity retained by queue and playlist state; it is not replaced by a local projection.
- **Playback source**: A selected local URI or remote asset reference used for the current load; it can change without changing queued song identity.
- **Local source record**: Persisted source key, URI, conservative metadata, availability, local content identity, and optional resolved remote identity.
- **Source resolution result**: Explicit exact-local, conservative-local, remote, or unavailable outcome with a reason and candidate cardinality.
- **Verified range**: Bytes at a manifest-derived offset and length accepted only after the existing per-chunk SHA-256 check and source-stability check.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Automated startup, queue-restore, and source-selection tests observe zero full-file hash invocations.
- **SC-002**: An unchanged scan persists zero local-track records and performs zero full-file hashes; its assertions are deterministic in unit tests.
- **SC-003**: Automated matching tests select an exact local source over every heuristic candidate and select no source when heuristic candidates are ambiguous.
- **SC-004**: Automated mutation tests accept zero bytes after a source mutation, short read, invalid range, or digest mismatch.
- **SC-005**: Existing server chunk SHA-256 compatibility tests remain green without protocol or manifest changes.
- **SC-006**: Coordinator-owned mobile playback integration tests demonstrate that local-source fallback does not alter queued song identity or queue order.
- **SC-007**: Real-device Android scan and first-play timing measurements are recorded as pending or measured values, never fabricated estimates.

## Assumptions

- Existing remote file hashes and per-chunk manifest hashes are authoritative when already persisted or supplied by the server.
- Exact local identity means a persisted source key/content identity already known to the application, not a newly invented fingerprint.
- Metadata candidates are limited to title, artist, duration, size, and available source metadata; they are not proof of content identity.
- Full hashing remains an explicit upload/isolate operation and is not moved into startup or scanning.
- No confirmation UI is required for this slice; ambiguous automatic substitution simply falls back safely.
- ObjectBox generated output is not edited manually; a schema change is permitted only if implementation proves existing fields cannot represent the required persisted lifecycle.
- Integration tests and final artifacts are owned by the coordinator after slices A, B, and C complete.

## Out of Scope

### Authorized Delivery Follow-up

The user requested committing/pushing this feature and starting a GitHub Android
build for testing. A manual APK-only dispatch must not build unrelated platforms
or publish to the download server. Existing all-platform/release behavior and
test/coverage/security gates remain intact. Delivery is tracked by T029-T030.

- iOS system music-library access.
- Full cloud logical-recording migration.
- A new content fingerprint or hashing protocol.
- Confirmation UI for ambiguous local candidates.
- Real-device performance claims before measurements are collected.
