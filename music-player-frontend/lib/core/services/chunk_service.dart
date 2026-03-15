import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/models/chunk_delivery_stats.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:music_player_frontend/core/services/rest_clients/streaming_rest_service.dart';
import 'package:music_player_frontend/core/services/webrtc_service.dart';

class ChunkService {
  final int songId;
  final ChunkCacheRepository cacheRepo;
  final StreamingRestService _streamingClient;
  final WebRTCService _webrtcManager;

  ChunkManifestDto? manifest;

  final Map<int, Future<Uint8List>> _activeRequests = {};
  final Map<int, Completer<Uint8List>> _p2pCompleters = {};
  final Map<int, Uint8List> _hotRamCache = {};

  // Delivery tracking: chunkIndex → true if P2P, false if server.
  final Map<int, bool> _deliveredBy = {};
  String? _songName;
  void Function(ChunkDeliveryStats)? _onFullyReceived;

  bool get isReady => manifest != null;
  int get totalBytes => manifest?.totalBytes ?? 0;
  int get totalChunks => manifest?.totalChunks ?? 0;

  ChunkService({
    required this.songId,
    required this.cacheRepo,
    required StreamingRestService streamingClient,
    required WebRTCService webrtcManager,
  }) : _streamingClient = streamingClient,
       _webrtcManager = webrtcManager;

  /// Call this right after the factory creates a ChunkService to enable
  /// per-song delivery statistics.
  void configureSongInfo(
    String songName,
    void Function(ChunkDeliveryStats)? onFullyReceived,
  ) {
    _songName = songName;
    _onFullyReceived = onFullyReceived;
  }

  Future<void> loadManifest() async {
    if (isReady) return;
    try {
      manifest = await _streamingClient.fetchManifest(songId);

      _webrtcManager.discoverPeers(songId);

      var indices = await cacheRepo.getAvailableChunkIndices(songId);
      if (indices.isNotEmpty) {
        _webrtcManager.registerCache(songId, indices);
      }
    } catch (e) {
      debugPrint("Failed to load manifest for $songId: $e");
      rethrow;
    }
  }

  Future<Uint8List> getChunk(int index) async {
    if (!isReady) await loadManifest();

    if (_hotRamCache.containsKey(index)) return _hotRamCache[index]!;

    if (_activeRequests.containsKey(index)) return _activeRequests[index]!;

    final cachedData = await cacheRepo.readChunk(songId, index);
    if (cachedData != null) {
      _addToHotCache(index, cachedData);
      return cachedData;
    }

    if (index + 1 < totalChunks) {
      _preloadChunk(index + 1);
    }

    final future = _fetchChunkLogic(index);
    _activeRequests[index] = future;

    try {
      final data = await future;
      _activeRequests.remove(index);
      return data;
    } catch (e) {
      _activeRequests.remove(index);
      rethrow;
    }
  }

  Future<void> _preloadChunk(int index) async {
    if (_activeRequests.containsKey(index) || _hotRamCache.containsKey(index)) {
      return;
    }
    try {
      await getChunk(index);
    } catch (e) {
      debugPrint("Preload failed for chunk $index: $e");
    }
  }

  Future<Uint8List> _fetchChunkLogic(int index) async {
    Uint8List data;
    bool isP2P = false;

    if (index < 8) {
      data = await _streamingClient.downloadChunkFallback(songId, index);
    } else if (_webrtcManager.hasPeersForSong(songId)) {
      try {
        data = await _requestFromPeer(index).timeout(const Duration(seconds: 5));
        isP2P = true;
        debugPrint('[P2P] song=$songId chunk=$index — served by peer');
      } catch (_) {
        _p2pCompleters.remove(index);
        debugPrint(
          '[P2P] song=$songId chunk=$index — peer timeout/fail, falling back to server',
        );
        data = await _streamingClient.downloadChunkFallback(songId, index);
      }
    } else {
      data = await _streamingClient.downloadChunkFallback(songId, index);
    }

    if (_verifyIntegrity(index, data)) {
      _saveToCache(index, data);
      _recordDelivery(index, isP2P);
      return data;
    } else {
      if (index >= 8) {
        final serverData = await _streamingClient.downloadChunkFallback(
          songId,
          index,
        );
        if (_verifyIntegrity(index, serverData)) {
          _saveToCache(index, serverData);
          _recordDelivery(index, false); // integrity fallback always = server
          return serverData;
        }
      }
      throw Exception("Integrity failed for chunk $index");
    }
  }

  void _recordDelivery(int index, bool isP2P) {
    if (_deliveredBy.containsKey(index)) return;
    _deliveredBy[index] = isP2P;

    final total = manifest?.totalChunks ?? 0;
    if (total > 0 && _deliveredBy.length == total && _onFullyReceived != null) {
      final p2pCount = _deliveredBy.values.where((v) => v).length;
      final serverCount = _deliveredBy.values.where((v) => !v).length;
      _onFullyReceived!(
        ChunkDeliveryStats(
          songId: songId,
          songName: _songName ?? 'Unknown',
          p2pChunks: p2pCount,
          serverChunks: serverCount,
        ),
      );
    }
  }

  Future<Uint8List> _requestFromPeer(int index) {
    final completer = Completer<Uint8List>();
    _p2pCompleters[index] = completer;
    _webrtcManager.requestChunk(songId, index);
    return completer.future;
  }

  void resolvePeerRequest(int chunkIndex, Uint8List data) {
    _p2pCompleters.remove(chunkIndex)?.complete(data);
  }

  bool _verifyIntegrity(int index, Uint8List data) {
    if (manifest == null || index >= manifest!.hashes.length) return false;
    final digest = sha256.convert(data).toString();
    return digest == manifest!.hashes[index];
  }

  void _saveToCache(int index, Uint8List data) {
    _addToHotCache(index, data);
    cacheRepo.saveChunk(songId, index, data).then((_) {
      _webrtcManager.registerCache(songId, [index]);
    });
  }

  void _addToHotCache(int index, Uint8List data) {
    if (_hotRamCache.length > 15) {
      _hotRamCache.remove(_hotRamCache.keys.first);
    }
    _hotRamCache[index] = data;
  }
}
