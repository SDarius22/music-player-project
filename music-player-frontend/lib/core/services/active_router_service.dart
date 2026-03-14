import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';

class ActiveChunkRouter {
  final Map<int, ChunkService> _activeManagers = {};
  final ChunkCacheRepository _cacheRepo;

  ActiveChunkRouter(this._cacheRepo);

  void registerManager(ChunkService manager) {
    _activeManagers[manager.songId] = manager;
    if (_activeManagers.length > 5) {
      _activeManagers.remove(_activeManagers.keys.first);
    }
  }

  void routeChunk(int songId, int chunkIndex, Uint8List data) {
    if (_activeManagers.containsKey(songId)) {
      _activeManagers[songId]!.resolvePeerRequest(chunkIndex, data);
    } else {
      debugPrint("Router: Dropped stray chunk $chunkIndex for song $songId");
    }
  }

  Future<Uint8List?> getLocalChunk(int songId, int chunkIndex) async {
    return await _cacheRepo.readChunk(songId, chunkIndex);
  }
}
