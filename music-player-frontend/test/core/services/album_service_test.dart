import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/dtos/album_page_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/album_rest_service.dart';

import 'album_service_test.mocks.dart';

@GenerateNiceMocks([MockSpec<AlbumRepository>(), MockSpec<AlbumRestService>()])
void main() {
  late MockAlbumRepository mockRepo;
  late MockAlbumRestService mockRestService;
  late AlbumService service;

  Album makeAlbum({int serverId = 1, String name = 'Album', int id = 0}) {
    final a = Album();
    a.id = id;
    a.serverId = serverId;
    a.name = name;
    return a;
  }

  setUp(() {
    mockRepo = MockAlbumRepository();
    mockRestService = MockAlbumRestService();
    service = AlbumService(mockRepo, mockRestService);
  });

  group('getAlbum', () {
    test('returns album from repository', () {
      final album = makeAlbum(id: 5);
      when(mockRepo.getAlbum(5)).thenReturn(album);

      expect(service.getAlbum(5), same(album));
    });

    test('throws when repository returns null', () {
      when(mockRepo.getAlbum(any)).thenReturn(null);

      expect(() => service.getAlbum(99), throwsException);
    });
  });

  group('cacheServerAlbum', () {
    test('saves new album when not found by serverId or name', () {
      final serverAlbum = makeAlbum(serverId: 10, name: 'New Album');
      when(mockRepo.getAlbumByServerId(10)).thenReturn(null);
      when(mockRepo.getAlbumByName('New Album')).thenReturn(null);
      when(mockRepo.saveAlbum(any)).thenReturn(serverAlbum);

      final result = service.cacheServerAlbum(serverAlbum);

      expect(result, same(serverAlbum));
      verify(mockRepo.saveAlbum(serverAlbum)).called(1);
    });

    test('updates existing album found by serverId', () {
      final existing = makeAlbum(serverId: 10, name: 'Old Name', id: 1);
      final serverAlbum = makeAlbum(serverId: 10, name: 'New Name');
      when(mockRepo.getAlbumByServerId(10)).thenReturn(existing);

      service.cacheServerAlbum(serverAlbum);

      expect(existing.name, 'New Name');
      verify(mockRepo.updateAlbum(existing)).called(1);
      verifyNever(mockRepo.saveAlbum(any));
    });

    test('updates existing album found by name when no match by serverId', () {
      final existing = makeAlbum(serverId: -1, name: 'Shared Name', id: 2);
      final serverAlbum = makeAlbum(serverId: 20, name: 'Shared Name');
      when(mockRepo.getAlbumByServerId(20)).thenReturn(null);
      when(mockRepo.getAlbumByName('Shared Name')).thenReturn(existing);

      service.cacheServerAlbum(serverAlbum);

      expect(existing.serverId, 20); // server ID should be linked
      verify(mockRepo.updateAlbum(existing)).called(1);
    });

    test('does not overwrite existing imageBytes with null', () {
      final existing = makeAlbum(serverId: 5);
      existing.imageBytes = Uint8List.fromList([1, 2, 3]);
      final serverAlbum = makeAlbum(serverId: 5);

      when(mockRepo.getAlbumByServerId(5)).thenReturn(existing);

      service.cacheServerAlbum(serverAlbum);

      expect(existing.imageBytes, isNotNull); // preserved
    });
  });

  group('getAlbumsPage', () {
    test('returns server page data when server call succeeds', () async {
      final serverAlbum = makeAlbum(serverId: 3, name: 'Server Album');
      final serverPage = AlbumPageDto(
        content: [serverAlbum],
        page: 0,
        size: 20,
        totalPages: 1,
        totalElements: 1,
      );
      when(
        mockRestService.getAlbumsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenAnswer((_) async => serverPage);

      when(mockRepo.getAlbumByServerId(any)).thenReturn(null);
      when(mockRepo.getAlbumByName(any)).thenReturn(null);
      when(
        mockRepo.saveAlbum(any),
      ).thenAnswer((inv) => inv.positionalArguments[0] as Album);

      final local = [makeAlbum(serverId: 3)];
      when(mockRepo.getAlbumsPaged(any, any, any, any, any)).thenReturn(local);

      final result = await service.getAlbumsPage('', 'name', true, 0, 20);

      expect(result.content, equals(local));
      expect(result.totalElements, 1);
    });

    test('falls back to local when server call fails', () async {
      when(
        mockRestService.getAlbumsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenThrow(Exception('timeout'));

      final local = [makeAlbum(), makeAlbum()];
      when(mockRepo.getAlbums(any, any, any)).thenReturn(local);
      when(mockRepo.getAlbumsPaged(any, any, any, any, any)).thenReturn(local);

      final result = await service.getAlbumsPage('', 'name', true, 0, 20);

      expect(result.totalElements, 2);
    });

    test('returns empty content when offset exceeds total', () async {
      when(
        mockRestService.getAlbumsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenThrow(Exception('timeout'));

      when(mockRepo.getAlbums(any, any, any)).thenReturn([makeAlbum()]);
      when(mockRepo.getAlbumsPaged(any, any, any, any, any)).thenReturn([]);

      final result = await service.getAlbumsPage('', 'name', true, 5, 20);

      expect(result.content, isEmpty);
    });
  });

  group('getAllAlbums', () {
    test('delegates to repository', () {
      final albums = [makeAlbum(), makeAlbum()];
      when(mockRepo.getAllAlbums()).thenReturn(albums);

      expect(service.getAllAlbums(), equals(albums));
    });
  });

  group('getAlbumByServerId', () {
    test('returns album when found', () {
      final album = makeAlbum(serverId: 42);
      when(mockRepo.getAlbumByServerId(42)).thenReturn(album);

      expect(service.getAlbumByServerId(42), same(album));
    });

    test('returns null when not found', () {
      when(mockRepo.getAlbumByServerId(any)).thenReturn(null);

      expect(service.getAlbumByServerId(99), isNull);
    });
  });

  group('updateAlbum', () {
    test('delegates to repository', () {
      final album = makeAlbum(id: 3);

      service.updateAlbum(album);

      verify(mockRepo.updateAlbum(album)).called(1);
    });
  });

  group('getOrCreateAlbum', () {
    test('returns existing album when found by name', () {
      final existing = makeAlbum(id: 1, name: 'Dark Side');
      when(mockRepo.getAlbumByName('Dark Side')).thenReturn(existing);
      when(mockRepo.saveAlbum(any)).thenReturn(existing);

      final result = service.getOrCreateAlbum('Dark Side', 10);

      expect(result, same(existing));
    });

    test('sets imageBytes on existing album when it was null', () {
      final existing = makeAlbum(id: 1, name: 'No Cover');
      final image = Uint8List.fromList([1, 2, 3]);
      when(mockRepo.getAlbumByName('No Cover')).thenReturn(existing);
      when(mockRepo.saveAlbum(any)).thenReturn(existing);

      service.getOrCreateAlbum('No Cover', 10, image: image);

      expect(existing.imageBytes, equals(image));
      verify(mockRepo.saveAlbum(existing)).called(1);
    });

    test('does not overwrite existing imageBytes', () {
      final existing = makeAlbum(id: 1, name: 'Has Cover');
      final originalImage = Uint8List.fromList([9, 8, 7]);
      existing.imageBytes = originalImage;
      when(mockRepo.getAlbumByName('Has Cover')).thenReturn(existing);
      when(mockRepo.saveAlbum(any)).thenReturn(existing);

      service.getOrCreateAlbum(
          'Has Cover', 10, image: Uint8List.fromList([1, 2, 3]));

      expect(existing.imageBytes, same(originalImage));
    });

    test('creates and saves new album when not found by name', () {
      when(mockRepo.getAlbumByName(any)).thenReturn(null);
      final saved = makeAlbum(id: 5, name: 'New Album');
      when(mockRepo.saveAlbum(any)).thenReturn(saved);

      final result = service.getOrCreateAlbum('New Album', 7);

      verify(mockRepo.saveAlbum(any)).called(1);
      expect(result, same(saved));
    });
  });

  group('cacheServerAlbum additional', () {
    test('copies imageBytes from server when existing has null', () {
      final existing = makeAlbum(serverId: 5, id: 1);
      existing.imageBytes = null;
      final serverAlbum = makeAlbum(serverId: 5);
      serverAlbum.imageBytes = Uint8List.fromList([4, 5, 6]);
      when(mockRepo.getAlbumByServerId(5)).thenReturn(existing);

      service.cacheServerAlbum(serverAlbum);

      expect(existing.imageBytes, equals(serverAlbum.imageBytes));
    });

    test('does not re-link serverId when found-by-name album already has one',
        () {
      final existing = makeAlbum(serverId: 5, name: 'Shared', id: 2);
      final serverAlbum = makeAlbum(serverId: 20, name: 'Shared');
      when(mockRepo.getAlbumByServerId(20)).thenReturn(null);
      when(mockRepo.getAlbumByName('Shared')).thenReturn(existing);

      service.cacheServerAlbum(serverAlbum);

      expect(existing.serverId, 5); // unchanged
    });
  });

  group('getAlbumsPage — server returns 0 total elements', () {
    test('falls through to local page when totalElements == 0', () async {
      final serverPage = AlbumPageDto(
        content: [],
        page: 0,
        size: 20,
        totalPages: 0,
        totalElements: 0,
      );
      when(mockRestService.getAlbumsPage(
        query: anyNamed('query'),
        page: anyNamed('page'),
        size: anyNamed('size'),
        sort: anyNamed('sort'),
      )).thenAnswer((_) async => serverPage);

      final local = [makeAlbum(), makeAlbum()];
      when(mockRepo.getAlbums(any, any, any)).thenReturn(local);
      when(mockRepo.getAlbumsPaged(any, any, any, any, any)).thenReturn(local);

      final result = await service.getAlbumsPage('', 'name', true, 0, 20);

      expect(result.totalElements, 2);
    });
  });
}
