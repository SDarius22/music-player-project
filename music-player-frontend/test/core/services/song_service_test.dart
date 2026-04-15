import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/dtos/albums/album_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';
import 'package:music_player_frontend/core/dtos/sync/sync_response_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
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
  MockSpec<AuthService>(),
])
void main() {
  late MockSongRepository mockSongRepo;
  late MockArtistRepository mockArtistRepo;
  late MockAlbumRepository mockAlbumRepo;
  late MockSongRestClient mockSongRestClient;
  late MockDataSyncClient mockDataSyncClient;
  late MockAuthService mockAuthService;
  late SongService service;

  SongDto makeSongDto({String fileHash = 'song-hash'}) {
    return SongDto(
      fileHash: fileHash,
      name: 'Track',
      durationInSeconds: 123,
      trackNumber: 1,
      discNumber: 1,
      releaseYear: 2024,
      artist: ArtistDto(hash: 'artist-h', name: 'Artist'),
      album: AlbumDto(hash: 'album-h', name: 'Album'),
    );
  }

  setUp(() {
    mockSongRepo = MockSongRepository();
    mockArtistRepo = MockArtistRepository();
    mockAlbumRepo = MockAlbumRepository();
    mockSongRestClient = MockSongRestClient();
    mockDataSyncClient = MockDataSyncClient();
    mockAuthService = MockAuthService();

    when(mockSongRestClient.authService).thenReturn(mockAuthService);
    when(mockSongRepo.watchSongs()).thenAnswer((_) => const Stream.empty());
    when(mockSongRepo.getSongs(any, any, any)).thenReturn(const []);
    when(
      mockSongRepo.getSongsPaged(any, any, any, any, any),
    ).thenReturn(const []);

    service = SongService(
      mockSongRepo,
      mockArtistRepo,
      mockAlbumRepo,
      mockSongRestClient,
      mockDataSyncClient,
    );
  });

  group('getLocalSong', () {
    test('validates empty hash', () {
      expect(() => service.getLocalSong(''), throwsArgumentError);
    });

    test('returns null when repository throws', () {
      when(
        mockSongRepo.getSongByFileHash('broken'),
      ).thenThrow(Exception('boom'));
      expect(service.getLocalSong('broken'), isNull);
    });
  });

  group('fetchSongByFileHash', () {
    test('returns local song when present', () async {
      final local = Song('song-hash');
      when(mockSongRepo.getSongByFileHash('song-hash')).thenReturn(local);

      final result = await service.fetchSongByFileHash('song-hash');

      expect(result, same(local));
      verifyNever(mockSongRestClient.getServerSong(any));
    });

    test('fetches and caches song when local miss', () async {
      final cachedSong = Song('song-hash')..id = 11;
      final artist = Artist('artist-h', 'Artist')..id = 22;
      final album = Album('album-h', 'Album')..id = 33;
      final callCount = <String, int>{'lookup': 0};

      when(mockSongRepo.getSongByFileHash('song-hash')).thenAnswer((_) {
        final c = callCount['lookup']!;
        callCount['lookup'] = c + 1;
        return c == 0 ? null : cachedSong;
      });
      when(
        mockSongRestClient.getServerSong('song-hash'),
      ).thenAnswer((_) async => makeSongDto());
      when(mockSongRepo.getOrCreateSong('song-hash')).thenReturn(cachedSong);
      when(
        mockArtistRepo.getOrCreateArtist('artist-h', 'Artist'),
      ).thenReturn(artist);
      when(
        mockAlbumRepo.getOrCreateAlbum('album-h', 'Album', artist),
      ).thenReturn(album);
      when(mockSongRepo.saveSong(cachedSong)).thenReturn(cachedSong);

      final result = await service.fetchSongByFileHash('song-hash');

      expect(result, same(cachedSong));
      verify(mockSongRepo.saveSong(cachedSong)).called(1);
      verify(mockArtistRepo.updateArtist(artist)).called(1);
      verify(mockAlbumRepo.updateAlbum(album)).called(1);
    });
  });

  group('getSongsPage', () {
    test('uses mapped sort field when fetching from server', () async {
      final cachedSong = Song('song-hash')..id = 1;
      final artist = Artist('artist-h', 'Artist')..id = 2;
      final album = Album('album-h', 'Album')..id = 3;

      when(
        mockSongRestClient.getSongsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenAnswer(
        (_) async => SongPageDto(
          content: [makeSongDto()],
          page: 0,
          size: 20,
          totalPages: 2,
          totalElements: 1,
        ),
      );
      when(mockSongRepo.getOrCreateSong('song-hash')).thenReturn(cachedSong);
      when(
        mockArtistRepo.getOrCreateArtist('artist-h', 'Artist'),
      ).thenReturn(artist);
      when(
        mockAlbumRepo.getOrCreateAlbum('album-h', 'Album', artist),
      ).thenReturn(album);
      when(mockSongRepo.saveSong(cachedSong)).thenReturn(cachedSong);
      when(
        mockSongRepo.getSongsPaged(any, any, any, any, any),
      ).thenReturn([cachedSong]);

      final result = await service.getSongsPage('', 'duration', true, 0, 20);

      expect(result.totalPages, 2);
      expect(result.content.single.getHash(), 'song-hash');
      verify(
        mockSongRestClient.getSongsPage(
          query: '',
          page: 0,
          size: 20,
          sort: 'durationInSeconds,asc',
        ),
      ).called(1);
    });

    test('falls back to local pages when server fails', () async {
      final local = [Song('local-1'), Song('local-2')];
      when(
        mockSongRestClient.getSongsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenThrow(Exception('offline'));
      when(
        mockSongRepo.getSongsPaged(any, any, any, any, any),
      ).thenReturn(local);
      when(mockSongRepo.getSongs(any, any, any)).thenReturn(local);

      final result = await service.getSongsPage('', 'name', true, 0, 20);

      expect(result.content, equals(local));
      expect(result.totalPages, 1);
    });
  });

  group('recommendation endpoints', () {
    test('getRecommendations caches and returns songs', () async {
      final cachedSong = Song('song-hash')..id = 1;
      final artist = Artist('artist-h', 'Artist')..id = 2;
      final album = Album('album-h', 'Album')..id = 3;

      when(mockSongRestClient.getRecommendations()).thenAnswer(
        (_) async => SongPageDto(
          content: [makeSongDto()],
          page: 0,
          size: 1,
          totalPages: 1,
          totalElements: 1,
        ),
      );
      when(mockSongRepo.getOrCreateSong('song-hash')).thenReturn(cachedSong);
      when(
        mockArtistRepo.getOrCreateArtist('artist-h', 'Artist'),
      ).thenReturn(artist);
      when(
        mockAlbumRepo.getOrCreateAlbum('album-h', 'Album', artist),
      ).thenReturn(album);
      when(mockSongRepo.saveSong(cachedSong)).thenReturn(cachedSong);

      final result = await service.getRecommendations();

      expect(result.single.getHash(), 'song-hash');
      verify(mockSongRestClient.getRecommendations()).called(1);
    });
  });

  group('syncLibraryMetadata', () {
    test('returns early when user is not logged in', () async {
      when(mockAuthService.isLoggedIn).thenReturn(false);

      await service.syncLibraryMetadata();

      verifyNever(
        mockDataSyncClient.syncUserLibrary(
          lastSyncTime: anyNamed('lastSyncTime'),
          localChanges: anyNamed('localChanges'),
        ),
      );
    });

    test('syncs pending songs and clears pending counters', () async {
      final pendingSong =
          Song('sync-hash')
            ..requiresSync = true
            ..pendingPlayCountDelta = 3
            ..pendingPlayDurationSeconds = 120
            ..likedByUser = true
            ..lastPlayed = DateTime(2026, 1, 1);

      when(mockAuthService.isLoggedIn).thenReturn(true);
      when(mockSongRepo.getAllSongs()).thenReturn([pendingSong]);
      when(
        mockDataSyncClient.syncUserLibrary(
          lastSyncTime: anyNamed('lastSyncTime'),
          localChanges: anyNamed('localChanges'),
        ),
      ).thenAnswer(
        (_) async => SyncResponseDto.fromJson({
          'newSyncTime': '2026-04-01T00:00:00Z',
          'serverChanges': [],
        }),
      );

      await service.syncLibraryMetadata();

      expect(pendingSong.requiresSync, isFalse);
      expect(pendingSong.pendingPlayCountDelta, 0);
      expect(pendingSong.pendingPlayDurationSeconds, 0);
      verify(mockSongRepo.updateSong(pendingSong)).called(1);
    });
  });
}
