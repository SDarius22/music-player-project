import 'package:music_player_frontend/core/database/object_box_store.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_stat_repository.dart';

class ObjectBoxChunkStatRepository implements ChunkStatRepository {
  Box<ChunkStat> get _box => ObjectBox.store.box<ChunkStat>();

  @override
  ChunkStat saveStat(ChunkStat stat) {
    stat.id = _box.put(stat);
    return stat;
  }

  @override
  List<ChunkStat> getAllStats() {
    final query =
        (_box.query()..order(ChunkStat_.timestamp, flags: Order.descending))
            .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  @override
  List<ChunkStat> getStatsForSong(String songFileHash) {
    final query =
        (_box.query(ChunkStat_.songFileHash.equals(songFileHash))
              ..order(ChunkStat_.timestamp, flags: Order.descending))
            .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  @override
  void deleteStat(ChunkStat stat) {
    _box.remove(stat.id);
  }

  @override
  void clearAll() {
    _box.removeAll();
  }
}
