import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/albums/album_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_local_track_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_album_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_artist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/song_rest_client.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/core/services/potential_identity.dart';

class FakeSongRestClient extends SongRestClient {
  FakeSongRestClient()
    : super(
        baseUrl: 'http://localhost',
        authService: AuthService(baseUrl: 'http://localhost'),
      );

  final Map<String, SongDto> byHash = {};
  SongPageDto songsPage = SongPageDto(
    content: const [],
    page: 0,
    size: 50,
    totalPages: 0,
    totalElements: 0,
  );
  SongPageDto favouritesPage = SongPageDto(
    content: const [],
    page: 0,
    size: 50,
    totalPages: 0,
    totalElements: 0,
  );
  SongPageDto mostPlayedPage = SongPageDto(
    content: const [],
    page: 0,
    size: 50,
    totalPages: 0,
    totalElements: 0,
  );
  SongPageDto recentlyPlayedPage = SongPageDto(
    content: const [],
    page: 0,
    size: 50,
    totalPages: 0,
    totalElements: 0,
  );
  SongPageDto recommendationsPage = SongPageDto(
    content: const [],
    page: 0,
    size: 50,
    totalPages: 0,
    totalElements: 0,
  );
  SongPageDto forgottenPage = SongPageDto(
    content: const [],
    page: 0,
    size: 50,
    totalPages: 0,
    totalElements: 0,
  );
  SongPageDto quickDialPage = SongPageDto(
    content: const [],
    page: 0,
    size: 50,
    totalPages: 0,
    totalElements: 0,
  );
  bool throwOnLists = false;
  bool throwOnUpdate = false;

  @override
  Future<SongDto> getServerSong(String fileHash) async {
    final dto = byHash[fileHash];
    if (dto == null) throw Exception('not found');
    return dto;
  }

  @override
  Future<SongPageDto> getSongsPage({
    String? query,
    String? filterAlbumHash,
    String? filterArtistHash,
    int? filterPlaylistId,
    int page = 0,
    int size = 50,
    String sort = 'name,asc',
  }) async {
    return songsPage;
  }

  @override
  Future<SongPageDto> getFavourites({int page = 0, int size = 250}) async {
    if (throwOnLists) throw Exception('offline');
    return favouritesPage;
  }

  @override
  Future<SongPageDto> getMostPlayed({int page = 0, int size = 50}) async {
    if (throwOnLists) throw Exception('offline');
    return mostPlayedPage;
  }

  @override
  Future<SongPageDto> getRecentlyPlayed({int page = 0, int size = 50}) async {
    if (throwOnLists) throw Exception('offline');
    return recentlyPlayedPage;
  }

  @override
  Future<SongPageDto> getRecommendations({int page = 0, int size = 50}) async =>
      recommendationsPage;

  @override
  Future<SongPageDto> getForgottenFavourites({
    int page = 0,
    int size = 50,
  }) async => forgottenPage;

  @override
  Future<SongPageDto> getQuickDial({int page = 0, int size = 50}) async =>
      quickDialPage;

  @override
  Future<SongDto?> updateSongLibraryEntry(
    String songFileHash,
    bool likedByUser,
    DateTime? lastPlayed,
    int playCount,
  ) async {
    if (throwOnUpdate) {
      throw Exception('update failed');
    }
    return byHash[songFileHash];
  }
}

SongDto buildSongDto(String hash) {
  return SongDto(
    fileHash: hash,
    name: 'Track $hash',
    durationInSeconds: 120,
    trackNumber: 1,
    discNumber: 1,
    year: 2024,
    artist: ArtistDto(hash: 'artist-$hash', name: 'Artist'),
    album: AlbumDto(hash: 'album-$hash', name: 'Album'),
    playCount: 0,
    likedByUser: false,
  );
}

void main() {
  group('SongService', () {
    late InMemorySongRepository songRepo;
    late InMemoryArtistRepository artistRepo;
    late InMemoryAlbumRepository albumRepo;
    late FakeSongRestClient restClient;
    late SongService service;

    setUp(() {
      songRepo = InMemorySongRepository();
      artistRepo = InMemoryArtistRepository();
      albumRepo = InMemoryAlbumRepository();
      restClient = FakeSongRestClient();
      service = SongService(songRepo, artistRepo, albumRepo, restClient);
    });

    test('getLocalSong throws on empty hash', () {
      expect(() => service.getLocalSong(''), throwsArgumentError);
    });

    test('fetchSongByFileHash returns local song when present', () async {
      final local =
          Song('local-hash')
            ..name = 'Local'
            ..fullyLoaded = true;
      songRepo.saveSong(local);

      final result = await service.fetchSongByFileHash('local-hash');

      expect(result, same(local));
    });

    test('fetchSongByFileHash caches server response on local miss', () async {
      restClient.byHash['remote-hash'] = buildSongDto('remote-hash');

      final result = await service.fetchSongByFileHash('remote-hash');

      expect(result, isNotNull);
      expect(result!.getHash(), 'remote-hash');
      expect(result.fullyLoaded, isTrue);
      expect(result.artist.target?.name, 'Artist');
      expect(result.album.target?.name, 'Album');
    });

    test('getSongsPage returns local results when localOnly is true', () async {
      final local =
          Song('h1')
            ..name = 'Track'
            ..path = '/music/track.flac'
            ..fullyLoaded = true;
      songRepo.saveSong(local);

      final page = await service.getSongsPage(
        '',
        'Title',
        null,
        null,
        null,
        true,
        true,
        0,
        20,
      );

      expect(page.content, hasLength(1));
      expect(page.content.first.getHash(), 'h1');
      expect(page.totalPages, 1);
    });

    test(
      'offline and stream filters intersect after identity merging',
      () async {
        final localRepository = InMemoryLocalTrackRepository();
        final localTracks = LocalTrackService(localRepository);
        final identity = PotentialIdentity.create(
          title: 'Shared Track',
          artist: 'Artist',
          durationInSeconds: 120,
        );
        localRepository.save(
          LocalTrack(
            sourceKey: '/music/shared.flac',
            sourceUri: '/music/shared.flac',
            potentialIdentityKey: identity,
            name: 'Shared Track',
            artistName: 'Artist',
            durationInSeconds: 120,
            metadataLoaded: true,
          ),
        );
        restClient.songsPage = SongPageDto(
          content: [
            SongDto(
              fileHash: 'remote-shared',
              name: 'Shared Track',
              durationInSeconds: 120,
              trackNumber: 1,
              discNumber: 1,
              year: 2024,
              artist: ArtistDto(hash: 'artist', name: 'Artist'),
              album: AlbumDto(hash: 'album', name: 'Album'),
              playCount: 0,
              likedByUser: false,
            ),
          ],
          page: 0,
          size: 20,
          totalPages: 1,
          totalElements: 1,
        );
        final unifiedService = SongService(
          songRepo,
          artistRepo,
          albumRepo,
          restClient,
          localTracks,
        );

        final both = await unifiedService.getSongsPage(
          '',
          'Title',
          null,
          null,
          null,
          true,
          true,
          0,
          20,
          streamOnly: true,
        );

        expect(both.content, hasLength(1));
        expect(both.content.single.hasLocalFile, isTrue);
        expect(both.content.single.isAvailableToStream, isTrue);
        expect(both.content.single.potentialRemoteHashes, ['remote-shared']);
        expect(
          localRepository
              .getBySourceKey('/music/shared.flac')
              ?.resolvedSongHash,
          'remote-shared',
        );
      },
    );

    test('fullyFetchSong restores a matching local playback source', () async {
      final localRepository = InMemoryLocalTrackRepository();
      final localTracks = LocalTrackService(localRepository);
      localRepository.save(
        LocalTrack(
          sourceKey: '/music/local.flac',
          sourceUri: '/music/local.flac',
          potentialIdentityKey: PotentialIdentity.create(
            title: 'Track',
            artist: 'Artist',
            durationInSeconds: 120,
          ),
          name: 'Track',
          artistName: 'Artist',
          durationInSeconds: 120,
          metadataLoaded: true,
        )..resolvedSongHash = 'remote-hash',
      );
      final localAwareService = SongService(
        songRepo,
        artistRepo,
        albumRepo,
        restClient,
        localTracks,
      );
      final queued =
          Song('remote-hash')
            ..name = 'Track'
            ..durationInSeconds = 120;

      final resolved = await localAwareService.fullyFetchSong(queued);

      expect(resolved.path, '/music/local.flac');
      expect(resolved.hasLocalFile, isTrue);
      expect(resolved.potentialRemoteHashes, contains('remote-hash'));
    });

    test('getOrCreateSong throws on empty hash', () {
      expect(() => service.getOrCreateSong(''), throwsArgumentError);
    });

    test('chunk manifest round-trips through the persisted song', () {
      final manifest = ChunkManifestDto.fromJson({
        'fileHash': 'manifest-song',
        'totalChunks': 2,
        'chunkSize': 4,
        'totalBytes': 8,
        'hashes': ['0' * 64, '1' * 64],
      });

      service.cacheManifest(manifest);
      service.updateCacheAvailability('manifest-song', 2, 2);

      final restored = service.getCachedManifest('manifest-song');
      final song = service.getLocalSong('manifest-song')!;
      expect(restored?.toJson(), manifest.toJson());
      expect(song.expectedChunkCount, 2);
      expect(song.isFullyCached, isTrue);
      expect(song.isPlayableOffline, isTrue);
    });

    test('successful scan reconciliation detaches missing local files', () {
      final present =
          Song('present')
            ..path = '/music/present.flac'
            ..localFileSize = 10;
      final missing =
          Song('missing')
            ..path = '/music/missing.flac'
            ..localFileSize = 20;
      songRepo.saveSongs([present, missing]);

      service.reconcileMissingLocalFiles({'/music/present.flac'});

      expect(service.getLocalSong('present')?.hasLocalFile, isTrue);
      expect(service.getLocalSong('missing')?.hasLocalFile, isFalse);
    });

    test('exposes repository metadata, stream, and basic mutations', () async {
      expect(service.sortFields, isNotEmpty);
      expect(service.watchSongs, isA<Stream<dynamic>>());
      final song = service.getOrCreateSong('created');
      service.updateSongsBatch([song..name = 'Updated']);
      expect(service.getLocalSong('created')?.name, 'Updated');
      service.deleteSong(song);
      expect(service.getLocalSong('created'), isNull);
    });

    test(
      'fullyFetchSong returns same song when already fully loaded',
      () async {
        final song = Song('loaded')..fullyLoaded = true;

        final result = await service.fullyFetchSong(song);

        expect(result, same(song));
      },
    );

    test('fullyFetchSong prefers fully loaded local cached version', () async {
      final local =
          Song('cached')
            ..name = 'Cached'
            ..fullyLoaded = true;
      songRepo.saveSong(local);

      final result = await service.fullyFetchSong(Song('cached'));

      expect(result, same(local));
    });

    test('fullyFetchSong returns input song when server fetch fails', () async {
      final partial = Song('missing');

      final result = await service.fullyFetchSong(partial);

      expect(result, same(partial));
    });

    test('fullyFetchSongs downloads and caches every partial song', () async {
      restClient.byHash['one'] = buildSongDto('one');
      restClient.byHash['two'] = buildSongDto('two');
      final result = await service.fullyFetchSongs([Song('one'), Song('two')]);
      expect(result.map((song) => song.getHash()), ['one', 'two']);
      expect(result.every((song) => song.fullyLoaded), isTrue);
    });

    test(
      'server page is cached and its total page count is retained',
      () async {
        restClient.songsPage = SongPageDto(
          content: [buildSongDto('paged')],
          page: 1,
          size: 1,
          totalPages: 4,
          totalElements: 4,
        );
        final page = await service.getSongsPage(
          'Track',
          'duration',
          null,
          null,
          null,
          false,
          false,
          1,
          1,
        );
        expect(page.totalPages, 4);
        expect(songRepo.getSongByFileHash('paged'), isNotNull);
      },
    );

    test('recommendation collections are cached', () async {
      SongPageDto page(String hash) => SongPageDto(
        content: [buildSongDto(hash)],
        page: 0,
        size: 1,
        totalPages: 1,
        totalElements: 1,
      );
      restClient.recommendationsPage = page('recommendation');
      restClient.forgottenPage = page('forgotten');
      restClient.quickDialPage = page('quick');
      expect(
        (await service.getRecommendations(0, 1)).content.single.getHash(),
        'recommendation',
      );
      expect(
        (await service.getForgottenFavourites()).single.getHash(),
        'forgotten',
      );
      expect((await service.getQuickDial()).single.getHash(), 'quick');
    });

    test('invalid server songs are rejected', () {
      expect(
        () => service.cacheServerSongs([buildSongDto('')]),
        throwsException,
      );
    });

    test(
      'updateSong still persists local update when server update fails',
      () async {
        final song =
            Song('h1')
              ..likedByUser = true
              ..playCount = 5;
        restClient.throwOnUpdate = true;

        await service.updateSong(song);

        expect(songRepo.getSongByFileHash('h1')?.likedByUser, isTrue);
        expect(songRepo.getSongByFileHash('h1')?.playCount, 5);
      },
    );

    test(
      'getFavoriteSongs falls back to server when local list is empty',
      () async {
        restClient.favouritesPage = SongPageDto(
          content: [buildSongDto('fav-1')],
          page: 0,
          size: 10,
          totalPages: 1,
          totalElements: 1,
        );

        final result = await service.getFavoriteSongs();

        expect(result, hasLength(1));
        expect(result.single.getHash(), 'fav-1');
      },
    );

    test('getMostPlayedSongs prefers local values over server', () async {
      final local = Song('local-most')..playCount = 99;
      songRepo.saveSong(local);
      restClient.mostPlayedPage = SongPageDto(
        content: [buildSongDto('remote-most')],
        page: 0,
        size: 1,
        totalPages: 1,
        totalElements: 1,
      );

      final result = await service.getMostPlayedSongs(1);

      expect(result.single.getHash(), 'local-most');
    });

    test(
      'getRecentlyPlayedSongs falls back to server when local list is empty',
      () async {
        restClient.recentlyPlayedPage = SongPageDto(
          content: [buildSongDto('recent-1')],
          page: 0,
          size: 1,
          totalPages: 1,
          totalElements: 1,
        );

        final result = await service.getRecentlyPlayedSongs(1);

        expect(result.single.getHash(), 'recent-1');
      },
    );

    test('empty recommendation fallbacks survive server failures', () async {
      restClient.throwOnLists = true;
      expect(await service.getFavoriteSongs(), isEmpty);
      expect(await service.getMostPlayedSongs(2), isEmpty);
      expect(await service.getRecentlyPlayedSongs(2), isEmpty);
    });
  });
}
