import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/albums/album_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_page_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_album_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_artist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_playlist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/playlist_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/song_rest_client.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class _FakeSongRestClient extends SongRestClient {
  _FakeSongRestClient()
    : super(
        baseUrl: 'http://localhost',
        authService: AuthService(baseUrl: 'http://localhost'),
      );

  final Map<String, SongDto> songs = {};

  @override
  Future<SongDto> getServerSong(String fileHash) async {
    final dto = songs[fileHash];
    if (dto == null) throw Exception('not found');
    return dto;
  }

  @override
  Future<SongPageDto> getSongsPage({
    String? query,
    String? filterAlbumHash,
    String? filterArtistHash,
    int? filterPlaylistId,
    int page = 0,
    int size = 50,
    String sort = 'name,asc',
  }) async {
    return SongPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }
}

class _FakePlaylistRestClient extends PlaylistRestClient {
  _FakePlaylistRestClient()
    : super(
        baseUrl: 'http://localhost',
        authService: AuthService(baseUrl: 'http://localhost'),
      );

  @override
  Future<PlaylistPageDto> getPlaylistsPage({
    String? query,
    bool? filterIndestructible,
    bool? includeQueue,
    int page = 0,
    int size = 50,
  }) async {
    return PlaylistPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }
}

SongDto _songDto(String hash, String name) {
  return SongDto(
    fileHash: hash,
    name: name,
    durationInSeconds: 120,
    trackNumber: 1,
    discNumber: 1,
    year: 2024,
    artist: ArtistDto(hash: 'artist-$hash', name: 'Artist $hash'),
    album: AlbumDto(hash: 'album-$hash', name: 'Album $hash'),
    playCount: 0,
    likedByUser: false,
  );
}

void main() {
  group('Song + Playlist integration flow', () {
    test('fetched songs can be queued into a playlist and paged by playlist hash', () async {
      final songRepo = InMemorySongRepository();
      final artistRepo = InMemoryArtistRepository();
      final albumRepo = InMemoryAlbumRepository();
      final playlistRepo = InMemoryPlaylistRepository();
      final songClient = _FakeSongRestClient();
      final playlistClient = _FakePlaylistRestClient();

      songClient.songs['s1'] = _songDto('s1', 'One');
      songClient.songs['s2'] = _songDto('s2', 'Two');

      final songService = SongService(songRepo, artistRepo, albumRepo, songClient);
      final playlistService = PlaylistService(
        playlistRepo,
        playlistClient,
        songRepo,
        songService,
      );

      final s1 = await songService.fetchSongByFileHash('s1');
      final s2 = await songService.fetchSongByFileHash('s2');
      expect(s1, isNotNull);
      expect(s2, isNotNull);

      final playlist = await playlistService.addPlaylist('Queue', [s2!, s1!], null);
      final page = await playlistService.getPlaylistSongsPageByHash(
        playlist.getHash(),
        page: 0,
        size: 10,
      );

      expect(page.content.map((Song s) => s.getHash()).toList(), ['s2', 's1']);
      expect(page.totalPages, 1);
    });
  });
}

