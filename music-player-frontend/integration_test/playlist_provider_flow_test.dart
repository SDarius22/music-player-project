import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';

import 'support/library_provider_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('playlist provider integration flow', () {
    late FakeScanner scanner;

    setUp(() {
      scanner = FakeScanner();
    });

    tearDown(() async {
      await scanner.dispose();
    });

    testWidgets('creates playlists and preserves song order', (tester) async {
      final harness = buildLibraryHarness(
        scanner,
        songs: [
          songDto(
            hash: 'hash-gold',
            name: 'Gold Line',
            artist: 'North Archive',
            album: 'Signals',
          ),
          songDto(
            hash: 'hash-blue',
            name: 'Blue Hour',
            artist: 'Coast Pattern',
            album: 'Night Work',
          ),
        ],
      );
      final songs =
          (await harness.songProvider.fetchPage(
            '',
            'Title',
            true,
            false,
            0,
            10,
          )).content;

      await harness.playlistProvider.addPlaylist('Road Trip', [
        songs[1],
        songs[0],
      ], null);

      final createRequest = harness.playlistClient.lastCreateRequest!;
      expect(createRequest.playlistSongs.map((entry) => entry.songFileHash), [
        'hash-gold',
        'hash-blue',
      ]);
      expect(createRequest.playlistSongs.map((entry) => entry.position), [
        0,
        1,
      ]);

      final playlistPage = await harness.playlistProvider.fetchPage(
        'road',
        'Name',
        true,
        false,
        0,
        10,
      );
      final playlist = playlistPage.content.single as Playlist;

      expect(playlist.serverId, 100);
      expect(playlist.getName(), 'Road Trip');

      final playlistSongs = await harness.playlistProvider.getSongsPage(
        playlist.getHash(),
        page: 0,
        size: 10,
      );

      expect(harness.playlistClient.songPageRequests, [100]);
      expect(playlistSongs.content.map((song) => song.getName()), [
        'Gold Line',
        'Blue Hour',
      ]);
    });

    testWidgets(
      'mutations update server request bodies and local fallback pages',
      (tester) async {
        final harness = buildLibraryHarness(
          scanner,
          songs: [
            songDto(
              hash: 'hash-alpha',
              name: 'Alpha Run',
              artist: 'Route Unit',
              album: 'Map Lines',
            ),
            songDto(
              hash: 'hash-beta',
              name: 'Beta Turn',
              artist: 'Route Unit',
              album: 'Map Lines',
            ),
            songDto(
              hash: 'hash-gamma',
              name: 'Gamma Exit',
              artist: 'Route Unit',
              album: 'Map Lines',
            ),
          ],
        );

        final songs =
            (await harness.songProvider.fetchPage(
              '',
              'Title',
              true,
              false,
              0,
              10,
            )).content;

        await harness.playlistProvider.addPlaylist('Commute', [
          songs[0],
          songs[1],
        ], null);
        final playlistPage = await harness.playlistProvider.fetchPage(
          'commute',
          'Name',
          true,
          false,
          0,
          10,
        );
        final playlist = playlistPage.content.single as Playlist;

        harness.playlistClient.failPlaylistSongPages = true;
        await harness.playlistProvider.addSongsToPlaylist(playlist, [songs[2]]);

        expect(harness.playlistClient.updateRequests, [100]);
        expect(
          harness.playlistClient.lastUpdateRequest!.playlistSongs!.map(
            (entry) => entry.songFileHash,
          ),
          ['hash-alpha', 'hash-beta', 'hash-gamma'],
        );

        final localFallback = await harness.playlistProvider.getSongsPage(
          playlist.getHash(),
          page: 0,
          size: 10,
        );
        expect(localFallback.content.map((song) => song.getName()), [
          'Alpha Run',
          'Beta Turn',
          'Gamma Exit',
        ]);

        await harness.playlistProvider.deleteSongFromPlaylist(
          songs[1],
          playlist,
        );

        expect(harness.playlistClient.updateRequests, [100, 100]);
        final afterRemove = await harness.playlistProvider.getSongsPage(
          playlist.getHash(),
          page: 0,
          size: 10,
        );
        expect(afterRemove.content.map((song) => song.getName()), [
          'Alpha Run',
          'Gamma Exit',
        ]);

        await harness.playlistProvider.deletePlaylist(playlist);

        expect(harness.playlistClient.deleteRequests, [100]);
        final afterDelete = await harness.playlistProvider.fetchPage(
          '',
          'Name',
          true,
          false,
          0,
          10,
        );
        expect(afterDelete.content, isEmpty);
      },
    );
  });
}
