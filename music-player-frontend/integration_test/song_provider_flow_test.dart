import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/library_provider_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('song provider integration flow', () {
    late FakeScanner scanner;

    setUp(() {
      scanner = FakeScanner();
    });

    tearDown(() async {
      await scanner.dispose();
    });

    testWidgets('caches server songs and links artists/albums', (tester) async {
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

      final songPage = await harness.songProvider.fetchPage(
        '',
        'Title',
        true,
        false,
        0,
        10,
      );

      expect(harness.songClient.pageRequests.single.sort, 'name,asc');
      expect(songPage.content.map((song) => song.getName()), [
        'Blue Hour',
        'Gold Line',
      ]);
      expect(songPage.content.first.artist.target?.name, 'Coast Pattern');
      expect(songPage.content.first.album.target?.name, 'Night Work');
      expect(harness.songRepository.getAllSongs(), hasLength(2));
    });

    testWidgets('falls back to cached songs when server song paging fails', (
      tester,
    ) async {
      final harness = buildLibraryHarness(
        scanner,
        songs: [
          songDto(
            hash: 'hash-local',
            name: 'Local Echo',
            artist: 'Cached Artist',
            album: 'Offline Set',
          ),
          songDto(
            hash: 'hash-remote',
            name: 'Remote Drift',
            artist: 'Cached Artist',
            album: 'Offline Set',
          ),
        ],
      );

      await harness.songProvider.fetchPage('', 'Title', true, false, 0, 10);
      harness.songClient.failSongPages = true;

      final fallbackPage = await harness.songProvider.fetchPage(
        'local',
        'Title',
        true,
        false,
        0,
        10,
      );

      expect(harness.songClient.pageRequests.last.query, 'local');
      expect(fallbackPage.content.map((song) => song.getName()), [
        'Local Echo',
      ]);
      expect(fallbackPage.totalPages, 1);
    });
  });
}
