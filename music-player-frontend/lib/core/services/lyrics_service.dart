import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/rest_clients/backend_lyrics_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/lyrics_rest_client.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';

class LyricsService {
  static final _logger = Logger('LyricsService');

  final AbstractFileService _fileService;
  final LyricsRestClient _lyricsRestClient;
  final BackendLyricsRestClient _backendLyricsRestClient;
  final Map<String, int> _nextAlternativeIndex = <String, int>{};

  LyricsService(
    this._fileService,
    this._lyricsRestClient,
    this._backendLyricsRestClient,
  );

  Future<String?> fetchLyricsForSong(Song? song) async {
    _logger.fine('Fetching lyrics for song: $song');
    if (song == null) return null;
    if (song.path != null && song.path!.isNotEmpty) {
      try {
        final lyrics = _fileService.getLyrics(song.path);
        if (lyrics.isNotEmpty) {
          return lyrics;
        }
      } catch (e) {
        // If reading from file fails, we can ignore and try fetching from server
      }
    }

    final backendLyrics = await _backendLyricsRestClient.fetchLyrics(
      song.fileHash,
    );
    if (backendLyrics != null) return backendLyrics;

    _logger.fine('No saved lyrics found, searching for: ${song.name}');
    final externalLyrics = await _lyricsRestClient.fetchLyrics(song);
    if (externalLyrics != null && song.fileHash.isNotEmpty) {
      await _backendLyricsRestClient.upsertLyrics(
        song.fileHash,
        externalLyrics,
      );
    }
    return externalLyrics;
  }

  Future<String?> findAlternativeLyrics(Song? song) async {
    if (song == null) return null;
    final key = song.getHash();
    final resultIndex = _nextAlternativeIndex[key] ?? 1;
    var lyrics = await _lyricsRestClient.fetchLyrics(
      song,
      resultIndex: resultIndex,
    );
    _nextAlternativeIndex[key] = resultIndex + 1;
    lyrics ??= await _lyricsRestClient.fetchLyrics(song, titleOnly: true);
    if (lyrics != null && song.fileHash.isNotEmpty) {
      await _backendLyricsRestClient.upsertLyrics(song.fileHash, lyrics);
    }
    return lyrics;
  }

  Future<bool> saveLyricsLocally(Song? song, String lyrics) {
    if (song == null || !song.hasLocalFile) return Future.value(false);
    return _fileService.saveLyrics(song.path, lyrics);
  }

  Future<bool> updateLyrics(Song? song, String lyrics) async {
    if (song == null || lyrics.trim().isEmpty) return false;
    final localSaved =
        song.hasLocalFile ? await saveLyricsLocally(song, lyrics) : false;
    final backendSaved =
        song.fileHash.isNotEmpty
            ? await _backendLyricsRestClient.upsertLyrics(song.fileHash, lyrics)
            : false;
    return localSaved || backendSaved;
  }
}
