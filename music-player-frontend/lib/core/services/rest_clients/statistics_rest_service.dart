import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/models/chunk_delivery_stats.dart';
import 'package:music_player_frontend/core/models/chunk_stat_record.dart';
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

  Future<List<ChunkStatRecord>> getStatistics() async {
    try {
      final response = await get('/statistics');
      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        return decoded
            .map((e) => ChunkStatRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[StatisticsRestService] Error fetching statistics: $e');
    }
    return [];
  }

  Future<void> submitStat(ChunkDeliveryStats stats) async {
    try {
      final response = await post('/statistics', {
        'songFileHash': stats.fileHash,
        'songName': stats.songName,
        'localChunks': stats.localChunks,
        'localCachedChunks': stats.localCachedChunks,
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
