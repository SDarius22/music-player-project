import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/playback_state_dto.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class PlaybackRestClient extends AbstractRestClient {
  static final _logger = Logger('PlaybackRestClient');

  PlaybackRestClient({
    required String baseUrl,
    required AuthService authService,
  }) {
    super.baseUrl = baseUrl;
    super.authService = authService;
  }

  Future<PlaybackStateDto?> getPlaybackState() async {
    try {
      final response = await get('/playback');
      if (response.statusCode == 200) {
        return PlaybackStateDto.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      _logger.warning('PlaybackRestService.getPlaybackState error', e);
      return null;
    }
  }

  Future<void> savePlaybackState(PlaybackStateDto state) async {
    try {
      await put('/playback', state.toJson());
    } catch (e) {
      _logger.warning('PlaybackRestService.savePlaybackState error', e);
    }
  }
}
