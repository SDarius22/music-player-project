import 'dart:async';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/models/chunk_delivery_stats.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:music_player_frontend/core/services/rest_clients/streaming_rest_service.dart';
import 'package:music_player_frontend/core/services/webrtc_service.dart';

enum _ChunkSource { localCached, p2p, server }

class ChunkService {
  final String fileHash;
  final ChunkCacheRepository cacheRepo;
  final StreamingRestService _streamingClient;
  final WebRTCService _webrtcManager;

  ChunkManifestDto? manifest;

  static const int _preloadAhead = 16;

  final Map<int, Future<Uint8List>> _activeRequests = {};
  final Map<int, Completer<Uint8List>> _p2pCompleters = {};
  final Map<int, Uint8List> _hotRamCache = {};

  final Map<int, _ChunkSource> _deliveredBy = {};
  String? _songName;
  void Function(ChunkDeliveryStats)? _onFullyReceived;
  bool _statsFlushed = false;

  bool get isReady => manifest != null;

  String? get songName => _songName;

  int get totalBytes => manifest?.totalBytes ?? 0;

  int get totalChunks => manifest?.totalChunks ?? 0;

  // First N chunks always fetched from server for reliable playback start.
  // Equals 5 % of totalChunks, minimum 1.
  int get _serverPrefixCount => max(1, (totalChunks * 0.05).round());

  ChunkService({
    required this.fileHash,
    required this.cacheRepo,
    required StreamingRestService streamingClient,
    required WebRTCService webrtcManager,
  }) : _streamingClient = streamingClient,
       _webrtcManager = webrtcManager;

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
      manifest = await _streamingClient.fetchManifest(fileHash);

      unawaited(_webrtcManager.discoverPeers(fileHash));

      var indices = await cacheRepo.getAvailableChunkIndices(fileHash);
      if (indices.isNotEmpty) {
        unawaited(_webrtcManager.registerCache(fileHash, indices));
      }
    } catch (e) {
      debugPrint("Failed to load manifest for $fileHash: $e");
      rethrow;
    }
  }

  Future<Uint8List> getChunk(int index) async {
    if (!isReady) await loadManifest();

    if (_hotRamCache.containsKey(index)) return _hotRamCache[index]!;

    if (_activeRequests.containsKey(index)) return _activeRequests[index]!;

    final cachedData = await cacheRepo.readChunk(fileHash, index);
    if (cachedData != null) {
      _addToHotCache(index, cachedData);
      _recordDelivery(index, _ChunkSource.localCached);
      return cachedData;
    }

    for (
      var i = index + 1;
      i <= index + _preloadAhead && i < totalChunks;
      i++
    ) {
      _preloadChunk(i);
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
    final future = _fetchChunkLogic(index);
    _activeRequests[index] = future;
    try {
      await future;
    } catch (e) {
      debugPrint("Preload failed for chunk $index: $e");
    } finally {
      _activeRequests.remove(index);
    }
  }

  Future<Uint8List> _fetchChunkLogic(int index) async {
    Uint8List data;
    _ChunkSource source = _ChunkSource.server;

    if (index < _serverPrefixCount) {
      data = await _streamingClient.downloadChunkFallback(fileHash, index);
    } else {
      final peers = _webrtcManager.getSortedPeersForSong(fileHash);
      if (peers.isNotEmpty) {
        try {
          data = await _requestFromPeers(index, peers).timeout(
            const Duration(seconds: 1),
          );
          source = _ChunkSource.p2p;
          debugPrint('[P2P] song=$fileHash chunk=$index — served by peer');
        } catch (_) {
          _p2pCompleters.remove(index);
          debugPrint(
            '[P2P] song=$fileHash chunk=$index — peer timeout/fail, falling back to server',
          );
          data = await _streamingClient.downloadChunkFallback(fileHash, index);
        }
      } else {
        data = await _streamingClient.downloadChunkFallback(fileHash, index);
      }
    }

    if (_verifyIntegrity(index, data)) {
      _saveToCache(index, data);
      _recordDelivery(index, source);
      return data;
    } else {
      if (index >= 8) {
        final serverData = await _streamingClient.downloadChunkFallback(
          fileHash,
          index,
        );
        if (_verifyIntegrity(index, serverData)) {
          _saveToCache(index, serverData);
          _recordDelivery(index, _ChunkSource.server);
          return serverData;
        }
      }
      throw Exception("Integrity failed for chunk $index");
    }
  }

  void _recordDelivery(int index, _ChunkSource source) {
    if (_deliveredBy.containsKey(index)) return;
    _deliveredBy[index] = source;

    final total = manifest?.totalChunks ?? 0;
    if (total > 0 && _deliveredBy.length == total) {
      _emitStats();
    }
  }

  void _emitStats() {
    if (_statsFlushed || _onFullyReceived == null || _deliveredBy.isEmpty) {
      return;
    }
    _statsFlushed = true;
    _onFullyReceived!(
      ChunkDeliveryStats(
        fileHash: fileHash,
        songName: _songName ?? 'Unknown',
        localCachedChunks:
            _deliveredBy.values.where((v) => v == _ChunkSource.localCached).length,
        p2pChunks: _deliveredBy.values.where((v) => v == _ChunkSource.p2p).length,
        serverChunks:
            _deliveredBy.values.where((v) => v == _ChunkSource.server).length,
      ),
    );
  }

  /// Emits delivery stats for however many chunks were received so far.
  /// Call when the song is skipped or stopped before completion.
  /// Safe to call multiple times — only fires once.
  void flushStats() => _emitStats();

  /// Requests [index] from the peers in [peers] (sorted best-first).
  /// Cascades to the next peer every 200 ms so the first responder wins.
  Future<Uint8List> _requestFromPeers(int index, List<String> peers) {
    final completer = Completer<Uint8List>();
    _p2pCompleters[index] = completer;

    _webrtcManager.requestChunkFromPeer(peers[0], fileHash, index);

    for (var i = 1; i < peers.length && i <= 2; i++) {
      final peerId = peers[i];
      Future.delayed(Duration(milliseconds: 200 * i), () {
        if (!completer.isCompleted) {
          _webrtcManager.requestChunkFromPeer(peerId, fileHash, index);
        }
      });
    }

    return completer.future;
  }

  void resolvePeerRequest(int chunkIndex, Uint8List data) {
    _p2pCompleters.remove(chunkIndex)?.complete(data);
  }

  /// Background prefetch: tries peers first for ALL indices (no server-prefix
  /// rule) since we have time to wait. Falls back to server. Silent on error.
  Future<void> prefetchChunk(int index) async {
    if (!isReady || index >= totalChunks) return;
    if (_hotRamCache.containsKey(index)) return;
    final cached = await cacheRepo.readChunk(fileHash, index);
    if (cached != null) return;
    if (_activeRequests.containsKey(index)) {
      await _activeRequests[index];
      return;
    }

    Uint8List data;
    final peers = _webrtcManager.getSortedPeersForSong(fileHash);
    if (peers.isNotEmpty) {
      try {
        data = await _requestFromPeers(index, peers).timeout(
          const Duration(seconds: 2),
        );
      } catch (_) {
        _p2pCompleters.remove(index);
        try {
          data = await _streamingClient.downloadChunkFallback(fileHash, index);
        } catch (_) {
          return;
        }
      }
    } else {
      try {
        data = await _streamingClient.downloadChunkFallback(fileHash, index);
      } catch (_) {
        return;
      }
    }

    if (_verifyIntegrity(index, data)) {
      _saveToCache(index, data);
    }
  }

  /// Returns true if the chunk was served by a peer, false otherwise,
  /// or null if the chunk has not been fetched yet.
  bool? wasServedByP2P(int chunkIndex) {
    final source = _deliveredBy[chunkIndex];
    if (source == null) return null;
    return source == _ChunkSource.p2p;
  }

  bool _verifyIntegrity(int index, Uint8List data) {
    if (manifest == null || index >= manifest!.hashes.length) return false;
    final digest = sha256.convert(data).toString();
    return digest == manifest!.hashes[index];
  }

  void _saveToCache(int index, Uint8List data) {
    _addToHotCache(index, data);
    cacheRepo.saveChunk(fileHash, index, data).then((_) {
      unawaited(_webrtcManager.registerCache(fileHash, [index]));
    });
  }

  void _addToHotCache(int index, Uint8List data) {
    if (_hotRamCache.length > 15) {
      _hotRamCache.remove(_hotRamCache.keys.first);
    }
    _hotRamCache[index] = data;
  }
}
