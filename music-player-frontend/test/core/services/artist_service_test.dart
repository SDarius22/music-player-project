import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/dtos/artist_page_dto.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/artist_rest_service.dart';

import 'artist_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ArtistRepository>(),
  MockSpec<ArtistRestService>(),
])
void main() {
  late MockArtistRepository mockRepo;
  late MockArtistRestService mockRestService;
  late ArtistService service;

  Artist makeArtist({int serverId = 1, String name = 'Artist', int id = 0}) {
    final a = Artist();
    a.id = id;
    a.serverId = serverId;
    a.name = name;
    return a;
  }

  ArtistPageDto makeServerPage({
    List<Artist>? content,
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
    mockRestService = MockArtistRestService();
    service = ArtistService(mockRepo, mockRestService);
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
    test('returns artist when found', () {
      final artist = makeArtist(serverId: 42);
      when(mockRepo.getArtistByServerId(42)).thenReturn(artist);
      expect(service.getArtistByServerId(42), same(artist));
    });

    test('returns null when not found', () {
      when(mockRepo.getArtistByServerId(any)).thenReturn(null);
      expect(service.getArtistByServerId(99), isNull);
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
      expect(service.getArtistByName('Found'), same(artist));
    });

    test('throws when not found', () {
      when(mockRepo.getArtistByName(any)).thenReturn(null);
      expect(() => service.getArtistByName('Missing'), throwsException);
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
    test('updates name and calls updateArtist when found by serverId', () {
      final existing = makeArtist(serverId: 10, name: 'Old Name', id: 1);
      final serverArtist = makeArtist(serverId: 10, name: 'New Name');
      when(mockRepo.getArtistByServerId(10)).thenReturn(existing);

      final result = service.cacheServerArtist(serverArtist);

      expect(result, same(existing));
      expect(existing.name, 'New Name');
      verify(mockRepo.updateArtist(existing)).called(1);
      verifyNever(mockRepo.saveArtist(any));
    });

    test('links serverId when found by name with no serverId', () {
      final existing = makeArtist(serverId: -1, name: 'Jazz Band', id: 2);
      final serverArtist = makeArtist(serverId: 20, name: 'Jazz Band');
      when(mockRepo.getArtistByServerId(20)).thenReturn(null);
      when(mockRepo.getArtistByName('Jazz Band')).thenReturn(existing);

      service.cacheServerArtist(serverArtist);

      expect(existing.serverId, 20);
      verify(mockRepo.updateArtist(existing)).called(1);
    });

    test('does not re-link serverId when found-by-name artist already has one', () {
      final existing = makeArtist(serverId: 5, name: 'Jazz Band', id: 3);
      final serverArtist = makeArtist(serverId: 20, name: 'Jazz Band');
      when(mockRepo.getArtistByServerId(20)).thenReturn(null);
      when(mockRepo.getArtistByName('Jazz Band')).thenReturn(existing);

      service.cacheServerArtist(serverArtist);

      expect(existing.serverId, 5); // unchanged
      verifyNever(mockRepo.updateArtist(any));
    });

    test('saves new artist when not found by serverId or name', () {
      final serverArtist = makeArtist(serverId: 10, name: 'New Artist');
      when(mockRepo.getArtistByServerId(10)).thenReturn(null);
      when(mockRepo.getArtistByName('New Artist')).thenReturn(null);
      when(mockRepo.saveArtist(any)).thenReturn(serverArtist);

      final result = service.cacheServerArtist(serverArtist);

      verify(mockRepo.saveArtist(serverArtist)).called(1);
      expect(result, same(serverArtist));
    });

    test('skips serverId lookup when serverId <= 0', () {
      final serverArtist = makeArtist(serverId: -1, name: 'Unknown');
      when(mockRepo.getArtistByName('Unknown')).thenReturn(null);
      when(mockRepo.saveArtist(any)).thenReturn(serverArtist);

      service.cacheServerArtist(serverArtist);

      verifyNever(mockRepo.getArtistByServerId(any));
      verify(mockRepo.saveArtist(serverArtist)).called(1);
    });
  });

  group('getArtistsPage', () {
    test('caches artists and returns local paged data when server succeeds', () async {
      final serverArtist = makeArtist(serverId: 3, name: 'Server Artist');
      when(mockRestService.getArtistsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenAnswer((_) async => makeServerPage(content: [serverArtist], totalElements: 1));
      when(mockRepo.getArtistByServerId(any)).thenReturn(null);
      when(mockRepo.getArtistByName(any)).thenReturn(null);
      when(mockRepo.saveArtist(any)).thenAnswer((inv) => inv.positionalArguments[0] as Artist);
      final local = [makeArtist(serverId: 3)];
      when(mockRepo.getArtistsPaged(any, any, any, any, any)).thenReturn(local);

      final result = await service.getArtistsPage('', 'name', true, 0, 20);

      expect(result.content, equals(local));
      expect(result.totalElements, 1);
    });

    test('falls to local when server returns 0 totalElements', () async {
      when(mockRestService.getArtistsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenAnswer((_) async => makeServerPage(content: [], totalElements: 0));
      final local = [makeArtist(), makeArtist()];
      when(mockRepo.getArtists(any, any, any)).thenReturn(local);
      when(mockRepo.getArtistsPaged(any, any, any, any, any)).thenReturn(local);

      final result = await service.getArtistsPage('', 'name', true, 0, 20);

      expect(result.totalElements, 2);
    });

    test('falls to local when server throws', () async {
      when(mockRestService.getArtistsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenThrow(Exception('timeout'));
      final local = [makeArtist(), makeArtist()];
      when(mockRepo.getArtists(any, any, any)).thenReturn(local);
      when(mockRepo.getArtistsPaged(any, any, any, any, any)).thenReturn(local);

      final result = await service.getArtistsPage('', 'name', true, 0, 20);

      expect(result.totalElements, 2);
    });

    test('returns empty content when local offset exceeds total', () async {
      when(mockRestService.getArtistsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenThrow(Exception('error'));
      when(mockRepo.getArtists(any, any, any)).thenReturn([makeArtist()]);

      final result = await service.getArtistsPage('', 'name', true, 5, 20);

      expect(result.content, isEmpty);
    });

    test('passes non-empty query string to server', () async {
      when(mockRestService.getArtistsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenAnswer((_) async => makeServerPage(content: [], totalElements: 0));
      when(mockRepo.getArtists(any, any, any)).thenReturn([]);

      await service.getArtistsPage('rock', 'name', true, 0, 20);

      verify(mockRestService.getArtistsPage(
        query: 'rock',
        page: 0,
        size: 20,
        sort: anyNamed('sort'),
      )).called(1);
    });

    test('passes null for empty query', () async {
      when(mockRestService.getArtistsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenAnswer((_) async => makeServerPage(content: [], totalElements: 0));
      when(mockRepo.getArtists(any, any, any)).thenReturn([]);

      await service.getArtistsPage('', 'name', true, 0, 20);

      verify(mockRestService.getArtistsPage(
        query: null,
        page: 0,
        size: 20,
        sort: anyNamed('sort'),
      )).called(1);
    });

    test('passes desc sort when ascending is false', () async {
      when(mockRestService.getArtistsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenAnswer((_) async => makeServerPage(content: [], totalElements: 0));
      when(mockRepo.getArtists(any, any, any)).thenReturn([]);

      await service.getArtistsPage('', 'name', false, 0, 20);

      verify(mockRestService.getArtistsPage(
        query: null,
        page: 0,
        size: 20,
        sort: 'name,desc',
      )).called(1);
    });
  });
}
