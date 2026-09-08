import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/local_track_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/services/local_byte_range_reader.dart';
import 'package:music_player_frontend/core/services/potential_identity.dart';

class LocalTrackService {
  final LocalTrackRepository _repository;
  final SongRepository? _songRepository;
  final Set<String> _rejectedChunkCandidates = {};

  /// Injected reader seam for platform sources. The default is the
  /// filesystem reader; platform composition roots may swap in a reader that
  /// additionally routes scoped-storage content URIs.
  LocalByteRangeReader byteRangeReader;

  LocalTrackService(this._repository, [this._songRepository])
    : byteRangeReader = const FileLocalByteRangeReader() {
    _migrateLegacySongPaths();
  }

  Stream<List<LocalTrack>> get watchTracks => _repository.watch();

  LocalTrack? getBySourceKey(String sourceKey) =>
      _repository.getBySourceKey(sourceKey);

  List<LocalTrack> getAll() => _repository.getAll();

  void saveMany(List<LocalTrack> tracks) => _repository.saveMany(tracks);

  void setResolvedSongHash(String sourceKey, String songHash) {
    if (songHash.isEmpty) return;
    final track = _repository.getBySourceKey(sourceKey);
    if (track == null || track.resolvedSongHash == songHash) return;
    track.resolvedSongHash = songHash;
    _repository.save(track);
  }

  LocalTrack discover({
    required String sourceKey,
    required String sourceUri,
    required String fallbackTitle,
    int? fileSize,
    DateTime? modifiedAt,
    bool supportsRandomAccess = true,
  }) {
    final snapshot = LocalSourceSnapshot(
      sourceKey: sourceKey,
      sourceUri: sourceUri,
      size: fileSize,
      modifiedAt: modifiedAt,
      supportsRandomAccess: supportsRandomAccess,
    );
    final existing = _repository.getBySourceKey(sourceKey);
    if (existing == null) {
      final track = LocalTrack(
        sourceKey: sourceKey,
        sourceUri: sourceUri,
        potentialIdentityKey: PotentialIdentity.create(
          title: fallbackTitle,
          artist: 'Unknown Artist',
          durationInSeconds: 0,
        ),
        name: fallbackTitle,
        supportsRandomAccess: supportsRandomAccess,
      );
      _applySnapshot(track, snapshot);
      return track;
    }
    if (!isUnchanged(existing, snapshot)) {
      invalidateChangedSource(existing, snapshot);
    }
    _applySnapshot(existing, snapshot);
    return existing;
  }

  /// A cheap scan comparison, not proof of content identity.
  bool isUnchanged(LocalTrack track, LocalSourceSnapshot snapshot) {
    if (!track.available || track.sourceKey != snapshot.sourceKey) return false;
    if (track.sourceUri != snapshot.sourceUri) return false;
    if (snapshot.size != null) {
      if (track.fileSize != snapshot.size) return false;
    } else if (track.fileSize != null) {
      return false;
    }
    if (snapshot.modifiedAt != null) {
      if (track.modifiedAt?.microsecondsSinceEpoch !=
          snapshot.modifiedAt!.microsecondsSinceEpoch) {
        return false;
      }
    } else if (track.modifiedAt != null) {
      return false;
    }
    return true;
  }

  /// Invalidates persisted content-linked identities and rejected-reader state
  /// when a source is observed to have changed, while preserving user metadata
  /// and listening statistics.
  void invalidateChangedSource(LocalTrack track, LocalSourceSnapshot snapshot) {
    track
      ..contentHash = null
      ..resolvedSongHash = null
      ..metadataLoaded = false;
    _rejectedChunkCandidates.clear();
  }

  void _applySnapshot(LocalTrack track, LocalSourceSnapshot snapshot) {
    track
      ..sourceUri = snapshot.sourceUri
      ..fileSize = snapshot.size
      ..modifiedAt = snapshot.modifiedAt
      ..supportsRandomAccess = snapshot.supportsRandomAccess
      ..available = true;
  }

  void applyMetadata(
    LocalTrack track, {
    required String title,
    required String artist,
    required String album,
    required int durationInSeconds,
    required int trackNumber,
    required int discNumber,
    required int year,
  }) {
    track
      ..name = title
      ..artistName = artist
      ..albumName = album
      ..durationInSeconds = durationInSeconds
      ..trackNumber = trackNumber
      ..discNumber = discNumber
      ..year = year
      ..potentialIdentityKey = PotentialIdentity.create(
        title: title,
        artist: artist,
        durationInSeconds: durationInSeconds,
      )
      ..metadataLoaded = true;
  }

  void reconcileMissing(Set<String> discoveredSourceKeys) {
    final changed = <LocalTrack>[];
    for (final track in _repository.getAll()) {
      if (track.available && !discoveredSourceKeys.contains(track.sourceKey)) {
        track.available = false;
        changed.add(track);
      }
    }
    if (changed.isNotEmpty) _repository.saveMany(changed);
  }

  Song toSongProjection(LocalTrack track) {
    final artist = Artist(
      'local-artist:${PotentialIdentity.create(title: track.artistName, artist: '', durationInSeconds: 0)}',
      track.artistName,
    );
    final album = Album(
      'local-album:${PotentialIdentity.create(title: track.albumName, artist: track.artistName, durationInSeconds: 0)}',
      track.albumName,
    )..artist.target = artist;
    final song =
        Song(track.contentHash ?? '')
          ..localSourceKey = track.sourceKey
          ..potentialIdentityKey = track.potentialIdentityKey
          ..path = track.sourceUri
          ..localFileSize = track.fileSize
          ..localFileModifiedAt = track.modifiedAt
          ..name = track.name
          ..durationInSeconds = track.durationInSeconds
          ..trackNumber = track.trackNumber
          ..discNumber = track.discNumber
          ..year = track.year
          ..fullyLoaded = true
          ..likedByUser = track.likedByUser
          ..lastPlayed = track.lastPlayed
          ..playCount = track.playCount
          ..artist.target = artist
          ..album.target = album;
    if (track.resolvedSongHash?.isNotEmpty == true) {
      song.potentialRemoteHashes = [track.resolvedSongHash!];
    }
    album.addSong(song);
    artist.addSong(song);
    return song;
  }

  void updateFromProjection(Song song) {
    final sourceKey = song.localSourceKey;
    if (sourceKey == null) return;
    final track = _repository.getBySourceKey(sourceKey);
    if (track == null) return;
    track
      ..likedByUser = song.likedByUser
      ..lastPlayed = song.lastPlayed
      ..playCount = song.playCount;
    _repository.save(track);
  }

  void _migrateLegacySongPaths() {
    final songs = _songRepository?.getAllSongs() ?? const <Song>[];
    final detached = <Song>[];
    final migrated = <LocalTrack>[];
    for (final song in songs.where((candidate) => candidate.hasLocalFile)) {
      final path = song.path!;
      if (_repository.getBySourceKey(path) == null) {
        migrated.add(
          LocalTrack(
              sourceKey: path,
              sourceUri: path,
              potentialIdentityKey: PotentialIdentity.create(
                title: song.name,
                artist: song.artist.target?.name ?? 'Unknown Artist',
                durationInSeconds: song.durationInSeconds,
              ),
              name: song.name,
              artistName: song.artist.target?.name ?? 'Unknown Artist',
              albumName: song.album.target?.name ?? 'Unknown Album',
              durationInSeconds: song.durationInSeconds,
              trackNumber: song.trackNumber,
              discNumber: song.discNumber,
              year: song.year,
              metadataLoaded: song.fullyLoaded,
            )
            ..contentHash = song.fileHash
            ..resolvedSongHash = song.fileHash
            ..fileSize = song.localFileSize
            ..modifiedAt = song.localFileModifiedAt
            ..likedByUser = song.likedByUser
            ..lastPlayed = song.lastPlayed
            ..playCount = song.playCount,
        );
      }
      song
        ..path = null
        ..localFileSize = null
        ..localFileModifiedAt = null;
      detached.add(song);
    }
    if (migrated.isNotEmpty) _repository.saveMany(migrated);
    if (detached.isNotEmpty) _songRepository?.updateSongs(detached);
  }

  Future<Uint8List?> readVerifiedPotentialChunk(
    Song remoteSong,
    ChunkManifestDto manifest,
    int chunkIndex,
  ) async {
    if (!manifest.isValidFor(remoteSong.fileHash) ||
        chunkIndex < 0 ||
        chunkIndex >= manifest.totalChunks) {
      return null;
    }
    final offset = chunkIndex * manifest.chunkSize;
    final remaining = manifest.totalBytes - offset;
    final expectedLength =
        remaining < manifest.chunkSize ? remaining : manifest.chunkSize;
    if (expectedLength <= 0) return null;
    final identity = PotentialIdentity.create(
      title: remoteSong.name,
      artist: remoteSong.artist.target?.name ?? 'Unknown Artist',
      durationInSeconds: remoteSong.durationInSeconds,
    );
    final candidates = _repository.getAll().where(
      (track) =>
          track.available &&
          track.supportsRandomAccess &&
          track.fileSize == manifest.totalBytes &&
          (track.contentHash == remoteSong.fileHash ||
              track.potentialIdentityKey == identity),
    );

    for (final track in candidates) {
      final sourceUri = track.sourceUri;
      final modifiedAt = track.modifiedAt;
      final fileSize = track.fileSize;
      final fingerprint =
          '${track.sourceKey}|$sourceUri|$fileSize|${modifiedAt?.microsecondsSinceEpoch}|${remoteSong.fileHash}|${manifest.chunkSize}|$chunkIndex|${manifest.hashes[chunkIndex]}';
      if (_rejectedChunkCandidates.contains(fingerprint)) continue;

      LocalByteRangeResult? result;
      try {
        result = await byteRangeReader.read(
          track,
          LocalByteRange(offset: offset, length: expectedLength),
        );
      } catch (_) {
        // Transient reader/platform errors are not permanently rejected.
        continue;
      }
      if (result == null || !result.sourceStable) continue;
      if (!track.available ||
          track.sourceUri != sourceUri ||
          track.fileSize != fileSize ||
          track.modifiedAt != modifiedAt ||
          result.snapshot.sourceKey != track.sourceKey ||
          result.snapshot.sourceUri != sourceUri) {
        continue;
      }
      if (result.bytes.length != expectedLength) {
        _rejectedChunkCandidates.add(fingerprint);
        continue;
      }
      if (result.snapshot.size != manifest.totalBytes) {
        _rejectedChunkCandidates.add(fingerprint);
        continue;
      }
      if (track.modifiedAt != null &&
          (result.snapshot.modifiedAt == null ||
              result.snapshot.modifiedAt!.microsecondsSinceEpoch !=
                  track.modifiedAt!.microsecondsSinceEpoch)) {
        _rejectedChunkCandidates.add(fingerprint);
        continue;
      }
      if (sha256.convert(result.bytes).toString() ==
          manifest.hashes[chunkIndex]) {
        return result.bytes;
      }
      _rejectedChunkCandidates.add(fingerprint);
    }
    return null;
  }
}
