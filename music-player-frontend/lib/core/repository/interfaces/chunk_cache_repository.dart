import 'dart:typed_data';

abstract class ChunkCacheRepository {
  Future<Uint8List?> readChunk(int songId, int chunkIndex);

  Future<void> saveChunk(int songId, int chunkIndex, Uint8List data);

  Future<List<int>> getAvailableChunkIndices(int songId);
}
