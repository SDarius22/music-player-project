import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_detail_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_page_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class ArtistRestClient extends AbstractRestClient {
  static final _logger = Logger('ArtistRestClient');

  ArtistRestClient({
    required String baseUrl,
    required AuthService authService,
  }) {
    super.baseUrl = baseUrl;
    super.authService = authService;
  }

  Future<ArtistPageDto> getArtistsPage({
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
    final endpoint = '/artists?${Uri(queryParameters: qp).query}';

    try {
      final response = await get(endpoint);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return ArtistPageDto.fromJson(decoded);
        }
      } else {
        _logger.warning('Failed to fetch artists: ${response.statusCode}');
      }
    } catch (e) {
      _logger.warning('Error fetching artists', e);
    }

    return ArtistPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<ArtistDetailDto?> getArtistByHash(String artistHash) async {
    try {
      final response = await get('/artists/$artistHash');
      if (response.statusCode == 200) {
        return ArtistDetailDto.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      _logger.warning('Error fetching artist with hash: $artistHash', e);
    }
    return null;
  }

  Future<SongPageDto> getArtistSongsPage({
    required String artistHash,
    int page = 0,
    int size = 50,
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    final endpoint = '/artists/$artistHash/songs?${Uri(queryParameters: qp).query}';

    try {
      final response = await get(endpoint);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return SongPageDto.fromJson(decoded);
        }
      } else {
        _logger.warning('Failed to fetch artist songs: ${response.statusCode}');
      }
    } catch (e) {
      _logger.warning('Error fetching artist songs', e);
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
