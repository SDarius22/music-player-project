import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/rest_clients/lyrics_rest_client.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/lyrics_service.dart';

class _FakeFileService extends Fake implements AbstractFileService {
  String lyricsToReturn = '';
  Object? throwOnRead;

  @override
  List<String> get supportedAudioExtensions => const ['mp3'];

  @override
  String getLyrics(String? songPath) {
    if (throwOnRead != null) {
      throw throwOnRead!;
    }
    return lyricsToReturn;
  }
}

class _FakeLyricsRestClient extends Fake implements LyricsRestClient {
  String? lyricsToReturn;

  @override
  Future<String?> fetchLyrics(Song? song) async {
    return lyricsToReturn;
  }
}

void main() {
  group('LyricsService', () {
    late _FakeFileService fileService;
    late _FakeLyricsRestClient restClient;
    late LyricsService service;

    setUp(() {
      fileService = _FakeFileService();
      restClient = _FakeLyricsRestClient();
      service = LyricsService(fileService, restClient);
    });

    test('returns null for null song', () async {
      final lyrics = await service.fetchLyricsForSong(null);

      expect(lyrics, isNull);
    });

    test('returns local lyrics when file service yields content', () async {
      final song = Song('hash')..path = '/tmp/song.mp3';
      fileService.lyricsToReturn = '[00:00] local';
      restClient.lyricsToReturn = 'server';

      final lyrics = await service.fetchLyricsForSong(song);

      expect(lyrics, '[00:00] local');
    });

    test('falls back to server when local lyrics are empty', () async {
      final song = Song('hash')
        ..name = 'Remote Song'
        ..path = '/tmp/song.mp3';
      fileService.lyricsToReturn = '';
      restClient.lyricsToReturn = 'server lyrics';

      final lyrics = await service.fetchLyricsForSong(song);

      expect(lyrics, 'server lyrics');
    });

    test('falls back to server when local read throws', () async {
      final song = Song('hash')
        ..name = 'Remote Song'
        ..path = '/tmp/song.mp3';
      fileService.throwOnRead = Exception('read failed');
      restClient.lyricsToReturn = 'server lyrics';

      final lyrics = await service.fetchLyricsForSong(song);

      expect(lyrics, 'server lyrics');
    });

    test('uses server directly when path is empty', () async {
      final song = Song('hash')..name = 'No Path';
      restClient.lyricsToReturn = 'from server';

      final lyrics = await service.fetchLyricsForSong(song);

      expect(lyrics, 'from server');
    });
  });
}

