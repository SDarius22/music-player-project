import 'dart:typed_data';

abstract class ChunkCacheRepository {
  Future<void> configureSong(
    String fileHash,
    int chunkSize,
    int totalBytes,
    int totalChunks,
  );

  Future<bool> finalizeSong(String fileHash);

  Future<Uint8List?> readChunk(String fileHash, int chunkIndex);

  Future<void> saveChunk(String fileHash, int chunkIndex, Uint8List data);

  Future<void> deleteChunk(String fileHash, int chunkIndex);

  Future<List<int>> getAvailableChunkIndices(String fileHash);

  Future<List<String>> getCachedFileHashes();
}
