import 'package:music_player_frontend/core/entities/song.dart';

enum PlaybackSourceKind { local, remote, unavailable, ambiguous }

enum SourceMatchStrength { exactSource, exactContent, metadata, remote, none }

class PlaybackSourceSelection {
  final PlaybackSourceKind kind;
  final SourceMatchStrength strength;
  final String? sourceKey;
  final String? sourceUri;
  final String? remoteAssetHash;
  final String reason;
  final int candidateCount;

  const PlaybackSourceSelection({
    required this.kind,
    required this.strength,
    this.sourceKey,
    this.sourceUri,
    this.remoteAssetHash,
    required this.reason,
    this.candidateCount = 0,
  });

  bool get isLocal => kind == PlaybackSourceKind.local;

  static PlaybackSourceSelection remote(Song song, String reason) {
    final remoteHash =
        song.localSourceKey == null && song.fileHash.isNotEmpty
            ? song.fileHash
            : song.potentialRemoteHashes.length != 1
            ? null
            : song.potentialRemoteHashes.first;
    return PlaybackSourceSelection(
      kind:
          remoteHash == null
              ? PlaybackSourceKind.unavailable
              : PlaybackSourceKind.remote,
      strength:
          remoteHash == null
              ? SourceMatchStrength.none
              : SourceMatchStrength.remote,
      remoteAssetHash: remoteHash,
      reason: reason,
    );
  }
}
