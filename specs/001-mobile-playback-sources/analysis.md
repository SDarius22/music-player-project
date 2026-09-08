# Specification Analysis: Mobile Hash-Free Playback Sources

**Analysis date**: 2026-09-08
**Mode**: Planning analysis retained below, followed by implementation verification.

## Findings

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|---|---|---|---|---|---|
| A1 | Coverage | HIGH | spec FR-001..FR-011; tasks T004..T023 | All buildable requirements map to slice or coordinator tasks. | Preserve task IDs and ownership during implementation. |
| A2 | Boundary | HIGH | contracts/playback-source.md; contracts/local-source-reader.md | A/B and B/C boundaries define who selects, persists, reads, and verifies. | Reject cross-slice edits that bypass these contracts. |
| A3 | Migration | MEDIUM | data-model.md; plan.md; tasks T013 | Existing fields are expected to suffice, but Android provider revision may prove otherwise. | Stop and create a separate approved migration if device validation exposes the gap. |
| A4 | Measurement | MEDIUM | spec SC-007; tasks T024 | Real-device timing and scoped-storage behavior cannot be established from repository inspection. | Record measured or pending values only after emulator/device validation. |
| A5 | Generated Artifacts | HIGH | plan.md; tasks T013 | ObjectBox generated changes are intentionally not planned. | B alone owns generation if a schema change becomes necessary. |

## Coverage Summary

| Requirement | Task coverage | Notes |
|---|---|---|
| FR-001/FR-005 queue identity separation | T004-T008, T020-T021 | A plus coordinator integration. |
| FR-002/SC-001 hash-free startup | T005-T008, T016, T023 | Assertions require injected/mock hasher visibility. |
| FR-003/FR-004 matching safety | T005-T006 | Exact-first and ambiguity tests. |
| FR-006/SC-004 invalidation | T009-T014 | B lifecycle and reader ownership. |
| FR-007 imported-file/iOS scope | T014, T024 | Existing imported-file regression; iOS deferred. |
| FR-008/SC-002 no-op scan | T015-T019 | C scanner and adapter tests. |
| FR-009/SC-004 verified range | T010-T012, T015-T019 | B verification, C access. |
| FR-010/SC-005 protocol stability | T014, T023 | Existing chunk tests remain required. |
| FR-011 tests | T005, T008-T010, T015-T016, T021-T023 | Unit, platform, and coordinator integration. |
| FR-012/SC-007 measurement honesty | T024 | Pending values allowed. |

## Consistency Checks

- **Spec to plan**: Pass. The three stories map directly to A, B, and C, with no backend or API changes.
- **Plan to tasks**: Pass. All source ownership paths and coordinator gates are represented.
- **Tasks to contracts**: Pass. A/B and B/C dependencies are explicit and parallel work is disjoint after the baseline.
- **Constitution**: Pass. Spec Kit artifacts, Graphify query, contract-first boundaries, tests, migration caution, and generated-file rules are reflected.
- **Clarification status**: No material unresolved requirement remains. Device-specific provider behavior is a validation blocker/deferred measurement, not an unresolved product choice.

## Metrics

- Functional requirements: 12
- Measurable success criteria: 7
- Implementation tasks: 25
- Requirements with task coverage: 12/12 (100%)
- Critical inconsistencies: 0
- Known validation blockers: real-device Android provider behavior and timing measurements

## Next Actions

1. Coordinator freezes contracts and fixtures (T001-T003).
2. Launch exactly three disjoint agents for A, B, and C.
3. Stop B before generated schema edits unless a concrete provider-revision gap is demonstrated.
4. Run coordinator integration and full frontend quality gates, then update Graphify after source changes.

## Implementation Review

- A: stable queue identity is preserved while selecting local URI or remote asset.
  Source installation is serialized and stale requests are discarded. Synchronous
  local-load failure and later player error have remote recovery coverage.
- B: source changes invalidate persisted hashes without clearing listening data.
  File and Android readers share exact manifest SHA-256 verification. Reader
  results must have matching source keys/URIs, size, length, and change hints.
- C: MediaStore provides content URIs, size and modification metadata without
  startup file reads; unchanged rows are not saved. Query failure or malformed
  partial results cannot mark the library missing. Imported records are preserved.
- Coordinator corrected heuristic `resolvedSongHash` being treated as exact,
  unsafe local-encoding hash fallback, stale-load races, ambiguity grouping,
  metadata refresh, native query error propagation, and engine-owned registration.
- No backend contract, ObjectBox schema, dependency, or iOS library changes.
- Constructor injection was refined to immediate property assignment; see plan.
- SC-001's fully instrumented startup measurement remains incomplete (T026).
  No unsupported claim of device timing, acoustic matching, or whole-file identity
  is made from metadata or a single verified chunk.
- Host checks pass with native-library skips; full release acceptance awaits
  T024 and convergence T026-T028. See verification.md for commands and limitations.
