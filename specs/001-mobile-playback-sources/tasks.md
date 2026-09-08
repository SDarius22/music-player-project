# Tasks: Mobile Hash-Free Playback Sources

**Input**: Design documents from `/specs/001-mobile-playback-sources/`
**Implementation mode**: Three disjoint agent slices; coordinator owns integration and final artifacts.

## Phase 1: Shared Contract Baseline

- [x] T001 Freeze the A/B playback source contract in `specs/001-mobile-playback-sources/contracts/playback-source.md` before parallel implementation; coordinator only
- [x] T002 Freeze the B/C lifecycle and byte-reader contract in `specs/001-mobile-playback-sources/contracts/local-source-reader.md` and `contracts/android-scan.md`; coordinator only
- [x] T003 [P] Establish fixture ownership: existing fixtures suffice; each slice uses its own test fakes and coordinator may add integration support under `music-player-frontend/test/support/`.

**Checkpoint**: Agents can work independently against the contracts without changing another slice's ownership files.

## Phase 2: Slice A - Playback and Song Matching (P1)

**Owner**: Agent A. Files: `song_service.dart`, `app_audio_service.dart`, source-resolution model/interfaces, A tests.

**Independent test**: Resolver and playback tests prove exact-first selection, ambiguity refusal, remote fallback, zero full-file hashing, and unchanged queue identity/order.

- [x] T004 [P] [A] Add the playback-source selection model/interface described by `specs/001-mobile-playback-sources/contracts/playback-source.md` in `music-player-frontend/lib/core/`.
- [x] T005 [P] [A] Add exact-first, ambiguity-safe matching tests in `music-player-frontend/test/core/services/song_service_test.dart` or a new resolver test file.
- [x] T006 [A] Refactor `music-player-frontend/lib/core/services/song_service.dart` so local resolution returns source selection data without replacing queued song identity and never hashes during resolution (depends on T004).
- [x] T007 [A] Refactor `music-player-frontend/lib/core/services/app_audio_service.dart` so queue entries remain stable while selected local/remote sources are loaded and local failure falls back safely (depends on T004, T006).
- [ ] T008 [A] Add playback regression tests in `music-player-frontend/test/core/services/app_audio_service_playback_test.dart` for changed local projection, queue identity/order, fallback, and zero startup hash calls (depends on T007). Playback regressions pass; explicit full-startup hash invocation instrumentation remains T026.

## Phase 3: Slice B - Local Source Lifecycle and Byte Readers (P1)

**Owner**: Agent B. Files: `local_track_service.dart`, `local_track.dart`, local repository interfaces/implementations only if required, B tests. B alone may regenerate ObjectBox if a schema change is proven necessary.

**Independent test**: Lifecycle and reader tests prove unchanged records are not rewritten, changed sources lose persisted content-linked identities, and exact verified ranges remain safe for file/content readers.

- [x] T009 [P] [B] Add source snapshot comparison and lifecycle tests in `music-player-frontend/test/core/services/local_track_service_test.dart` for unchanged, URI-changed, size/modified-changed, missing, and reappearing sources.
- [x] T010 [P] [B] Add common byte-range reader contract/fakes and tests in `music-player-frontend/test/core/services/` for exact offsets, final-chunk length, mutation, short-read, unsupported-range, and digest mismatch behavior.
- [x] T011 [B] Update `music-player-frontend/lib/core/services/local_track_service.dart` to invalidate `contentHash`/`resolvedSongHash` on observed source changes while preserving stats and metadata (depends on T009).
- [x] T012 [B] Refactor `music-player-frontend/lib/core/services/local_track_service.dart` to use the B/C reader boundary for filesystem and content-URI reads while retaining existing manifest SHA-256 checks (depends on T010).
- [x] T013 [B] Assess schema needs: existing `LocalTrack` fields suffice for the scoped lifecycle; no schema or generated ObjectBox change required (depends on T009).
- [x] T014 [B] Verify existing imported-file behavior and chunk integrity tests remain green in `music-player-frontend/test/core/services/` (depends on T011, T012).

## Phase 4: Slice C - Android Query, Scanning, and Native Bridge (P1)

**Owner**: Agent C. Files: Android scanner/file service, Android/native bridge adapters as required, C tests.

**Independent test**: Scanner tests prove unchanged media items do not write; adapter tests prove content URIs bypass filesystem APIs and return exact source snapshots/ranges or safe failures.

- [x] T015 [P] [C] Add Android snapshot and adapter fakes in `music-player-frontend/test/platforms/android/services/` for path, content URI, permission, provider revision, and random-access cases.
- [x] T016 [P] [C] Add no-op scan assertions in `music-player-frontend/test/platforms/android/services/android_music_scanner_service_test.dart`, including zero unchanged persistence saves and hash-free, path-free MediaStore discovery.
- [x] T017 [C] Update `music-player-frontend/lib/platforms/android/services/android_file_service.dart` and any native bridge to expose stable media snapshots and bounded content-URI range reads without treating content URIs as filesystem paths (depends on T015).
- [x] T018 [C] Update `music-player-frontend/lib/platforms/android/services/android_music_scanner_service.dart` to compare snapshots/metadata, batch only changed/new records, and preserve missing-source reconciliation (depends on T016, T017).
- [x] T019 [C] Add Android adapter error handling for permission loss, unsupported range access, and provider mutation without direct LocalTrack persistence (depends on T017).

## Phase 5: Coordinator Integration and Quality Gates

- [x] T020 Integrate A/B/C implementations at their contract boundaries; coordinator owns composition wiring and may repair slice files only after their agents finish (depends on T008 playback implementation, T014, T019).
- [x] T021 [P] Add coordinator-owned mobile playback integration coverage under `music-player-frontend/integration_test/` proving local fallback does not change queued identity/order (depends on T020). Shared flow also runs in `test/integration/mobile_playback_sources_test.dart`; device execution remains T024.
- [x] T022 [P] Run `flutter analyze` and `dart format --output=none lib test integration_test` from `music-player-frontend/`; fix only approved feature issues (depends on T020).
- [x] T023 Run `flutter test` from `music-player-frontend/`, including existing chunk/server SHA-256 compatibility tests and all slice tests (depends on T020). Final run: 437 passed, 9 native-library-dependent tests skipped; see verification.md.
- [ ] T024 Record Android emulator/real-device scan and first-play timing plus scoped-storage results in the feature artifacts; mark unavailable measurements pending rather than inventing values (depends on T021).
- [x] T025 Coordinator performs final Spec Kit consistency review and updates `specs/001-mobile-playback-sources/analysis.md` and `checklists/requirements.md`; Graphify source index updated after implementation. Device-validation gaps from T024 remain explicitly open.

## Ownership and Dependency Graph

- T001-T003 are coordinator prerequisites.
- After T001-T003, A tasks T004-T008, B tasks T009-T014, and C tasks T015-T019 are disjoint and may run in parallel.
- T020 depends on all three slices and is coordinator-owned.
- T021-T025 are coordinator-owned final validation and artifact work.
- B is the sole owner of any persistence/schema generation; C never edits B persistence; A never edits B/C internals.

## Test Commands

- Slice A: `flutter test test/core/services/song_service_test.dart test/core/services/app_audio_service_playback_test.dart`
- Slice B: `flutter test test/core/services/local_track_service_test.dart test/core/services/chunk_service_test.dart`
- Slice C: `flutter test test/platforms/android/services/android_music_scanner_service_test.dart`
- Coordinator: `flutter analyze`, `dart format --output=none lib test integration_test`, `flutter test`

## Implementation Strategy

1. Freeze interfaces and tests/fixtures.
2. Run A, B, and C in parallel with no cross-slice file edits.
3. Integrate only after each slice's independent tests pass.
4. Run coordinator integration and full frontend gates.
5. Measure real-device behavior, then update final artifacts and Graphify only after meaningful source changes.

## Phase 6: Convergence

Assessment date: 2026-09-08. Remaining verification is not presented as completed implementation.

- [ ] T026 [FR-002, SC-001, T008] Add explicit startup/queue-restoration whole-file-hasher invocation instrumentation in a full application harness. Current evidence is the absence of a hasher dependency on these paths plus successful playback/discovery of unhashed sources, not an instrumented device-wide I/O measurement.
- [ ] T027 [FR-011, T023] Restore the native ObjectBox test library at the path expected by `test/core/repository/repository_platform_parity_test.dart`, then rerun its nine currently skipped parity tests. No persistence schema changes were introduced.
- [ ] T028 [FR-009, T024] Run `integration_test/mobile_playback_sources_test.dart` on Android and exercise real MediaStore permission revocation, descriptor offsets, non-seekable providers, background engine lifetime, and mid-read file mutation. Kotlin compilation and fake-channel tests do not establish these device behaviors.

## Phase 7: Android Test Build

User request: commit, push, and start the GitHub Android build for device testing.

- [x] T029 Add APK-only selection and an explicit server-publish switch to `.github/workflows/build-publish.yml`, preserving release/all-platform behavior. Pin the tested Flutter version and Android Java runtime; fail artifact upload when the APK is absent. Workflow validated with actionlint 1.7.7; dispatch tracked by T030.
- [ ] T030 Commit only this feature's source/tests/specification/workflow changes, push to origin, dispatch the Android build on the pushed commit, monitor automatic frontend deployment and requested build, and report links/results. Pre-existing unrelated `.gitignore`, `.gitattributes`, governance, and tool configuration changes remain unstaged.
