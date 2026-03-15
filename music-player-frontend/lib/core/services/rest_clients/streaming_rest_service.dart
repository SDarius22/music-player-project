import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';

class StreamingRestService {
  final String baseUrl;
  final AuthService _auth;

  static const int _maxConcurrent = 3;
  int _active = 0;
  final Queue<Completer<void>> _waitQueue = Queue();

  StreamingRestService({
    required this.baseUrl,
    required AuthService authService,
  }) : _auth = authService;

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

  Future<http.Response> _getJson(String endpoint) async {
    String? token = await _auth.accessToken;

    Future<http.Response> perform(String t) {
      return http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $t',
        },
      );
    }

    var response = await perform(token ?? "");

    if (response.statusCode == 401) {
      final newToken = await _auth.refreshAccessToken();
      if (newToken != null) return perform(newToken);
    }
    return response;
  }

  Future<http.Response> _getBinary(String endpoint) async {
    String? token = await _auth.accessToken;

    Future<http.Response> perform(String t) {
      return http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Authorization': 'Bearer $t'},
      );
    }

    var response = await perform(token ?? "");

    if (response.statusCode == 401) {
      debugPrint("401 detected. Refreshing token...");
      final newToken = await _auth.refreshAccessToken();
      if (newToken != null) return perform(newToken);
    }
    return response;
  }

  Future<ChunkManifestDto> fetchManifest(int songId) async {
    final response = await _getJson('/stream/$songId/manifest');

    if (response.statusCode == 200) {
      return ChunkManifestDto.fromJson(jsonDecode(response.body));
    }
    throw Exception("Fetch manifest failed: ${response.statusCode}");
  }

  Future<Uint8List> downloadChunkFallback(int songId, int chunkIndex) async {
    await _acquire();
    try {
      final response = await _getBinary('/stream/$songId/chunk/$chunkIndex');
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      throw Exception("Master fallback failed: ${response.statusCode}");
    } finally {
      _release();
    }
  }

  Future<Uint8List> fetchPrefix(int songId) async {
    final response = await _getBinary('/stream/$songId/prefix');

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception("Prefix fetch failed: ${response.statusCode}");
  }
}
