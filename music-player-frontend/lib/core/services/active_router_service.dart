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
    _activeManagers.remove(manager.fileHash);
    _activeManagers[manager.fileHash] = manager;
  }

  void unregisterManager(ChunkService manager) {
    if (identical(_activeManagers[manager.fileHash], manager)) {
      _activeManagers.remove(manager.fileHash);
    }
  }

  void routeChunk(String fileHash, int chunkIndex, Uint8List data) {
    if (_activeManagers.containsKey(fileHash)) {
      _activeManagers[fileHash]!.resolvePeerRequest(chunkIndex, data);
    } else {
      _logger.fine(
        'Router: Dropped stray chunk $chunkIndex for song $fileHash; '
        'registered keys=${_activeManagers.keys.toList()}',
      );
    }
  }

  Future<Uint8List?> getLocalChunk(String fileHash, int chunkIndex) async {
    return await _cacheRepo.readChunk(fileHash, chunkIndex);
  }
}
