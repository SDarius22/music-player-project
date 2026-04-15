import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';

class ActiveChunkRouter {
  static final _logger = Logger('ActiveChunkRouter');

  final Map<String, ChunkService> _activeManagers = {};
  final ChunkCacheRepository _cacheRepo;

  ActiveChunkRouter(this._cacheRepo);

  void registerManager(ChunkService manager) {
    _activeManagers[manager.fileHash] = manager;
    if (_activeManagers.length > 5) {
      _activeManagers.remove(_activeManagers.keys.first);
    }
  }

  void routeChunk(String fileHash, int chunkIndex, Uint8List data) {
    if (_activeManagers.containsKey(fileHash)) {
      _activeManagers[fileHash]!.resolvePeerRequest(chunkIndex, data);
    } else {
      _logger.fine('Router: Dropped stray chunk $chunkIndex for song $fileHash');
    }
  }

  Future<Uint8List?> getLocalChunk(String fileHash, int chunkIndex) async {
    return await _cacheRepo.readChunk(fileHash, chunkIndex);
  }
}
