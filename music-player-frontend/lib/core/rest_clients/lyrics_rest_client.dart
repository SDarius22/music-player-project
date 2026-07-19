import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/song.dart';

class LyricsRestClient {
  static final _logger = Logger('LyricsRestClient');

  Future<String?> fetchLyrics(
    Song? song, {
    int resultIndex = 0,
    bool titleOnly = false,
  }) async {
    if (song == null) return null;
    final parameters = <String, String>{'track_name': song.name};
    if (!titleOnly && song.artist.target != null) {
      parameters['artist_name'] = song.artist.target!.name;
    }
    if (!titleOnly && song.album.target != null) {
      parameters['album_name'] = song.album.target!.name;
    }
    final uri = Uri.https('lrclib.net', '/api/search', parameters);
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        var lyricsList = jsonDecode(response.body) as List<dynamic>;
        final usable =
            lyricsList
                .cast<Map<String, dynamic>>()
                .map(
                  (result) =>
                      result['syncedLyrics'] as String? ??
                      result['plainLyrics'] as String?,
                )
                .where((lyrics) => lyrics?.trim().isNotEmpty == true)
                .cast<String>()
                .toList();
        if (resultIndex >= 0 && resultIndex < usable.length) {
          return usable[resultIndex];
        }
        return null;
      }
      throw Exception('Failed to fetch lyrics: ${response.statusCode}');
    } catch (e) {
      _logger.warning('LyricsRestClient.fetchLyrics error', e);
      return null;
    }
  }
}
