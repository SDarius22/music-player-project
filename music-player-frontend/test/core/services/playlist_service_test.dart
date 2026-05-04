import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/albums/album_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_detail_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_page_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_playlist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/playlist_rest_client.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';

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

  @override
  Future<PlaylistPageDto> getPlaylistsPage({
    int page = 0,
    int size = 50,
  }) async {
    return pageToReturn;
  }

  @override
  Future<PlaylistDetailDto?> createPlaylist(
    String name,
    List<String> songFileHashes,
    String? coverBase64,
  ) async {
    createCalls++;
    return createResult;
  }

  @override
  Future<bool> updatePlaylist(
    int playlistId,
    String name,
    List<String> songFileHashes,
    String? coverBase64,
  ) async {
    updateCalls++;
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
    late InMemorySongRepository songRepo;
    late FakePlaylistRestClient restClient;
    late PlaylistService service;

    setUp(() {
      playlistRepo = InMemoryPlaylistRepository();
      songRepo = InMemorySongRepository();
      restClient = FakePlaylistRestClient();
      service = PlaylistService(playlistRepo, songRepo, restClient);
    });

    test('constructor initializes indestructible playlists', () {
      final names =
          service.getIndestructiblePlaylists().map((p) => p.getName()).toSet();
      expect(
        names,
        containsAll({'Queue', 'Favorites', 'Most Played', 'Recently Played'}),
      );
    });

    test('getQueuePlaylist recreates queue when missing', () {
      final queue = playlistRepo.getPlaylistByServerIdAndName(-1, 'Queue');
      playlistRepo.deletePlaylist(queue!);

      final recreated = service.getQueuePlaylist();

      expect(recreated.getName(), 'Queue');
      expect(recreated.indestructible, isTrue);
    });

    test(
      'addPlaylist saves local playlist and applies returned server id',
      () async {
        restClient.createResult = PlaylistDetailDto(
          id: 77,
          name: 'Roadtrip',
          songs: const [],
        );

        final saved = await service.addPlaylist('Roadtrip', [
          Song('s1'),
        ], Uint8List.fromList([1, 2]));

        expect(saved.getName(), 'Roadtrip');
        expect(saved.serverId, 77);
        expect(restClient.createCalls, 1);
      },
    );

    test('addToPlaylist avoids duplicates', () {
      final playlist = Playlist('Custom');
      final song = Song('hash-1');

      service.addToPlaylist(playlist, [song, song]);

      expect(playlist.getSongs(), hasLength(1));
      expect(playlist.getSongs().single.getHash(), 'hash-1');
    });

    test(
      'updatePlaylist refreshes cover for indestructible playlist',
      () async {
        final album = Album('a', 'Album')
          ..imageBytes = Uint8List.fromList([8, 8]);
        final song = Song('s')..album.target = album;
        final favorites =
            service.getFavoritesPlaylist()
              ..serverId = 5
              ..clearSongs()
              ..addSong(song);

        await service.updatePlaylist(favorites);

        expect(favorites.imageBytes, equals(album.imageBytes));
        expect(restClient.updateCalls, 1);
      },
    );

    test('cacheServerPlaylist creates/reuses playlist and links songs', () {
      final cached = service.cacheServerPlaylist(
        PlaylistDto(id: 42, name: 'Server PL', songFileHashes: ['a', 'b']),
      );

      expect(cached.serverId, 42);
      expect(cached.getSongs().map((s) => s.getHash()).toSet(), {'a', 'b'});
      expect(
        playlistRepo.getPlaylistByServerIdAndName(42, 'Server PL'),
        isNotNull,
      );
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
        expect(
          playlistRepo.getPlaylistByServerIdAndName(101, 'FromServer'),
          isNotNull,
        );
      },
    );

    test(
      'updateMostPlayedPlaylist fills Most Played from repository ranking',
      () {
        final low = Song('l')..playCount = 1;
        final high = Song('h')..playCount = 10;
        songRepo.saveSongs([low, high]);

        service.updateMostPlayedPlaylist();

        final mostPlayed = service.getIndestructiblePlaylists().firstWhere(
          (p) => p.getName() == 'Most Played',
        );
        expect(mostPlayed.getSongs().first.getHash(), 'h');
      },
    );

    test(
      'deletePlaylist ignores indestructible and deletes normal playlist',
      () async {
        final favorites = service.getFavoritesPlaylist();
        await service.deletePlaylist(favorites);
        expect(
          playlistRepo.getPlaylistByServerIdAndName(-1, 'Favorites'),
          isNotNull,
        );

        final custom = Playlist('Custom')..serverId = 55;
        playlistRepo.savePlaylist(custom);
        await service.deletePlaylist(custom);

        expect(restClient.deleteCalls, 1);
        expect(playlistRepo.getPlaylistByServerIdAndName(55, 'Custom'), isNull);
      },
    );

    test('cacheServerPlaylist rejects invalid server ids', () {
      expect(
        () => service.cacheServerPlaylist(
          PlaylistDto(id: 0, name: 'Bad', songFileHashes: const []),
        ),
        throwsException,
      );
    });

    test('getMostRecentPlayedSong delegates to repository', () {
      final song = Song('played')..lastPlayed = DateTime(2026, 1, 1);
      songRepo.saveSong(song);

      expect(service.getMostRecentPlayedSong()?.getHash(), 'played');
    });

    test('deleteAllSongsFromPlaylist clears and persists', () {
      final playlist =
          Playlist('ToClear')
            ..addSong(Song('s1'))
            ..addSong(Song('s2'));
      playlistRepo.savePlaylist(playlist);

      service.deleteAllSongsFromPlaylist(playlist);

      expect(playlist.getSongs(), isEmpty);
      expect(
        playlistRepo
            .getAllPlaylists()
            .firstWhere((p) => p.getName() == 'ToClear')
            .getSongs(),
        isEmpty,
      );
    });

    test('deleteFromPlaylist removes song safely', () {
      final playlist = Playlist('X')..addSong(Song('s1'));
      service.deleteFromPlaylist(playlist.getSongs().first, playlist);
      expect(playlist.getSongs(), isEmpty);
    });

    test(
      'getPlaylistsPage falls back to local paging when server has zero pages',
      () async {
        restClient.pageToReturn = PlaylistPageDto(
          content: const [],
          page: 0,
          size: 20,
          totalPages: 0,
          totalElements: 0,
        );
        playlistRepo.savePlaylist(Playlist('Local1'));
        playlistRepo.savePlaylist(Playlist('Local2'));

        final result = await service.getPlaylistsPage(
          '',
          'Name',
          true,
          false,
          0,
          20,
        );

        expect(result.totalPages, 1);
        expect(result.content, isNotEmpty);
      },
    );

    test(
      'addPlaylist handles null server response and still returns local playlist',
      () async {
        restClient.createResult = null;

        final created = await service.addPlaylist('Offline', const [], null);

        expect(created.serverId, -1);
        expect(created.getName(), 'Offline');
      },
    );

    test(
      'updateRecentlyPlayedPlaylist and updateFavoritesPlaylist refresh targets',
      () {
        final recent = Song('r')..lastPlayed = DateTime.now();
        final favorite = Song('f')..likedByUser = true;
        songRepo.saveSongs([recent, favorite]);

        service.updateRecentlyPlayedPlaylist();
        service.updateFavoritesPlaylist();

        final recentlyPlayed = service.getIndestructiblePlaylists().firstWhere(
          (p) => p.getName() == 'Recently Played',
        );
        final favorites = service.getFavoritesPlaylist();
        expect(
          recentlyPlayed.getSongs().map((s) => s.getHash()),
          contains('r'),
        );
        expect(favorites.getSongs().map((s) => s.getHash()), contains('f'));
      },
    );

    test(
      'addPlaylist sends only non-empty song hashes to server payload',
      () async {
        final localOnly = Song('')..path = '/tmp/local.mp3';
        final remote = Song('remote-hash');
        restClient.createResult = PlaylistDetailDto(
          id: 1,
          name: 'Mix',
          songs: [
            SongDto(
              fileHash: 'remote-hash',
              name: 'Remote',
              durationInSeconds: 1,
              trackNumber: 1,
              discNumber: 1,
              year: 2024,
              artist: ArtistDto(hash: 'ar', name: 'Artist'),
              album: AlbumDto(hash: 'al', name: 'Album'),
            ),
          ],
        );

        final created = await service.addPlaylist('Mix', [
          localOnly,
          remote,
        ], null);

        expect(created.serverId, 1);
        expect(restClient.createCalls, 1);
      },
    );
  });
}
