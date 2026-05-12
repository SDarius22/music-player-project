import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/albums/album_detail_dto.dart';
import 'package:music_player_frontend/core/dtos/albums/album_page_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class AlbumRestClient extends AbstractRestClient {
  static final _logger = Logger('AlbumRestClient');

  AlbumRestClient({required String baseUrl, required AuthService authService}) {
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
        _logger.warning('Failed to fetch albums: ${response.statusCode}');
      }
    } catch (e) {
      _logger.warning('Error fetching albums', e);
    }

    return AlbumPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<AlbumDetailDto?> getAlbumByHash(String albumHash) async {
    try {
      final response = await get('/albums/$albumHash');
      if (response.statusCode == 200) {
        return AlbumDetailDto.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      _logger.warning('Error fetching album by hash', e);
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
      _logger.warning('Error fetching album cover', e);
    }
    return null;
  }

  Future<SongPageDto> getAlbumSongsPage({
    required String albumHash,
    int page = 0,
    int size = 50,
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    final endpoint = '/albums/$albumHash/songs?${Uri(queryParameters: qp).query}';

    try {
      final response = await get(endpoint);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return SongPageDto.fromJson(decoded);
        }
      } else {
        _logger.warning('Failed to fetch album songs: ${response.statusCode}');
      }
    } catch (e) {
      _logger.warning('Error fetching album songs', e);
    }

    return SongPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }
}
