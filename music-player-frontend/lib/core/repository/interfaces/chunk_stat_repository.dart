import 'package:music_player_frontend/core/entities/chunk_stat.dart';

abstract class ChunkStatRepository {
  ChunkStat saveStat(ChunkStat stat);

  List<ChunkStat> getAllStats();

  List<ChunkStat> getStatsForSong(String songFileHash);

  void deleteStat(ChunkStat stat);

  void clearAll();
}
