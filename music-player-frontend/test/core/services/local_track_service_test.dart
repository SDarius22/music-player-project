import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_local_track_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/services/local_byte_range_reader.dart';
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

  test('supportsRandomAccess defaults to true and honors discover input', () {
    final defaultTrack = service.discover(
      sourceKey: 'default',
      sourceUri: '/music/default.flac',
      fallbackTitle: 'Default',
    );
    final capped = service.discover(
      sourceKey: 'capped',
      sourceUri: 'content://media/audio/1',
      fallbackTitle: 'Capped',
      supportsRandomAccess: false,
    );

    expect(defaultTrack.supportsRandomAccess, isTrue);
    expect(capped.supportsRandomAccess, isFalse);
  });

  group('source lifecycle invalidation', () {
    LocalTrack seed({
      required String sourceKey,
      required String sourceUri,
      required int fileSize,
      required DateTime modifiedAt,
    }) {
      final track = service.discover(
        sourceKey: sourceKey,
        sourceUri: sourceUri,
        fallbackTitle: 'Song',
        fileSize: fileSize,
        modifiedAt: modifiedAt,
      );
      service.applyMetadata(
        track,
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        durationInSeconds: 120,
        trackNumber: 1,
        discNumber: 1,
        year: 2026,
      );
      track
        ..contentHash = 'remote-hash'
        ..resolvedSongHash = 'remote-hash'
        ..likedByUser = true
        ..lastPlayed = DateTime.utc(2026)
        ..playCount = 3;
      service.saveMany([track]);
      return track;
    }

    void expectInvalidated(LocalTrack track) {
      expect(track.contentHash, isNull);
      expect(track.resolvedSongHash, isNull);
      expect(track.metadataLoaded, isFalse);
      expect(track.likedByUser, isTrue);
      expect(track.playCount, 3);
      expect(track.lastPlayed, DateTime.utc(2026));
      expect(track.available, isTrue);
    }

    test('unchanged rediscovery preserves content and resolved identities', () {
      final modified = DateTime.utc(2026, 1, 2);
      final track = seed(
        sourceKey: '/music/song.flac',
        sourceUri: '/music/song.flac',
        fileSize: 100,
        modifiedAt: modified,
      );
      final snapshot = LocalSourceSnapshot(
        sourceKey: track.sourceKey,
        sourceUri: track.sourceUri,
        size: 100,
        modifiedAt: modified,
      );

      expect(service.isUnchanged(track, snapshot), isTrue);
      final rediscovered = service.discover(
        sourceKey: track.sourceKey,
        sourceUri: track.sourceUri,
        fallbackTitle: 'Song',
        fileSize: 100,
        modifiedAt: modified,
      );

      expect(rediscovered, same(track));
      expect(rediscovered.contentHash, 'remote-hash');
      expect(rediscovered.resolvedSongHash, 'remote-hash');
      expect(rediscovered.metadataLoaded, isTrue);
      expect(rediscovered.playCount, 3);
    });

    test('URI change invalidates identities while preserving stats', () {
      final modified = DateTime.utc(2026, 1, 2);
      final track = seed(
        sourceKey: 'key',
        sourceUri: '/music/old.flac',
        fileSize: 100,
        modifiedAt: modified,
      );
      final snapshot = LocalSourceSnapshot(
        sourceKey: 'key',
        sourceUri: '/music/new.flac',
        size: 100,
        modifiedAt: modified,
      );

      expect(service.isUnchanged(track, snapshot), isFalse);
      final rediscovered = service.discover(
        sourceKey: 'key',
        sourceUri: '/music/new.flac',
        fallbackTitle: 'Song',
        fileSize: 100,
        modifiedAt: modified,
      );

      expectInvalidated(rediscovered);
      expect(rediscovered.sourceUri, '/music/new.flac');
    });

    test('size change invalidates identities', () {
      final modified = DateTime.utc(2026, 1, 2);
      final track = seed(
        sourceKey: '/music/song.flac',
        sourceUri: '/music/song.flac',
        fileSize: 100,
        modifiedAt: modified,
      );
      final snapshot = LocalSourceSnapshot(
        sourceKey: track.sourceKey,
        sourceUri: track.sourceUri,
        size: 101,
        modifiedAt: modified,
      );

      expect(service.isUnchanged(track, snapshot), isFalse);
      final rediscovered = service.discover(
        sourceKey: track.sourceKey,
        sourceUri: track.sourceUri,
        fallbackTitle: 'Song',
        fileSize: 101,
        modifiedAt: modified,
      );

      expectInvalidated(rediscovered);
      expect(rediscovered.fileSize, 101);
    });

    test('modified time change invalidates identities', () {
      final track = seed(
        sourceKey: '/music/song.flac',
        sourceUri: '/music/song.flac',
        fileSize: 100,
        modifiedAt: DateTime.utc(2026, 1, 2),
      );
      final snapshot = LocalSourceSnapshot(
        sourceKey: track.sourceKey,
        sourceUri: track.sourceUri,
        size: 100,
        modifiedAt: DateTime.utc(2026, 1, 3),
      );

      expect(service.isUnchanged(track, snapshot), isFalse);
      expectInvalidated(
        service.discover(
          sourceKey: track.sourceKey,
          sourceUri: track.sourceUri,
          fallbackTitle: 'Song',
          fileSize: 100,
          modifiedAt: DateTime.utc(2026, 1, 3),
        ),
      );
    });

    test('a lost known hint invalidates conservatively', () {
      final track = seed(
        sourceKey: '/music/song.flac',
        sourceUri: '/music/song.flac',
        fileSize: 100,
        modifiedAt: DateTime.utc(2026, 1, 2),
      );
      final snapshot = LocalSourceSnapshot(
        sourceKey: track.sourceKey,
        sourceUri: track.sourceUri,
      );

      expect(service.isUnchanged(track, snapshot), isFalse);
      expectInvalidated(
        service.discover(
          sourceKey: track.sourceKey,
          sourceUri: track.sourceUri,
          fallbackTitle: 'Song',
        ),
      );
    });

    test('reappearance after unavailability invalidates old identity', () {
      final modified = DateTime.utc(2026, 1, 2);
      final track = seed(
        sourceKey: '/music/song.flac',
        sourceUri: '/music/song.flac',
        fileSize: 100,
        modifiedAt: modified,
      );
      service.reconcileMissing(const {});
      expect(repository.getBySourceKey('/music/song.flac')!.available, isFalse);
      expect(
        repository.getBySourceKey('/music/song.flac')!.contentHash,
        'remote-hash',
      );
      final snapshot = LocalSourceSnapshot(
        sourceKey: track.sourceKey,
        sourceUri: track.sourceUri,
        size: 100,
        modifiedAt: modified,
      );

      expect(service.isUnchanged(track, snapshot), isFalse);
      expectInvalidated(
        service.discover(
          sourceKey: track.sourceKey,
          sourceUri: track.sourceUri,
          fallbackTitle: 'Song',
          fileSize: 100,
          modifiedAt: modified,
        ),
      );
    });
  });

  group('verified chunk reads through the injected reader', () {
    late _FakeByteRangeReader reader;

    setUp(() {
      reader = _FakeByteRangeReader();
      service.byteRangeReader = reader;
    });

    Song song(String fileHash) =>
        Song(fileHash)
          ..name = 'Track'
          ..durationInSeconds = 120
          ..artist.target = Artist('artist', 'Artist');

    LocalTrack candidate({
      required String sourceUri,
      required int fileSize,
      required String contentHash,
    }) {
      final track = service.discover(
        sourceKey: sourceUri,
        sourceUri: sourceUri,
        fallbackTitle: 'Track',
        fileSize: fileSize,
        modifiedAt: DateTime.utc(2026, 1, 2),
      );
      track.contentHash = contentHash;
      service.saveMany([track]);
      return track;
    }

    Uint8List bytesOf(List<int> values) => Uint8List.fromList(values);

    test(
      'returns a verified exact chunk and the manifest-derived final chunk',
      () async {
        const fileHash = 'remote-hash';
        final first = bytesOf([1, 2, 3, 4]);
        final last = bytesOf([5, 6, 7]);
        final manifest = ChunkManifestDto.fromJson({
          'fileHash': fileHash,
          'totalChunks': 2,
          'chunkSize': 4,
          'totalBytes': 7,
          'hashes': [
            sha256.convert(first).toString(),
            sha256.convert(last).toString(),
          ],
        });
        final track = candidate(
          sourceUri: '/music/song.flac',
          fileSize: 7,
          contentHash: fileHash,
        );
        final requested = <LocalByteRange>[];
        reader.handler = (called, range) {
          requested.add(range);
          return LocalByteRangeResult(
            bytes: range.offset == 0 ? first : last,
            sourceStable: true,
            snapshot: LocalSourceSnapshot(
              sourceKey: track.sourceKey,
              sourceUri: track.sourceUri,
              size: 7,
              modifiedAt: DateTime.utc(2026, 1, 2),
            ),
          );
        };

        expect(
          await service.readVerifiedPotentialChunk(song(fileHash), manifest, 0),
          first,
        );
        expect(
          await service.readVerifiedPotentialChunk(song(fileHash), manifest, 1),
          last,
        );
        expect(requested, hasLength(2));
        expect(requested[0].offset, 0);
        expect(requested[0].length, 4);
        expect(requested[1].offset, 4);
        expect(requested[1].length, 3);
      },
    );

    test('rejects a short read without returning bytes', () async {
      final fileHash = 'remote-hash';
      final bytes = bytesOf([1, 2, 3, 4]);
      final manifest = ChunkManifestDto.fromJson({
        'fileHash': fileHash,
        'totalChunks': 1,
        'chunkSize': 4,
        'totalBytes': 4,
        'hashes': [sha256.convert(bytes).toString()],
      });
      candidate(
        sourceUri: '/music/song.flac',
        fileSize: 4,
        contentHash: fileHash,
      );
      reader.handler =
          (called, range) => LocalByteRangeResult(
            bytes: bytesOf([1, 2]),
            sourceStable: true,
            snapshot: const LocalSourceSnapshot(
              sourceKey: 'k',
              sourceUri: '/music/song.flac',
              size: 4,
            ),
          );

      expect(
        await service.readVerifiedPotentialChunk(song(fileHash), manifest, 0),
        isNull,
      );
    });

    test('rejects a digest mismatch without returning bytes', () async {
      const fileHash = 'remote-hash';
      final manifest = ChunkManifestDto.fromJson({
        'fileHash': fileHash,
        'totalChunks': 1,
        'chunkSize': 4,
        'totalBytes': 4,
        'hashes': [
          sha256.convert([1, 2, 3, 4]).toString(),
        ],
      });
      final track = candidate(
        sourceUri: '/music/song.flac',
        fileSize: 4,
        contentHash: fileHash,
      );
      reader.handler =
          (called, range) => LocalByteRangeResult(
            bytes: bytesOf([9, 9, 9, 9]),
            sourceStable: true,
            snapshot: LocalSourceSnapshot(
              sourceKey: track.sourceKey,
              sourceUri: track.sourceUri,
              size: 4,
              modifiedAt: track.modifiedAt,
            ),
          );

      expect(
        await service.readVerifiedPotentialChunk(song(fileHash), manifest, 0),
        isNull,
      );
    });

    test('rejects an unstable reader result', () async {
      const fileHash = 'remote-hash';
      final manifest = ChunkManifestDto.fromJson({
        'fileHash': fileHash,
        'totalChunks': 1,
        'chunkSize': 4,
        'totalBytes': 4,
        'hashes': [
          sha256.convert([1, 2, 3, 4]).toString(),
        ],
      });
      final track = candidate(
        sourceUri: '/music/song.flac',
        fileSize: 4,
        contentHash: fileHash,
      );
      reader.handler =
          (called, range) => LocalByteRangeResult(
            bytes: bytesOf([1, 2, 3, 4]),
            sourceStable: false,
            snapshot: LocalSourceSnapshot(
              sourceKey: track.sourceKey,
              sourceUri: track.sourceUri,
              size: 4,
              modifiedAt: track.modifiedAt,
            ),
          );

      expect(
        await service.readVerifiedPotentialChunk(song(fileHash), manifest, 0),
        isNull,
      );
    });

    test('rejects a snapshot size inconsistent with the manifest', () async {
      const fileHash = 'remote-hash';
      final manifest = ChunkManifestDto.fromJson({
        'fileHash': fileHash,
        'totalChunks': 1,
        'chunkSize': 4,
        'totalBytes': 4,
        'hashes': [
          sha256.convert([1, 2, 3, 4]).toString(),
        ],
      });
      candidate(
        sourceUri: '/music/song.flac',
        fileSize: 4,
        contentHash: fileHash,
      );
      reader.handler =
          (called, range) => LocalByteRangeResult(
            bytes: bytesOf([1, 2, 3, 4]),
            sourceStable: true,
            snapshot: const LocalSourceSnapshot(
              sourceKey: 'k',
              sourceUri: '/music/song.flac',
              size: 99,
            ),
          );

      expect(
        await service.readVerifiedPotentialChunk(song(fileHash), manifest, 0),
        isNull,
      );
    });

    test(
      'rejects a snapshot whose modified time differs from the record',
      () async {
        const fileHash = 'remote-hash';
        final manifest = ChunkManifestDto.fromJson({
          'fileHash': fileHash,
          'totalChunks': 1,
          'chunkSize': 4,
          'totalBytes': 4,
          'hashes': [
            sha256.convert([1, 2, 3, 4]).toString(),
          ],
        });
        candidate(
          sourceUri: '/music/song.flac',
          fileSize: 4,
          contentHash: fileHash,
        );
        reader.handler =
            (called, range) => LocalByteRangeResult(
              bytes: bytesOf([1, 2, 3, 4]),
              sourceStable: true,
              snapshot: const LocalSourceSnapshot(
                sourceKey: 'k',
                sourceUri: '/music/song.flac',
                size: 4,
                modifiedAt: null,
              ),
            );

        expect(
          await service.readVerifiedPotentialChunk(song(fileHash), manifest, 0),
          isNull,
        );
      },
    );

    test('does not permanently reject transient null reader results', () async {
      const fileHash = 'remote-hash';
      final bytes = bytesOf([1, 2, 3, 4]);
      final manifest = ChunkManifestDto.fromJson({
        'fileHash': fileHash,
        'totalChunks': 1,
        'chunkSize': 4,
        'totalBytes': 4,
        'hashes': [sha256.convert(bytes).toString()],
      });
      final track = candidate(
        sourceUri: '/music/song.flac',
        fileSize: 4,
        contentHash: fileHash,
      );
      reader.handler = (called, range) {
        if (reader.calls == 1) return null;
        return LocalByteRangeResult(
          bytes: bytes,
          sourceStable: true,
          snapshot: LocalSourceSnapshot(
            sourceKey: track.sourceKey,
            sourceUri: track.sourceUri,
            size: 4,
            modifiedAt: track.modifiedAt,
          ),
        );
      };

      expect(
        await service.readVerifiedPotentialChunk(song(fileHash), manifest, 0),
        isNull,
      );
      expect(
        await service.readVerifiedPotentialChunk(song(fileHash), manifest, 0),
        bytes,
      );
    });
  });
}

class _FakeByteRangeReader implements LocalByteRangeReader {
  _FakeByteRangeReader();

  LocalByteRangeResult? Function(LocalTrack track, LocalByteRange range)?
  handler;
  int calls = 0;

  @override
  Future<LocalByteRangeResult?> read(
    LocalTrack track,
    LocalByteRange range,
  ) async {
    calls++;
    return handler?.call(track, range);
  }
}
