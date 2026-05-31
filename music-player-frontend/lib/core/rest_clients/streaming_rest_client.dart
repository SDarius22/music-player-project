import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class StreamingRestClient extends AbstractRestClient {
  static const int _maxConcurrent = 3;
  static const int _maxPrefetchConcurrent = 1;

  int _active = 0;
  int _activePrefetch = 0;

  final Queue<Completer<void>> _playbackWaiters = Queue();
  final Queue<Completer<void>> _prefetchWaiters = Queue();

  StreamingRestClient({
    required String baseUrl,
    required AuthService authService,
  }) {
    super.baseUrl = baseUrl;
    super.authService = authService;
  }

  bool _canRun(bool prefetch) {
    if (_active >= _maxConcurrent) return false;
    if (prefetch && _activePrefetch >= _maxPrefetchConcurrent) return false;
    return true;
  }

  Future<void> _acquire(bool prefetch) {
    if (_canRun(prefetch)) {
      _active++;
      if (prefetch) _activePrefetch++;
      return Future<void>.value();
    }
    final completer = Completer<void>();
    (prefetch ? _prefetchWaiters : _playbackWaiters).add(completer);
    return completer.future;
  }

  void _release(bool prefetch) {
    _active--;
    if (prefetch) _activePrefetch--;

    if (_playbackWaiters.isNotEmpty && _canRun(false)) {
      _active++;
      _playbackWaiters.removeFirst().complete();
      return;
    }
    if (_prefetchWaiters.isNotEmpty && _canRun(true)) {
      _active++;
      _activePrefetch++;
      _prefetchWaiters.removeFirst().complete();
    }
  }

  Future<ChunkManifestDto> fetchManifest(String fileHash) async {
    final response = await get('/stream/$fileHash/manifest');

    if (response.statusCode == 200) {
      return ChunkManifestDto.fromJson(jsonDecode(response.body));
    }
    throw Exception("Fetch manifest failed: ${response.statusCode}");
  }

  Future<Uint8List> downloadChunkFallback(
    String fileHash,
    int chunkIndex, {
    bool prefetch = false,
  }) async {
    await _acquire(prefetch);
    try {
      final response = await get(
        '/stream/$fileHash/chunk/$chunkIndex',
        headers: {},
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      throw Exception("Master fallback failed: ${response.statusCode}");
    } finally {
      _release(prefetch);
    }
  }
}
