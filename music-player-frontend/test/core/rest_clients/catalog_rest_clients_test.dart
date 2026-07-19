import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_player_frontend/core/dtos/playlists/create_playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/update_playlist_dto.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/rest_clients/album_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/artist_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/backend_lyrics_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/lyrics_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/playlist_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/statistics_rest_client.dart';

class _Auth extends AuthService {
  _Auth() : super(baseUrl: 'http://test');

  @override
  String? get accessToken => 'token';
}

const _emptyPage = {
  'content': <Object>[],
  'page': 0,
  'size': 10,
  'totalPages': 0,
  'totalElements': 0,
};

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Song _song(String name) => Song('hash')..name = name;

void main() {
  final auth = _Auth();

  group('AlbumRestClient', () {
    test('parses pages, details, covers, and song pages', () async {
      final requests = <http.BaseRequest>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/cover')) {
          return http.Response.bytes([1, 2, 3], 200);
        }
        if (request.url.path.endsWith('/songs')) return _json(_emptyPage);
        if (request.url.path == '/albums/hash') {
          return _json({
            'hash': 'hash',
            'name': 'Album',
            'songFileHashes': ['song'],
            'durationInSeconds': 4,
            'artist': {'hash': 'artist', 'name': 'Artist'},
          });
        }
        return _json(_emptyPage);
      });

      await http.runWithClient(() async {
        final rest = AlbumRestClient(baseUrl: 'http://test', authService: auth);
        expect(
          (await rest.getAlbumsPage(query: ' album ', page: 2)).content,
          isEmpty,
        );
        expect((await rest.getAlbumByHash('hash'))!.name, 'Album');
        expect(await rest.getAlbumCover(7), [1, 2, 3]);
        expect(
          (await rest.getAlbumSongsPage(albumHash: 'hash')).content,
          isEmpty,
        );
      }, () => client);

      expect(requests.first.url.queryParameters['q'], 'album');
    });

    test('returns safe defaults on server and decoding failures', () async {
      await http.runWithClient(() async {
        final rest = AlbumRestClient(baseUrl: 'http://test', authService: auth);
        expect((await rest.getAlbumsPage()).content, isEmpty);
        expect(await rest.getAlbumByHash('x'), isNull);
        expect(await rest.getAlbumCover(1), isNull);
        expect((await rest.getAlbumSongsPage(albumHash: 'x')).content, isEmpty);
      }, () => MockClient((_) async => http.Response('bad', 500)));
    });
  });

  group('ArtistRestClient', () {
    test('parses list, details, and songs', () async {
      await http.runWithClient(
        () async {
          final rest = ArtistRestClient(
            baseUrl: 'http://test',
            authService: auth,
          );
          expect(
            (await rest.getArtistsPage(query: ' artist ')).content,
            isEmpty,
          );
          expect((await rest.getArtistByHash('hash'))!.name, 'Artist');
          expect(
            (await rest.getArtistSongsPage(artistHash: 'hash')).content,
            isEmpty,
          );
        },
        () => MockClient((request) async {
          if (request.url.path == '/artists/hash') {
            return _json({
              'hash': 'hash',
              'name': 'Artist',
              'songFileHashes': ['song'],
            });
          }
          return _json(_emptyPage);
        }),
      );
    });

    test('returns safe defaults after failures', () async {
      await http.runWithClient(() async {
        final rest = ArtistRestClient(
          baseUrl: 'http://test',
          authService: auth,
        );
        expect((await rest.getArtistsPage()).content, isEmpty);
        expect(await rest.getArtistByHash('x'), isNull);
        expect(
          (await rest.getArtistSongsPage(artistHash: 'x')).content,
          isEmpty,
        );
      }, () => MockClient((_) async => http.Response('bad', 500)));
    });
  });

  group('PlaylistRestClient', () {
    test('covers playlist CRUD, filtering, and song paging', () async {
      final requests = <http.BaseRequest>[];
      await http.runWithClient(
        () async {
          final rest = PlaylistRestClient(
            baseUrl: 'http://test',
            authService: auth,
          );
          expect((await rest.getPlaylistDetails(4))!.id, 4);
          expect((await rest.getPlaylistDetailsByName('Queue'))!.name, 'Queue');
          expect(
            (await rest.getPlaylistsPage(
              query: ' q ',
              filterIndestructible: true,
              includeQueue: false,
            )).content,
            isEmpty,
          );
          expect(
            (await rest.createPlaylist(
              CreatePlaylistDto(name: 'New', playlistSongs: const []),
            ))!.name,
            'Queue',
          );
          expect(
            await rest.updatePlaylist(4, UpdatePlaylistDto(name: 'Renamed')),
            isTrue,
          );
          expect(await rest.deletePlaylist(4), isTrue);
          expect(
            (await rest.getPlaylistSongsPage(playlistId: 4)).content,
            isEmpty,
          );
        },
        () => MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/songs')) return _json(_emptyPage);
          if (request.url.path == '/playlists' && request.method == 'GET') {
            return _json(_emptyPage);
          }
          if (request.method == 'DELETE') return http.Response('', 204);
          if (request.method == 'PATCH') return http.Response('', 200);
          return _json({
            'id': 4,
            'name': 'Queue',
            'songFileHashes': <String>[],
            'durationInSeconds': 0,
            'indestructible': true,
          }, request.method == 'POST' ? 201 : 200);
        }),
      );

      final listRequest = requests.firstWhere(
        (r) => r.method == 'GET' && r.url.path == '/playlists',
      );
      expect(listRequest.url.queryParameters['q'], 'q');
      expect(listRequest.url.queryParameters['filter[indestructible]'], 'true');
      expect(listRequest.url.queryParameters['includeQueue'], 'false');
    });

    test('returns failure values for unsuccessful responses', () async {
      await http.runWithClient(() async {
        final rest = PlaylistRestClient(
          baseUrl: 'http://test',
          authService: auth,
        );
        expect(await rest.getPlaylistDetails(1), isNull);
        expect(await rest.getPlaylistDetailsByName('x'), isNull);
        expect((await rest.getPlaylistsPage()).content, isEmpty);
        expect(
          await rest.createPlaylist(
            CreatePlaylistDto(name: 'x', playlistSongs: const []),
          ),
          isNull,
        );
        expect(await rest.updatePlaylist(1, UpdatePlaylistDto()), isFalse);
        expect(await rest.deletePlaylist(1), isFalse);
        expect(
          (await rest.getPlaylistSongsPage(playlistId: 1)).content,
          isEmpty,
        );
      }, () => MockClient((_) async => http.Response('bad', 500)));
    });
  });

  group('StatisticsRestClient', () {
    test('sorts downloaded records and submits statistics', () async {
      final methods = <String>[];
      await http.runWithClient(
        () async {
          final rest = StatisticsRestClient(
            baseUrl: 'http://test',
            authService: auth,
          );
          final records = await rest.getStatistics();
          expect(records.map((e) => e.songName), ['new', 'old']);
          await rest.submitStat(records.first);
        },
        () => MockClient((request) async {
          methods.add(request.method);
          if (request.method == 'POST') return http.Response('', 201);
          return _json([
            {
              'songName': 'old',
              'songFileHash': '1',
              'timestamp': '2024-01-01T00:00:00Z',
            },
            {
              'songName': 'new',
              'songFileHash': '2',
              'timestamp': '2025-01-01T00:00:00Z',
            },
          ]);
        }),
      );
      expect(methods, ['GET', 'POST']);
    });

    test('handles failed reads and writes', () async {
      await http.runWithClient(() async {
        final rest = StatisticsRestClient(
          baseUrl: 'http://test',
          authService: auth,
        );
        expect(await rest.getStatistics(), isEmpty);
        await rest.submitStat(ChunkStat(songFileHash: 'x', songName: 'x'));
      }, () => MockClient((_) async => http.Response('bad', 500)));
    });
  });

  group('LyricsRestClient', () {
    test('returns null for no song and parses synced lyrics', () async {
      final rest = LyricsRestClient();
      expect(await rest.fetchLyrics(null), isNull);
      await http.runWithClient(
        () async {
          expect(await rest.fetchLyrics(_song('A song')), '[00:00]Hi');
        },
        () => MockClient((request) async {
          expect(request.url.queryParameters['track_name'], 'A song');
          return _json([
            {'syncedLyrics': '[00:00]Hi'},
          ]);
        }),
      );
    });

    test('returns null for empty results and request failures', () async {
      final rest = LyricsRestClient();
      await http.runWithClient(() async {
        expect(await rest.fetchLyrics(_song('Song')), isNull);
      }, () => MockClient((_) async => _json([])));
      await http.runWithClient(() async {
        expect(await rest.fetchLyrics(_song('Song')), isNull);
      }, () => MockClient((_) async => http.Response('', 500)));
    });

    test('can select the next usable external lyrics result', () async {
      final rest = LyricsRestClient();
      await http.runWithClient(
        () async {
          expect(
            await rest.fetchLyrics(_song('Song'), resultIndex: 1),
            'second',
          );
        },
        () => MockClient(
          (_) async => _json([
            {'syncedLyrics': 'first'},
            {'syncedLyrics': null, 'plainLyrics': 'second'},
          ]),
        ),
      );
    });
  });

  group('BackendLyricsRestClient', () {
    test('gets and upserts lyrics through the application API', () async {
      final methods = <String>[];
      await http.runWithClient(
        () async {
          final rest = BackendLyricsRestClient(
            baseUrl: 'http://test',
            authService: auth,
          );
          expect(await rest.fetchLyrics('hash'), '[00:00] backend');
          expect(await rest.upsertLyrics('hash', '[00:00] changed'), isTrue);
        },
        () => MockClient((request) async {
          methods.add(request.method);
          expect(request.url.path, '/songs/hash/lyrics');
          expect(request.headers['authorization'], 'Bearer token');
          if (request.method == 'PUT') {
            expect(jsonDecode(request.body), {'lyrics': '[00:00] changed'});
          }
          return _json({'lyrics': '[00:00] backend'});
        }),
      );
      expect(methods, ['GET', 'PUT']);
    });

    test('returns safe values when backend lyrics are unavailable', () async {
      await http.runWithClient(() async {
        final rest = BackendLyricsRestClient(
          baseUrl: 'http://test',
          authService: auth,
        );
        expect(await rest.fetchLyrics('hash'), isNull);
        expect(await rest.upsertLyrics('hash', 'lyrics'), isFalse);
        expect(await rest.fetchLyrics(''), isNull);
      }, () => MockClient((_) async => http.Response('', 404)));
    });
  });
}
