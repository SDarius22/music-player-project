import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:music_player_frontend/core/dtos/negotiation_request_dto.dart';
import 'package:music_player_frontend/core/dtos/negotiation_response_dto.dart';
import 'package:music_player_frontend/core/dtos/song_page_dto.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';

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

  CachedNetworkImage fetchCoverArt(int songId) {
    return CachedNetworkImage(
      imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
      imageUrl: '$baseUrl/songs/$songId/cover',
      httpHeaders: {'Authorization': 'Bearer ${authService.accessToken}'},
      errorWidget: (context, url, error) {
        debugPrint('Error fetching cover art: $error');
        return Container(
          color: Colors.black,
          child: Icon(
            FluentIcons.music,
            color: Colors.white.withValues(alpha: 0.25),
            size: 64,
          ),
        );
      },
    );
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
        onProgress(1, 1); // Mark as complete
        return true;
      } else {
        onProgress(0, 1); // Reset progress on failure
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
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          return SongPageDto.fromJson(decoded);
        }
        if (decoded is List) {
          final songs =
              decoded
                  .map((e) => Song.fromJson(e as Map<String, dynamic>))
                  .toList();
          return SongPageDto(
            content: songs,
            page: 0,
            size: songs.length,
            totalPages: 1,
            totalElements: songs.length,
          );
        }
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

  Future<List<Song>> getRecommendations() async {
    try {
      final response = await get('/songs/recommendations');
      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        return decoded
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching recommendations: $e');
    }
    return [];
  }

  Future<List<Song>> getForgottenFavourites() async {
    try {
      final response = await get('/songs/forgotten');
      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        return decoded
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching forgotten favourites: $e');
    }
    return [];
  }

  Future<List<Song>> getQuickDial() async {
    try {
      final response = await get('/songs/quick-dial');
      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        return decoded
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching quick dial: $e');
    }
    return [];
  }

  Future<List<Song>> getAllSongs() async {
    final page = await getSongsPage(page: 0, size: 200);
    debugPrint('Fetched ${page.content.length} songs from server.');
    if (page.content.isNotEmpty) {
      final s = page.content.first;
      debugPrint('First song: ${s.name}, ${s.id}, ${s.serverId}, ${s.path}');
    }
    return page.content;
  }
}
