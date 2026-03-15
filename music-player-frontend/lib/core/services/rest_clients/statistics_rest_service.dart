import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/models/chunk_delivery_stats.dart';
import 'package:music_player_frontend/core/services/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';

class StatisticsRestService extends AbstractRestService {
  StatisticsRestService({
    required String baseUrl,
    required AuthService authService,
  }) {
    super.baseUrl = baseUrl;
    super.authService = authService;
  }

  Future<void> submitStat(ChunkDeliveryStats stats) async {
    try {
      final response = await post('/statistics', {
        'songId': stats.songId,
        'songName': stats.songName,
        'p2pChunks': stats.p2pChunks,
        'serverChunks': stats.serverChunks,
      });

      if (response.statusCode != 201) {
        debugPrint(
          '[StatisticsRestService] Failed to submit stat: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[StatisticsRestService] Error submitting stat: $e');
    }
  }
}
