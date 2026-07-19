import 'dart:async';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:music_player_frontend/core/rest_clients/streaming_rest_client.dart';
import 'package:music_player_frontend/core/p2p/webrtc_service.dart';

enum _ChunkSource { localCached, p2p, server }

typedef CacheAvailabilityChanged =
    void Function(String fileHash, int expectedChunks, int cachedChunks);
typedef CachedManifestLoader = ChunkManifestDto? Function(String fileHash);
typedef ManifestCached = void Function(ChunkManifestDto manifest);
typedef PotentialLocalChunkLoader =
    Future<Uint8List?> Function(
      String fileHash,
      ChunkManifestDto manifest,
      int chunkIndex,
    );

class ChunkService {
  static final _logger = Logger('ChunkService');

  final String fileHash;
  final ChunkCacheRepository cacheRepo;
  final StreamingRestClient _streamingClient;
  final WebRTCService _webrtcManager;
  final CacheAvailabilityChanged? _onCacheAvailabilityChanged;
  final CachedManifestLoader? _cachedManifestLoader;
  final ManifestCached? _onManifestCached;
  final PotentialLocalChunkLoader? _potentialLocalChunkLoader;

  ChunkManifestDto? manifest;

  static const int _preloadAhead = 16;
  static const Duration _playbackPeerTimeout = Duration(milliseconds: 1700);
  static const Duration _prefetchPeerTimeout = Duration(milliseconds: 2500);
  static const Duration _peerFanoutStep = Duration(milliseconds: 150);

  final Map<int, Future<Uint8List>> _activeRequests = {};
  final Map<int, Completer<Uint8List>> _p2pCompleters = {};
  final Map<int, Uint8List> _hotRamCache = {};
  final Set<int> _availableCachedIndices = {};
  final Set<Future<void>> _pendingCacheWrites = {};
  Future<bool>? _finalizationFuture;
  Timer? _cacheAvailabilityTimer;
  int? _lastReportedCachedCount;

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
    CacheAvailabilityChanged? onCacheAvailabilityChanged,
    CachedManifestLoader? cachedManifestLoader,
    ManifestCached? onManifestCached,
    PotentialLocalChunkLoader? potentialLocalChunkLoader,
  }) : _streamingClient = streamingClient,
       _webrtcManager = webrtcManager,
       _onCacheAvailabilityChanged = onCacheAvailabilityChanged,
       _cachedManifestLoader = cachedManifestLoader,
       _onManifestCached = onManifestCached,
       _potentialLocalChunkLoader = potentialLocalChunkLoader;

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
      final cachedManifest = _cachedManifestLoader?.call(fileHash);
      if (cachedManifest?.isValidFor(fileHash) == true) {
        manifest = cachedManifest;
        _logger.fine('[P2P] Using cached manifest for file=$fileHash');
      } else {
        final serverManifest = await _streamingClient.fetchManifest(fileHash);
        if (!serverManifest.isValidFor(fileHash)) {
          throw FormatException('Invalid chunk manifest for $fileHash');
        }
        _onManifestCached?.call(serverManifest);
        manifest = serverManifest;
      }
      _logger.fine(
        '[P2P] Manifest loaded for file=$fileHash '
        'chunks=${manifest?.totalChunks ?? 0} bytes=${manifest?.totalBytes ?? 0} '
        'serverPrefix=$_serverPrefixCount',
      );

      await cacheRepo.configureSong(
        fileHash,
        manifest!.chunkSize,
        manifest!.totalBytes,
        manifest!.totalChunks,
      );

      unawaited(_webrtcManager.discoverPeers(fileHash));

      var indices = await cacheRepo.getAvailableChunkIndices(fileHash);
      _availableCachedIndices
        ..clear()
        ..addAll(indices);
      _reportCacheAvailability(force: true);
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
    if (index < 0 || index >= totalChunks) {
      throw RangeError.range(index, 0, totalChunks - 1, 'index');
    }

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
      _availableCachedIndices
        ..clear()
        ..addAll(await cacheRepo.getAvailableChunkIndices(fileHash));
      _reportCacheAvailability(force: true);
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

    final localCandidate = await _potentialLocalChunkLoader?.call(
      fileHash,
      manifest!,
      index,
    );
    if (localCandidate != null && _verifyIntegrity(index, localCandidate)) {
      _saveToCache(index, localCandidate);
      _recordDelivery(index, _ChunkSource.localCached);
      return localCandidate;
    }

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
    final pending = _p2pCompleters[index];
    if (pending != null && !pending.isCompleted) return pending.future;

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
          data = await _streamingClient.downloadChunkFallback(
            fileHash,
            index,
            prefetch: true,
          );
        } catch (_) {
          return;
        }
      }
    } else {
      try {
        data = await _streamingClient.downloadChunkFallback(
          fileHash,
          index,
          prefetch: true,
        );
      } catch (_) {
        return;
      }
    }

    if (_verifyIntegrity(index, data)) {
      _saveToCache(index, data);
      _recordDelivery(index, source);
    }
  }

  Future<void> downloadAll() async {
    if (!isReady) await loadManifest();
    for (var index = 0; index < totalChunks; index++) {
      await getChunk(index);
    }
    while (_pendingCacheWrites.isNotEmpty) {
      await Future.wait(List<Future<void>>.from(_pendingCacheWrites));
    }
    final cached = await cacheRepo.getAvailableChunkIndices(fileHash);
    _availableCachedIndices
      ..clear()
      ..addAll(cached.where((index) => index < totalChunks));
    if (_availableCachedIndices.length != totalChunks) {
      throw StateError(
        'Download incomplete for $fileHash: '
        '${_availableCachedIndices.length}/$totalChunks chunks cached',
      );
    }
    if (!await _finalizeOnce()) {
      throw StateError('Downloaded file failed final integrity verification');
    }
    _reportCacheAvailability(force: true);
  }

  void dispose() {
    _flushCacheAvailability();
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
    late final Future<void> write;
    write = cacheRepo
        .saveChunk(fileHash, index, data)
        .then((_) {
          _logger.fine(
            '[P2P] Cached chunk for file=$fileHash idx=$index bytes=${data.length}; registering for sharing',
          );
          unawaited(_webrtcManager.registerCache(fileHash, [index]));
          _availableCachedIndices.add(index);
          if (_availableCachedIndices.length >= (manifest?.totalChunks ?? 0)) {
            unawaited(_finalizeOnce());
          }
          _reportCacheAvailability();
        })
        .whenComplete(() {
          _pendingCacheWrites.remove(write);
        });
    _pendingCacheWrites.add(write);
  }

  Future<bool> _finalizeOnce() {
    final active = _finalizationFuture;
    if (active != null) return active;
    late final Future<bool> future;
    future = cacheRepo.finalizeSong(fileHash).whenComplete(() {
      if (identical(_finalizationFuture, future)) {
        _finalizationFuture = null;
      }
    });
    _finalizationFuture = future;
    return future;
  }

  void _reportCacheAvailability({bool force = false}) {
    final expected = manifest?.totalChunks ?? 0;
    if (expected == 0) return;
    final validCount =
        _availableCachedIndices.where((index) => index < expected).length;
    if (validCount == _lastReportedCachedCount) return;

    final change = (validCount - (_lastReportedCachedCount ?? 0)).abs();
    if (force || validCount >= expected || change >= 16) {
      _flushCacheAvailability();
      return;
    }

    _cacheAvailabilityTimer ??= Timer(
      const Duration(seconds: 2),
      _flushCacheAvailability,
    );
  }

  void _flushCacheAvailability() {
    _cacheAvailabilityTimer?.cancel();
    _cacheAvailabilityTimer = null;
    final expected = manifest?.totalChunks ?? 0;
    if (expected == 0) return;
    final validCount =
        _availableCachedIndices.where((index) => index < expected).length;
    if (validCount == _lastReportedCachedCount) return;
    _lastReportedCachedCount = validCount;
    _onCacheAvailabilityChanged?.call(fileHash, expected, validCount);
  }

  void _addToHotCache(int index, Uint8List data) {
    if (_hotRamCache.length >= 15) {
      _hotRamCache.remove(_hotRamCache.keys.first);
    }
    _hotRamCache[index] = data;
  }
}
