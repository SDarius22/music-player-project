import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/dtos/albums/album_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/create_playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_detail_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_page_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_song_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/update_playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_playlist_repository.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/playlist_rest_client.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class FakeSongService extends Fake implements SongService {
  final Map<String, Song> _songs = {};
  List<Song> recent = [];

  @override
  Song getOrCreateSong(String fileHash) {
    return _songs.putIfAbsent(fileHash, () => Song(fileHash));
  }

  @override
  List<Song> cacheServerSongs(List<SongDto> serverSongs) {
    return serverSongs.map((dto) => getOrCreateSong(dto.fileHash)).toList();
  }

  @override
  Future<List<Song>> getRecentlyPlayedSongs(int limit) async {
    return recent.take(limit).toList();
  }
}

class FakePlaylistRestClient extends PlaylistRestClient {
  FakePlaylistRestClient()
    : super(
        baseUrl: 'http://localhost',
        authService: AuthService(baseUrl: 'http://localhost'),
      );

  PlaylistPageDto pageToReturn = PlaylistPageDto(
    content: const [],
    page: 0,
    size: 50,
    totalPages: 0,
    totalElements: 0,
  );
  PlaylistDetailDto? createResult;
  bool updateResult = true;
  bool deleteResult = true;

  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  CreatePlaylistDto? lastCreateRequest;
  UpdatePlaylistDto? lastUpdateRequest;

  @override
  Future<PlaylistPageDto> getPlaylistsPage({
    String? query,
    bool? filterIndestructible,
    bool? includeQueue,
    int page = 0,
    int size = 50,
  }) async {
    return pageToReturn;
  }

  @override
  Future<PlaylistDetailDto?> createPlaylist(CreatePlaylistDto createPlaylistDto) async {
    createCalls++;
    lastCreateRequest = createPlaylistDto;
    return createResult;
  }

  @override
  Future<bool> updatePlaylist(int playlistId, UpdatePlaylistDto updatePlaylistDto) async {
    updateCalls++;
    lastUpdateRequest = updatePlaylistDto;
    return updateResult;
  }

  @override
  Future<bool> deletePlaylist(int playlistId) async {
    deleteCalls++;
    return deleteResult;
  }
}

void main() {
  group('PlaylistService', () {
    late InMemoryPlaylistRepository playlistRepo;
    late FakeSongService songService;
    late FakePlaylistRestClient restClient;
    late PlaylistService service;

    setUp(() {
      playlistRepo = InMemoryPlaylistRepository();
      songService = FakeSongService();
      restClient = FakePlaylistRestClient();
      service = PlaylistService(playlistRepo, restClient, songService);
    });

    test(
      'addPlaylist saves local playlist and applies returned server id',
      () async {
        restClient.createResult = PlaylistDetailDto(
          id: 77,
          name: 'Roadtrip',
          playlistSongs: const [],
        );

        final saved = await service.addPlaylist('Roadtrip', [
          Song('s1'),
        ], Uint8List.fromList([1, 2]));

        expect(saved.getName(), 'Roadtrip');
        expect(saved.serverId, 77);
        expect(restClient.createCalls, 1);
        expect(restClient.lastCreateRequest, isNotNull);
      },
    );

    test('cacheServerPlaylist creates/reuses playlist and links songs', () {
      final cached = service.cacheServerPlaylist(
        PlaylistDto(id: 42, name: 'Server PL', songFileHashes: ['a', 'b']),
      );

      expect(cached.serverId, 42);
      expect(cached.getSongs().map((s) => s.getHash()).toSet(), {'a', 'b'});
      expect(playlistRepo.getPlaylistByName('Server PL'), isNotNull);
    });

    test(
      'getPlaylistsPage uses server totalPages and caches server playlists',
      () async {
        restClient.pageToReturn = PlaylistPageDto(
          content: [
            PlaylistDto(id: 101, name: 'FromServer', songFileHashes: ['x']),
          ],
          page: 0,
          size: 20,
          totalPages: 3,
          totalElements: 1,
        );

        final result = await service.getPlaylistsPage(
          '',
          'Name',
          true,
          false,
          0,
          20,
        );

        expect(result.totalPages, 3);
        expect(playlistRepo.getPlaylistByName('FromServer'), isNotNull);
      },
    );

    test('cacheServerPlaylistDetails respects server song order', () {
      final details = PlaylistDetailDto(
        id: 9,
        name: 'Ordered',
        playlistSongs: [
          PlaylistSongDto(song: _songDto('b'), position: 1),
          PlaylistSongDto(song: _songDto('a'), position: 0),
        ],
      );

      final cached = service.cacheServerPlaylistDetails(details);

      expect(cached.getSongs().map((s) => s.getHash()).toList(), ['a', 'b']);
    });

    test('deletePlaylist removes normal playlist and hits server when needed', () async {
      final custom = Playlist('Custom')..serverId = 55;
      playlistRepo.savePlaylist(custom);

      await service.deletePlaylist(custom);

      expect(restClient.deleteCalls, 1);
      expect(playlistRepo.getPlaylistByName('Custom'), isNull);
    });
  });
}

SongDto _songDto(String hash) {
  return SongDto(
    fileHash: hash,
    name: 'Song $hash',
    durationInSeconds: 1,
    trackNumber: 1,
    discNumber: 1,
    year: 2024,
    artist: ArtistDto(hash: 'ar-$hash', name: 'Artist'),
    album: AlbumDto(hash: 'al-$hash', name: 'Album'),
    playCount: 0,
    likedByUser: false,
  );
}
