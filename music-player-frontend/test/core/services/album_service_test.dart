import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/dtos/albums/album_expanded_dto.dart';
import 'package:music_player_frontend/core/dtos/albums/album_page_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/album_rest_client.dart';
import 'package:music_player_frontend/core/services/album_service.dart';

import 'album_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<AlbumRepository>(),
  MockSpec<ArtistRepository>(),
  MockSpec<SongRepository>(),
  MockSpec<AlbumRestClient>(),
])
void main() {
  late MockAlbumRepository mockAlbumRepo;
  late MockArtistRepository mockArtistRepo;
  late MockSongRepository mockSongRepo;
  late MockAlbumRestClient mockRestClient;
  late AlbumService service;

  Album makeAlbum({int serverId = 1, String name = 'Album', int id = 0}) {
    final a = Album();
    a.id = id;
    a.serverId = serverId;
    a.name = name;
    return a;
  }

  AlbumExpandedDto makeExpandedDto({
    int id = 1,
    String name = 'Album',
    List<String> songFileHashes = const [],
    int artistId = 1,
    String artistName = 'Artist',
  }) {
    return AlbumExpandedDto(
      id: id,
      name: name,
      songFileHashes: songFileHashes,
      artist: ArtistDto(id: artistId, name: artistName),
    );
  }

  setUp(() {
    mockAlbumRepo = MockAlbumRepository();
    mockArtistRepo = MockArtistRepository();
    mockSongRepo = MockSongRepository();
    mockRestClient = MockAlbumRestClient();
    service = AlbumService(
      mockAlbumRepo,
      mockArtistRepo,
      mockSongRepo,
      mockRestClient,
    );
  });

  group('getAlbum', () {
    test('returns album from repository', () {
      final album = makeAlbum(id: 5);
      when(mockAlbumRepo.getAlbum(5)).thenReturn(album);

      expect(service.getAlbum(5), same(album));
    });

    test('throws when repository returns null', () {
      when(mockAlbumRepo.getAlbum(any)).thenReturn(null);

      expect(() => service.getAlbum(99), throwsException);
    });
  });

  group('cacheServerAlbum', () {
    test('creates album via getOrCreateAlbumByServerId and sets name', () {
      final dto = makeExpandedDto(id: 10, name: 'New Album');
      final cachedAlbum = makeAlbum(serverId: 10);
      final artist = Artist()..id = 1;

      when(
        mockAlbumRepo.getOrCreateAlbumByServerId(10),
      ).thenReturn(cachedAlbum);
      when(mockArtistRepo.getOrCreateArtistByServerId(any)).thenReturn(artist);
      when(mockAlbumRepo.saveAlbum(any)).thenReturn(cachedAlbum);

      final result = service.cacheServerAlbum(dto);

      expect(result, same(cachedAlbum));
      expect(cachedAlbum.name, 'New Album');
      verify(mockAlbumRepo.saveAlbum(cachedAlbum)).called(1);
    });

    test('links artist to album', () {
      final dto = makeExpandedDto(id: 10, artistId: 5, artistName: 'Rock Band');
      final cachedAlbum = makeAlbum(serverId: 10);
      final artist =
          Artist()
            ..id = 99
            ..serverId = 5
            ..name = 'Rock Band';

      when(
        mockAlbumRepo.getOrCreateAlbumByServerId(10),
      ).thenReturn(cachedAlbum);
      when(mockArtistRepo.getOrCreateArtistByServerId(5)).thenReturn(artist);
      when(mockAlbumRepo.saveAlbum(any)).thenReturn(cachedAlbum);

      service.cacheServerAlbum(dto);

      expect(cachedAlbum.artist.targetId, 99);
    });

    test('links songs from songFileHashes', () {
      final dto = makeExpandedDto(id: 10, songFileHashes: ['hash1', 'hash2']);
      final cachedAlbum = makeAlbum(serverId: 10, id: 3);
      final artist = Artist()..id = 1;
      final song1 = Song()..fileHash = 'hash1';
      final song2 = Song()..fileHash = 'hash2';

      when(
        mockAlbumRepo.getOrCreateAlbumByServerId(10),
      ).thenReturn(cachedAlbum);
      when(mockArtistRepo.getOrCreateArtistByServerId(any)).thenReturn(artist);
      when(mockSongRepo.getOrCreateSongByFileHash('hash1')).thenReturn(song1);
      when(mockSongRepo.getOrCreateSongByFileHash('hash2')).thenReturn(song2);
      when(mockAlbumRepo.saveAlbum(any)).thenReturn(cachedAlbum);

      service.cacheServerAlbum(dto);

      verify(mockSongRepo.updateSong(song1)).called(1);
      verify(mockSongRepo.updateSong(song2)).called(1);
      expect(song1.album.targetId, 3);
      expect(song2.album.targetId, 3);
    });

    test('does not overwrite existing imageBytes with null', () {
      final dto = makeExpandedDto(id: 5);
      final existing = makeAlbum(serverId: 5);
      existing.imageBytes = Uint8List.fromList([1, 2, 3]);
      final artist = Artist()..id = 1;

      when(mockAlbumRepo.getOrCreateAlbumByServerId(5)).thenReturn(existing);
      when(mockArtistRepo.getOrCreateArtistByServerId(any)).thenReturn(artist);
      when(mockAlbumRepo.saveAlbum(any)).thenReturn(existing);

      service.cacheServerAlbum(dto);

      expect(existing.imageBytes, isNotNull);
    });
  });

  group('getAlbumsPage', () {
    test('returns server totalPages when server call succeeds', () async {
      final serverDto = makeExpandedDto(id: 3, name: 'Server Album');
      final serverPage = AlbumPageDto(
        content: [serverDto],
        page: 0,
        size: 20,
        totalPages: 3,
        totalElements: 3,
      );
      when(
        mockRestClient.getAlbumsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenAnswer((_) async => serverPage);

      when(
        mockAlbumRepo.getOrCreateAlbumByServerId(any),
      ).thenReturn(makeAlbum());
      when(
        mockArtistRepo.getOrCreateArtistByServerId(any),
      ).thenReturn(Artist()..id = 1);
      when(
        mockAlbumRepo.saveAlbum(any),
      ).thenAnswer((inv) => inv.positionalArguments[0] as Album);

      final local = [makeAlbum(serverId: 3)];
      when(
        mockAlbumRepo.getAlbumsPaged(any, any, any, any, any),
      ).thenReturn(local);

      final result = await service.getAlbumsPage('', 'name', true, 0, 20);

      expect(result.content, equals(local));
      expect(result.totalPages, 3);
    });

    test('falls back to local when server call fails', () async {
      when(
        mockRestClient.getAlbumsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenThrow(Exception('timeout'));

      final local = [makeAlbum(), makeAlbum()];
      when(mockAlbumRepo.getAlbums(any, any, any)).thenReturn(local);
      when(
        mockAlbumRepo.getAlbumsPaged(any, any, any, any, any),
      ).thenReturn(local);

      final result = await service.getAlbumsPage('', 'name', true, 0, 20);

      expect(result.content, equals(local));
      expect(result.totalPages, 1); // ceil(2/20) = 1
    });

    test('returns empty content when offset exceeds total', () async {
      when(
        mockRestClient.getAlbumsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenThrow(Exception('timeout'));

      when(mockAlbumRepo.getAlbums(any, any, any)).thenReturn([makeAlbum()]);
      when(
        mockAlbumRepo.getAlbumsPaged(any, any, any, any, any),
      ).thenReturn([]);

      final result = await service.getAlbumsPage('', 'name', true, 5, 20);

      expect(result.content, isEmpty);
    });
  });

  group('getAllAlbums', () {
    test('delegates to repository', () {
      final albums = [makeAlbum(), makeAlbum()];
      when(mockAlbumRepo.getAllAlbums()).thenReturn(albums);

      expect(service.getAllAlbums(), equals(albums));
    });
  });

  group('getAlbumByServerId', () {
    test('returns album when found', () {
      final album = makeAlbum(serverId: 42);
      when(mockAlbumRepo.getAlbumByServerId(42)).thenReturn(album);

      expect(service.getAlbumByServerId(42), same(album));
    });

    test('returns null when not found', () {
      when(mockAlbumRepo.getAlbumByServerId(any)).thenReturn(null);

      expect(service.getAlbumByServerId(99), isNull);
    });
  });

  group('updateAlbum', () {
    test('delegates to repository', () {
      final album = makeAlbum(id: 3);

      service.updateAlbum(album);

      verify(mockAlbumRepo.updateAlbum(album)).called(1);
    });
  });

  group('getOrCreateAlbum', () {
    test('returns existing album when found by name', () {
      final existing = makeAlbum(id: 1, name: 'Dark Side');
      when(mockAlbumRepo.getAlbumByName('Dark Side')).thenReturn(existing);
      when(mockAlbumRepo.saveAlbum(any)).thenReturn(existing);

      final result = service.getOrCreateAlbum('Dark Side', 10);

      expect(result, same(existing));
    });

    test('sets imageBytes on existing album when it was null', () {
      final existing = makeAlbum(id: 1, name: 'No Cover');
      final image = Uint8List.fromList([1, 2, 3]);
      when(mockAlbumRepo.getAlbumByName('No Cover')).thenReturn(existing);
      when(mockAlbumRepo.saveAlbum(any)).thenReturn(existing);

      service.getOrCreateAlbum('No Cover', 10, image: image);

      expect(existing.imageBytes, equals(image));
      verify(mockAlbumRepo.saveAlbum(existing)).called(1);
    });

    test('does not overwrite existing imageBytes', () {
      final existing = makeAlbum(id: 1, name: 'Has Cover');
      final originalImage = Uint8List.fromList([9, 8, 7]);
      existing.imageBytes = originalImage;
      when(mockAlbumRepo.getAlbumByName('Has Cover')).thenReturn(existing);
      when(mockAlbumRepo.saveAlbum(any)).thenReturn(existing);

      service.getOrCreateAlbum(
        'Has Cover',
        10,
        image: Uint8List.fromList([1, 2, 3]),
      );

      expect(existing.imageBytes, same(originalImage));
    });

    test('creates and saves new album when not found by name', () {
      when(mockAlbumRepo.getAlbumByName(any)).thenReturn(null);
      final saved = makeAlbum(id: 5, name: 'New Album');
      when(mockAlbumRepo.saveAlbum(any)).thenReturn(saved);

      final result = service.getOrCreateAlbum('New Album', 7);

      verify(mockAlbumRepo.saveAlbum(any)).called(1);
      expect(result, same(saved));
    });
  });

  group('getAlbumsPage — server returns 0 totalPages', () {
    test('falls through to local pagination when totalPages == 0', () async {
      final serverPage = AlbumPageDto(
        content: [],
        page: 0,
        size: 20,
        totalPages: 0,
        totalElements: 0,
      );
      when(
        mockRestClient.getAlbumsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenAnswer((_) async => serverPage);

      final local = [makeAlbum(), makeAlbum()];
      when(mockAlbumRepo.getAlbums(any, any, any)).thenReturn(local);
      when(
        mockAlbumRepo.getAlbumsPaged(any, any, any, any, any),
      ).thenReturn(local);

      final result = await service.getAlbumsPage('', 'name', true, 0, 20);

      expect(result.totalPages, 1); // ceil(2/20) clamped to 1
    });
  });
}
