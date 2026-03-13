import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:music_player_frontend/core/dtos/negotiation_request_dto.dart';
import 'package:music_player_frontend/core/dtos/negotiation_response_dto.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';

class SongRestService extends AbstractRestService {
  SongRestService({required String baseUrl, required AuthService authService}) {
    super.baseUrl = baseUrl;
    super.authService = authService;
  }

  Future<NegotiationResponseDto?> negotiateUpload(
    NegotiationRequestDto request,
  ) async {
    try {
      final response = await post('/songs/negotiate', request.toJson());

      if (response.statusCode == 200) {
        return NegotiationResponseDto.fromJson(jsonDecode(response.body));
      } else {
        debugPrint(
          'Negotiation failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error negotiating upload: $e');
    }
    return null;
  }

  Future<bool> uploadChunk({
    required int songId,
    required int chunkIndex,
    required List<int> chunkBytes,
    required String hash,
  }) async {
    try {
      final response = await multipartRequest(
        'POST',
        '/songs/$songId/chunks/$chunkIndex',
        fields: {'contentHash': hash},
        files: [
          http.MultipartFile.fromBytes(
            'chunkData',
            chunkBytes,
            filename: 'chunk_$chunkIndex.bin',
          ),
        ],
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        debugPrint(
          'Chunk upload failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error uploading chunk: $e');
    }
    return false;
  }

  Future<Song?> finalizeSong(int songId) async {
    try {
      final response = await post('/songs/$songId/finalize', {});

      if (response.statusCode == 200) {
        return Song.fromJson(jsonDecode(response.body));
      } else {
        debugPrint('Finalize failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error finalizing song: $e');
    }
    return null;
  }

  Future<Uint8List?> fetchCoverArt(int songId) async {
    try {
      final response = await get('/songs/$songId/cover');

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Error fetching cover art: $e');
    }
    return null;
  }

  Future<bool> uploadFullSong({
    required String audioFilePath,
    required String name,
    required String artistName,
    required String albumName,
    required int durationInSeconds,
    required int trackNumber,
    required int discNumber,
    required int releaseYear,
    required Uint8List? coverArtBytes,
    required void Function(int sentBytes, int totalBytes) onProgress,
  }) async {
    try {
      final fields = {
        'name': name,
        'artistName': artistName,
        'albumName': albumName,
        'durationInSeconds': durationInSeconds.toString(),
        'trackNumber': trackNumber.toString(),
        'discNumber': discNumber.toString(),
        'releaseYear': releaseYear.toString(),
        'photo': coverArtBytes != null ? base64Encode(coverArtBytes) : '',
      };

      final file = File(audioFilePath);

      final streamedResponse = await multipartRequestWithProgress(
        'POST',
        '/songs',
        file,
        fields,
        onProgress,
      );

      if (streamedResponse.statusCode == 201) {
        onProgress(1, 1); // Mark as complete
        return true;
      } else {
        debugPrint(
          'Full song upload failed: ${streamedResponse.statusCode} ${streamedResponse.body}',
        );
      }
    } catch (e) {
      debugPrint('Error uploading full song: $e');
    }
    return false;
  }

  Future<Song> getServerSong(int songId) async {
    try {
      final response = await get('/songs/$songId');

      if (response.statusCode == 200) {
        return Song.fromJson(jsonDecode(response.body));
      } else {
        debugPrint(
          'Failed to fetch song: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching song: $e');
    }
    throw Exception('Failed to fetch song with ID $songId');
  }

  Future<List<Song>> getAllSongs() async {
    try {
      final response = await get('/songs');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Song.fromJson(json)).toList();
      } else {
        debugPrint(
          'Failed to fetch songs: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching songs: $e');
    }
    return [];
  }
}
