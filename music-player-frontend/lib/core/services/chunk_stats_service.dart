import 'package:bot_toast/bot_toast.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_stat_repository.dart';
import 'package:music_player_frontend/core/rest_clients/statistics_rest_client.dart';

class ChunkStatsService {
  static final _logger = Logger('ChunkStatsService');

  static final ChunkStatsService instance = ChunkStatsService._();

  ChunkStatsService._();

  StatisticsRestClient? _restService;
  ChunkStatRepository? _repository;

  void configure(
    StatisticsRestClient restService, {
    ChunkStatRepository? repository,
  }) {
    _restService = restService;
    _repository = repository;
  }

  Future<void> report(ChunkStat stats) async {
    await _report(stats, showToast: true);
  }

  Future<void> reportSilently(ChunkStat stats) async {
    await _report(stats, showToast: false);
  }

  Future<List<ChunkStat>> getStatistics() async {
    final local = _repository?.getAllStats() ?? <ChunkStat>[];
    final remote = await _restService?.getStatistics() ?? <ChunkStat>[];

    final merged = <String, ChunkStat>{};
    for (final s in remote) {
      merged[_dedupeKey(s)] = s;
    }
    for (final s in local) {
      merged.putIfAbsent(_dedupeKey(s), () => s);
    }

    final result = merged.values.toList();
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  String _dedupeKey(ChunkStat s) =>
      '${s.songFileHash}|${s.timestamp.millisecondsSinceEpoch ~/ 1000}';

  Future<void> _report(ChunkStat stats, {required bool showToast}) async {
    final String msg;
    if (stats.isLocalFilePlayback) {
      msg = '"${stats.songName}" played from local file';
    } else {
      final pct = stats.p2pPercentage.toStringAsFixed(1);
      msg = '$pct% of "${stats.songName}" was delivered by peers';
    }
    _logger.info('[ChunkStats] $msg');

    if (showToast) {
      BotToast.showText(text: msg, duration: const Duration(seconds: 5));
    }

    try {
      _repository?.saveStat(stats);
    } catch (e) {
      _logger.warning('Failed to persist chunk stat locally', e);
    }

    await _restService?.submitStat(stats);
  }
}
