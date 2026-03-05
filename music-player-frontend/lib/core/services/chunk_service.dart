import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:music_player_frontend/core/entities/chunk_manifest.dart';
import 'package:music_player_frontend/core/repository/chunk_cache_repo.dart';
import 'package:music_player_frontend/core/services/sync_rest_service.dart';
import 'package:music_player_frontend/core/services/webrtc_service.dart';

class ChunkService {
  final int songId;
  final ChunkCacheRepository cacheRepo;
  final SyncRestService restClient;
  final WebRTCService? webrtcManager;

  ChunkManifest? manifest;

  bool get isReady => manifest != null;

  int get totalBytes => isReady ? manifest!.totalBytes : 0;

  final Map<int, Completer<Uint8List>> _pendingPeerRequests = {};

  ChunkService({
    required this.songId,
    required this.cacheRepo,
    required this.restClient,
    this.webrtcManager,
  });

  Future<void> loadManifest() async {
    if (isReady) return;
    final data = await restClient.fetchManifest(songId);
    manifest = ChunkManifest.fromJson(data);

    webrtcManager?.discoverPeers(songId);
  }

  Future<Uint8List> getChunk(int chunkIndex) async {
    if (!isReady) await loadManifest();

    // 1. Mobile Edge Cache (Check local disk first, always)
    Uint8List? data = await cacheRepo.readChunk(songId, chunkIndex);
    if (data != null) return data;

    // --- PREFIX CACHING ENFORCEMENT ---
    // If this is the very first chunk of the song, NEVER wait for the WebRTC swarm.
    // Pull it directly from the Master Server to guarantee zero-latency playback startup.
    if (chunkIndex == 0) {
      data = await restClient.downloadChunkFallback(songId, 0);
      if (_verifyIntegrity(0, data)) {
        await cacheRepo.saveChunk(songId, 0, data);
        return data;
      }
      throw Exception("Master server integrity failed on Prefix Cache.");
    }
    // ----------------------------------

    // 2. WebRTC P2P Swarm (Only for Chunk 1 and beyond)
    if (webrtcManager != null && webrtcManager!.isConnected) {
      try {
        data = await _requestFromPeer(
          chunkIndex,
        ).timeout(const Duration(milliseconds: 500));
      } catch (_) {
        data = await restClient.downloadChunkFallback(songId, chunkIndex);
      }
    } else {
      // 3. Master Server Fallback
      data = await restClient.downloadChunkFallback(songId, chunkIndex);
    }

    // 4. Verification
    if (_verifyIntegrity(chunkIndex, data)) {
      await cacheRepo.saveChunk(songId, chunkIndex, data);
      webrtcManager?.registerCache(songId, [chunkIndex]);
      return data;
    } else {
      data = await restClient.downloadChunkFallback(songId, chunkIndex);
      if (_verifyIntegrity(chunkIndex, data)) {
        await cacheRepo.saveChunk(songId, chunkIndex, data);
        return data;
      }
      throw Exception("Master server integrity failed.");
    }
  }

  Future<Uint8List> _requestFromPeer(int chunkIndex) {
    final completer = Completer<Uint8List>();
    _pendingPeerRequests[chunkIndex] = completer;
    webrtcManager!.requestChunk(songId, chunkIndex);
    return completer.future;
  }

  void resolvePeerRequest(int chunkIndex, Uint8List data) {
    if (_pendingPeerRequests.containsKey(chunkIndex)) {
      _pendingPeerRequests[chunkIndex]!.complete(data);
      _pendingPeerRequests.remove(chunkIndex);
    }
  }

  bool _verifyIntegrity(int chunkIndex, Uint8List data) {
    if (chunkIndex >= manifest!.hashes.length) return false;
    final digest = sha256.convert(data);
    return digest.toString() == manifest!.hashes[chunkIndex];
  }
}
