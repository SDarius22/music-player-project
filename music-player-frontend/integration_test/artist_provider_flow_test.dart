import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:music_player_frontend/core/entities/artist.dart';

import 'support/library_provider_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('artist provider integration flow', () {
    late FakeScanner scanner;

    setUp(() {
      scanner = FakeScanner();
    });

    tearDown(() async {
      await scanner.dispose();
    });

    testWidgets('caches artist pages and fetches artist songs', (tester) async {
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
            album: 'Night Work',
            artistHash: 'artist-north',
            albumHash: 'album-night-work',
          ),
        ],
        artists: [
          artistDto(
            hash: 'artist-north',
            name: 'North Archive',
            songFileHashes: ['hash-gold', 'hash-blue'],
          ),
        ],
      );

      final artistPage = await harness.artistProvider.fetchPage(
        '',
        'Name',
        true,
        false,
        0,
        10,
      );
      final artist = artistPage.content.single as Artist;

      expect(harness.artistClient.pageRequests.single.sort, 'name,asc');
      expect(artist.getName(), 'North Archive');
      expect(
        harness.artistRepository.getArtistByHash('artist-north'),
        isNotNull,
      );

      final songs = await harness.artistProvider.getSongsPage(
        'artist-north',
        page: 0,
        size: 10,
      );

      expect(harness.artistClient.songPageRequests, ['artist-north']);
      expect(songs.content.map((song) => song.getName()), [
        'Blue Hour',
        'Gold Line',
      ]);
    });

    testWidgets('falls back to local artist song cache when server fails', (
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
            album: 'Night Work',
            artistHash: 'artist-north',
            albumHash: 'album-night-work',
          ),
        ],
        artists: [
          artistDto(
            hash: 'artist-north',
            name: 'North Archive',
            songFileHashes: ['hash-gold', 'hash-blue'],
          ),
        ],
      );

      await harness.artistProvider.fetchPage('', 'Name', true, false, 0, 10);
      await harness.artistProvider.getSongsPage(
        'artist-north',
        page: 0,
        size: 10,
      );
      harness.artistClient.failArtistSongPages = true;

      final localFallback = await harness.artistProvider.getSongsPage(
        'artist-north',
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
