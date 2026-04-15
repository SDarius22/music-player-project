import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_detail_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_page_dto.dart';
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

  Future<PlaylistPageDto> getPlaylistsPage({
    int page = 0,
    int size = 50,
  }) async {
    try {
      final endpoint = '/playlists?page=$page&size=$size';
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
    String name,
    List<String> songFileHashes,
    String? coverBase64,
  ) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'songFileHashes': songFileHashes,
        if (coverBase64 != null) 'coverImage': coverBase64,
      };
      final response = await post('/playlists', body);
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
    int playlistId,
    String name,
    List<String> songFileHashes,
    String? coverBase64,
  ) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'songFileHashes': songFileHashes,
        if (coverBase64 != null) 'coverImage': coverBase64,
      };
      final response = await put('/playlists/$playlistId', body);
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
}
