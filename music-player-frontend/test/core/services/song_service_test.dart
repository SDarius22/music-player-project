import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/dtos/song_page_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/song_rest_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

import 'song_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<SongRepository>(),
  MockSpec<SongRestService>(),
  MockSpec<ArtistService>(),
  MockSpec<AlbumService>(),
])
void main() {
  late MockSongRepository mockRepo;
  late MockSongRestService mockRestService;
  late MockArtistService mockArtistService;
  late MockAlbumService mockAlbumService;
  late SongService service;

  Song makeSong({int serverId = 1, String name = 'Song', int id = 0}) {
    final s = Song();
    s.id = id;
    s.serverId = serverId;
    s.name = name;
    return s;
  }

  setUp(() {
    mockRepo = MockSongRepository();
    mockRestService = MockSongRestService();
    mockArtistService = MockArtistService();
    mockAlbumService = MockAlbumService();
    service = SongService(
      mockRepo,
      mockRestService,
      mockArtistService,
      mockAlbumService,
    );
  });

  group('getSongByServerId', () {
    test('delegates to repository', () {
      final song = makeSong(serverId: 42);
      when(mockRepo.getSongByServerId(42)).thenReturn(song);

      final result = service.getSongByServerId(42);

      expect(result, same(song));
    });

    test('returns null when not in repository', () {
      when(mockRepo.getSongByServerId(any)).thenReturn(null);

      expect(service.getSongByServerId(99), isNull);
    });
  });

  group('getSongCount', () {
    test('returns count from repository', () {
      when(mockRepo.getSongCount()).thenReturn(15);

      expect(service.getSongCount(), 15);
    });
  });

  group('addSongEntity', () {
    test('saves song through repository and returns it', () {
      final song = makeSong();
      when(mockRepo.saveSong(song)).thenReturn(song);

      final result = service.addSongEntity(song);

      expect(result, same(song));
      verify(mockRepo.saveSong(song)).called(1);
    });
  });

  group('recordPlay', () {
    test('increments playCount, sets lastPlayed, marks requiresSync', () {
      final song = makeSong(id: 5);
      song.playCount = 3;
      song.requiresSync = false;
      when(mockRepo.getSong(5)).thenReturn(song);

      service.recordPlay(5);

      expect(song.playCount, 4);
      expect(song.lastPlayed, isNotNull);
      expect(song.requiresSync, isTrue);
      verify(mockRepo.updateSong(song)).called(1);
    });
  });

  group('getAllSongs', () {
    test('fetches from server, caches, then returns local list', () async {
      final serverSong = makeSong(serverId: 10, name: 'Server Song');
      serverSong.artist.target = Artist()..name = 'Artist';
      serverSong.album.target = Album()..name = 'Album';

      when(mockRestService.getAllSongs()).thenAnswer((_) async => [serverSong]);
      when(mockRepo.getSongByServerId(10)).thenReturn(null);
      when(mockRepo.getSongContaining('Server Song')).thenReturn(null);
      when(mockRepo.saveSong(any)).thenReturn(serverSong);
      when(
        mockArtistService.cacheServerArtist(any),
      ).thenAnswer((inv) => inv.positionalArguments[0] as Artist);
      when(
        mockAlbumService.cacheServerAlbum(any),
      ).thenAnswer((inv) => inv.positionalArguments[0] as Album);

      final local = [makeSong(serverId: 10)];
      when(mockRepo.getAllSongs()).thenReturn(local);

      final result = await service.getAllSongs();

      expect(result, equals(local));
      verify(mockRestService.getAllSongs()).called(1);
      verify(mockRepo.getAllSongs()).called(1);
    });

    test('falls back to local when server fetch fails', () async {
      when(mockRestService.getAllSongs()).thenThrow(Exception('network'));
      final local = [makeSong()];
      when(mockRepo.getAllSongs()).thenReturn(local);

      final result = await service.getAllSongs();

      expect(result, equals(local));
    });
  });

  group('getSongsPage', () {
    test('returns local page data after server caches results', () async {
      final serverPage = SongPageDto(
        content: [makeSong(serverId: 5)],
        page: 0,
        size: 20,
        totalPages: 1,
        totalElements: 1,
      );
      when(
        mockRestService.getSongsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenAnswer((_) async => serverPage);

      when(mockRepo.getSongByServerId(any)).thenReturn(null);
      when(mockRepo.getSongContaining(any)).thenReturn(null);
      when(
        mockRepo.saveSong(any),
      ).thenAnswer((inv) => inv.positionalArguments[0] as Song);
      when(
        mockArtistService.cacheServerArtist(any),
      ).thenAnswer((inv) => inv.positionalArguments[0] as Artist);
      when(
        mockAlbumService.cacheServerAlbum(any),
      ).thenAnswer((inv) => inv.positionalArguments[0] as Album);

      final local = [makeSong(serverId: 5)];
      when(mockRepo.getSongsPaged(any, any, any, any, any)).thenReturn(local);

      final result = await service.getSongsPage('', 'name', true, 0, 20);

      expect(result.content, equals(local));
      expect(result.totalPages, 1);
      expect(result.totalElements, 1);
    });

    test('falls back to local pagination when server fails', () async {
      when(
        mockRestService.getSongsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenThrow(Exception('timeout'));

      when(
        mockRepo.getSongs(any, any, any),
      ).thenReturn([makeSong(), makeSong()]);
      when(
        mockRepo.getSongsPaged(any, any, any, any, any),
      ).thenReturn([makeSong()]);

      final result = await service.getSongsPage('', 'name', true, 0, 20);

      expect(result.content, hasLength(1));
      expect(result.totalElements, 2);
    });
  });

  group('deleteSong', () {
    test('delegates to repository', () {
      final song = makeSong();

      service.deleteSong(song);

      verify(mockRepo.deleteSong(song)).called(1);
    });
  });

  group('updateSong', () {
    test('delegates to repository', () {
      final song = makeSong();

      service.updateSong(song);

      verify(mockRepo.updateSong(song)).called(1);
    });
  });

  group('getSongsFromPaths', () {
    test('returns empty list for empty input', () async {
      final result = await service.getSongsFromPaths([]);

      expect(result, isEmpty);
      verifyNever(mockRepo.getSongByPath(any));
    });

    test('resolves each path via getSong', () async {
      final song = makeSong();
      when(mockRepo.getSongByPath('/music/track.mp3')).thenReturn(song);

      final result = await service.getSongsFromPaths(['/music/track.mp3']);

      expect(result, equals([song]));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // getSong
  // ──────────────────────────────────────────────────────────────────────────

  group('getSong — preferServer=true', () {
    test('returns null immediately when serverId is null', () async {
      final result = await service.getSong('', preferServer: true);

      expect(result, isNull);
      verifyNever(mockRepo.getSongByServerId(any));
    });

    test('returns cached song without server call', () async {
      final song = makeSong(serverId: 5);
      when(mockRepo.getSongByServerId(5)).thenReturn(song);

      final result =
          await service.getSong('', preferServer: true, serverId: 5);

      expect(result, same(song));
      verifyNever(mockRestService.getServerSong(any));
    });

    test('fetches from server and returns cached result', () async {
      final serverSong = makeSong(serverId: 7);
      when(mockRepo.getSongByServerId(7)).thenReturn(null);
      when(mockRestService.getServerSong(7))
          .thenAnswer((_) async => serverSong);
      when(mockRepo.saveSong(any)).thenReturn(serverSong);
      when(mockRepo.getSongContaining(any)).thenReturn(null);
      when(mockArtistService.getArtistByServerId(any)).thenReturn(null);
      when(mockAlbumService.getAlbumByServerId(any)).thenReturn(null);

      // After caching, the second getSongByServerId call returns the song
      var callCount = 0;
      when(mockRepo.getSongByServerId(7)).thenAnswer((_) {
        callCount++;
        return callCount > 1 ? serverSong : null;
      });

      final result =
          await service.getSong('', preferServer: true, serverId: 7);

      expect(result, same(serverSong));
    });

    test('returns null when server fetch throws', () async {
      when(mockRepo.getSongByServerId(any)).thenReturn(null);
      when(mockRestService.getServerSong(any))
          .thenThrow(Exception('server down'));

      final result =
          await service.getSong('', preferServer: true, serverId: 3);

      expect(result, isNull);
    });
  });

  group('getSong — local path', () {
    test('throws ArgumentError for empty path', () async {
      expect(
          () async => await service.getSong(''), throwsArgumentError);
    });

    test('returns song when found by path', () async {
      final song = makeSong();
      when(mockRepo.getSongByPath('/music/a.mp3')).thenReturn(song);

      final result = await service.getSong('/music/a.mp3');

      expect(result, same(song));
    });

    test('returns null when path throws (not found)', () async {
      when(mockRepo.getSongByPath(any)).thenThrow(Exception('not found'));

      final result = await service.getSong('/missing.mp3');

      expect(result, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // getSongs
  // ──────────────────────────────────────────────────────────────────────────

  group('getSongs', () {
    test('calls server search then returns local songs', () async {
      final serverPage = SongPageDto(
        content: [makeSong(serverId: 3)],
        page: 0,
        size: 200,
        totalPages: 1,
        totalElements: 1,
      );
      when(mockRestService.getSongsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenAnswer((_) async => serverPage);
      when(mockRepo.getSongByServerId(any)).thenReturn(null);
      when(mockRepo.getSongContaining(any)).thenReturn(null);
      when(mockRepo.saveSong(any))
          .thenAnswer((inv) => inv.positionalArguments[0] as Song);

      final local = [makeSong()];
      when(mockRepo.getSongs(any, any, any)).thenReturn(local);

      final result = await service.getSongs('rock', 'title', true);

      expect(result, equals(local));
    });

    test('returns local songs even when server throws', () async {
      when(mockRestService.getSongsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenThrow(Exception('timeout'));
      final local = [makeSong()];
      when(mockRepo.getSongs(any, any, any)).thenReturn(local);

      final result = await service.getSongs('', 'title', true);

      expect(result, equals(local));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // addSongsBatch / addSongsEntitiesBatch
  // ──────────────────────────────────────────────────────────────────────────

  group('addSongsBatch', () {
    test('calls saveSong for each song', () {
      final songs = [makeSong(id: 1), makeSong(id: 2)];
      when(mockRepo.saveSong(any))
          .thenAnswer((inv) => inv.positionalArguments[0] as Song);

      service.addSongsBatch(songs);

      verify(mockRepo.saveSong(any)).called(2);
    });
  });

  group('addSongsEntitiesBatch', () {
    test('delegates to saveSongs and returns list', () {
      final songs = [makeSong(id: 1), makeSong(id: 2)];
      when(mockRepo.saveSongs(songs)).thenReturn(songs);

      final result = service.addSongsEntitiesBatch(songs);

      expect(result, equals(songs));
      verify(mockRepo.saveSongs(songs)).called(1);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // getSongContaining / linkToServerId / updateSongsBatch
  // ──────────────────────────────────────────────────────────────────────────

  group('getSongContaining', () {
    test('delegates to repository', () {
      final song = makeSong();
      when(mockRepo.getSongContaining('rock')).thenReturn(song);

      expect(service.getSongContaining('rock'), same(song));
    });

    test('returns null when not found', () {
      when(mockRepo.getSongContaining(any)).thenReturn(null);

      expect(service.getSongContaining('missing'), isNull);
    });
  });

  group('linkToServerId', () {
    test('gets song, sets serverId, calls updateSong', () {
      final song = makeSong(id: 5, serverId: -1);
      when(mockRepo.getSong(5)).thenReturn(song);

      service.linkToServerId(5, 99);

      expect(song.serverId, 99);
      verify(mockRepo.updateSong(song)).called(1);
    });
  });

  group('updateSongsBatch', () {
    test('delegates to updateSongs', () {
      final songs = [makeSong(id: 1), makeSong(id: 2)];

      service.updateSongsBatch(songs);

      verify(mockRepo.updateSongs(songs)).called(1);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // getSongsPagedLocal
  // ──────────────────────────────────────────────────────────────────────────

  group('getSongsPagedLocal', () {
    test('delegates with correct offset calculation (page * pageSize)', () {
      final local = [makeSong()];
      when(mockRepo.getSongsPaged('', 'title', true, 20, 10)).thenReturn(local);

      final result =
          service.getSongsPagedLocal('', 'title', true, 2, 10);

      expect(result, equals(local));
      verify(mockRepo.getSongsPaged('', 'title', true, 20, 10)).called(1);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // searchSongsPageFromServer / searchSongsFromServer
  // ──────────────────────────────────────────────────────────────────────────

  group('searchSongsPageFromServer', () {
    test('caches songs and returns refreshed list using local cached songs',
        () async {
      final serverSong = makeSong(serverId: 10, name: 'Hit');
      final serverPage = SongPageDto(
        content: [serverSong],
        page: 0,
        size: 50,
        totalPages: 1,
        totalElements: 1,
      );
      when(mockRestService.getSongsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenAnswer((_) async => serverPage);

      final cachedSong = makeSong(serverId: 10, name: 'Hit Cached', id: 5);
      when(mockRepo.getSongByServerId(10)).thenReturn(null);
      when(mockRepo.getSongContaining(any)).thenReturn(null);
      when(mockRepo.saveSong(any)).thenReturn(serverSong);

      // After caching, return the cached song
      var callCount = 0;
      when(mockRepo.getSongByServerId(10)).thenAnswer((_) {
        callCount++;
        return callCount > 1 ? cachedSong : null;
      });

      final result =
          await service.searchSongsPageFromServer('hit', page: 0, size: 50);

      expect(result.content.first, same(cachedSong));
      expect(result.totalElements, 1);
    });

    test('returns server song directly when not in local cache after caching',
        () async {
      final serverSong = makeSong(serverId: 11, name: 'Uncached');
      final serverPage = SongPageDto(
        content: [serverSong],
        page: 0,
        size: 50,
        totalPages: 1,
        totalElements: 1,
      );
      when(mockRestService.getSongsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenAnswer((_) async => serverPage);
      when(mockRepo.getSongByServerId(any)).thenReturn(null);
      when(mockRepo.getSongContaining(any)).thenReturn(null);
      when(mockRepo.saveSong(any)).thenReturn(serverSong);

      final result = await service.searchSongsPageFromServer('');

      expect(result.content.first, same(serverSong));
    });
  });

  group('searchSongsFromServer', () {
    test('returns content list from searchSongsPageFromServer', () async {
      final serverSong = makeSong(serverId: 5);
      final serverPage = SongPageDto(
        content: [serverSong],
        page: 0,
        size: 50,
        totalPages: 1,
        totalElements: 1,
      );
      when(mockRestService.getSongsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenAnswer((_) async => serverPage);
      when(mockRepo.getSongByServerId(any)).thenReturn(null);
      when(mockRepo.getSongContaining(any)).thenReturn(null);
      when(mockRepo.saveSong(any)).thenReturn(serverSong);

      final result = await service.searchSongsFromServer('');

      expect(result, isA<List<Song>>());
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // refreshServerSongs / getServerSongs
  // ──────────────────────────────────────────────────────────────────────────

  group('refreshServerSongs / getServerSongs', () {
    test('refreshServerSongs fetches, caches, and returns all local songs',
        () async {
      final serverSong = makeSong(serverId: 20);
      when(mockRestService.getAllSongs())
          .thenAnswer((_) async => [serverSong]);
      when(mockRepo.getSongByServerId(any)).thenReturn(null);
      when(mockRepo.getSongContaining(any)).thenReturn(null);
      when(mockRepo.saveSong(any)).thenReturn(serverSong);

      final local = [makeSong(serverId: 20)];
      when(mockRepo.getAllSongs()).thenReturn(local);

      final result = await service.refreshServerSongs();

      expect(result, equals(local));
      verify(mockRestService.getAllSongs()).called(1);
    });

    test('getServerSongs delegates to refreshServerSongs', () async {
      when(mockRestService.getAllSongs()).thenAnswer((_) async => []);
      when(mockRepo.getAllSongs()).thenReturn([]);

      final result = await service.getServerSongs();

      expect(result, isEmpty);
      verify(mockRestService.getAllSongs()).called(1);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // _cacheServerSong branches (via getAllSongs)
  // ──────────────────────────────────────────────────────────────────────────

  group('_cacheServerSong branches', () {
    test('skips song with serverId <= 0', () async {
      final badSong = makeSong(serverId: -1, name: 'No ID');
      badSong.serverId = -1;
      when(mockRestService.getAllSongs()).thenAnswer((_) async => [badSong]);
      when(mockRepo.getAllSongs()).thenReturn([]);

      await service.getAllSongs();

      verifyNever(mockRepo.saveSong(any));
      verifyNever(mockRepo.updateSong(any));
    });

    test('updates existing found directly by serverId', () async {
      final serverSong = makeSong(serverId: 5, name: 'Updated Name');
      final existing = makeSong(serverId: 5, id: 10);
      when(mockRestService.getAllSongs()).thenAnswer((_) async => [serverSong]);
      when(mockRepo.getSongByServerId(5)).thenReturn(existing);
      when(mockRepo.getAllSongs()).thenReturn([existing]);

      await service.getAllSongs();

      expect(existing.name, 'Updated Name');
      verify(mockRepo.updateSong(existing)).called(1);
    });

    test('saves new song when not found by serverId or name', () async {
      final serverSong = makeSong(serverId: 6, name: 'New Song');
      when(mockRestService.getAllSongs()).thenAnswer((_) async => [serverSong]);
      when(mockRepo.getSongByServerId(6)).thenReturn(null);
      when(mockRepo.getSongContaining('New Song')).thenReturn(null);
      when(mockRepo.saveSong(any)).thenReturn(serverSong);
      when(mockRepo.getAllSongs()).thenReturn([]);

      await service.getAllSongs();

      verify(mockRepo.saveSong(serverSong)).called(1);
    });

    test('saves as new when not found by serverId (no candidate lookup)', () async {
      final serverSong = makeSong(serverId: 7, name: 'Match');

      when(mockRestService.getAllSongs()).thenAnswer((_) async => [serverSong]);
      when(mockRepo.getSongByServerId(7)).thenReturn(null);
      when(mockRepo.saveSong(any)).thenReturn(serverSong);
      when(mockRepo.getAllSongs()).thenReturn([]);

      await service.getAllSongs();

      verify(mockRepo.saveSong(serverSong)).called(1);
    });

    test('saves as new when candidate artist name does not match', () async {
      final resolvedArtist = Artist()..name = 'Artist A';
      final serverSong = makeSong(serverId: 8, name: 'Mismatch');
      serverSong.serverArtistId = 99;

      final candidateSong = makeSong(id: 30);
      candidateSong.artist.target = Artist()..name = 'Artist B';

      when(mockArtistService.getArtistByServerId(99)).thenReturn(resolvedArtist);
      when(mockAlbumService.getAlbumByServerId(any)).thenReturn(null);
      when(mockRestService.getAllSongs()).thenAnswer((_) async => [serverSong]);
      when(mockRepo.getSongByServerId(8)).thenReturn(null);
      when(mockRepo.getSongContaining('Mismatch')).thenReturn(candidateSong);
      when(mockRepo.saveSong(any)).thenReturn(serverSong);
      when(mockRepo.getAllSongs()).thenReturn([]);

      await service.getAllSongs();

      verify(mockRepo.saveSong(serverSong)).called(1);
    });

    test('links serverId when existing song found directly by serverId',
        () async {
      final serverSong = makeSong(serverId: 9, name: 'Link Me');
      final existing = makeSong(id: 40);
      existing.serverId = -1;

      when(mockRestService.getAllSongs()).thenAnswer((_) async => [serverSong]);
      when(mockRepo.getSongByServerId(9)).thenReturn(existing);
      when(mockRepo.getAllSongs()).thenReturn([existing]);

      await service.getAllSongs();

      expect(existing.serverId, 9);
      verify(mockRepo.updateSong(existing)).called(1);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // getSongsPage — server returns 0 totalElements
  // ──────────────────────────────────────────────────────────────────────────

  group('getSongsPage — server 0 totalElements', () {
    test('falls through to local pagination', () async {
      final serverPage = SongPageDto(
        content: [],
        page: 0,
        size: 20,
        totalPages: 0,
        totalElements: 0,
      );
      when(mockRestService.getSongsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenAnswer((_) async => serverPage);
      when(mockRepo.getSongs(any, any, any)).thenReturn([makeSong(), makeSong()]);
      when(mockRepo.getSongsPaged(any, any, any, any, any)).thenReturn([makeSong()]);

      final result = await service.getSongsPage('', 'title', true, 0, 20);

      expect(result.totalElements, 2);
    });
  });
}
