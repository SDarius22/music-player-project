import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/albums/album_page_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_page_dto.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/dtos/negotiation_response_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_page_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';

void main() {
  group('Page DTOs', () {
    test('AlbumPageDto parses hash-based content', () {
      final dto = AlbumPageDto.fromJson({
        'content': [
          {
            'hash': 'album-hash',
            'name': 'Album One',
            'songFileHashes': ['s1'],
            'artist': {'hash': 'artist-hash', 'name': 'Artist One'},
          },
        ],
        'page': 0,
        'size': 1,
        'totalPages': 1,
        'totalElements': 1,
      });

      expect(dto.content.single.hash, 'album-hash');
      expect(dto.content.single.artist.hash, 'artist-hash');
      expect(dto.totalElements, 1);
    });

    test('ArtistPageDto parses hash-based content', () {
      final dto = ArtistPageDto.fromJson({
        'content': [
          {'hash': 'artist-hash', 'name': 'Artist', 'songFileHashes': ['s1', 's2']},
        ],
        'page': 0,
        'size': 1,
        'totalPages': 1,
        'totalElements': 1,
      });

      expect(dto.content.single.hash, 'artist-hash');
      expect(dto.content.single.songFileHashes, hasLength(2));
      expect(dto.totalElements, 1);
    });

    test('PlaylistPageDto parses playlist metadata', () {
      final dto = PlaylistPageDto.fromJson({
        'content': [
          {
            'id': 7,
            'name': 'Favorites',
            'songFileHashes': ['a', 'b'],
            'hasCover': true,
          },
        ],
      });

      expect(dto.content.single.id, 7);
      expect(dto.content.single.songFileHashes, ['a', 'b']);
      expect(dto.content.single.hasCover, isTrue);
    });

    test('SongPageDto parses nested artist/album fields', () {
      final dto = SongPageDto.fromJson({
        'content': [
          {
            'fileHash': 'song-hash',
            'name': 'Track',
            'durationInSeconds': 180,
            'trackNumber': 1,
            'discNumber': 1,
            'year': 2024,
            'artist': {'hash': 'artist-hash', 'name': 'Artist'},
            'album': {'hash': 'album-hash', 'name': 'Album'},
          },
        ],
      });

      expect(dto.content.single.fileHash, 'song-hash');
      expect(dto.content.single.artist.name, 'Artist');
      expect(dto.content.single.album.hash, 'album-hash');
    });
  });

  group('Other DTOs', () {
    test('ChunkManifestDto parses chunk metadata', () {
      final dto = ChunkManifestDto.fromJson({
        'fileHash': 'f1',
        'totalChunks': 2,
        'chunkSize': 65536,
        'totalBytes': 100000,
        'hashes': ['h1', 'h2'],
      });

      expect(dto.fileHash, 'f1');
      expect(dto.totalChunks, 2);
      expect(dto.hashes, ['h1', 'h2']);
    });

    test('NegotiationResponseDto parses missing indices', () {
      final dto = NegotiationResponseDto.fromJson({
        'fileHash': 'f2',
        'missingIndices': [0, 3],
      });

      expect(dto.fileHash, 'f2');
      expect(dto.missingIndices, [0, 3]);
    });
  });
}
