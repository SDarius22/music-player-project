import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class BackendLyricsRestClient extends AbstractRestClient {
  static final _logger = Logger('BackendLyricsRestClient');

  BackendLyricsRestClient({
    required String baseUrl,
    required AuthService authService,
  }) {
    super.baseUrl = baseUrl;
    super.authService = authService;
  }

  Future<String?> fetchLyrics(String fileHash) async {
    if (fileHash.isEmpty) return null;
    try {
      final response = await get('/songs/$fileHash/lyrics');
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final lyrics = json['lyrics']?.toString();
      return lyrics == null || lyrics.trim().isEmpty ? null : lyrics;
    } catch (e) {
      _logger.fine('Backend lyrics unavailable for $fileHash: $e');
      return null;
    }
  }

  Future<bool> upsertLyrics(String fileHash, String lyrics) async {
    if (fileHash.isEmpty || lyrics.trim().isEmpty) return false;
    try {
      final response = await put('/songs/$fileHash/lyrics', {'lyrics': lyrics});
      return response.statusCode == 200;
    } catch (e) {
      _logger.warning('Failed to save backend lyrics for $fileHash', e);
      return false;
    }
  }
}
