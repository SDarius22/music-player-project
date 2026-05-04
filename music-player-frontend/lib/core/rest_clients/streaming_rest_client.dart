import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class StreamingRestClient extends AbstractRestClient {
  static const int _maxConcurrent = 3;
  int _active = 0;
  final Queue<Completer<void>> _waitQueue = Queue();

  StreamingRestClient({
    required String baseUrl,
    required AuthService authService,
  }) {
    super.baseUrl = baseUrl;
    super.authService = authService;
  }

  Future<void> _acquire() async {
    if (_active < _maxConcurrent) {
      _active++;
      return;
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    await completer.future;
    _active++;
  }

  void _release() {
    _active--;
    if (_waitQueue.isNotEmpty) {
      _waitQueue.removeFirst().complete();
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
    int chunkIndex,
  ) async {
    await _acquire();
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
      _release();
    }
  }
}
