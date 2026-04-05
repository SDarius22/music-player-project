import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/dtos/albums/album_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/data_sync_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/song_rest_client.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

import 'song_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<SongRepository>(),
  MockSpec<ArtistRepository>(),
  MockSpec<AlbumRepository>(),
  MockSpec<SongRestClient>(),
  MockSpec<DataSyncClient>(),
])
void main() {
  late MockSongRepository mockRepo;
  late MockArtistRepository mockArtistRepo;
  late MockAlbumRepository mockAlbumRepo;
  late MockSongRestClient mockRestClient;
  late MockDataSyncClient mockDataSyncClient;
  late SongService service;

  Song makeSong({String fileHash = '', String name = 'Song', int id = 0}) {
    final s = Song();
    s.id = id;
    s.fileHash = fileHash;
    s.name = name;
    return s;
  }

  Artist makeArtist({int id = 1}) {
    final a = Artist();
    a.id = id;
    return a;
  }

  Album makeAlbum({int id = 1}) {
    final a = Album();
    a.id = id;
    return a;
  }

  setUp(() {
    mockRepo = MockSongRepository();
    mockArtistRepo = MockArtistRepository();
    mockAlbumRepo = MockAlbumRepository();
    mockRestClient = MockSongRestClient();
    mockDataSyncClient = MockDataSyncClient();
    service = SongService(
      mockRepo,
      mockArtistRepo,
      mockAlbumRepo,
      mockRestClient,
      mockDataSyncClient,
    );
  });

  group('getSongCount', () {
    test('returns count from repository', () {
      when(mockRepo.getSongCount()).thenReturn(15);

      expect(service.getSongCount(), 15);
    });
  });

  group('addSongEntity', () {
    test('saves song through repository and returns it', () {
      final song = makeSong(fileHash: 'hash_add');
      when(mockRepo.saveSong(song)).thenReturn(song);

      final result = service.addSongEntity(song);

      expect(result, same(song));
      verify(mockRepo.saveSong(song)).called(1);
    });
  });

  group('fetchSongByFileHash', () {
    test('returns local song when found without server call', () async {
      final song = makeSong(fileHash: 'hash42');
      when(mockRepo.getSongByFileHash('hash42')).thenReturn(song);

      final result = await service.fetchSongByFileHash('hash42');

      expect(result, same(song));
      verifyNever(mockRestClient.getServerSong(any));
    });

    test('fetches from server when not in local cache', () async {
      final cachedSong = makeSong(fileHash: 'hash7');
      final serverDto = SongDto(
        fileHash: 'hash7',
        name: 'Song',
        durationInSeconds: 0,
        trackNumber: 0,
        discNumber: 0,
        releaseYear: 0,
        artist: ArtistDto(id: 0, name: ''),
        album: AlbumDto(id: 0, name: ''),
      );
      when(
        mockRestClient.getServerSong('hash7'),
      ).thenAnswer((_) async => serverDto);
      when(mockRepo.saveSong(any)).thenReturn(cachedSong);
      when(mockArtistRepo.getOrCreateArtistByServerId(any)).thenReturn(makeArtist());
      when(mockAlbumRepo.getOrCreateAlbumByServerId(any)).thenReturn(makeAlbum());

      var callCount = 0;
      when(mockRepo.getSongByFileHash('hash7')).thenAnswer((_) {
        callCount++;
        return callCount > 1 ? cachedSong : null;
      });
      when(
        mockRepo.getOrCreateSongByFileHash('hash7'),
      ).thenReturn(cachedSong);

      final result = await service.fetchSongByFileHash('hash7');

      expect(result, same(cachedSong));
    });

    test('returns null when server fetch throws', () async {
      when(mockRepo.getSongByFileHash(any)).thenReturn(null);
      when(
        mockRestClient.getServerSong(any),
      ).thenThrow(Exception('server down'));

      final result = await service.fetchSongByFileHash('hash3');

      expect(result, isNull);
    });
  });

  group('updateSong', () {
    test('delegates to repository', () {
      final song = makeSong(fileHash: 'hash_upd');

      service.updateSong(song);

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

  group('deleteSong', () {
    test('delegates to repository', () {
      final song = makeSong(fileHash: 'hash_del');

      service.deleteSong(song);

      verify(mockRepo.deleteSong(song)).called(1);
    });
  });

  group('getSongsPage', () {
    test('returns local page data after server caches results', () async {
      final serverSong = makeSong(fileHash: 'hash5', name: 'Server Song');
      final serverSongDto = SongDto(
        fileHash: 'hash5',
        name: 'Server Song',
        durationInSeconds: 0,
        trackNumber: 0,
        discNumber: 0,
        releaseYear: 0,
        artist: ArtistDto(id: 0, name: ''),
        album: AlbumDto(id: 0, name: ''),
      );
      final serverPage = SongPageDto(
        content: [serverSongDto],
        page: 0,
        size: 20,
        totalPages: 1,
        totalElements: 1,
      );
      when(
        mockRestClient.getSongsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenAnswer((_) async => serverPage);

      when(mockRepo.getOrCreateSongByFileHash(any)).thenReturn(serverSong);
      when(
        mockRepo.saveSong(any),
      ).thenAnswer((inv) => inv.positionalArguments[0] as Song);
      when(mockArtistRepo.getOrCreateArtistByServerId(any)).thenReturn(makeArtist());
      when(mockAlbumRepo.getOrCreateAlbumByServerId(any)).thenReturn(makeAlbum());

      final local = [makeSong(fileHash: 'hash5')];
      when(mockRepo.getSongsPaged(any, any, any, any, any)).thenReturn(local);

      final result = await service.getSongsPage('', 'name', true, 0, 20);

      expect(result.content, equals(local));
      expect(result.totalPages, 1);
    });

    test('falls back to local pagination when server fails', () async {
      when(
        mockRestClient.getSongsPage(
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
      expect(result.totalPages, 1); // ceil(2/20) = 1
    });
  });

  group('getSongsPage — server 0 totalElements', () {
    test('falls through to local pagination', () async {
      final serverPage = SongPageDto(
        content: [],
        page: 0,
        size: 20,
        totalPages: 0,
        totalElements: 0,
      );
      when(
        mockRestClient.getSongsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenAnswer((_) async => serverPage);
      when(
        mockRepo.getSongs(any, any, any),
      ).thenReturn([makeSong(), makeSong()]);
      when(
        mockRepo.getSongsPaged(any, any, any, any, any),
      ).thenReturn([makeSong()]);

      final result = await service.getSongsPage('', 'title', true, 0, 20);

      expect(result.totalPages, 1); // ceil(2/20) = 1
    });
  });
}
