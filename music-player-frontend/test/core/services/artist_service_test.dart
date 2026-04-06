import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_expanded_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_page_dto.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/artist_rest_client.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';

import 'artist_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ArtistRepository>(),
  MockSpec<AlbumRepository>(),
  MockSpec<SongRepository>(),
  MockSpec<ArtistRestClient>(),
])
void main() {
  late MockArtistRepository mockRepo;
  late MockAlbumRepository mockAlbumRepo;
  late MockSongRepository mockSongRepo;
  late MockArtistRestClient mockRestClient;
  late ArtistService service;

  Artist makeArtist({int serverId = 1, String name = 'Artist', int id = 0}) {
    final a = Artist();
    a.id = id;
    a.serverId = serverId;
    a.name = name;
    return a;
  }

  ArtistExpandedDto makeExpandedDto({
    int id = 1,
    String name = 'Artist',
    List<String> songFileHashes = const [],
  }) {
    return ArtistExpandedDto(
      id: id,
      name: name,
      songFileHashes: songFileHashes,
    );
  }

  ArtistPageDto makeServerPage({
    List<ArtistExpandedDto>? content,
    int totalElements = 1,
    int page = 0,
    int size = 20,
  }) {
    return ArtistPageDto(
      content: content ?? [],
      page: page,
      size: size,
      totalPages: (totalElements / size).ceil().clamp(1, 999),
      totalElements: totalElements,
    );
  }

  setUp(() {
    mockRepo = MockArtistRepository();
    mockAlbumRepo = MockAlbumRepository();
    mockSongRepo = MockSongRepository();
    mockRestClient = MockArtistRestClient();
    service = ArtistService(
      mockRepo,
      mockAlbumRepo,
      mockSongRepo,
      mockRestClient,
    );
  });

  group('watchArtists', () {
    test('delegates to repository', () {
      final stream = Stream.empty();
      when(mockRepo.watchArtists()).thenAnswer((_) => stream);
      expect(service.watchArtists(), same(stream));
    });
  });

  group('sortFields', () {
    test('delegates to repository', () {
      const fields = {'Name': null};
      when(mockRepo.sortFields).thenReturn(fields);
      expect(service.sortFields, equals(fields));
    });
  });

  group('getArtist', () {
    test('returns artist from repository', () {
      final artist = makeArtist(id: 5);
      when(mockRepo.getArtist(5)).thenReturn(artist);
      expect(service.getArtist(5), same(artist));
    });

    test('throws when repository returns null', () {
      when(mockRepo.getArtist(any)).thenReturn(null);
      expect(() => service.getArtist(99), throwsException);
    });
  });

  group('getArtistByServerId', () {
    test('falls back to local when server fails', () async {
      final artist = makeArtist(serverId: 42);
      when(
        mockRestClient.getArtistById(42),
      ).thenThrow(Exception('server error'));
      when(mockRepo.getArtistByServerId(42)).thenReturn(artist);

      final result = await service.getArtistByServerId(42);

      expect(result, same(artist));
    });
  });

  group('getOrCreateArtist', () {
    test('returns existing artist without saving', () {
      final existing = makeArtist(name: 'Rock Band');
      when(mockRepo.getArtistByName('Rock Band')).thenReturn(existing);

      final result = service.getOrCreateArtist('Rock Band');

      expect(result, same(existing));
      verifyNever(mockRepo.saveArtist(any));
    });

    test('creates and saves new artist when not found', () {
      when(mockRepo.getArtistByName(any)).thenReturn(null);
      final saved = makeArtist(name: 'New Band', id: 7);
      when(mockRepo.saveArtist(any)).thenReturn(saved);

      final result = service.getOrCreateArtist('New Band');

      expect(result, same(saved));
      verify(mockRepo.saveArtist(any)).called(1);
    });
  });

  group('getArtistByName', () {
    test('returns artist when found', () {
      final artist = makeArtist(name: 'Found');
      when(mockRepo.getArtistByName('Found')).thenReturn(artist);
      expect(service.fetchArtistDetails('Found'), same(artist));
    });

    test('throws when not found', () {
      when(mockRepo.getArtistByName(any)).thenReturn(null);
      expect(() => service.fetchArtistDetails('Missing'), throwsException);
    });
  });

  group('getAllArtists', () {
    test('delegates to repository', () {
      final artists = [makeArtist(), makeArtist()];
      when(mockRepo.getAllArtists()).thenReturn(artists);
      expect(service.getAllArtists(), equals(artists));
    });
  });

  group('updateArtist', () {
    test('delegates to repository', () {
      final artist = makeArtist();
      service.updateArtist(artist);
      verify(mockRepo.updateArtist(artist)).called(1);
    });
  });

  group('cacheServerArtist', () {
    test('creates artist via getOrCreateArtistByServerId and sets name', () {
      final dto = makeExpandedDto(id: 10, name: 'New Artist');
      final cached = makeArtist(serverId: 10, id: 1);
      when(mockRepo.getOrCreateArtistByServerId(10)).thenReturn(cached);
      when(mockRepo.saveArtist(any)).thenReturn(cached);

      final result = service.cacheServerArtist(dto);

      expect(result, same(cached));
      expect(cached.name, 'New Artist');
      verify(mockRepo.saveArtist(cached)).called(1);
    });

    test('links songs from songFileHashes', () {
      final dto = makeExpandedDto(id: 10, songFileHashes: ['hash1', 'hash2']);
      final cached = makeArtist(serverId: 10, id: 1);
      final song1 = Song()..fileHash = 'hash1';
      final song2 = Song()..fileHash = 'hash2';

      when(mockRepo.getOrCreateArtistByServerId(10)).thenReturn(cached);
      when(mockSongRepo.getOrCreateSongByFileHash('hash1')).thenReturn(song1);
      when(mockSongRepo.getOrCreateSongByFileHash('hash2')).thenReturn(song2);
      when(mockRepo.saveArtist(any)).thenReturn(cached);

      service.cacheServerArtist(dto);

      verify(mockSongRepo.updateSong(song1)).called(1);
      verify(mockSongRepo.updateSong(song2)).called(1);
      expect(song1.artist.targetId, 1);
      expect(song2.artist.targetId, 1);
    });

    test('throws when id <= 0', () {
      final dto = makeExpandedDto(id: 0);
      expect(() => service.cacheServerArtist(dto), throwsException);
    });
  });

  group('getArtistsPage', () {
    test(
      'caches artists and returns local paged data when server succeeds',
      () async {
        final serverDto = makeExpandedDto(id: 3, name: 'Server Artist');
        when(
          mockRestClient.getArtistsPage(
            query: anyNamed('query'),
            page: anyNamed('page'),
            size: anyNamed('size'),
            sort: anyNamed('sort'),
          ),
        ).thenAnswer(
          (_) async => makeServerPage(content: [serverDto], totalElements: 1),
        );
        when(
          mockRepo.getOrCreateArtistByServerId(any),
        ).thenReturn(makeArtist());
        when(
          mockRepo.saveArtist(any),
        ).thenAnswer((inv) => inv.positionalArguments[0] as Artist);
        final local = [makeArtist(serverId: 3)];
        when(
          mockRepo.getArtistsPaged(any, any, any, any, any),
        ).thenReturn(local);

        final result = await service.getArtistsPage('', 'name', true, 0, 20);

        expect(result.content, equals(local));
        expect(result.totalPages, greaterThan(0));
      },
    );

    test('falls to local when server returns 0 totalElements', () async {
      when(
        mockRestClient.getArtistsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenAnswer((_) async => makeServerPage(content: [], totalElements: 0));
      final local = [makeArtist(), makeArtist()];
      when(mockRepo.getArtists(any, any, any)).thenReturn(local);
      when(mockRepo.getArtistsPaged(any, any, any, any, any)).thenReturn(local);

      final result = await service.getArtistsPage('', 'name', true, 0, 20);

      expect(result.totalPages, 1); // ceil(2/20) = 1
    });

    test('falls to local when server throws', () async {
      when(
        mockRestClient.getArtistsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenThrow(Exception('timeout'));
      final local = [makeArtist(), makeArtist()];
      when(mockRepo.getArtists(any, any, any)).thenReturn(local);
      when(mockRepo.getArtistsPaged(any, any, any, any, any)).thenReturn(local);

      final result = await service.getArtistsPage('', 'name', true, 0, 20);

      expect(result.totalPages, 1);
    });

    test('returns empty content when local offset exceeds total', () async {
      when(
        mockRestClient.getArtistsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenThrow(Exception('error'));
      when(mockRepo.getArtists(any, any, any)).thenReturn([makeArtist()]);
      when(mockRepo.getArtistsPaged(any, any, any, any, any)).thenReturn([]);

      final result = await service.getArtistsPage('', 'name', true, 5, 20);

      expect(result.content, isEmpty);
    });

    test('passes non-empty query string to server', () async {
      when(
        mockRestClient.getArtistsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenAnswer((_) async => makeServerPage(content: [], totalElements: 0));
      when(mockRepo.getArtists(any, any, any)).thenReturn([]);

      await service.getArtistsPage('rock', 'name', true, 0, 20);

      verify(
        mockRestClient.getArtistsPage(
          query: 'rock',
          page: 0,
          size: 20,
          sort: anyNamed('sort'),
        ),
      ).called(1);
    });

    test('passes null for empty query', () async {
      when(
        mockRestClient.getArtistsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenAnswer((_) async => makeServerPage(content: [], totalElements: 0));
      when(mockRepo.getArtists(any, any, any)).thenReturn([]);

      await service.getArtistsPage('', 'name', true, 0, 20);

      verify(
        mockRestClient.getArtistsPage(
          query: null,
          page: 0,
          size: 20,
          sort: anyNamed('sort'),
        ),
      ).called(1);
    });

    test('passes desc sort when ascending is false', () async {
      when(
        mockRestClient.getArtistsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenAnswer((_) async => makeServerPage(content: [], totalElements: 0));
      when(mockRepo.getArtists(any, any, any)).thenReturn([]);

      await service.getArtistsPage('', 'name', false, 0, 20);

      verify(
        mockRestClient.getArtistsPage(
          query: null,
          page: 0,
          size: 20,
          sort: 'name,desc',
        ),
      ).called(1);
    });
  });
}
