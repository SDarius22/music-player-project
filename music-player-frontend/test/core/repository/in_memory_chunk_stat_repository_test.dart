import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_chunk_stat_repository.dart';

void main() {
  group('InMemoryChunkStatRepository', () {
    late InMemoryChunkStatRepository repo;

    setUp(() {
      repo = InMemoryChunkStatRepository();
    });

    test('saveStat assigns an id and stores the record', () {
      final stat = ChunkStat(songFileHash: 'h1', songName: 'A', p2pChunks: 3);

      final saved = repo.saveStat(stat);

      expect(saved.id, greaterThan(0));
      expect(repo.getAllStats(), hasLength(1));
    });

    test('getAllStats returns stats sorted newest first', () {
      repo.saveStat(
        ChunkStat(
          songFileHash: 'h1',
          songName: 'older',
          timestamp: DateTime(2026, 1, 1),
        ),
      );
      repo.saveStat(
        ChunkStat(
          songFileHash: 'h2',
          songName: 'newer',
          timestamp: DateTime(2026, 5, 1),
        ),
      );

      final all = repo.getAllStats();

      expect(all.map((s) => s.songName), ['newer', 'older']);
    });

    test('getStatsForSong filters by file hash', () {
      repo.saveStat(ChunkStat(songFileHash: 'h1', songName: 'first'));
      repo.saveStat(ChunkStat(songFileHash: 'h2', songName: 'second'));
      repo.saveStat(ChunkStat(songFileHash: 'h1', songName: 'third'));

      final stats = repo.getStatsForSong('h1');

      expect(stats.map((s) => s.songName), containsAll(['first', 'third']));
      expect(stats, hasLength(2));
    });

    test('deleteStat removes the stat by id', () {
      final s1 = repo.saveStat(ChunkStat(songFileHash: 'h', songName: 'A'));
      repo.saveStat(ChunkStat(songFileHash: 'h', songName: 'B'));

      repo.deleteStat(s1);

      expect(repo.getAllStats().map((s) => s.songName), ['B']);
    });

    test('clearAll empties the repository', () {
      repo.saveStat(ChunkStat(songFileHash: 'h', songName: 'A'));
      repo.saveStat(ChunkStat(songFileHash: 'h', songName: 'B'));

      repo.clearAll();

      expect(repo.getAllStats(), isEmpty);
    });
  });
}
