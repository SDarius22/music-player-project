import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/models/chunk_delivery_stats.dart';
import 'package:music_player_frontend/core/models/chunk_stat_record.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class StatisticsRestClient extends AbstractRestClient {
  static final _logger = Logger('StatisticsRestClient');

  StatisticsRestClient({
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
        final List<ChunkStatRecord> records =
            decoded
                .map((e) => ChunkStatRecord.fromJson(e as Map<String, dynamic>))
                .toList();
        records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return records;
      }
    } catch (e) {
      _logger.warning('[StatisticsRestService] Error fetching statistics', e);
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
        _logger.warning(
          '[StatisticsRestService] Failed to submit stat: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.warning('[StatisticsRestService] Error submitting stat', e);
    }
  }
}
