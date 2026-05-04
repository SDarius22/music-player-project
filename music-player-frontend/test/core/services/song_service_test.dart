import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/albums/album_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_album_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_artist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/song_rest_client.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class FakeSongRestClient extends SongRestClient {
  FakeSongRestClient()
    : super(
        baseUrl: 'http://localhost',
        authService: AuthService(baseUrl: 'http://localhost'),
      );

  final Map<String, SongDto> byHash = {};
  SongPageDto songsPage = SongPageDto(
    content: const [],
    page: 0,
    size: 50,
    totalPages: 0,
    totalElements: 0,
  );

  @override
  Future<SongDto> getServerSong(String fileHash) async {
    final dto = byHash[fileHash];
    if (dto == null) throw Exception('not found');
    return dto;
  }

  @override
  Future<SongPageDto> getSongsPage({
    String? query,
    int page = 0,
    int size = 50,
    String sort = 'name,asc',
  }) async {
    return songsPage;
  }
}

SongDto buildSongDto(String hash) {
  return SongDto(
    fileHash: hash,
    name: 'Track $hash',
    durationInSeconds: 120,
    trackNumber: 1,
    discNumber: 1,
    year: 2024,
    artist: ArtistDto(hash: 'artist-$hash', name: 'Artist'),
    album: AlbumDto(hash: 'album-$hash', name: 'Album'),
    playCount: 0,
    likedByUser: false,
  );
}

void main() {
  group('SongService', () {
    late InMemorySongRepository songRepo;
    late InMemoryArtistRepository artistRepo;
    late InMemoryAlbumRepository albumRepo;
    late FakeSongRestClient restClient;
    late SongService service;

    setUp(() {
      songRepo = InMemorySongRepository();
      artistRepo = InMemoryArtistRepository();
      albumRepo = InMemoryAlbumRepository();
      restClient = FakeSongRestClient();
      service = SongService(songRepo, artistRepo, albumRepo, restClient);
    });

    test('getLocalSong throws on empty hash', () {
      expect(() => service.getLocalSong(''), throwsArgumentError);
    });

    test('fetchSongByFileHash returns local song when present', () async {
      final local = Song('local-hash')
        ..name = 'Local'
        ..fullyLoaded = true;
      songRepo.saveSong(local);

      final result = await service.fetchSongByFileHash('local-hash');

      expect(result, same(local));
    });

    test('fetchSongByFileHash caches server response on local miss', () async {
      restClient.byHash['remote-hash'] = buildSongDto('remote-hash');

      final result = await service.fetchSongByFileHash('remote-hash');

      expect(result, isNotNull);
      expect(result!.getHash(), 'remote-hash');
      expect(result.fullyLoaded, isTrue);
      expect(result.artist.target?.name, 'Artist');
      expect(result.album.target?.name, 'Album');
    });

    test('getSongsPage returns local results when localOnly is true', () async {
      final local = Song('h1')
        ..name = 'Track'
        ..fullyLoaded = true;
      songRepo.saveSong(local);

      final page = await service.getSongsPage('', 'Title', true, true, 0, 20);

      expect(page.content, hasLength(1));
      expect(page.content.first.getHash(), 'h1');
      expect(page.totalPages, 1);
    });
  });
}
