import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/album_page_dto.dart';
import 'package:music_player_frontend/core/dtos/artist_page_dto.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/dtos/negotiation_request_dto.dart';
import 'package:music_player_frontend/core/dtos/negotiation_response_dto.dart';
import 'package:music_player_frontend/core/dtos/playlist_page_dto.dart';
import 'package:music_player_frontend/core/dtos/song_page_dto.dart';
import 'package:music_player_frontend/core/dtos/song_sync_dto.dart';
import 'package:music_player_frontend/core/dtos/sync_request_dto.dart';
import 'package:music_player_frontend/core/dtos/sync_response_dto.dart';

void main() {
  // ─── AlbumPageDto ─────────────────────────────────────────────────────────

  group('AlbumPageDto.fromJson', () {
    test('parses full response', () {
      final dto = AlbumPageDto.fromJson({
        'content': [
          {'id': 1, 'name': 'Album One'},
          {'id': 2, 'name': 'Album Two'},
        ],
        'page': 0,
        'size': 2,
        'totalPages': 5,
        'totalElements': 10,
      });

      expect(dto.content.length, 2);
      expect(dto.content.first.name, 'Album One');
      expect(dto.content.first.serverId, 1);
      expect(dto.page, 0);
      expect(dto.size, 2);
      expect(dto.totalPages, 5);
      expect(dto.totalElements, 10);
    });

    test('uses defaults when fields absent', () {
      final dto = AlbumPageDto.fromJson({});

      expect(dto.content, isEmpty);
      expect(dto.page, 0);
      expect(dto.size, 0);
      expect(dto.totalPages, 1);
      expect(dto.totalElements, 0);
    });

    test('size defaults to content length when absent', () {
      final dto = AlbumPageDto.fromJson({
        'content': [
          {'id': 1, 'name': 'A'},
          {'id': 2, 'name': 'B'},
        ],
      });
      expect(dto.size, 2);
      expect(dto.totalElements, 2);
    });
  });

  // ─── ArtistPageDto ────────────────────────────────────────────────────────

  group('ArtistPageDto.fromJson', () {
    test('parses full response', () {
      final dto = ArtistPageDto.fromJson({
        'content': [
          {'id': 10, 'name': 'Led Zeppelin'},
        ],
        'page': 1,
        'size': 1,
        'totalPages': 3,
        'totalElements': 3,
      });

      expect(dto.content.length, 1);
      expect(dto.content.first.name, 'Led Zeppelin');
      expect(dto.content.first.serverId, 10);
      expect(dto.page, 1);
      expect(dto.size, 1);
      expect(dto.totalPages, 3);
      expect(dto.totalElements, 3);
    });

    test('uses defaults when fields absent', () {
      final dto = ArtistPageDto.fromJson({});

      expect(dto.content, isEmpty);
      expect(dto.page, 0);
      expect(dto.totalPages, 1);
      expect(dto.totalElements, 0);
    });
  });

  // ─── PlaylistPageDto ──────────────────────────────────────────────────────

  group('PlaylistPageDto.fromJson', () {
    test('parses full response including songIds', () {
      final dto = PlaylistPageDto.fromJson({
        'content': [
          {
            'id': 5,
            'name': 'Chill',
            'songIds': [1, 2, 3],
          },
        ],
        'page': 0,
        'size': 1,
        'totalPages': 1,
        'totalElements': 1,
      });

      expect(dto.content.length, 1);
      expect(dto.content.first.name, 'Chill');
      expect(dto.content.first.serverId, 5);
      expect(dto.content.first.serverSongIds, equals([1, 2, 3]));
      expect(dto.page, 0);
      expect(dto.totalPages, 1);
      expect(dto.totalElements, 1);
    });

    test('uses defaults when fields absent', () {
      final dto = PlaylistPageDto.fromJson({});

      expect(dto.content, isEmpty);
      expect(dto.page, 0);
      expect(dto.totalPages, 1);
    });
  });

  // ─── SongPageDto ──────────────────────────────────────────────────────────

  group('SongPageDto.fromJson', () {
    test('parses full response', () {
      final dto = SongPageDto.fromJson({
        'content': [
          {
            'id': 99,
            'name': 'Comfortably Numb',
            'durationInSeconds': 382,
            'trackNumber': 6,
            'discNumber': 2,
            'year': 1979,
            'artistId': 1,
            'albumId': 2,
          },
        ],
        'page': 0,
        'size': 1,
        'totalPages': 2,
        'totalElements': 2,
      });

      expect(dto.content.length, 1);
      expect(dto.content.first.serverId, 99);
      expect(dto.content.first.name, 'Comfortably Numb');
      expect(dto.content.first.durationInSeconds, 382);
      expect(dto.page, 0);
      expect(dto.totalPages, 2);
      expect(dto.totalElements, 2);
    });

    test('uses defaults when fields absent', () {
      final dto = SongPageDto.fromJson({});

      expect(dto.content, isEmpty);
      expect(dto.page, 0);
      expect(dto.totalPages, 1);
      expect(dto.totalElements, 0);
    });
  });

  // ─── ChunkManifestDto ─────────────────────────────────────────────────────

  group('ChunkManifestDto.fromJson', () {
    test('parses all fields', () {
      final dto = ChunkManifestDto.fromJson({
        'songId': 7,
        'totalChunks': 10,
        'chunkSize': 65536,
        'totalBytes': 655360,
        'hashes': ['abc', 'def'],
      });

      expect(dto.songId, 7);
      expect(dto.totalChunks, 10);
      expect(dto.chunkSize, 65536);
      expect(dto.totalBytes, 655360);
      expect(dto.hashes, equals(['abc', 'def']));
    });
  });

  // ─── SongSyncDto ──────────────────────────────────────────────────────────

  group('SongSyncDto.fromJson', () {
    test('parses all fields including dates', () {
      final dto = SongSyncDto.fromJson({
        'songId': 12,
        'likedByUser': true,
        'isDeleted': false,
        'lastPlayed': '2024-06-01T12:00:00.000',
        'addedAt': '2024-01-01T00:00:00.000',
      });

      expect(dto.songId, 12);
      expect(dto.playCountDelta, 0); // always 0 from fromJson
      expect(dto.likedByUser, isTrue);
      expect(dto.isDeleted, isFalse);
      expect(dto.lastPlayed, isNotNull);
      expect(dto.addedAt, isNotNull);
    });

    test('null dates stay null', () {
      final dto = SongSyncDto.fromJson({
        'songId': 1,
        'lastPlayed': null,
        'addedAt': null,
      });

      expect(dto.lastPlayed, isNull);
      expect(dto.addedAt, isNull);
    });

    test('isDeleted defaults to false when absent', () {
      final dto = SongSyncDto.fromJson({'songId': 1});
      expect(dto.isDeleted, isFalse);
    });
  });

  group('SongSyncDto.toJson', () {
    test('serializes all fields', () {
      final dt = DateTime(2024, 6, 1, 12);
      final added = DateTime(2024, 1, 1);
      final dto = SongSyncDto(
        songId: 5,
        playCountDelta: 3,
        likedByUser: true,
        isDeleted: false,
        lastPlayed: dt,
        addedAt: added,
      );

      final json = dto.toJson();

      expect(json['songId'], 5);
      expect(json['playCountDelta'], 3);
      expect(json['likedByUser'], isTrue);
      expect(json['isDeleted'], isFalse);
      expect(json['lastPlayed'], dt.toIso8601String());
      expect(json['addedAt'], added.toIso8601String());
    });

    test('null dates serialize to null', () {
      final dto = SongSyncDto(songId: 1);
      final json = dto.toJson();
      expect(json['lastPlayed'], isNull);
      expect(json['addedAt'], isNull);
    });
  });

  // ─── SyncRequestDto ───────────────────────────────────────────────────────

  group('SyncRequestDto.toJson', () {
    test('serializes with lastSyncTime and localChanges', () {
      final syncTime = DateTime(2024, 3, 15, 10, 0, 0);
      final change = SongSyncDto(songId: 7, playCountDelta: 2);
      final dto = SyncRequestDto(
        lastSyncTime: syncTime,
        localChanges: [change],
      );

      final json = dto.toJson();

      expect(json['lastSyncTime'], syncTime.toIso8601String());
      expect((json['localChanges'] as List).length, 1);
      expect((json['localChanges'] as List).first['songId'], 7);
    });

    test('null lastSyncTime serializes to null', () {
      final dto = SyncRequestDto(lastSyncTime: null, localChanges: []);
      final json = dto.toJson();
      expect(json['lastSyncTime'], isNull);
      expect(json['localChanges'], isEmpty);
    });
  });

  // ─── SyncResponseDto ──────────────────────────────────────────────────────

  group('SyncResponseDto.fromJson', () {
    test('parses newSyncTime and serverChanges', () {
      final dto = SyncResponseDto.fromJson({
        'newSyncTime': '2024-06-01T00:00:00.000',
        'serverChanges': [
          {'songId': 3, 'isDeleted': true},
        ],
      });

      expect(dto.newSyncTime, DateTime.parse('2024-06-01T00:00:00.000'));
      expect(dto.serverChanges.length, 1);
      expect(dto.serverChanges.first.songId, 3);
      expect(dto.serverChanges.first.isDeleted, isTrue);
    });

    test('empty serverChanges list', () {
      final dto = SyncResponseDto.fromJson({
        'newSyncTime': '2024-01-01T00:00:00.000',
        'serverChanges': [],
      });
      expect(dto.serverChanges, isEmpty);
    });
  });

  // ─── NegotiationRequestDto ────────────────────────────────────────────────

  group('NegotiationRequestDto.toJson', () {
    test('serializes all fields with correct key names', () {
      final dto = NegotiationRequestDto(
        name: 'Stairway',
        artistName: 'Led Zeppelin',
        albumName: 'IV',
        photoBase64: 'abc==',
        durationInSeconds: 482,
        trackNumber: 4,
        discNumber: 1,
        year: 1971,
        fileHash: 'sha256hash',
        hashes: ['h1', 'h2'],
      );

      final json = dto.toJson();

      expect(json['name'], 'Stairway');
      expect(json['artistName'], 'Led Zeppelin');
      expect(json['albumName'], 'IV');
      expect(json['photo'], 'abc==');
      expect(json['durationInSeconds'], 482);
      expect(json['trackNumber'], 4);
      expect(json['discNumber'], 1);
      expect(json['releaseYear'], 1971);
      expect(json['fileHash'], 'sha256hash');
      expect(json['hashes'], equals(['h1', 'h2']));
    });
  });

  // ─── NegotiationResponseDto ───────────────────────────────────────────────

  group('NegotiationResponseDto.fromJson', () {
    test('parses songId and missingIndices', () {
      final dto = NegotiationResponseDto.fromJson({
        'songId': 42,
        'missingIndices': [0, 3, 7],
      });

      expect(dto.songId, 42);
      expect(dto.missingIndices, equals([0, 3, 7]));
    });

    test('empty missingIndices', () {
      final dto = NegotiationResponseDto.fromJson({
        'songId': 1,
        'missingIndices': [],
      });
      expect(dto.missingIndices, isEmpty);
    });
  });
}
