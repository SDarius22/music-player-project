import 'package:bot_toast/bot_toast.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/models/chunk_delivery_stats.dart';
import 'package:music_player_frontend/core/rest_clients/statistics_rest_client.dart';

class ChunkStatsService {
  static final _logger = Logger('ChunkStatsService');

  static final ChunkStatsService instance = ChunkStatsService._();

  ChunkStatsService._();

  StatisticsRestClient? _restService;

  void configure(StatisticsRestClient restService) {
    _restService = restService;
  }

  Future<void> report(ChunkDeliveryStats stats) async {
    final String msg;
    if (stats.localChunks > 0 &&
        stats.p2pChunks == 0 &&
        stats.serverChunks == 0 &&
        stats.localCachedChunks == 0) {
      msg = '"${stats.songName}" played from local file';
    } else {
      final pct = stats.p2pPercentage.toStringAsFixed(1);
      msg = '$pct% of "${stats.songName}" was delivered by peers';
    }
    _logger.info('[ChunkStats] $msg');

    BotToast.showText(text: msg, duration: const Duration(seconds: 5));

    await _restService?.submitStat(stats);
  }
}
