import 'dart:async';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:music_player_frontend/core/rest_clients/streaming_rest_client.dart';
import 'package:music_player_frontend/core/services/webrtc_service.dart';

enum _ChunkSource { localCached, p2p, server }

class ChunkService {
  static final _logger = Logger('ChunkService');

  final String fileHash;
  final ChunkCacheRepository cacheRepo;
  final StreamingRestClient _streamingClient;
  final WebRTCService _webrtcManager;

  ChunkManifestDto? manifest;

  static const int _preloadAhead = 16;
  static const Duration _playbackPeerTimeout = Duration(milliseconds: 1700);
  static const Duration _prefetchPeerTimeout = Duration(milliseconds: 2500);
  static const Duration _peerFanoutStep = Duration(milliseconds: 150);

  final Map<int, Future<Uint8List>> _activeRequests = {};
  final Map<int, Completer<Uint8List>> _p2pCompleters = {};
  final Map<int, Uint8List> _hotRamCache = {};

  final Map<int, _ChunkSource> _deliveredBy = {};
  String? _songName;
  void Function(ChunkStat)? _onFullyReceived;
  static const Duration _statsEmitInterval = Duration(seconds: 15);
  Timer? _statsEmitTimer;
  int _lastReportedDeliveredCount = 0;

  bool get isReady => manifest != null;

  String? get songName => _songName;

  int get totalBytes => manifest?.totalBytes ?? 0;

  int get totalChunks => manifest?.totalChunks ?? 0;

  int get availablePeerCount =>
      _webrtcManager.getSortedPeersForSong(fileHash).length;

  ValueNotifier<int> get peerStateVersionNotifier =>
      _webrtcManager.peerStateVersionNotifier;

  int get _serverPrefixCount => max(1, (totalChunks * 0.05).round());

  ChunkService({
    required this.fileHash,
    required this.cacheRepo,
    required StreamingRestClient streamingClient,
    required WebRTCService webrtcManager,
  }) : _streamingClient = streamingClient,
       _webrtcManager = webrtcManager;

  void configureSongInfo(
    String songName,
    void Function(ChunkStat)? onFullyReceived,
  ) {
    _songName = songName;
    _onFullyReceived = onFullyReceived;
    _startPeriodicStatsEmission();
  }

  void _startPeriodicStatsEmission() {
    if (_statsEmitTimer != null || _onFullyReceived == null) return;
    _statsEmitTimer = Timer.periodic(_statsEmitInterval, (_) {
      _emitStats();
    });
  }

  Future<void> loadManifest() async {
    if (isReady) return;
    try {
      manifest = await _streamingClient.fetchManifest(fileHash);
      _logger.fine(
        '[P2P] Manifest loaded for file=$fileHash '
        'chunks=${manifest?.totalChunks ?? 0} bytes=${manifest?.totalBytes ?? 0} '
        'serverPrefix=$_serverPrefixCount',
      );

      unawaited(_webrtcManager.discoverPeers(fileHash));

      var indices = await cacheRepo.getAvailableChunkIndices(fileHash);
      if (indices.isNotEmpty) {
        _logger.fine(
          '[P2P] Registering ${indices.length} cached chunk(s) for file=$fileHash after manifest load',
        );
        unawaited(_webrtcManager.registerCache(fileHash, indices));
      }
    } catch (e) {
      _logger.fine("Failed to load manifest for $fileHash: $e");
      rethrow;
    }
  }

  Future<Uint8List> getChunk(int index) async {
    if (!isReady) await loadManifest();

    if (_hotRamCache.containsKey(index)) return _hotRamCache[index]!;

    if (_activeRequests.containsKey(index)) return _activeRequests[index]!;

    final cachedData = await cacheRepo.readChunk(fileHash, index);
    if (cachedData != null) {
      if (_verifyIntegrity(index, cachedData)) {
        _addToHotCache(index, cachedData);
        _recordDelivery(index, _ChunkSource.localCached);
        return cachedData;
      }
      _logger.warning(
        '[P2P] Corrupt cache hit for file=$fileHash idx=$index '
        '(bytes=${cachedData.length}); evicting and refetching',
      );
      await cacheRepo.deleteChunk(fileHash, index);
    }

    final future = _fetchChunkLogic(index);
    _activeRequests[index] = future;

    for (
      var i = index + 1;
      i <= index + _preloadAhead && i < totalChunks;
      i++
    ) {
      _preloadChunk(i);
    }

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
      _logger.fine("Preload failed for chunk $index: $e");
    } finally {
      _activeRequests.remove(index);
    }
  }

  Future<Uint8List> _fetchChunkLogic(int index) async {
    Uint8List data;
    _ChunkSource source = _ChunkSource.server;

    if (index < _serverPrefixCount) {
      _logger.fine(
        '[P2P] Chunk idx=$index file=$fileHash forced to server bootstrap prefix '
        'prefixCount=$_serverPrefixCount',
      );
      data = await _streamingClient.downloadChunkFallback(fileHash, index);
    } else {
      final peers = _webrtcManager.getSortedPeersForChunk(fileHash, index);
      if (peers.isNotEmpty) {
        _logger.fine(
          '[P2P] Attempting peer fetch for file=$fileHash idx=$index peers=${peers.take(3).join(',')}',
        );
        try {
          data = await _requestFromPeers(
            index,
            peers,
          ).timeout(_playbackPeerTimeout);
          source = _ChunkSource.p2p;
        } catch (e) {
          _logger.fine(
            '[P2P] Peer fetch failed/timed out for file=$fileHash idx=$index; '
            'falling back to server: $e',
          );
          _p2pCompleters.remove(index);
          data = await _streamingClient.downloadChunkFallback(fileHash, index);
        }
      } else {
        _logger.fine(
          '[P2P] No peers available for file=$fileHash idx=$index; using server',
        );
        data = await _streamingClient.downloadChunkFallback(fileHash, index);
      }
    }

    if (_verifyIntegrity(index, data)) {
      _saveToCache(index, data);
      _recordDelivery(index, source);
      return data;
    }

    if (source != _ChunkSource.server) {
      _logger.warning(
        '[P2P] Integrity failed for file=$fileHash idx=$index from $source; '
        'attempting server recovery',
      );
      final serverData = await _streamingClient.downloadChunkFallback(
        fileHash,
        index,
      );
      if (_verifyIntegrity(index, serverData)) {
        _logger.fine(
          '[P2P] Integrity recovery succeeded from server for file=$fileHash idx=$index',
        );
        _saveToCache(index, serverData);
        _recordDelivery(index, _ChunkSource.server);
        return serverData;
      }
    }

    throw Exception("Integrity failed for chunk $index");
  }

  void _recordDelivery(int index, _ChunkSource source) {
    if (_deliveredBy.containsKey(index)) return;
    _deliveredBy[index] = source;

    final total = manifest?.totalChunks ?? 0;
    if (total > 0 && _deliveredBy.length == total) {
      _emitStats(force: true);
    }
  }

  void _emitStats({bool force = false}) {
    if (_onFullyReceived == null || _deliveredBy.isEmpty) {
      return;
    }

    final deliveredCount = _deliveredBy.length;
    if (!force && deliveredCount == _lastReportedDeliveredCount) {
      return;
    }

    _lastReportedDeliveredCount = deliveredCount;

    _onFullyReceived!(
      ChunkStat(
        songFileHash: fileHash,
        songName: _songName ?? 'Unknown',
        localCachedChunks:
            _deliveredBy.values
                .where((v) => v == _ChunkSource.localCached)
                .length,
        p2pChunks:
            _deliveredBy.values.where((v) => v == _ChunkSource.p2p).length,
        serverChunks:
            _deliveredBy.values.where((v) => v == _ChunkSource.server).length,
      ),
    );
  }

  void flushStats() => _emitStats(force: true);

  Future<Uint8List> _requestFromPeers(int index, List<String> peers) {
    final completer = Completer<Uint8List>();
    _p2pCompleters[index] = completer;

    final peersToTry = peers.take(3).toList(growable: false);
    _logger.fine(
      '[P2P] Scheduling peer fanout for file=$fileHash idx=$index peers=${peersToTry.join(',')}',
    );

    _webrtcManager.requestChunkFromPeer(peersToTry[0], fileHash, index);

    for (var i = 1; i < peersToTry.length; i++) {
      final peerId = peersToTry[i];
      Future.delayed(_peerFanoutStep * i, () {
        if (!completer.isCompleted) {
          _webrtcManager.requestChunkFromPeer(peerId, fileHash, index);
        }
      });
    }

    return completer.future;
  }

  void resolvePeerRequest(int chunkIndex, Uint8List data) {
    _logger.fine(
      '[P2P] Resolving peer request for file=$fileHash idx=$chunkIndex bytes=${data.length}',
    );
    _p2pCompleters.remove(chunkIndex)?.complete(data);
  }

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
    _ChunkSource source = _ChunkSource.server;
    final peers = _webrtcManager.getSortedPeersForChunk(fileHash, index);
    if (peers.isNotEmpty) {
      _logger.fine(
        '[P2P] Prefetch attempting peer fetch for file=$fileHash idx=$index peers=${peers.take(3).join(',')}',
      );
      try {
        data = await _requestFromPeers(
          index,
          peers,
        ).timeout(_prefetchPeerTimeout);
        source = _ChunkSource.p2p;
      } catch (e) {
        _logger.fine(
          '[P2P] Prefetch peer fetch failed/timed out for file=$fileHash idx=$index; '
          'falling back to server: $e',
        );
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
      _recordDelivery(index, source);
    }
  }

  void dispose() {
    _statsEmitTimer?.cancel();
    _statsEmitTimer = null;
  }

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
      _logger.fine(
        '[P2P] Cached chunk for file=$fileHash idx=$index bytes=${data.length}; registering for sharing',
      );
      unawaited(_webrtcManager.registerCache(fileHash, [index]));
    });
  }

  void _addToHotCache(int index, Uint8List data) {
    if (_hotRamCache.length >= 15) {
      _hotRamCache.remove(_hotRamCache.keys.first);
    }
    _hotRamCache[index] = data;
  }
}
