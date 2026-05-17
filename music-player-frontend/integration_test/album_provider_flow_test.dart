import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:music_player_frontend/core/entities/album.dart';

import 'support/library_provider_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('album provider integration flow', () {
    late FakeScanner scanner;

    setUp(() {
      scanner = FakeScanner();
    });

    tearDown(() async {
      await scanner.dispose();
    });

    testWidgets('caches album pages and fetches album songs', (tester) async {
      final harness = buildLibraryHarness(
        scanner,
        songs: [
          songDto(
            hash: 'hash-gold',
            name: 'Gold Line',
            artist: 'North Archive',
            album: 'Signals',
            artistHash: 'artist-north',
            albumHash: 'album-signals',
          ),
          songDto(
            hash: 'hash-blue',
            name: 'Blue Hour',
            artist: 'North Archive',
            album: 'Signals',
            artistHash: 'artist-north',
            albumHash: 'album-signals',
          ),
        ],
        albums: [
          albumDto(
            hash: 'album-signals',
            name: 'Signals',
            artistHash: 'artist-north',
            artistName: 'North Archive',
            songFileHashes: ['hash-gold', 'hash-blue'],
          ),
        ],
      );

      final albumPage = await harness.albumProvider.fetchPage(
        '',
        'Name',
        true,
        false,
        0,
        10,
      );
      final album = albumPage.content.single as Album;

      expect(harness.albumClient.pageRequests.single.sort, 'name,asc');
      expect(album.getName(), 'Signals');
      expect(album.artist.target?.name, 'North Archive');
      expect(
        harness.albumRepository.getAlbumByHash('album-signals'),
        isNotNull,
      );

      final songs = await harness.albumProvider.getSongsPage(
        'album-signals',
        page: 0,
        size: 10,
      );

      expect(harness.albumClient.songPageRequests, ['album-signals']);
      expect(songs.content.map((song) => song.getName()), [
        'Blue Hour',
        'Gold Line',
      ]);
    });

    testWidgets('falls back to local album song cache when server fails', (
      tester,
    ) async {
      final harness = buildLibraryHarness(
        scanner,
        songs: [
          songDto(
            hash: 'hash-gold',
            name: 'Gold Line',
            artist: 'North Archive',
            album: 'Signals',
            artistHash: 'artist-north',
            albumHash: 'album-signals',
          ),
          songDto(
            hash: 'hash-blue',
            name: 'Blue Hour',
            artist: 'North Archive',
            album: 'Signals',
            artistHash: 'artist-north',
            albumHash: 'album-signals',
          ),
        ],
        albums: [
          albumDto(
            hash: 'album-signals',
            name: 'Signals',
            artistHash: 'artist-north',
            artistName: 'North Archive',
            songFileHashes: ['hash-gold', 'hash-blue'],
          ),
        ],
      );

      await harness.albumProvider.fetchPage('', 'Name', true, false, 0, 10);
      await harness.albumProvider.getSongsPage(
        'album-signals',
        page: 0,
        size: 10,
      );
      harness.albumClient.failAlbumSongPages = true;

      final localFallback = await harness.albumProvider.getSongsPage(
        'album-signals',
        page: 0,
        size: 10,
      );

      expect(localFallback.content.map((song) => song.getName()), [
        'Blue Hour',
        'Gold Line',
      ]);
    });
  });
}
