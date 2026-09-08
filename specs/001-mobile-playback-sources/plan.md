# Implementation Plan: Mobile Hash-Free Playback Sources

**Feature**: `001-mobile-playback-sources` | **Date**: 2026-09-07 | **Spec**: [spec.md](spec.md)

Implementation stayed on the existing `master` worktree; no branch was created or switched.

## Summary

Keep startup and warm scans hash-free by treating queued song identity as immutable playback intent and local/remote source as a separate selection. Slice A owns exact-first matching and queue-safe playback. Slice B owns local source lifecycle, persisted identity invalidation, and common verified range safety. Slice C owns Android snapshots, no-op scanning, and content-URI access. Existing server chunk SHA-256 semantics remain unchanged.

## Technical Context

**Language/Version**: Dart/Flutter as currently pinned by `music-player-frontend`; Android platform integration uses the existing project bridge.

**Primary Dependencies**: Existing Provider-style services, ObjectBox persistence, `on_audio_query`, `dart:io` filesystem access, and existing crypto SHA-256 verification. No new dependency is planned.

**Storage**: Existing ObjectBox `LocalTrack` and song repositories; no schema change unless implementation proves a provider revision cannot be represented by current fields.

**Testing**: `flutter test`, `flutter analyze`, `dart format`; coordinator integration tests; Android native/device validation when available.

**Target Platform**: Android mobile first, shared Flutter playback behavior across existing supported targets; iOS library access is out of scope.

**Project Type**: Flutter mobile/media client with existing backend chunk protocol.

**Performance Goals**: Startup, queue restore, and unchanged scan paths perform zero full-file hashes. Unchanged scan performs zero persistence writes for unchanged records. Real-device timings are pending measurement.

**Constraints**: Preserve queue identity, imported files, exact chunk offsets/lengths, existing manifest SHA-256, and safe fallback. Do not add speculative fingerprints or hash protocol changes.

**Scale/Scope**: Existing mobile library and playback queue; no new cloud logical-recording model.

## Constitution Check

- **I Spec-driven/Graph-aware**: Pass. Graphify was queried before targeted source reads; this feature contains spec, plan, tasks, and analysis artifacts. No implementation or graph update is part of this planning turn.
- **II Contract-first modularity**: Pass. A/B and B/C contracts define ownership and preserve service/repository/platform separation.
- **III Secure/reliable data**: Pass. Local source failures fail safely, private media is not logged, and no unplanned protocol/schema migration is introduced.
- **IV Tests/quality gates**: Pass with coordinator gate. Slice tests plus final integration, format, analyze, and full frontend tests are explicitly tasked.
- **V Cross-platform UX**: Pass. Existing fallback/error behavior is preserved; Android permission and unavailable-source states are covered. iOS library access is explicitly deferred.
- **VI Reproducible delivery**: Pass. Commands and pending real-device measurements are documented; generated files are not manually edited.

## Architecture and Ownership

### Slice A: Playback and Song Matching

Owner files: `music-player-frontend/lib/core/services/song_service.dart`, `app_audio_service.dart`, source-resolution model/interfaces, and their unit tests.

Responsibilities: immutable queued identity, exact-first resolver, ambiguity result, local/remote fallback, and playback-source construction. It may query B through [playback-source.md](contracts/playback-source.md), but must not mutate B persistence.

### Slice B: Local Source Lifecycle and Byte Readers

Owner files: `local_track_service.dart`, `local_track.dart`, local-track repository interfaces/implementations only if required, common byte-reader abstractions, and lifecycle/chunk tests.

Responsibilities: source snapshot comparison, changed-source invalidation, unchanged persistence behavior, filesystem/content reader policy, exact manifest range validation, and rejected-candidate invalidation. B is the sole owner of any ObjectBox generation if a schema change becomes unavoidable.

### Slice C: Android Query, Scan, and Native Bridge

Owner files: `platforms/android/services/android_music_scanner_service.dart`, `android_file_service.dart`, Android/native bridge files as required, and Android tests.

Responsibilities: stable media snapshots, content-URI access, provider capability/revision reporting, no-op scan filtering, and platform error mapping. C returns snapshots/read results to B and does not perform manifest validation or direct LocalTrack persistence.

### Coordinator-Owned Work

The coordinator owns cross-slice wiring, integration tests, final artifact updates, full frontend quality gates, and any decision to stop for a required schema migration or real-device blocker.

## Migration and Compatibility

Implementation refinement: preserve the existing optional-positional
`LocalTrackService(repository, [songRepository])` constructor. Dart cannot also
accept named optional parameters, so composition assigns the `byteRangeReader`
field immediately after construction. `MusicPlayerApp.createLocalByteRangeReader`
defaults to the filesystem implementation; Android overrides it. No persisted
schema or dependency change was needed. Existing `android:<id>` keys remain;
URIs become volume-qualified content URIs and their first rescan invalidates
old byte associations conservatively while retaining listening history.

Matching uses known hashes only for exact asset identity. Metadata-only listening
matches permit different encodings, reject placeholders/conflicting known albums,
and compare actual duration differences. A local content hash alone does not imply
the server hosts it; remote fallback for a managed local track requires a unique
remote association. The native reader is an engine-owned plugin, not activity-owned.

Use existing `sourceUri`, `fileSize`, and `modifiedAt` values for persisted lifecycle comparison. First discovery of absent snapshot values initializes them without hashing. A known URI/size/modified/provider-revision change clears `contentHash` and `resolvedSongHash` but preserves user statistics and metadata. Existing records are lazily migrated on discovery; no bulk migration or generated ObjectBox edit is planned. If Android evidence requires a provider revision field, pause implementation and add a separate migration task with B sole ownership.

## Validation Plan

Completed checks and remaining device/native-library gates are recorded in
[verification.md](verification.md). Host service-integration tests use the same
flow as the device entry point, with platform playback and transport mocked.

- Slice A: `flutter test test/core/services/song_service_test.dart test/core/services/app_audio_service_playback_test.dart` plus new resolver tests; assert zero hasher calls and unchanged queue identities.
- Slice B: `flutter test test/core/services/local_track_service_test.dart test/core/services/chunk_service_test.dart` plus lifecycle/reader tests; assert invalidation, exact range length, source mutation rejection, and digest preservation.
- Slice C: `flutter test test/platforms/android/services/android_music_scanner_service_test.dart` plus Android adapter tests; assert unchanged no-op saves and content-URI routing without `File.stat`.
- Coordinator: `flutter analyze`, `dart format --output=none lib test integration_test`, `flutter test`, and targeted integration playback tests. Real-device Android timing and scoped-storage validation remain pending until hardware/emulator execution.

## Project Structure

```text
specs/001-mobile-playback-sources/
├── spec.md
├── research.md
├── plan.md
├── data-model.md
├── contracts/
│   ├── playback-source.md
│   ├── local-source-reader.md
│   └── android-scan.md
├── tasks.md
├── checklists/requirements.md
└── analysis.md

music-player-frontend/
├── lib/core/services/{song_service,app_audio_service,local_track_service}.dart
├── lib/core/entities/local_track.dart
├── lib/platforms/android/services/{android_music_scanner_service,android_file_service}.dart
├── test/core/services/
└── test/platforms/android/services/
```

**Structure Decision**: Keep the existing Flutter feature-oriented structure. Platform-specific access stays under `platforms/android`; source identity and verification remain in core services; no backend/API contract changes are required.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| None planned | The design uses existing modules and boundaries. | No exception requested. |
