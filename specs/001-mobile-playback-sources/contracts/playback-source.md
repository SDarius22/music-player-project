# Contract A/B: Playback Source Resolution

Ownership: Slice A owns the resolver and `SongService`/`AppAudioService` integration. Slice B owns local-record lookup and source lifecycle behavior. The contract is a dependency-injected boundary; neither slice edits the other slice's internals.

```dart
enum PlaybackSourceKind { local, remote, unavailable, ambiguous }
enum SourceMatchStrength { exactSource, exactContent, metadata, remote, none }

class PlaybackSourceSelection {
  final PlaybackSourceKind kind;
  final SourceMatchStrength strength;
  final String? sourceKey;       // local only
  final String? sourceUri;       // local only
  final String? remoteAssetHash; // remote only or fallback identity
  final String reason;
}

abstract interface class PlaybackSourceResolver {
  Future<PlaybackSourceSelection> resolve(
    Song queuedSong, {
      required bool allowRemoteFallback,
    });
}
```

Rules:

- Resolver input is the queued song; resolver output never replaces it.
- Exact source/content matches precede metadata candidates. Existing `resolvedSongHash` was populated by metadata grouping and MUST NOT be promoted to exact evidence.
- A single conservative metadata match may be used for listening only; require meaningful normalized title/artist, an actual duration tolerance, and no conflicting known album/version metadata. Multiple candidates must not be silently collapsed in unified library grouping or substituted in playback. Never mark these associations byte-verified.
- More than one metadata candidate produces `ambiguous`, not first-match selection.
- A local selection failure may return `remote` while preserving the input song identity.
- No resolver path may invoke full-file hashing.
- Slice A may call Slice B only through a read/query interface returning source records or `PlaybackSourceSelection` data.

Minimum tests: exact ranking, ambiguity, remote fallback, changed local source, and queue identity preservation.

## Frozen Implementation Boundary

- A owns `lib/core/entities/playback_source_selection.dart` and keeps resolution in `SongService` unless a separate reusable resolver is justified. The abstract resolver above is conceptual, not a requirement to add another service.
- A reads B using existing `LocalTrackService.getAll()` and `getBySourceKey()`; no new A/B persistence API is required.
- `fullyFetchSong` must preserve input identity; `AppAudioService` resolves sources separately. Use existing song identities rather than a database/playlist migration in this slice.
- A owns all changes to unified library matching in `song_service.dart` and `potential_identity.dart` if needed. Hash keys remain candidate lookup helpers, not exact identity.
- Coordinator owns composition wiring and cross-slice integration tests. Fallback must be bounded and ignore stale asynchronous loads after queue changes.
