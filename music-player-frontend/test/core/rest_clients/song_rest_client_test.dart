import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_player_frontend/core/dtos/negotiation_request_dto.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/song_rest_client.dart';

class _Auth extends AuthService {
  _Auth() : super(baseUrl: 'http://test');

  @override
  String? get accessToken => 'token';
}

const _song = {
  'fileHash': 'song',
  'name': 'Track',
  'durationInSeconds': 120,
  'trackNumber': 1,
  'discNumber': 1,
  'year': 2025,
  'artist': {'hash': 'artist', 'name': 'Artist'},
  'album': {'hash': 'album', 'name': 'Album'},
  'playCount': 2,
  'likedByUser': true,
};

const _page = {
  'content': [_song],
  'page': 0,
  'size': 1,
  'totalPages': 1,
  'totalElements': 1,
};

final _negotiation = NegotiationRequestDto(
  name: 'Track',
  artistName: 'Artist',
  albumName: 'Album',
  photoBase64: '',
  durationInSeconds: 120,
  trackNumber: 1,
  discNumber: 1,
  year: 2025,
  fileHash: 'song',
  hashes: const ['chunk'],
);

SongRestClient _rest() =>
    SongRestClient(baseUrl: 'http://test', authService: _Auth());

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

void main() {
  group('SongRestClient successful responses', () {
    test('covers negotiation, chunk upload, song lookup, and update', () async {
      final requests = <http.BaseRequest>[];
      await http.runWithClient(
        () async {
          final rest = _rest();
          expect((await rest.negotiateUpload(_negotiation))!.missingIndices, [
            1,
          ]);
          expect(
            await rest.uploadChunk(
              fileHash: 'song',
              chunkIndex: 1,
              chunkBytes: [1, 2],
              hash: 'chunk',
            ),
            isTrue,
          );
          expect((await rest.getServerSong('song')).name, 'Track');
          expect(
            (await rest.updateSongLibraryEntry(
              'song',
              true,
              DateTime.utc(2025),
              2,
            ))!.likedByUser,
            isTrue,
          );
        },
        () => MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/songs/negotiate') {
            return _json({
              'fileHash': 'song',
              'missingIndices': [1],
            });
          }
          if (request.url.path.contains('/chunks/')) {
            return http.Response('', 201);
          }
          return _json(_song);
        }),
      );
      expect(
        requests.map((e) => e.method),
        containsAll(['POST', 'GET', 'PATCH']),
      );
    });

    test('builds each song-page endpoint and parses its page', () async {
      final paths = <String>[];
      await http.runWithClient(
        () async {
          final rest = _rest();
          expect(
            (await rest.getSongsPage(
              query: ' song ',
              page: 2,
            )).content.single.name,
            'Track',
          );
          await rest.getSongsPage(filterAlbumHash: 'album');
          await rest.getSongsPage(filterArtistHash: 'artist');
          await rest.getSongsPage(filterPlaylistId: 4);
          expect((await rest.getRecommendations()).content, hasLength(1));
          expect((await rest.getForgottenFavourites()).content, hasLength(1));
          expect((await rest.getQuickDial()).content, hasLength(1));
          expect((await rest.getFavourites()).content, hasLength(1));
          expect((await rest.getMostPlayed()).content, hasLength(1));
          expect((await rest.getRecentlyPlayed()).content, hasLength(1));
        },
        () => MockClient((request) async {
          paths.add(request.url.path);
          return _json(_page);
        }),
      );

      expect(paths, contains('/songs'));
      expect(paths, contains('/albums/album/songs'));
      expect(paths, contains('/artists/artist/songs'));
      expect(paths, contains('/playlists/4/songs'));
      expect(paths, contains('/songs/recommendations'));
      expect(paths, contains('/songs/forgotten'));
      expect(paths, contains('/songs/quick-dial'));
      expect(paths, contains('/songs/favourites'));
      expect(paths, contains('/songs/most-played'));
      expect(paths, contains('/songs/recently-played'));
    });

    test('uploads a full song and reports progress', () async {
      final directory = await Directory.systemTemp.createTemp('song-rest-test');
      final file = File('${directory.path}/song.mp3');
      await file.writeAsBytes([1, 2, 3]);
      addTearDown(() => directory.delete(recursive: true));
      final progress = <(int, int)>[];

      await http.runWithClient(() async {
        expect(
          await _rest().uploadFullSong(
            audioFilePath: file.path,
            name: 'Track',
            artistName: 'Artist',
            albumName: 'Album',
            durationInSeconds: 3,
            trackNumber: 1,
            discNumber: 1,
            releaseYear: 2025,
            coverArtBytes: Uint8List.fromList([4]),
            onProgress: (sent, total) => progress.add((sent, total)),
          ),
          isTrue,
        );
      }, () => MockClient((_) async => http.Response('', 201)));
      expect(progress, isNotEmpty);
      expect(progress.last, (1, 1));
    });
  });

  group('SongRestClient failure responses', () {
    test('returns fallbacks and throws for required song lookup', () async {
      await http.runWithClient(() async {
        final rest = _rest();
        expect(await rest.negotiateUpload(_negotiation), isNull);
        expect(
          await rest.uploadChunk(
            fileHash: 'song',
            chunkIndex: 0,
            chunkBytes: const [],
            hash: 'x',
          ),
          isFalse,
        );
        await expectLater(rest.getServerSong('song'), throwsException);
        expect((await rest.getSongsPage()).content, isEmpty);
        expect((await rest.getRecommendations()).content, isEmpty);
        expect((await rest.getForgottenFavourites()).content, isEmpty);
        expect((await rest.getQuickDial()).content, isEmpty);
        expect((await rest.getFavourites()).content, isEmpty);
        expect((await rest.getMostPlayed()).content, isEmpty);
        expect((await rest.getRecentlyPlayed()).content, isEmpty);
        expect(
          await rest.updateSongLibraryEntry('song', false, null, 0),
          isNull,
        );
      }, () => MockClient((_) async => http.Response('bad', 500)));
    });

    test('full-song upload reports failure', () async {
      final directory = await Directory.systemTemp.createTemp('song-rest-test');
      final file = File('${directory.path}/song.mp3');
      await file.writeAsBytes([1]);
      addTearDown(() => directory.delete(recursive: true));
      final progress = <(int, int)>[];
      await http.runWithClient(() async {
        expect(
          await _rest().uploadFullSong(
            audioFilePath: file.path,
            name: 'Track',
            artistName: 'Artist',
            albumName: 'Album',
            durationInSeconds: 1,
            trackNumber: 1,
            discNumber: 1,
            releaseYear: 2025,
            coverArtBytes: null,
            onProgress: (sent, total) => progress.add((sent, total)),
          ),
          isFalse,
        );
      }, () => MockClient((_) async => http.Response('', 500)));
      expect(progress.last, (0, 1));
    });
  });
}
