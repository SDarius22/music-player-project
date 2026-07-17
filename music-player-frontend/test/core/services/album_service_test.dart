import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/dtos/albums/album_expanded_dto.dart';
import 'package:music_player_frontend/core/dtos/albums/album_page_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';
import 'package:music_player_frontend/core/dtos/albums/album_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';
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

  group('getOrCreateAlbum', () {
    test(
      'derives album hash from artist + name and delegates to repository',
      () {
        final artist = Artist('artist-hash', 'Artist Name');
        final expectedHash =
            sha256.convert(utf8.encode('Artist Name - Album Name')).toString();
        final cached = Album(expectedHash, 'Album Name');

        when(
          mockAlbumRepo.getOrCreateAlbum(expectedHash, 'Album Name', artist),
        ).thenReturn(cached);

        final result = service.getOrCreateAlbum('Album Name', artist);

        expect(result, same(cached));
        verify(
          mockAlbumRepo.getOrCreateAlbum(expectedHash, 'Album Name', artist),
        ).called(1);
      },
    );
  });

  group('cacheServerAlbum', () {
    test('links artist and songs, then saves album', () {
      final dto = AlbumExpandedDto(
        hash: 'album-hash',
        name: 'Album',
        songFileHashes: ['s1', 's2'],
        artist: ArtistDto(hash: 'artist-hash', name: 'Artist'),
        durationInSeconds: 2,
      );
      final cachedArtist = Artist('artist-hash', 'Artist')..id = 10;
      final cachedAlbum = Album('album-hash', 'Album')..id = 20;
      final song1 = Song('s1');
      final song2 = Song('s2');

      when(
        mockArtistRepo.getOrCreateArtist('artist-hash', 'Artist'),
      ).thenReturn(cachedArtist);
      when(
        mockAlbumRepo.getOrCreateAlbum('album-hash', 'Album', cachedArtist),
      ).thenReturn(cachedAlbum);
      when(mockSongRepo.getOrCreateSong('s1')).thenReturn(song1);
      when(mockSongRepo.getOrCreateSong('s2')).thenReturn(song2);
      when(mockAlbumRepo.saveAlbum(cachedAlbum)).thenReturn(cachedAlbum);

      final result = service.cacheServerAlbum(dto);

      expect(result, same(cachedAlbum));
      expect(song1.album.targetId, 20);
      expect(song2.album.targetId, 20);
      expect(song1.artist.targetId, 10);
      expect(song2.artist.targetId, 10);
      verify(mockSongRepo.updateSong(song1)).called(1);
      verify(mockSongRepo.updateSong(song2)).called(1);
      verify(mockArtistRepo.updateArtist(cachedArtist)).called(1);
      verify(mockAlbumRepo.saveAlbum(cachedAlbum)).called(1);
    });
  });

  group('getAlbumsPage', () {
    test('returns server totalPages when server call succeeds', () async {
      final serverPage = AlbumPageDto(
        content: [
          AlbumExpandedDto(
            hash: 'album-hash',
            name: 'Album',
            songFileHashes: const [],
            artist: ArtistDto(hash: 'artist-hash', name: 'Artist'),
            durationInSeconds: 0,
          ),
        ],
        page: 0,
        size: 20,
        totalPages: 3,
        totalElements: 1,
      );
      final local = [Album('album-hash', 'Album')];
      final cachedArtist = Artist('artist-hash', 'Artist');

      when(
        mockRestClient.getAlbumsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenAnswer((_) async => serverPage);
      when(
        mockArtistRepo.getOrCreateArtist('artist-hash', 'Artist'),
      ).thenReturn(cachedArtist);
      when(
        mockAlbumRepo.getOrCreateAlbum('album-hash', 'Album', cachedArtist),
      ).thenReturn(local.first);
      when(
        mockAlbumRepo.saveAlbum(any),
      ).thenAnswer((inv) => inv.positionalArguments.first as Album);
      when(
        mockAlbumRepo.getAlbumsPaged(any, any, any, any, any, any),
      ).thenReturn(local);

      final result = await service.getAlbumsPage(
        '',
        'name',
        true,
        false,
        0,
        20,
      );

      expect(result.content, equals(local));
      expect(result.totalPages, 3);
    });

    test('falls back to local paging when server fetch fails', () async {
      final local = [Album('a1', 'A1'), Album('a2', 'A2')];

      when(
        mockRestClient.getAlbumsPage(
          query: anyNamed('query'),
          page: anyNamed('page'),
          size: anyNamed('size'),
          sort: anyNamed('sort'),
        ),
      ).thenThrow(Exception('timeout'));
      when(
        mockAlbumRepo.getAlbumsPaged(any, any, any, any, any, any),
      ).thenReturn(local);
      when(mockAlbumRepo.getAlbumCount(any, any)).thenReturn(local.length);

      final result = await service.getAlbumsPage(
        '',
        'name',
        true,
        false,
        0,
        20,
      );

      expect(result.content, equals(local));
      expect(result.totalPages, 1);
    });
  });

  group('fetchAlbumDetails', () {
    test('caches and returns server album details', () async {
      final artistDto = ArtistDto(hash: 'artist', name: 'Artist');
      final dto = AlbumExpandedDto(
        hash: 'album',
        name: 'Remote',
        songFileHashes: const [],
        artist: artistDto,
        durationInSeconds: 0,
      );
      final artist = Artist('artist', 'Artist');
      final album = Album('album', 'Remote');
      when(mockRestClient.getAlbumByHash('album')).thenAnswer((_) async => dto);
      when(
        mockArtistRepo.getOrCreateArtist('artist', 'Artist'),
      ).thenReturn(artist);
      when(
        mockAlbumRepo.getOrCreateAlbum('album', 'Remote', artist),
      ).thenReturn(album);
      when(mockAlbumRepo.saveAlbum(album)).thenReturn(album);
      expect(await service.fetchAlbumDetails('album'), same(album));
    });

    test('returns local album when server fetch throws', () async {
      final local = Album('album-hash', 'Local Album');
      when(mockRestClient.getAlbumByHash('album-hash')).thenThrow(Exception());
      when(mockAlbumRepo.getAlbumByHash('album-hash')).thenReturn(local);

      final result = await service.fetchAlbumDetails('album-hash');

      expect(result, same(local));
      verify(mockAlbumRepo.getAlbumByHash('album-hash')).called(1);
    });
  });

  group('updateAlbum', () {
    test('delegates to repository', () {
      final album = Album('album-hash', 'Album');

      service.updateAlbum(album);

      verify(mockAlbumRepo.updateAlbum(album)).called(1);
    });
  });

  group('getAlbumSongsPage', () {
    test('caches server songs and uses server total pages', () async {
      final artistDto = ArtistDto(hash: 'artist', name: 'Artist');
      final albumDto = AlbumDto(hash: 'album', name: 'Album');
      final dto = SongDto(
        fileHash: 'song',
        name: 'Track',
        durationInSeconds: 10,
        trackNumber: 1,
        discNumber: 1,
        year: 2025,
        artist: artistDto,
        album: albumDto,
        playCount: 2,
        likedByUser: true,
      );
      final song = Song('song');
      final artist = Artist('artist', 'Artist');
      final album = Album('album', 'Album');
      when(
        mockRestClient.getAlbumSongsPage(albumHash: 'album', page: 0, size: 10),
      ).thenAnswer(
        (_) async => SongPageDto(
          content: [dto],
          page: 0,
          size: 10,
          totalPages: 4,
          totalElements: 1,
        ),
      );
      when(mockSongRepo.getOrCreateSong('song')).thenReturn(song);
      when(
        mockArtistRepo.getOrCreateArtist('artist', 'Artist'),
      ).thenReturn(artist);
      when(
        mockAlbumRepo.getOrCreateAlbum('album', 'Album', artist),
      ).thenReturn(album);
      when(mockSongRepo.saveSong(song)).thenReturn(song);
      when(mockSongRepo.saveSongs(any)).thenAnswer(
        (invocation) => invocation.positionalArguments.first as List<Song>,
      );
      when(
        mockSongRepo.getAlbumSongsPaged('album', false, 0, 10),
      ).thenReturn([song]);

      final result = await service.getAlbumSongsPage('album', size: 10);
      expect(result.content, [song]);
      expect(result.totalPages, 4);
      expect(song.fullyLoaded, isTrue);
      expect(song.album.target, album);
    });

    test('local-only paging calculates local total pages', () async {
      final song = Song('local')..fullyLoaded = true;
      when(
        mockSongRepo.getAlbumSongsPaged('album', true, 0, 2),
      ).thenReturn([song]);
      when(mockSongRepo.getAlbumSongCount('album', true)).thenReturn(3);
      final result = await service.getAlbumSongsPage(
        'album',
        localOnly: true,
        size: 2,
      );
      expect(result.content, [song]);
      expect(result.totalPages, 2);
    });
  });
}
