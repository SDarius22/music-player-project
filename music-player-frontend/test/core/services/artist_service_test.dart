import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_expanded_dto.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_album_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_artist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/artist_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';

void main() {
  group('ArtistService', () {
    late InMemoryArtistRepository artistRepo;
    late InMemorySongRepository songRepo;
    late ArtistService service;

    setUp(() {
      artistRepo = InMemoryArtistRepository();
      songRepo = InMemorySongRepository();
      service = ArtistService(
        artistRepo,
        InMemoryAlbumRepository(),
        songRepo,
        ArtistRestClient(
          baseUrl: 'http://localhost',
          authService: AuthService(baseUrl: 'http://localhost'),
        ),
      );
    });

    test('getOrCreateArtist is stable for the same name', () {
      final first = service.getOrCreateArtist('Daft Punk');
      final second = service.getOrCreateArtist('Daft Punk');

      expect(first.id, isPositive);
      expect(second.id, first.id);
      expect(first.getHash(), second.getHash());
    });

    test('cacheServerArtist links songs to cached artist', () {
      final cached = service.cacheServerArtist(
        ArtistExpandedDto(
          hash: 'artist-hash',
          name: 'Artist',
          songFileHashes: ['s1', 's2'],
        ),
      );

      expect(cached.getSongs().map((s) => s.getHash()).toSet(), {'s1', 's2'});
      expect(songRepo.getSongByFileHash('s1')?.artist.targetId, cached.id);
    });
  });
}
