import 'dart:typed_data';

import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';

class InMemoryChunkCacheRepository implements ChunkCacheRepository {
  final Map<String, Uint8List> _cache = {};

  String _key(int songId, int chunkIndex) => '$songId:$chunkIndex';

  @override
  Future<Uint8List?> readChunk(int songId, int chunkIndex) async {
    return _cache[_key(songId, chunkIndex)];
  }

  @override
  Future<void> saveChunk(int songId, int chunkIndex, Uint8List data) async {
    _cache[_key(songId, chunkIndex)] = data;
  }

  @override
  Future<List<int>> getAvailableChunkIndices(int songId) async {
    final prefix = '$songId:';
    final indices = <int>[];
    for (final key in _cache.keys) {
      if (key.startsWith(prefix)) {
        final idx = int.tryParse(key.substring(prefix.length));
        if (idx != null) indices.add(idx);
      }
    }
    indices.sort();
    return indices;
  }
}
