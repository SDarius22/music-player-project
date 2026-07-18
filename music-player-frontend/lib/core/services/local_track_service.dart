import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/local_track_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/services/potential_identity.dart';

class LocalTrackService {
  final LocalTrackRepository _repository;
  final SongRepository? _songRepository;
  final Set<String> _rejectedChunkCandidates = {};

  LocalTrackService(this._repository, [this._songRepository]) {
    _migrateLegacySongPaths();
  }

  Stream<List<LocalTrack>> get watchTracks => _repository.watch();

  LocalTrack? getBySourceKey(String sourceKey) =>
      _repository.getBySourceKey(sourceKey);

  List<LocalTrack> getAll() => _repository.getAll();

  void saveMany(List<LocalTrack> tracks) => _repository.saveMany(tracks);

  LocalTrack discover({
    required String sourceKey,
    required String sourceUri,
    required String fallbackTitle,
    int? fileSize,
    DateTime? modifiedAt,
  }) {
    final existing = _repository.getBySourceKey(sourceKey);
    final track =
        existing ??
        LocalTrack(
          sourceKey: sourceKey,
          sourceUri: sourceUri,
          potentialIdentityKey: PotentialIdentity.create(
            title: fallbackTitle,
            artist: 'Unknown Artist',
            durationInSeconds: 0,
          ),
          name: fallbackTitle,
        );
    track
      ..sourceUri = sourceUri
      ..fileSize = fileSize
      ..modifiedAt = modifiedAt
      ..available = true;
    return track;
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
      final uri = Uri.tryParse(track.sourceUri);
      if (uri != null && uri.hasScheme && uri.scheme != 'file') continue;
      final path = uri?.scheme == 'file' ? uri!.toFilePath() : track.sourceUri;
      final fingerprint =
          '${track.sourceKey}|${track.fileSize}|${track.modifiedAt?.microsecondsSinceEpoch}|${remoteSong.fileHash}';
      if (_rejectedChunkCandidates.contains(fingerprint)) continue;

      RandomAccessFile? handle;
      try {
        final file = File(path);
        final before = await file.stat();
        if (before.size != manifest.totalBytes ||
            (track.modifiedAt != null &&
                before.modified.microsecondsSinceEpoch !=
                    track.modifiedAt!.microsecondsSinceEpoch)) {
          _rejectedChunkCandidates.add(fingerprint);
          continue;
        }
        final offset = chunkIndex * manifest.chunkSize;
        final expectedLength = (manifest.totalBytes - offset).clamp(
          0,
          manifest.chunkSize,
        );
        handle = await file.open();
        await handle.setPosition(offset);
        final bytes = await handle.read(expectedLength);
        final after = await file.stat();
        if (after.size != before.size ||
            after.modified.microsecondsSinceEpoch !=
                before.modified.microsecondsSinceEpoch) {
          _rejectedChunkCandidates.add(fingerprint);
          continue;
        }
        if (sha256.convert(bytes).toString() == manifest.hashes[chunkIndex]) {
          return bytes;
        }
        _rejectedChunkCandidates.add(fingerprint);
      } catch (_) {
        _rejectedChunkCandidates.add(fingerprint);
      } finally {
        await handle?.close();
      }
    }
    return null;
  }
}
