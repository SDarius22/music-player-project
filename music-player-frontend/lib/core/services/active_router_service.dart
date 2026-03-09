import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/repository/chunk_cache_repo.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';

class ActiveChunkRouter {
  ChunkService? activeChunkManager;

  final ChunkCacheRepository _cacheRepo;

  ActiveChunkRouter(this._cacheRepo);

  void routeChunk(int songId, int chunkIndex, Uint8List data) {
    if (activeChunkManager != null && activeChunkManager!.songId == songId) {
      activeChunkManager!.resolvePeerRequest(chunkIndex, data);
    } else {
      debugPrint("Router: Dropped stray chunk $chunkIndex for song $songId");
    }
  }

  Future<Uint8List?> getLocalChunk(int songId, int chunkIndex) async {
    return await _cacheRepo.readChunk(songId, chunkIndex);
  }
}
