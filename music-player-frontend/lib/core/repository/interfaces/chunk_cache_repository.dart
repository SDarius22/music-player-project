import 'dart:typed_data';

abstract class ChunkCacheRepository {
  Future<Uint8List?> readChunk(String fileHash, int chunkIndex);

  Future<void> saveChunk(String fileHash, int chunkIndex, Uint8List data);

  Future<void> deleteChunk(String fileHash, int chunkIndex);

  Future<List<int>> getAvailableChunkIndices(String fileHash);
}
