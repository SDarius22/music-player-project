import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_stat_repository.dart';

class InMemoryChunkStatRepository implements ChunkStatRepository {
  final List<ChunkStat> _stats = [];
  int _nextId = 1;

  @override
  ChunkStat saveStat(ChunkStat stat) {
    if (stat.id == 0) {
      stat.id = _nextId++;
      _stats.add(stat);
    } else {
      final idx = _stats.indexWhere((s) => s.id == stat.id);
      if (idx >= 0) {
        _stats[idx] = stat;
      } else {
        _stats.add(stat);
        if (stat.id >= _nextId) _nextId = stat.id + 1;
      }
    }
    return stat;
  }

  @override
  List<ChunkStat> getAllStats() {
    final list = List<ChunkStat>.from(_stats);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  @override
  List<ChunkStat> getStatsForSong(String songFileHash) {
    final list = _stats.where((s) => s.songFileHash == songFileHash).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  @override
  void deleteStat(ChunkStat stat) {
    _stats.removeWhere((s) => s.id == stat.id);
  }

  @override
  void clearAll() {
    _stats.clear();
  }
}
