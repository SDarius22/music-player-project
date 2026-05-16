import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/models/chunk_delivery_stats.dart';
import 'package:music_player_frontend/core/rest_clients/statistics_rest_client.dart';
import 'package:music_player_frontend/core/services/chunk_stats_service.dart';

class _FakeStatisticsRestClient extends Fake implements StatisticsRestClient {
  final List<ChunkDeliveryStats> submitted = [];

  @override
  Future<void> submitStat(ChunkDeliveryStats stats) async {
    submitted.add(stats);
  }
}

void main() {
  group('ChunkStatsService', () {
    late _FakeStatisticsRestClient restClient;

    setUp(() {
      restClient = _FakeStatisticsRestClient();
      ChunkStatsService.instance.configure(restClient);
    });

    test('reportSilently submits local-file playback stats', () async {
      const stats = ChunkDeliveryStats(
        fileHash: 'file',
        songName: 'Song A',
        localChunks: 1,
      );

      await ChunkStatsService.instance.reportSilently(stats);

      expect(restClient.submitted, [stats]);
    });

    test('reportSilently submits mixed-source playback stats', () async {
      const stats = ChunkDeliveryStats(
        fileHash: 'file',
        songName: 'Song B',
        localCachedChunks: 2,
        p2pChunks: 3,
        serverChunks: 5,
      );

      await ChunkStatsService.instance.reportSilently(stats);

      expect(restClient.submitted.single.p2pPercentage, closeTo(30.0, 0.001));
    });
  });
}

