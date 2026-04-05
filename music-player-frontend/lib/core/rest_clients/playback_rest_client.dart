import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/dtos/playback_state_dto.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class PlaybackRestClient extends AbstractRestClient {
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
      debugPrint('PlaybackRestService.getPlaybackState error: $e');
      return null;
    }
  }

  Future<void> savePlaybackState(PlaybackStateDto state) async {
    try {
      await put('/playback', state.toJson());
    } catch (e) {
      debugPrint('PlaybackRestService.savePlaybackState error: $e');
    }
  }
}
