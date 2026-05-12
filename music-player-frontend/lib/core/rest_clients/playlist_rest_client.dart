import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/playlists/create_playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_detail_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_page_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/update_playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class PlaylistRestClient extends AbstractRestClient {
  static final _logger = Logger('PlaylistRestClient');

  PlaylistRestClient({
    required String baseUrl,
    required AuthService authService,
  }) {
    super.baseUrl = baseUrl;
    super.authService = authService;
  }

  Future<PlaylistDetailDto?> getPlaylistDetails(int playlistId) async {
    try {
      final response = await get('/playlists/$playlistId');
      if (response.statusCode == 200) {
        return PlaylistDetailDto.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      _logger.warning('Error fetching playlist details', e);
    }
    return null;
  }

  Future<PlaylistDetailDto?> getPlaylistDetailsByName(
    String playlistName,
  ) async {
    try {
      final response = await get('/playlists/details-by-name/$playlistName');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return PlaylistDetailDto.fromJson(decoded);
        }
      }
    } catch (e) {
      _logger.warning('Error fetching playlist details by name', e);
    }
    return null;
  }

  Future<PlaylistPageDto> getPlaylistsPage({
    String? query,
    bool? filterIndestructible,
    bool? includeQueue,
    int page = 0,
    int size = 50,
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    if (query != null && query.trim().isNotEmpty) {
      qp['q'] = query.trim();
    }

    if (filterIndestructible != null) {
      qp['filter[indestructible]'] = filterIndestructible.toString();
    }

    if (includeQueue != null) {
      qp['includeQueue'] = includeQueue.toString();
    }

    try {
      final endpoint = '/playlists?${Uri(queryParameters: qp).query}';
      _logger.fine('Fetching playlists with endpoint: $endpoint');
      final response = await get(endpoint);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return PlaylistPageDto.fromJson(decoded);
        }
      }
    } catch (e) {
      _logger.warning('Error fetching playlists', e);
    }
    return PlaylistPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<PlaylistDetailDto?> createPlaylist(
    CreatePlaylistDto createPlaylistDto,
  ) async {
    try {
      final response = await post('/playlists', createPlaylistDto.toJson());
      if (response.statusCode == 201) {
        return PlaylistDetailDto.fromJson(jsonDecode(response.body));
      }
      _logger.warning('Failed to create playlist: ${response.statusCode}');
    } catch (e) {
      _logger.warning('Error creating playlist', e);
    }
    return null;
  }

  Future<bool> updatePlaylist(
    int playlistServerId,
    UpdatePlaylistDto updatePlaylistDto,
  ) async {
    try {
      final response = await patch(
        '/playlists/$playlistServerId',
        updatePlaylistDto.toJson(),
      );
      return response.statusCode == 200;
    } catch (e) {
      _logger.warning('Error updating playlist', e);
    }
    return false;
  }

  Future<bool> deletePlaylist(int playlistId) async {
    try {
      final response = await delete('/playlists/$playlistId');
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      _logger.warning('Error deleting playlist', e);
    }
    return false;
  }

  Future<SongPageDto> getPlaylistSongsPage({
    required int playlistId,
    int page = 0,
    int size = 50,
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    try {
      final endpoint =
          '/playlists/$playlistId/songs?${Uri(queryParameters: qp).query}';
      final response = await get(endpoint);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return SongPageDto.fromJson(decoded);
        }
      } else {
        _logger.warning(
          'Failed to fetch playlist songs: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.warning('Error fetching playlist songs', e);
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
