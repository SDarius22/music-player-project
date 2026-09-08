# Contract B/C: Local Source Lifecycle and Byte Reader

Ownership: Slice B owns lifecycle, invalidation, manifest validation, and the reader policy. Slice C owns Android source access and scanner/native bridge adapters.

```dart
class LocalSourceSnapshot {
  final String sourceKey;
  final String sourceUri;
  final int? size;
  final DateTime? modifiedAt;
  final String? providerRevision;
  final bool supportsRandomAccess;
}

class LocalByteRange {
  final int offset;
  final int length;
}

class LocalByteRangeResult {
  final Uint8List bytes;
  final bool sourceStable;
  final LocalSourceSnapshot snapshot;
}

abstract interface class LocalByteRangeReader {
  Future<LocalByteRangeResult?> read(LocalTrack track, LocalByteRange range);
}

abstract interface class LocalSourceLifecycle {
  LocalTrack discover(LocalSourceSnapshot snapshot, {required String fallbackTitle});
  bool isUnchanged(LocalTrack track, LocalSourceSnapshot snapshot);
  void invalidateChangedSource(LocalTrack track, LocalSourceSnapshot snapshot);
}
```

Rules:

- B owns invalidation of `contentHash` and `resolvedSongHash`; C reports snapshots and reads bytes.
- C must not mutate `LocalTrack` persistence directly.
- B accepts a reader result only if length, source stability, range, and existing manifest SHA-256 checks pass.
- Filesystem and content URI readers share the same B-owned verification path.
- Unsupported URI/range, permission failure, mutation, short non-final read, or digest mismatch returns null and never populates cache.
- A may request source selection through B's query API but does not write local records.

## Frozen Dart Boundary

B owns `lib/core/services/local_byte_range_reader.dart`. It exports the snapshot,
range, result, and reader types above with const named-argument constructors:
`LocalSourceSnapshot({required sourceKey, required sourceUri, size, modifiedAt,
providerRevision, supportsRandomAccess = false})`,
`LocalByteRange({required offset, required length})`, and
`LocalByteRangeResult({required bytes, required sourceStable, required snapshot})`.
Reader `read` takes a `LocalTrack` and `LocalByteRange` as positional arguments.
B provides the filesystem default and exposes a `byteRangeReader` field assigned
at composition. This preserves the existing optional-positional constructor;
Dart does not allow named optional parameters alongside optional positional ones.
C implements `AndroidLocalByteRangeReader` at
`lib/platforms/android/services/android_local_byte_range_reader.dart`; it routes
file paths/file URIs to B's public `FileLocalByteRangeReader` and content URIs to
its native bridge. Coordinator wires this into the Android composition root.

Keep existing `LocalTrackService.discover` named arguments compatible with
desktop callers; B adds optional `bool supportsRandomAccess = true` and exposes
`bool isUnchanged(LocalTrack track, LocalSourceSnapshot snapshot)`. C compares
metadata itself before calling discover/applyMetadata/saveMany. The lifecycle
interface above is conceptual; no wrapper class or schema change is required.
No persisted providerRevision is promised in this slice: size/modified time and
URI are the persisted change hints; revision may be used within a native read
to reject mutation. Missing or changed known hints must conservatively invalidate
old identities, including reappearance after unavailability. File metadata is
not cryptographic proof; manifest validation remains mandatory for every range.
