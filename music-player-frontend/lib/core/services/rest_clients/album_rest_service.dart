import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/dtos/album_page_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/services/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';

class AlbumRestService extends AbstractRestService {
  AlbumRestService({required String baseUrl, required AuthService authService}) {
    super.baseUrl = baseUrl;
    super.authService = authService;
  }

  Future<AlbumPageDto> getAlbumsPage({
    String? query,
    int page = 0,
    int size = 30,
    String sort = 'name,asc',
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      'sort': sort,
    };
    if (query != null && query.trim().isNotEmpty) {
      qp['q'] = query.trim();
    }
    final endpoint = '/albums?${Uri(queryParameters: qp).query}';

    try {
      final response = await get(endpoint);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return AlbumPageDto.fromJson(decoded);
        }
      } else {
        debugPrint('Failed to fetch albums: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching albums: $e');
    }

    return AlbumPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<Album?> getAlbumById(int albumId) async {
    try {
      final response = await get('/albums/$albumId');
      if (response.statusCode == 200) {
        return Album.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error fetching album $albumId: $e');
    }
    return null;
  }

  Future<Uint8List?> getAlbumCover(int albumId) async {
    try {
      final response = await get('/albums/$albumId/cover');
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Error fetching album cover: $e');
    }
    return null;
  }
}
