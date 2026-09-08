# Contract C: Android Scan and Native Source Access

Ownership: Slice C owns `android_music_scanner_service.dart`, Android file/provider adapter(s), and Android-specific tests. It exposes platform-neutral snapshots and range reads to Slice B.

```dart
abstract interface class AndroidMediaSourceAdapter {
  Future<List<AndroidMediaItemSnapshot>> queryAudioSources();
  Future<LocalByteRangeResult?> readRange(
    String sourceUri,
    LocalByteRange range,
  );
}

class AndroidMediaItemSnapshot {
  final String sourceKey;       // stable provider/media id
  final String sourceUri;       // path or content URI
  final String title;
  final String artist;
  final String album;
  final int durationInSeconds;
  final int? size;
  final DateTime? modifiedAt;
  final String? providerRevision;
  final bool supportsRandomAccess;
}
```

Rules:

- Querying must preserve imported-file support and may return filesystem paths or content URIs.
- Scanner compares snapshots and metadata before calling persistence; unchanged records are not saved.
- A content URI is never passed to `File.stat` or `File.open`.
- The adapter must report unsupported random access rather than copying or hashing the entire source.
- Native/provider errors map to a safe unavailable result and do not alter queued identity.
- C does not own manifest SHA-256 validation; B performs it.

The adapter class above is conceptual: reuse existing query models where possible
rather than duplicate all metadata. The exact shared reader types and filenames
are frozen in `local-source-reader.md`. C owns Android runner Kotlin bridge and
vendored `on_audio_query` Android/model files only where needed. Native reads must
run off the platform/UI thread, be bounded to requested length, respect asset
descriptor start offsets, and reject non-seekable sources without whole-file
copying. Use content URIs from MediaStore, qualify IDs by volume when available,
and preserve existing records/history via a documented source-key migration if
keys change. Permission/query failure must not mark the whole library missing.
