import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:music_player_frontend/core/entities/song.dart';

class SyncRestService {
  final String baseUrl;

  SyncRestService({required this.baseUrl});

  Future<bool> pushDeltas(List<Song> payload) async {
    if (payload.isEmpty) return true;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload.map((e) => e.toJson()).toList()),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchManifest(int songId) async {
    debugPrint(
      "Fetching manifest for songId: $songId, URL: $baseUrl/stream/$songId/manifest",
    );
    final response = await http.get(
      Uri.parse('$baseUrl/stream/$songId/manifest'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(
      "Failed to fetch manifest with status code ${response.statusCode}",
    );
  }

  Future<Uint8List> downloadChunkFallback(int songId, int chunkIndex) async {
    final response = await http.get(
      Uri.parse('$baseUrl/stream/$songId/chunk/$chunkIndex'),
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception("Master fallback failed for chunk $chunkIndex");
  }
}
