import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/rest_clients/backend_lyrics_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/lyrics_rest_client.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/lyrics_service.dart';

class _FakeFileService extends Fake implements AbstractFileService {
  String lyricsToReturn = '';
  Object? throwOnRead;
  bool saveResult = true;
  String? savedPath;
  String? savedLyrics;

  @override
  List<String> get supportedAudioExtensions => const ['mp3'];

  @override
  String getLyrics(String? songPath) {
    if (throwOnRead != null) {
      throw throwOnRead!;
    }
    return lyricsToReturn;
  }

  @override
  Future<bool> saveLyrics(String? songPath, String lyrics) async {
    savedPath = songPath;
    savedLyrics = lyrics;
    return saveResult;
  }
}

class _FakeLyricsRestClient extends Fake implements LyricsRestClient {
  String? lyricsToReturn;
  String? alternativeLyrics;

  @override
  Future<String?> fetchLyrics(
    Song? song, {
    int resultIndex = 0,
    bool titleOnly = false,
  }) async => resultIndex > 0 || titleOnly ? alternativeLyrics : lyricsToReturn;
}

class _FakeBackendLyricsRestClient extends Fake
    implements BackendLyricsRestClient {
  String? lyricsToReturn;
  final List<String> savedLyrics = <String>[];

  @override
  Future<String?> fetchLyrics(String fileHash) async => lyricsToReturn;

  @override
  Future<bool> upsertLyrics(String fileHash, String lyrics) async {
    savedLyrics.add(lyrics);
    return true;
  }
}

void main() {
  group('LyricsService', () {
    late _FakeFileService fileService;
    late _FakeLyricsRestClient restClient;
    late _FakeBackendLyricsRestClient backendClient;
    late LyricsService service;

    setUp(() {
      fileService = _FakeFileService();
      restClient = _FakeLyricsRestClient();
      backendClient = _FakeBackendLyricsRestClient();
      service = LyricsService(fileService, restClient, backendClient);
    });

    test('returns null for null song', () async {
      final lyrics = await service.fetchLyricsForSong(null);

      expect(lyrics, isNull);
    });

    test('returns local lyrics when file service yields content', () async {
      final song = Song('hash')..path = '/tmp/song.mp3';
      fileService.lyricsToReturn = '[00:00] local';
      backendClient.lyricsToReturn = 'server';

      final lyrics = await service.fetchLyricsForSong(song);

      expect(lyrics, '[00:00] local');
    });

    test('falls back to backend when local lyrics are empty', () async {
      final song =
          Song('hash')
            ..name = 'Remote Song'
            ..path = '/tmp/song.mp3';
      fileService.lyricsToReturn = '';
      backendClient.lyricsToReturn = 'server lyrics';

      final lyrics = await service.fetchLyricsForSong(song);

      expect(lyrics, 'server lyrics');
    });

    test('falls back to server when local read throws', () async {
      final song =
          Song('hash')
            ..name = 'Remote Song'
            ..path = '/tmp/song.mp3';
      fileService.throwOnRead = Exception('read failed');
      backendClient.lyricsToReturn = 'server lyrics';

      final lyrics = await service.fetchLyricsForSong(song);

      expect(lyrics, 'server lyrics');
    });

    test('uses backend directly when path is empty', () async {
      final song = Song('hash')..name = 'No Path';
      backendClient.lyricsToReturn = 'from server';

      final lyrics = await service.fetchLyricsForSong(song);

      expect(lyrics, 'from server');
    });

    test('falls back to external lyrics and saves them to backend', () async {
      final song = Song('hash')..name = 'External';
      restClient.lyricsToReturn = 'external lyrics';

      final lyrics = await service.fetchLyricsForSong(song);

      expect(lyrics, 'external lyrics');
      expect(backendClient.savedLyrics, ['external lyrics']);
    });

    test(
      'incorrect lyrics choose an alternative and replace backend',
      () async {
        final song = Song('hash')..name = 'External';
        restClient.alternativeLyrics = 'second match';

        final lyrics = await service.findAlternativeLyrics(song);

        expect(lyrics, 'second match');
        expect(backendClient.savedLyrics, ['second match']);
      },
    );

    test('saves displayed lyrics beside a local song', () async {
      final song = Song('')..path = '/music/song.mp3';

      expect(await service.saveLyricsLocally(song, 'lyrics'), isTrue);
      expect(fileService.savedPath, '/music/song.mp3');
      expect(fileService.savedLyrics, 'lyrics');
    });

    test('edited merged-song lyrics update local and backend copies', () async {
      final song = Song('hash')..path = '/music/song.mp3';

      expect(await service.updateLyrics(song, 'corrected'), isTrue);
      expect(fileService.savedLyrics, 'corrected');
      expect(backendClient.savedLyrics, ['corrected']);
    });
  });
}
