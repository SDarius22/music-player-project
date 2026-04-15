import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/rest_clients/lyrics_rest_client.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';

class LyricsService {
  static final _logger = Logger('LyricsService');

  final AbstractFileService _fileService;
  final LyricsRestClient _lyricsRestClient;

  LyricsService(this._fileService, this._lyricsRestClient);

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

    _logger.fine(
      'No local lyrics found, fetching from server for song: ${song.name}',
    );

    return await _lyricsRestClient.fetchLyrics(song);
  }
}
