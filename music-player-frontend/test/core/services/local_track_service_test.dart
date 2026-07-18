import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_local_track_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';

void main() {
  late InMemoryLocalTrackRepository repository;
  late LocalTrackService service;

  setUp(() {
    repository = InMemoryLocalTrackRepository();
    service = LocalTrackService(repository);
  });

  test('discovery creates an immediately playable unresolved local track', () {
    final track = service.discover(
      sourceKey: '/music/song.flac',
      sourceUri: '/music/song.flac',
      fallbackTitle: 'song',
      fileSize: 42,
      modifiedAt: DateTime.utc(2026),
    );
    service.saveMany([track]);

    expect(track.contentHash, isNull);
    expect(track.isLocal, isTrue);
    expect(track.getHash(), startsWith('local:'));
    expect(repository.getBySourceKey(track.sourceKey), same(track));
  });

  test('metadata enrichment changes potential identity without hashing', () {
    final track = service.discover(
      sourceKey: 'source',
      sourceUri: '/music/song.flac',
      fallbackTitle: 'song',
    );
    final discoveryIdentity = track.potentialIdentityKey;

    service.applyMetadata(
      track,
      title: 'Get Lucky',
      artist: 'Daft Punk',
      album: 'Random Access Memories',
      durationInSeconds: 248,
      trackNumber: 8,
      discNumber: 1,
      year: 2013,
    );

    expect(track.contentHash, isNull);
    expect(track.metadataLoaded, isTrue);
    expect(track.potentialIdentityKey, isNot(discoveryIdentity));
  });

  test(
    'missing reconciliation retains metadata and marks source unavailable',
    () {
      final track = service.discover(
        sourceKey: 'removed',
        sourceUri: '/music/removed.flac',
        fallbackTitle: 'Removed',
      );
      service.saveMany([track]);

      service.reconcileMissing({});

      expect(repository.getBySourceKey('removed')!.available, isFalse);
      expect(repository.getBySourceKey('removed')!.name, 'Removed');
    },
  );

  test('potential local bytes require a matching manifest hash', () async {
    final directory = await Directory.systemTemp.createTemp('local-chunk-');
    addTearDown(() => directory.delete(recursive: true));
    final bytes = [1, 2, 3, 4];
    final file = File('${directory.path}/song.flac');
    await file.writeAsBytes(bytes);
    final stat = await file.stat();
    final track = service.discover(
      sourceKey: file.path,
      sourceUri: file.path,
      fallbackTitle: 'Track',
      fileSize: stat.size,
      modifiedAt: stat.modified,
    );
    service.applyMetadata(
      track,
      title: 'Track',
      artist: 'Artist',
      album: 'Album',
      durationInSeconds: 120,
      trackNumber: 1,
      discNumber: 1,
      year: 2026,
    );
    service.saveMany([track]);
    final song =
        Song('remote-hash')
          ..name = 'Track'
          ..durationInSeconds = 120
          ..artist.target = Artist('artist', 'Artist');
    final manifest = ChunkManifestDto.fromJson({
      'fileHash': 'remote-hash',
      'totalChunks': 1,
      'chunkSize': 4,
      'totalBytes': 4,
      'hashes': [sha256.convert(bytes).toString()],
    });

    expect(await service.readVerifiedPotentialChunk(song, manifest, 0), bytes);
  });

  test('migrates legacy song paths and preserves their metadata', () {
    final songRepository = InMemorySongRepository();
    final artist = Artist('artist', 'Artist');
    final album = Album('album', 'Album')..artist.target = artist;
    final modified = DateTime.utc(2026, 1, 2);
    final legacy =
        Song('legacy-hash')
          ..name = 'Legacy'
          ..path = '/music/legacy.flac'
          ..localFileSize = 123
          ..localFileModifiedAt = modified
          ..durationInSeconds = 90
          ..trackNumber = 2
          ..discNumber = 1
          ..year = 2020
          ..fullyLoaded = true
          ..likedByUser = true
          ..playCount = 4
          ..artist.target = artist
          ..album.target = album;
    songRepository.saveSong(legacy);

    LocalTrackService(repository, songRepository);

    final migrated = repository.getBySourceKey('/music/legacy.flac')!;
    expect(migrated.contentHash, 'legacy-hash');
    expect(migrated.name, 'Legacy');
    expect(migrated.artistName, 'Artist');
    expect(migrated.albumName, 'Album');
    expect(migrated.fileSize, 123);
    expect(migrated.modifiedAt, modified);
    expect(migrated.likedByUser, isTrue);
    expect(migrated.playCount, 4);
    expect(legacy.path, isNull);
    expect(legacy.localFileSize, isNull);
  });

  test('updates mutable local metadata from a song projection', () {
    final track = service.discover(
      sourceKey: 'source',
      sourceUri: '/music/song.flac',
      fallbackTitle: 'Song',
    );
    service.saveMany([track]);
    final projection =
        service.toSongProjection(track)
          ..likedByUser = true
          ..lastPlayed = DateTime.utc(2026)
          ..playCount = 7;

    service.updateFromProjection(projection);
    service.updateFromProjection(Song('unrelated'));

    final updated = repository.getBySourceKey('source')!;
    expect(updated.likedByUser, isTrue);
    expect(updated.lastPlayed, DateTime.utc(2026));
    expect(updated.playCount, 7);
  });

  test(
    'rejects invalid, remote, changed, and corrupt chunk candidates',
    () async {
      final directory = await Directory.systemTemp.createTemp('local-chunk-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/song.flac');
      await file.writeAsBytes([1, 2, 3, 4]);
      final stat = await file.stat();
      final local = service.discover(
        sourceKey: file.path,
        sourceUri: file.path,
        fallbackTitle: 'Track',
        fileSize: stat.size,
        modifiedAt: stat.modified,
      );
      service.applyMetadata(
        local,
        title: 'Track',
        artist: 'Artist',
        album: 'Album',
        durationInSeconds: 120,
        trackNumber: 1,
        discNumber: 1,
        year: 2026,
      );
      final remoteSource = service.discover(
        sourceKey: 'content-uri',
        sourceUri: 'content://music/song',
        fallbackTitle: 'Track',
        fileSize: 4,
      );
      service.applyMetadata(
        remoteSource,
        title: 'Track',
        artist: 'Artist',
        album: 'Album',
        durationInSeconds: 120,
        trackNumber: 1,
        discNumber: 1,
        year: 2026,
      );
      service.saveMany([remoteSource, local]);
      final song =
          Song('remote-hash')
            ..name = 'Track'
            ..durationInSeconds = 120
            ..artist.target = Artist('artist', 'Artist');
      final corruptManifest = ChunkManifestDto.fromJson({
        'fileHash': 'remote-hash',
        'totalChunks': 1,
        'chunkSize': 4,
        'totalBytes': 4,
        'hashes': [
          sha256.convert([9, 9, 9, 9]).toString(),
        ],
      });

      expect(
        await service.readVerifiedPotentialChunk(song, corruptManifest, -1),
        isNull,
      );
      expect(
        await service.readVerifiedPotentialChunk(song, corruptManifest, 0),
        isNull,
      );
      expect(
        await service.readVerifiedPotentialChunk(song, corruptManifest, 0),
        isNull,
      );
    },
  );
}
