import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_local_track_repository.dart';
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
}
