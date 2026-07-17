import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/playlists/create_playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_detail_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_page_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/update_playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_playlist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
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
  PlaylistExpandedDto? createResult;
  bool updateResult = true;
  bool deleteResult = true;

  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  CreatePlaylistDto? lastCreateRequest;
  UpdatePlaylistDto? lastUpdateRequest;
  PlaylistExpandedDto? detailsResult;
  SongPageDto songsPage = SongPageDto(
    content: const [],
    page: 0,
    size: 10,
    totalPages: 1,
    totalElements: 0,
  );

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
  Future<PlaylistExpandedDto?> createPlaylist(
    CreatePlaylistDto createPlaylistDto,
  ) async {
    createCalls++;
    lastCreateRequest = createPlaylistDto;
    return createResult;
  }

  @override
  Future<bool> updatePlaylist(
    int playlistId,
    UpdatePlaylistDto updatePlaylistDto,
  ) async {
    updateCalls++;
    lastUpdateRequest = updatePlaylistDto;
    return updateResult;
  }

  @override
  Future<bool> deletePlaylist(int playlistId) async {
    deleteCalls++;
    return deleteResult;
  }

  @override
  Future<PlaylistExpandedDto?> getPlaylistDetails(int playlistId) async =>
      detailsResult;

  @override
  Future<PlaylistExpandedDto?> getPlaylistDetailsByName(String name) async =>
      detailsResult;

  @override
  Future<SongPageDto> getPlaylistSongsPage({
    required int playlistId,
    int page = 0,
    int size = 50,
  }) async => songsPage;
}

void main() {
  group('PlaylistService', () {
    late InMemoryPlaylistRepository playlistRepo;
    late InMemorySongRepository songRepo;
    late FakeSongService songService;
    late FakePlaylistRestClient restClient;
    late PlaylistService service;

    setUp(() {
      playlistRepo = InMemoryPlaylistRepository();
      songRepo = InMemorySongRepository();
      songService = FakeSongService();
      restClient = FakePlaylistRestClient();
      service = PlaylistService(
        playlistRepo,
        restClient,
        songRepo,
        songService,
      );
    });

    test(
      'addPlaylist saves local playlist and applies returned server id',
      () async {
        restClient.createResult = PlaylistExpandedDto(
          id: 77,
          name: 'Roadtrip',
          songFileHashes: const [],
          indestructible: false,
          durationSeconds: 0,
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
      final details = PlaylistExpandedDto(
        id: 9,
        name: 'Ordered',
        songFileHashes: ['a', 'b'],
        indestructible: false,
        durationSeconds: 2,
      );

      final cached = service.cacheServerPlaylistDetails(details);

      expect(cached.getSongs().map((s) => s.getHash()).toList(), ['a', 'b']);
    });

    test(
      'deletePlaylist removes normal playlist and hits server when needed',
      () async {
        final custom = Playlist('Custom')..serverId = 55;
        playlistRepo.savePlaylist(custom);

        await service.deletePlaylist(custom);

        expect(restClient.deleteCalls, 1);
        expect(playlistRepo.getPlaylistByName('Custom'), isNull);
      },
    );

    test(
      'updates server playlists and supports add/remove song helpers',
      () async {
        final playlist = Playlist('Custom')..serverId = 4;
        final a = Song('a');
        final b = Song('b');
        playlistRepo.savePlaylist(playlist);
        await service.addToPlaylist(playlist, [a, b]);
        expect(restClient.updateCalls, 1);
        expect(restClient.lastUpdateRequest!.playlistSongs, hasLength(2));
        await service.deleteFromPlaylist(a, playlist);
        expect(playlist.getSongs(), [b]);
        expect(restClient.updateCalls, 2);
      },
    );

    test('returns recent song or null', () async {
      final song = Song('recent');
      songService.recent = [song];
      expect(await service.getMostRecentPlayedSong(), song);
      songService.recent = [];
      expect(await service.getMostRecentPlayedSong(), isNull);
    });

    test(
      'fetches playlist by name and falls back to indestructible local',
      () async {
        restClient.detailsResult = PlaylistExpandedDto(
          id: 8,
          name: 'Queue',
          songFileHashes: const ['a'],
          indestructible: true,
          durationSeconds: 0,
        );
        expect((await service.getPlaylistByName('Queue')).serverId, 8);
        restClient.detailsResult = null;
        final local = await service.getPlaylistByName(
          'Offline',
          indestructible: true,
        );
        expect(local.indestructible, isTrue);
      },
    );

    test('pages normal and indestructible playlists', () async {
      restClient.pageToReturn = PlaylistPageDto(
        content: [
          PlaylistDto(
            id: 1,
            name: 'Queue',
            songFileHashes: const [],
            indestructible: true,
          ),
          PlaylistDto(id: 2, name: 'Normal', songFileHashes: const []),
        ],
        page: 0,
        size: 10,
        totalPages: 2,
        totalElements: 2,
      );
      final protected = await service.getIndestructiblePlaylists(0, 10);
      final normal = await service.getNormalPlaylists(0, 10);
      expect(protected.totalPages, 2);
      expect(normal.totalPages, 2);
      expect(protected.content.single.name, 'Queue');
      expect(normal.content.single.name, 'Normal');
    });

    test('gets details and playlist songs from server', () async {
      final playlist = Playlist('Server')..serverId = 5;
      playlistRepo.savePlaylist(playlist);
      restClient.detailsResult = PlaylistExpandedDto(
        id: 5,
        name: 'Server',
        songFileHashes: const ['a'],
        indestructible: false,
        durationSeconds: 0,
      );
      expect(
        (await service.getPlaylistDetails(playlist)).getSongs(),
        hasLength(1),
      );

      restClient.songsPage = SongPageDto(
        content: const [],
        page: 0,
        size: 10,
        totalPages: 3,
        totalElements: 0,
      );
      final page = await service.getPlaylistSongsPage(playlist, size: 10);
      expect(page.totalPages, 3);
    });

    test('uses local song paging and hash lookup fallback', () async {
      final playlist = Playlist('Local', songs: [Song('a')]);
      playlistRepo.savePlaylist(playlist);
      final song =
          songRepo.getOrCreateSong('a')
            ..fullyLoaded = true
            ..path = '/tmp/a.mp3';
      songRepo.updateSong(song);
      final page = await service.getPlaylistSongsPage(
        playlist,
        localOnly: true,
        size: 1,
      );
      expect(page.content, [song]);
      expect(
        (await service.getPlaylistSongsPageByHash(
          playlist.getHash(),
          localOnly: true,
        )).content,
        [song],
      );
      expect(
        (await service.getPlaylistSongsPageByHash('missing')).content,
        isEmpty,
      );
    });

    test(
      'does not delete indestructible playlists and rejects invalid server ids',
      () async {
        final protected = Playlist('Queue')..indestructible = true;
        playlistRepo.savePlaylist(protected);
        await service.deletePlaylist(protected);
        expect(playlistRepo.getPlaylistByName('Queue'), protected);
        expect(
          () => service.cacheServerPlaylist(
            PlaylistDto(id: 0, name: 'bad', songFileHashes: const []),
          ),
          throwsException,
        );
        expect(
          () => service.cacheServerPlaylistDetails(
            PlaylistExpandedDto(
              id: 0,
              name: 'bad',
              songFileHashes: const [],
              indestructible: false,
              durationSeconds: 0,
            ),
          ),
          throwsException,
        );
      },
    );
  });
}
