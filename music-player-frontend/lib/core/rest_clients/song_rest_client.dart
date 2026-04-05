import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:music_player_frontend/core/dtos/negotiation_request_dto.dart';
import 'package:music_player_frontend/core/dtos/negotiation_response_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class SongRestClient extends AbstractRestClient {
  SongRestClient({required String baseUrl, required AuthService authService}) {
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
    required String fileHash,
    required int chunkIndex,
    required List<int> chunkBytes,
    required String hash,
  }) async {
    try {
      final response = await multipartRequest(
        'POST',
        '/songs/$fileHash/chunks/$chunkIndex',
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
      final file = File(audioFilePath);
      final fileBytes = await file.readAsBytes();
      final fileHash = sha256.convert(fileBytes).toString();

      final fields = {
        'name': name,
        'artistName': artistName,
        'albumName': albumName,
        'durationInSeconds': durationInSeconds.toString(),
        'trackNumber': trackNumber.toString(),
        'discNumber': discNumber.toString(),
        'releaseYear': releaseYear.toString(),
        'photo': coverArtBytes != null ? base64Encode(coverArtBytes) : '',
        'fileHash': fileHash,
      };

      final streamedResponse = await multipartRequestWithProgress(
        'POST',
        '/songs',
        file,
        fields,
        onProgress,
      );

      if (streamedResponse.statusCode == 201) {
        onProgress(1, 1);
        return true;
      } else {
        onProgress(0, 1);
        debugPrint(
          'Full song upload failed: ${streamedResponse.statusCode} ${streamedResponse.body}',
        );
      }
    } catch (e) {
      debugPrint('Error uploading full song: $e');
    }
    return false;
  }

  Future<SongDto> getServerSong(String fileHash) async {
    try {
      final response = await get('/songs/$fileHash');

      if (response.statusCode == 200) {
        return SongDto.fromJson(jsonDecode(response.body));
      } else {
        debugPrint(
          'Failed to fetch song: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching song: $e');
    }
    throw Exception('Failed to fetch song with file hash $fileHash');
  }

  Future<SongPageDto> getSongsPage({
    String? query,
    int page = 0,
    int size = 50,
    String sort = 'name,asc',
  }) async {
    debugPrint('Fetching songs page from server...');

    final qp = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      'sort': sort,
    };
    if (query != null && query.trim().isNotEmpty) {
      qp['q'] = query.trim();
    }

    final endpoint = '/songs?${Uri(queryParameters: qp).query}';

    try {
      final response = await get(endpoint);

      if (response.statusCode == 200) {
        return SongPageDto.fromJson(jsonDecode(response.body));
      } else {
        debugPrint(
          'Failed to fetch songs: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching songs: $e');
    }

    return SongPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<SongPageDto> getRecommendations() async {
    try {
      final response = await get('/songs/recommendations');
      if (response.statusCode == 200) {
        return SongPageDto.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching recommendations: $e');
    }
    return SongPageDto(
      content: [],
      page: 0,
      size: 0,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<SongPageDto> getForgottenFavourites() async {
    try {
      final response = await get('/songs/forgotten');
      if (response.statusCode == 200) {
        return SongPageDto.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching forgotten favourites: $e');
    }
    return SongPageDto(
      content: [],
      page: 0,
      size: 0,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<SongPageDto> getQuickDial() async {
    try {
      final response = await get('/songs/quick-dial');
      if (response.statusCode == 200) {
        return SongPageDto.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching quick dial: $e');
    }
    return SongPageDto(
      content: [],
      page: 0,
      size: 0,
      totalPages: 0,
      totalElements: 0,
    );
  }
}
