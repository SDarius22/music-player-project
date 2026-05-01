import 'dart:typed_data';

import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';

class InMemoryChunkCacheRepository implements ChunkCacheRepository {
  final Map<String, Uint8List> _cache = {};

  String _key(String fileHash, int chunkIndex) => '$fileHash:$chunkIndex';

  @override
  Future<Uint8List?> readChunk(String fileHash, int chunkIndex) async {
    return _cache[_key(fileHash, chunkIndex)];
  }

  @override
  Future<void> saveChunk(String fileHash, int chunkIndex, Uint8List data) async {
    _cache[_key(fileHash, chunkIndex)] = data;
  }

  @override
  Future<void> deleteChunk(String fileHash, int chunkIndex) async {
    _cache.remove(_key(fileHash, chunkIndex));
  }

  @override
  Future<List<int>> getAvailableChunkIndices(String fileHash) async {
    final prefix = '$fileHash:';
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
