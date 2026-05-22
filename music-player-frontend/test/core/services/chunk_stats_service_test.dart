import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_chunk_stat_repository.dart';
import 'package:music_player_frontend/core/rest_clients/statistics_rest_client.dart';
import 'package:music_player_frontend/core/services/chunk_stats_service.dart';

class _FakeStatisticsRestClient extends Fake implements StatisticsRestClient {
  final List<ChunkStat> submitted = [];
  final List<ChunkStat> remoteRecords = [];

  @override
  Future<void> submitStat(ChunkStat stats) async {
    submitted.add(stats);
  }

  @override
  Future<List<ChunkStat>> getStatistics() async => remoteRecords;
}

void main() {
  group('ChunkStatsService', () {
    late _FakeStatisticsRestClient restClient;
    late InMemoryChunkStatRepository repo;

    setUp(() {
      restClient = _FakeStatisticsRestClient();
      repo = InMemoryChunkStatRepository();
      ChunkStatsService.instance.configure(restClient, repository: repo);
    });

    test('reportSilently submits local-file playback stats', () async {
      final stats = ChunkStat(
        songFileHash: 'file',
        songName: 'Song A',
        localChunks: 1,
      );

      await ChunkStatsService.instance.reportSilently(stats);

      expect(restClient.submitted, [stats]);
    });

    test('reportSilently submits mixed-source playback stats', () async {
      final stats = ChunkStat(
        songFileHash: 'file',
        songName: 'Song B',
        localCachedChunks: 2,
        p2pChunks: 3,
        serverChunks: 5,
      );

      await ChunkStatsService.instance.reportSilently(stats);

      expect(restClient.submitted.single.p2pPercentage, closeTo(30.0, 0.001));
    });

    test('reportSilently persists stat to local repository', () async {
      final stats = ChunkStat(
        songFileHash: 'hash-1',
        songName: 'Song C',
        p2pChunks: 4,
        serverChunks: 1,
      );

      await ChunkStatsService.instance.reportSilently(stats);

      final stored = repo.getAllStats();
      expect(stored, hasLength(1));
      expect(stored.single.songName, 'Song C');
      expect(stored.single.id, greaterThan(0));
    });

    test('getStatistics merges local and remote records by song+timestamp',
        () async {
      final localOnly = ChunkStat(
        songFileHash: 'local-only',
        songName: 'Local',
        localChunks: 1,
        timestamp: DateTime(2026, 1, 1, 12, 0, 0),
      );
      repo.saveStat(localOnly);

      final remoteOnly = ChunkStat(
        songFileHash: 'remote-only',
        songName: 'Remote',
        p2pChunks: 5,
        timestamp: DateTime(2026, 1, 2, 12, 0, 0),
      );
      restClient.remoteRecords.add(remoteOnly);

      final merged = await ChunkStatsService.instance.getStatistics();

      expect(merged.map((s) => s.songName), ['Remote', 'Local']);
    });
  });
}
