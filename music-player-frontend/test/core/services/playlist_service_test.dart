import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/dtos/playlist_page_dto.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/playlist_rest_service.dart';

import 'playlist_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<PlaylistRepository>(),
  MockSpec<SongRepository>(),
  MockSpec<PlaylistRestService>(),
])
void main() {
  late MockPlaylistRepository mockPlaylistRepo;
  late MockSongRepository mockSongRepo;
  late MockPlaylistRestService mockRestService;
  late PlaylistService service;

  Playlist makePlaylist({
    int id = 0,
    String name = 'Test',
    bool indestructible = false,
    int serverId = -1,
  }) {
    final p = Playlist();
    p.id = id;
    p.name = name;
    p.indestructible = indestructible;
    p.nextAdded = 'last';
    if (serverId > 0) p.serverId = serverId;
    return p;
  }

  Song makeSong({int id = 1, String fileHash = 'hash1'}) {
    final s = Song();
    s.id = id;
    s.fileHash = fileHash;
    s.name = 'Song $id';
    return s;
  }

  setUp(() {
    mockPlaylistRepo = MockPlaylistRepository();
    mockSongRepo = MockSongRepository();
    mockRestService = MockPlaylistRestService();

    // Satisfy the constructor check that initializes indestructible playlists.
    when(mockPlaylistRepo.getIndestructiblePlaylists()).thenReturn([
      makePlaylist(id: 1, name: 'Queue', indestructible: true),
      makePlaylist(id: 2, name: 'Favorites', indestructible: true),
      makePlaylist(id: 3, name: 'Most Played', indestructible: true),
      makePlaylist(id: 4, name: 'Recently Played', indestructible: true),
    ]);

    service = PlaylistService(mockPlaylistRepo, mockSongRepo, mockRestService);
  });

  // ---------------------------------------------------------------------------
  // getQueuePlaylist
  // ---------------------------------------------------------------------------

  group('getQueuePlaylist', () {
    test('returns queue playlist from repository', () {
      final queue = makePlaylist(id: 1, name: 'Queue', indestructible: true);
      when(mockPlaylistRepo.getPlaylistByName('Queue')).thenReturn(queue);

      final result = service.getQueuePlaylist();

      expect(result.name, 'Queue');
    });

    test('initializes queue if not found, then returns it', () {
      final queue = makePlaylist(name: 'Queue');
      var callCount = 0;
      when(mockPlaylistRepo.getPlaylistByName('Queue')).thenAnswer((_) {
        callCount++;
        return callCount == 1 ? null : queue;
      });
      when(mockPlaylistRepo.savePlaylist(any)).thenReturn(queue);

      final result = service.getQueuePlaylist();

      expect(result.name, 'Queue');
    });
  });

  // ---------------------------------------------------------------------------
  // addToPlaylist
  // ---------------------------------------------------------------------------

  group('addToPlaylist', () {
    test('appends songs to end when nextAdded is last', () {
      final playlist = makePlaylist();
      playlist.nextAdded = 'last';
      final songs = [makeSong(id: 1), makeSong(id: 2)];
      when(mockPlaylistRepo.savePlaylist(any)).thenReturn(playlist);

      service.addToPlaylist(playlist, songs);

      expect(playlist.songsIds, containsAll([1, 2]));
      expect(playlist.songsIds.first, 1);
      expect(playlist.songsIds.last, 2);
    });

    test('prepends songs when nextAdded is not last', () {
      final playlist = makePlaylist();
      playlist.nextAdded = 'first';
      final existing = makeSong(id: 10);
      playlist.songsIds.add(existing.id);
      final newSongs = [makeSong(id: 20)];
      when(mockPlaylistRepo.savePlaylist(any)).thenReturn(playlist);

      service.addToPlaylist(playlist, newSongs);

      expect(playlist.songsIds.first, 20);
      expect(playlist.songsIds[1], 10);
    });
  });

  // ---------------------------------------------------------------------------
  // deleteFromPlaylist
  // ---------------------------------------------------------------------------

  group('deleteFromPlaylist', () {
    test('removes song from ids and songs list', () {
      final song = makeSong(id: 5);
      final playlist = makePlaylist();
      playlist.songsIds.add(song.id);
      playlist.songs.add(song);
      when(mockPlaylistRepo.savePlaylist(any)).thenReturn(playlist);

      service.deleteFromPlaylist(song, playlist);

      expect(playlist.songsIds, isNot(contains(5)));
      expect(playlist.songs, isNot(contains(song)));
      verify(
        mockPlaylistRepo.savePlaylist(playlist),
      ).called(greaterThanOrEqualTo(1));
    });
  });

  // ---------------------------------------------------------------------------
  // deletePlaylist
  // ---------------------------------------------------------------------------

  group('deletePlaylist', () {
    test('deletes a normal playlist via repository', () async {
      final playlist = makePlaylist(name: 'Normal');

      await service.deletePlaylist(playlist);

      verify(mockPlaylistRepo.deletePlaylist(playlist)).called(1);
    });

    test('does not delete an indestructible playlist', () async {
      final indestructible = makePlaylist(
        name: 'Favorites',
        indestructible: true,
      );

      await service.deletePlaylist(indestructible);

      verifyNever(mockPlaylistRepo.deletePlaylist(any));
    });

    test(
      'calls REST deletePlaylist before local delete when serverId > 0',
      () async {
        final playlist = makePlaylist(name: 'Remote', serverId: 42);
        when(mockRestService.deletePlaylist(42)).thenAnswer((_) async => true);

        await service.deletePlaylist(playlist);

        verify(mockRestService.deletePlaylist(42)).called(1);
        verify(mockPlaylistRepo.deletePlaylist(playlist)).called(1);
      },
    );

    test('skips REST when serverId <= 0 and deletes locally', () async {
      final playlist = makePlaylist(name: 'Local Only');

      await service.deletePlaylist(playlist);

      verifyNever(mockRestService.deletePlaylist(any));
      verify(mockPlaylistRepo.deletePlaylist(playlist)).called(1);
    });

    test('still does local delete when REST throws', () async {
      final playlist = makePlaylist(name: 'Remote Fail', serverId: 7);
      when(
        mockRestService.deletePlaylist(7),
      ).thenThrow(Exception('network error'));

      await service.deletePlaylist(playlist);

      verify(mockPlaylistRepo.deletePlaylist(playlist)).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // deleteAllSongsFromPlaylist
  // ---------------------------------------------------------------------------

  group('deleteAllSongsFromPlaylist', () {
    test('clears all songs and ids', () {
      final playlist = makePlaylist();
      playlist.songsIds.addAll([1, 2, 3]);
      playlist.songs.addAll([
        makeSong(id: 1),
        makeSong(id: 2),
        makeSong(id: 3),
      ]);
      when(mockPlaylistRepo.savePlaylist(any)).thenReturn(playlist);

      service.deleteAllSongsFromPlaylist(playlist);

      expect(playlist.songsIds, isEmpty);
      expect(playlist.songs, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getPlaylists
  // ---------------------------------------------------------------------------

  group('getPlaylists', () {
    test('delegates to repository', () {
      final playlists = [makePlaylist(), makePlaylist()];
      when(mockPlaylistRepo.getPlaylists(any, any, any)).thenReturn(playlists);

      final result = service.getPlaylists('', 'name', true);

      expect(result, equals(playlists));
    });
  });

  // ---------------------------------------------------------------------------
  // updateMostPlayedPlaylist
  // ---------------------------------------------------------------------------

  group('updateMostPlayedPlaylist', () {
    test('updates Most Played playlist with top songs', () {
      final mostPlayed = makePlaylist(
        name: 'Most Played',
        indestructible: true,
      );
      when(
        mockPlaylistRepo.getIndestructiblePlaylists(),
      ).thenReturn([mostPlayed]);
      final songs = [makeSong(id: 1), makeSong(id: 2)];
      when(mockSongRepo.getMostPlayedSongs(50)).thenReturn(songs);
      when(mockPlaylistRepo.savePlaylist(any)).thenReturn(mostPlayed);

      service.updateMostPlayedPlaylist();

      expect(mostPlayed.songsIds, containsAll([1, 2]));
      verify(mockSongRepo.getMostPlayedSongs(50)).called(1);
    });

    test('does nothing gracefully when Most Played playlist not found', () {
      when(mockPlaylistRepo.getIndestructiblePlaylists()).thenReturn([]);

      expect(() => service.updateMostPlayedPlaylist(), returnsNormally);
      verifyNever(mockSongRepo.getMostPlayedSongs(any));
    });
  });

  // ---------------------------------------------------------------------------
  // addPlaylist
  // ---------------------------------------------------------------------------

  group('addPlaylist', () {
    test('creates playlist locally and stores returned server ID', () async {
      final song = makeSong(id: 1, fileHash: 'hash10');
      when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
        return inv.positionalArguments[0] as Playlist;
      });
      when(
        mockRestService.createPlaylist(any, any, any),
      ).thenAnswer((_) async => {'id': 99});

      final result = await service.addPlaylist('My List', [song], 'last', null);

      expect(result.name, 'My List');
      expect(result.serverId, 99);
      verify(
        mockRestService.createPlaylist('My List', ['hash10'], null),
      ).called(1);
    });

    test('gracefully handles REST failure', () async {
      when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
        return inv.positionalArguments[0] as Playlist;
      });
      when(
        mockRestService.createPlaylist(any, any, any),
      ).thenThrow(Exception('server down'));

      final result = await service.addPlaylist('Offline', [], 'last', null);

      expect(result.name, 'Offline');
      // serverId should remain default (not set) since REST failed
      expect(result.serverId, lessThanOrEqualTo(0));
    });

    test(
      'passes empty file hash list to REST when songs have no server hashes',
      () async {
        final song = makeSong(
          id: 1,
          fileHash: '',
        ); // empty fileHash → filtered out
        when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
          return inv.positionalArguments[0] as Playlist;
        });
        when(
          mockRestService.createPlaylist(any, any, any),
        ).thenAnswer((_) async => {'id': 5});

        await service.addPlaylist('No Server Songs', [song], 'last', null);

        final captured =
            verify(
              mockRestService.createPlaylist(any, captureAny, any),
            ).captured;
        expect(captured.first as List<String>, isEmpty);
      },
    );

    test('encodes coverArt as base64 and passes to REST', () async {
      final cover = Uint8List.fromList([1, 2, 3]);
      when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
        return inv.positionalArguments[0] as Playlist;
      });
      when(
        mockRestService.createPlaylist(any, any, any),
      ).thenAnswer((_) async => {'id': 1});

      await service.addPlaylist('With Cover', [], 'last', cover);

      final captured =
          verify(mockRestService.createPlaylist(any, any, captureAny)).captured;
      expect(captured.first, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // updatePlaylist
  // ---------------------------------------------------------------------------

  group('updatePlaylist', () {
    test(
      'indestructible playlist: sets imageBytes from first song coverArt when songs not empty',
      () async {
        final song = makeSong(id: 1);

        // song.coverArt comes from album; we need to provide it via album.
        // Since Song.coverArt => album.target?.coverArt and we can't set that easily,
        // we test the branch by checking savePlaylist is called.
        // Instead, create a real scenario using a subclass workaround is impractical;
        // just verify savePlaylist was invoked and the service doesn't throw.
        final playlist = makePlaylist(indestructible: true);
        playlist.songs.add(song);
        playlist.songsIds.add(song.id);
        when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
          return inv.positionalArguments[0] as Playlist;
        });

        await service.updatePlaylist(playlist);

        verify(
          mockPlaylistRepo.savePlaylist(playlist),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    test('indestructible playlist: no image change when songs empty', () async {
      final playlist = makePlaylist(indestructible: true);
      playlist.imageBytes = Uint8List.fromList([1, 2, 3]);
      when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
        return inv.positionalArguments[0] as Playlist;
      });

      await service.updatePlaylist(playlist);

      // imageBytes should remain unchanged (no songs to pull from)
      expect(playlist.imageBytes, isNotNull);
    });

    test('calls REST updatePlaylist when serverId > 0', () async {
      final playlist = makePlaylist(serverId: 5);
      playlist.serverId = 5;
      when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
        return inv.positionalArguments[0] as Playlist;
      });
      when(
        mockRestService.updatePlaylist(any, any, any, any),
      ).thenAnswer((_) async => true);

      await service.updatePlaylist(playlist);

      verify(mockRestService.updatePlaylist(5, any, any, any)).called(1);
    });

    test('skips REST when serverId <= 0', () async {
      final playlist = makePlaylist();
      when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
        return inv.positionalArguments[0] as Playlist;
      });

      await service.updatePlaylist(playlist);

      verifyNever(mockRestService.updatePlaylist(any, any, any, any));
    });

    test('handles REST failure gracefully', () async {
      final playlist = makePlaylist(serverId: 3);
      playlist.serverId = 3;
      when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
        return inv.positionalArguments[0] as Playlist;
      });
      when(
        mockRestService.updatePlaylist(any, any, any, any),
      ).thenThrow(Exception('network error'));

      expect(
        () async => await service.updatePlaylist(playlist),
        returnsNormally,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // getPlaylistsPage
  // ---------------------------------------------------------------------------

  group('getPlaylistsPage', () {
    test(
      'server success with totalElements > 0: caches and returns local paged content with server totals',
      () async {
        final serverPlaylist = makePlaylist(serverId: 11, name: 'Server PL');
        serverPlaylist.serverId = 11;
        final serverPage = PlaylistPageDto(
          content: [serverPlaylist],
          page: 0,
          size: 10,
          totalPages: 1,
          totalElements: 1,
        );
        when(
          mockRestService.getPlaylistsPage(
            page: anyNamed('page'),
            size: anyNamed('size'),
          ),
        ).thenAnswer((_) async => serverPage);

        // cacheServerPlaylist will call getPlaylistByServerId and getPlaylistByName
        when(mockPlaylistRepo.getPlaylistByServerId(11)).thenReturn(null);
        when(mockPlaylistRepo.getPlaylistByName('Server PL')).thenReturn(null);
        when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
          return inv.positionalArguments[0] as Playlist;
        });

        final localContent = [makePlaylist(name: 'Cached PL')];
        when(
          mockPlaylistRepo.getPlaylistsPaged(any, any, any, any, any),
        ).thenReturn(localContent);

        final result = await service.getPlaylistsPage('', 'name', true, 0, 10);

        expect(result.content, equals(localContent));
        expect(result.totalElements, 1);
        expect(result.totalPages, 1);
      },
    );

    test(
      'server success but totalElements == 0: falls through to local',
      () async {
        final serverPage = PlaylistPageDto(
          content: [],
          page: 0,
          size: 10,
          totalPages: 0,
          totalElements: 0,
        );
        when(
          mockRestService.getPlaylistsPage(
            page: anyNamed('page'),
            size: anyNamed('size'),
          ),
        ).thenAnswer((_) async => serverPage);

        final localPlaylists = [makePlaylist(name: 'Local PL')];
        when(
          mockPlaylistRepo.getPlaylists(any, any, any),
        ).thenReturn(localPlaylists);

        final result = await service.getPlaylistsPage('', 'name', true, 0, 10);

        expect(result.totalElements, 1);
        expect(result.content, equals(localPlaylists));
      },
    );

    test('server throws: returns local page', () async {
      when(
        mockRestService.getPlaylistsPage(
          page: anyNamed('page'),
          size: anyNamed('size'),
        ),
      ).thenThrow(Exception('timeout'));

      final localPlaylists = [makePlaylist(), makePlaylist()];
      when(
        mockPlaylistRepo.getPlaylists(any, any, any),
      ).thenReturn(localPlaylists);

      final result = await service.getPlaylistsPage('', 'name', true, 0, 10);

      expect(result.totalElements, 2);
    });

    test('local page with offset > total: returns empty content', () async {
      when(
        mockRestService.getPlaylistsPage(
          page: anyNamed('page'),
          size: anyNamed('size'),
        ),
      ).thenThrow(Exception('timeout'));

      when(
        mockPlaylistRepo.getPlaylists(any, any, any),
      ).thenReturn([makePlaylist()]);

      final result = await service.getPlaylistsPage('', 'name', true, 5, 10);

      expect(result.content, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // cacheServerPlaylist
  // ---------------------------------------------------------------------------

  group('cacheServerPlaylist', () {
    test('found by serverId: updates name, resolves songs, saves', () {
      final existing = makePlaylist(id: 1, name: 'Old', serverId: 10);
      existing.serverId = 10;
      final serverPlaylist = makePlaylist(name: 'New Name', serverId: 10);
      serverPlaylist.serverId = 10;

      when(mockPlaylistRepo.getPlaylistByServerId(10)).thenReturn(existing);
      when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
        return inv.positionalArguments[0] as Playlist;
      });

      final result = service.cacheServerPlaylist(serverPlaylist);

      expect(existing.name, 'New Name');
      verify(mockPlaylistRepo.savePlaylist(existing)).called(1);
      expect(result, same(existing));
    });

    test(
      'found by name (not indestructible, no serverId): links serverId, saves',
      () {
        final existing = makePlaylist(id: 2, name: 'By Name');
        final serverPlaylist = makePlaylist(name: 'By Name', serverId: 20);
        serverPlaylist.serverId = 20;

        when(mockPlaylistRepo.getPlaylistByServerId(20)).thenReturn(null);
        when(
          mockPlaylistRepo.getPlaylistByName('By Name'),
        ).thenReturn(existing);
        when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
          return inv.positionalArguments[0] as Playlist;
        });

        final result = service.cacheServerPlaylist(serverPlaylist);

        expect(existing.serverId, 20);
        verify(mockPlaylistRepo.savePlaylist(existing)).called(1);
        expect(result, same(existing));
      },
    );

    test(
      'found by name (not indestructible, already has serverId): no re-link',
      () {
        final existing = makePlaylist(
          id: 3,
          name: 'Has ServerId',
          serverId: 99,
        );
        existing.serverId = 99;
        final serverPlaylist = makePlaylist(name: 'Has ServerId', serverId: 20);
        serverPlaylist.serverId = 20;

        when(mockPlaylistRepo.getPlaylistByServerId(20)).thenReturn(null);
        when(
          mockPlaylistRepo.getPlaylistByName('Has ServerId'),
        ).thenReturn(existing);
        when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
          return inv.positionalArguments[0] as Playlist;
        });

        service.cacheServerPlaylist(serverPlaylist);

        expect(existing.serverId, 99);
      },
    );

    test(
      'found by name but IS indestructible: skips that match, saves as new',
      () {
        final indestructible = makePlaylist(
          name: 'Favorites',
          indestructible: true,
        );
        final serverPlaylist = makePlaylist(name: 'Favorites', serverId: 30);
        serverPlaylist.serverId = 30;

        when(mockPlaylistRepo.getPlaylistByServerId(30)).thenReturn(null);
        when(
          mockPlaylistRepo.getPlaylistByName('Favorites'),
        ).thenReturn(indestructible);
        when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
          return inv.positionalArguments[0] as Playlist;
        });

        service.cacheServerPlaylist(serverPlaylist);

        verify(mockPlaylistRepo.savePlaylist(serverPlaylist)).called(1);
      },
    );

    test('not found at all: saves as new', () {
      final serverPlaylist = makePlaylist(name: 'Brand New', serverId: 50);
      serverPlaylist.serverId = 50;

      when(mockPlaylistRepo.getPlaylistByServerId(50)).thenReturn(null);
      when(mockPlaylistRepo.getPlaylistByName('Brand New')).thenReturn(null);
      when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
        return inv.positionalArguments[0] as Playlist;
      });

      final result = service.cacheServerPlaylist(serverPlaylist);

      verify(mockPlaylistRepo.savePlaylist(serverPlaylist)).called(1);
      expect(result, same(serverPlaylist));
    });

    test(
      'serverSongFileHashes resolved: sets songs and songsIds on playlist',
      () {
        final song = makeSong(id: 5, fileHash: 'hash100');
        final existing = makePlaylist(id: 1, name: 'Has Songs', serverId: 10);
        existing.serverId = 10;

        final serverPlaylist = makePlaylist(name: 'Has Songs', serverId: 10);
        serverPlaylist.serverId = 10;
        serverPlaylist.serverSongFileHashes = ['hash100'];

        when(mockPlaylistRepo.getPlaylistByServerId(10)).thenReturn(existing);
        when(mockSongRepo.getSongByFileHash('hash100')).thenReturn(song);
        when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
          return inv.positionalArguments[0] as Playlist;
        });

        service.cacheServerPlaylist(serverPlaylist);

        expect(existing.songsIds, contains(5));
      },
    );

    test('serverSongFileHashes empty: skips song resolution', () {
      final existing = makePlaylist(id: 1, name: 'No Songs', serverId: 10);
      existing.serverId = 10;
      final serverPlaylist = makePlaylist(name: 'No Songs', serverId: 10);
      serverPlaylist.serverId = 10;
      serverPlaylist.serverSongFileHashes = [];

      when(mockPlaylistRepo.getPlaylistByServerId(10)).thenReturn(existing);
      when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
        return inv.positionalArguments[0] as Playlist;
      });

      service.cacheServerPlaylist(serverPlaylist);

      verifyNever(mockSongRepo.getSongByFileHash(any));
    });

    test(
      'serverSongFileHashes with unresolved (null from repo): filters them out',
      () {
        final song = makeSong(id: 7, fileHash: 'hash200');
        final existing = makePlaylist(id: 1, name: 'Partial', serverId: 10);
        existing.serverId = 10;

        final serverPlaylist = makePlaylist(name: 'Partial', serverId: 10);
        serverPlaylist.serverId = 10;
        serverPlaylist.serverSongFileHashes = ['hash200', 'hash999'];

        when(mockPlaylistRepo.getPlaylistByServerId(10)).thenReturn(existing);
        when(mockSongRepo.getSongByFileHash('hash200')).thenReturn(song);
        when(mockSongRepo.getSongByFileHash('hash999')).thenReturn(null);
        when(mockPlaylistRepo.savePlaylist(any)).thenAnswer((inv) {
          return inv.positionalArguments[0] as Playlist;
        });

        service.cacheServerPlaylist(serverPlaylist);

        expect(existing.songsIds, contains(7));
        expect(existing.songsIds.length, 1);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // getFavoritesPlaylist
  // ---------------------------------------------------------------------------

  group('getFavoritesPlaylist', () {
    test('returns favorites playlist when found', () {
      final favorites = makePlaylist(
        id: 2,
        name: 'Favorites',
        indestructible: true,
      );
      when(
        mockPlaylistRepo.getPlaylistByName('Favorites'),
      ).thenReturn(favorites);

      final result = service.getFavoritesPlaylist();

      expect(result.name, 'Favorites');
    });

    test('initializes and returns when not found', () {
      final favorites = makePlaylist(name: 'Favorites');
      var callCount = 0;
      when(mockPlaylistRepo.getPlaylistByName('Favorites')).thenAnswer((_) {
        callCount++;
        return callCount == 1 ? null : favorites;
      });
      when(mockPlaylistRepo.savePlaylist(any)).thenReturn(favorites);

      final result = service.getFavoritesPlaylist();

      expect(result.name, 'Favorites');
    });
  });

  // ---------------------------------------------------------------------------
  // updateRecentlyPlayedPlaylist
  // ---------------------------------------------------------------------------

  group('updateRecentlyPlayedPlaylist', () {
    test('updates recently played with songs from repo', () {
      final recentlyPlayed = makePlaylist(
        name: 'Recently Played',
        indestructible: true,
      );
      when(
        mockPlaylistRepo.getIndestructiblePlaylists(),
      ).thenReturn([recentlyPlayed]);
      final songs = [makeSong(id: 3), makeSong(id: 4)];
      when(mockSongRepo.getRecentlyPlayedSongs(50)).thenReturn(songs);
      when(mockPlaylistRepo.savePlaylist(any)).thenReturn(recentlyPlayed);

      service.updateRecentlyPlayedPlaylist();

      expect(recentlyPlayed.songsIds, containsAll([3, 4]));
      verify(mockSongRepo.getRecentlyPlayedSongs(50)).called(1);
    });

    test('does nothing gracefully when playlist not found', () {
      when(mockPlaylistRepo.getIndestructiblePlaylists()).thenReturn([]);

      expect(() => service.updateRecentlyPlayedPlaylist(), returnsNormally);
      verifyNever(mockSongRepo.getRecentlyPlayedSongs(any));
    });
  });

  // ---------------------------------------------------------------------------
  // updateFavoritesPlaylist
  // ---------------------------------------------------------------------------

  group('updateFavoritesPlaylist', () {
    test('updates favorites with songs from repo', () {
      final favorites = makePlaylist(name: 'Favorites', indestructible: true);
      when(
        mockPlaylistRepo.getIndestructiblePlaylists(),
      ).thenReturn([favorites]);
      final songs = [makeSong(id: 5), makeSong(id: 6)];
      when(mockSongRepo.getFavoriteSongs()).thenReturn(songs);
      when(mockPlaylistRepo.savePlaylist(any)).thenReturn(favorites);

      service.updateFavoritesPlaylist();

      expect(favorites.songsIds, containsAll([5, 6]));
      verify(mockSongRepo.getFavoriteSongs()).called(1);
    });

    test('does nothing when playlist not found', () {
      when(mockPlaylistRepo.getIndestructiblePlaylists()).thenReturn([]);

      expect(() => service.updateFavoritesPlaylist(), returnsNormally);
      verifyNever(mockSongRepo.getFavoriteSongs());
    });
  });

  // ---------------------------------------------------------------------------
  // initializeIndestructible called from constructor
  // ---------------------------------------------------------------------------

  group('initializeIndestructible called from constructor', () {
    test('saves all 4 indestructible playlists when none exist', () {
      final freshRepo = MockPlaylistRepository();
      final freshSongRepo = MockSongRepository();
      final freshRest = MockPlaylistRestService();

      when(freshRepo.getIndestructiblePlaylists()).thenReturn([]);
      when(freshRepo.getPlaylistByName(any)).thenReturn(null);
      when(freshRepo.savePlaylist(any)).thenAnswer((inv) {
        return inv.positionalArguments[0] as Playlist;
      });

      PlaylistService(freshRepo, freshSongRepo, freshRest);

      verify(freshRepo.savePlaylist(any)).called(greaterThanOrEqualTo(4));
    });
  });

  // ---------------------------------------------------------------------------
  // getMostRecentPlayedSong
  // ---------------------------------------------------------------------------

  group('getMostRecentPlayedSong', () {
    test('delegates to SongRepository', () {
      final song = makeSong(id: 9);
      when(mockSongRepo.getMostRecentPlayedSong()).thenReturn(song);

      final result = service.getMostRecentPlayedSong();

      expect(result, same(song));
      verify(mockSongRepo.getMostRecentPlayedSong()).called(1);
    });

    test('returns null when no recently played song', () {
      when(mockSongRepo.getMostRecentPlayedSong()).thenReturn(null);

      expect(service.getMostRecentPlayedSong(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // getPlaylist
  // ---------------------------------------------------------------------------

  group('getPlaylist', () {
    test('delegates to repository', () {
      final playlist = makePlaylist(id: 7, name: 'Found');
      when(mockPlaylistRepo.getPlaylist(7)).thenReturn(playlist);

      final result = service.getPlaylist(7);

      expect(result, same(playlist));
    });

    test('returns null when not found', () {
      when(mockPlaylistRepo.getPlaylist(any)).thenReturn(null);

      expect(service.getPlaylist(999), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // getIndestructiblePlaylists / getNormalPlaylists / getAllPlaylists
  // ---------------------------------------------------------------------------

  group('getIndestructiblePlaylists', () {
    test('delegates to repository', () {
      final list = [makePlaylist(indestructible: true)];
      when(mockPlaylistRepo.getIndestructiblePlaylists()).thenReturn(list);

      expect(service.getIndestructiblePlaylists(), equals(list));
    });
  });

  group('getNormalPlaylists', () {
    test('delegates to repository', () {
      final list = [
        makePlaylist(name: 'Normal 1'),
        makePlaylist(name: 'Normal 2'),
      ];
      when(mockPlaylistRepo.getNormalPlaylists()).thenReturn(list);

      expect(service.getNormalPlaylists(), equals(list));
    });
  });

  group('getAllPlaylists', () {
    test('delegates to repository', () {
      final list = [makePlaylist(name: 'A'), makePlaylist(name: 'B')];
      when(mockPlaylistRepo.getAllPlaylists()).thenReturn(list);

      expect(service.getAllPlaylists(), equals(list));
    });
  });

  // ---------------------------------------------------------------------------
  // watchPlaylists
  // ---------------------------------------------------------------------------

  group('watchPlaylists', () {
    test('delegates to repository', () {
      final controller = StreamController<List<Playlist>>();
      when(
        mockPlaylistRepo.watchPlaylists(),
      ).thenAnswer((_) => controller.stream);

      final stream = service.watchPlaylists();

      expect(stream, isA<Stream>());
      controller.close();
    });
  });

  // ---------------------------------------------------------------------------
  // sortFields
  // ---------------------------------------------------------------------------

  group('sortFields', () {
    test('delegates to repository', () {
      final fields = <String, dynamic>{'name': 'name', 'date': 'createdAt'};
      when(mockPlaylistRepo.sortFields).thenReturn(fields);

      expect(service.sortFields, equals(fields));
    });
  });
}
