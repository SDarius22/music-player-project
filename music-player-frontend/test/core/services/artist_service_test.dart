import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_expanded_dto.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_album_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_artist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/artist_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';

void main() {
  group('ArtistService', () {
    late InMemoryArtistRepository artistRepo;
    late InMemorySongRepository songRepo;
    late ArtistService service;

    setUp(() {
      artistRepo = InMemoryArtistRepository();
      songRepo = InMemorySongRepository();
      service = ArtistService(
        artistRepo,
        InMemoryAlbumRepository(),
        songRepo,
        ArtistRestClient(
          baseUrl: 'http://localhost',
          authService: AuthService(baseUrl: 'http://localhost'),
        ),
      );
    });

    test('getOrCreateArtist is stable for the same name', () {
      final first = service.getOrCreateArtist('Daft Punk');
      final second = service.getOrCreateArtist('Daft Punk');

      expect(first.id, isPositive);
      expect(second.id, first.id);
      expect(first.getHash(), second.getHash());
    });

    test('cacheServerArtist links songs to cached artist', () {
      final cached = service.cacheServerArtist(
        ArtistExpandedDto(
          hash: 'artist-hash',
          name: 'Artist',
          songFileHashes: ['s1', 's2'],
        ),
      );

      expect(cached.getSongs().map((s) => s.getHash()).toSet(), {'s1', 's2'});
      expect(songRepo.getSongByFileHash('s1')?.artist.target, same(cached));
    });

    test(
      'updateArtist delegates and fetch details caches server data',
      () async {
        final artist = service.getOrCreateArtist('Artist');
        service.updateArtist(artist);
        expect(artistRepo.getArtistByHash(artist.hash), same(artist));

        await http.runWithClient(
          () async {
            final fetched = await service.fetchArtistDetails('server-hash');
            expect(fetched!.name, 'Server Artist');
            expect(fetched.getSongs().single.fileHash, 'song');
          },
          () => MockClient(
            (_) async => http.Response(
              jsonEncode({
                'hash': 'server-hash',
                'name': 'Server Artist',
                'songFileHashes': ['song'],
              }),
              200,
            ),
          ),
        );
      },
    );

    test('fetch details falls back to locally cached artist', () async {
      final local = artistRepo.saveArtist(Artist('hash', 'Local'));
      await http.runWithClient(() async {
        expect(await service.fetchArtistDetails('hash'), same(local));
      }, () => MockClient((_) async => http.Response('', 500)));
    });

    test(
      'gets server-backed artist page and caches returned artists',
      () async {
        await http.runWithClient(
          () async {
            final result = await service.getArtistsPage(
              'query',
              'name',
              false,
              false,
              0,
              10,
            );
            expect(result.totalPages, 2);
            expect(artistRepo.getArtistByHash('remote'), isNotNull);
          },
          () => MockClient(
            (_) async => http.Response(
              jsonEncode({
                'content': [
                  {
                    'hash': 'remote',
                    'name': 'Remote',
                    'songFileHashes': <String>[],
                  },
                ],
                'page': 0,
                'size': 10,
                'totalPages': 2,
                'totalElements': 1,
              }),
              200,
            ),
          ),
        );
      },
    );

    test('falls back to local artist and song paging', () async {
      final artist = artistRepo.saveArtist(Artist('artist', 'Artist'));
      final song =
          songRepo.getOrCreateSong('song')
            ..fullyLoaded = true
            ..path = '/tmp/song.mp3';
      song.artist.target = artist;
      songRepo.updateSong(song);

      final artists = await service.getArtistsPage(
        '',
        'name',
        true,
        true,
        0,
        10,
      );
      expect(artists.content, [artist]);
      expect(artists.totalPages, 0);

      final songs = await service.getArtistSongsPage(
        'artist',
        localOnly: true,
        size: 10,
      );
      expect(songs.content, [song]);
      expect(songs.totalPages, 1);
    });

    test('caches complete server songs from artist song paging', () async {
      await http.runWithClient(
        () async {
          final result = await service.getArtistSongsPage('artist', size: 10);
          expect(result.totalPages, 3);
          expect(songRepo.getSongByFileHash('song')!.fullyLoaded, isTrue);
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'content': [
                {
                  'fileHash': 'song',
                  'name': 'Track',
                  'durationInSeconds': 10,
                  'trackNumber': 1,
                  'discNumber': 1,
                  'year': 2025,
                  'artist': {'hash': 'artist', 'name': 'Artist'},
                  'album': {'hash': 'album', 'name': 'Album'},
                },
              ],
              'page': 0,
              'size': 10,
              'totalPages': 3,
              'totalElements': 1,
            }),
            200,
          ),
        ),
      );
    });
  });
}
