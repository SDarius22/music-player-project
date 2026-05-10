import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/negotiation_request_dto.dart';
import 'package:music_player_frontend/core/dtos/negotiation_response_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class SongRestClient extends AbstractRestClient {
  static final _logger = Logger('SongRestClient');

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
        _logger.warning(
          'Negotiation failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _logger.warning('Error negotiating upload', e);
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
        _logger.warning(
          'Chunk upload failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _logger.warning('Error uploading chunk', e);
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
        _logger.warning(
          'Full song upload failed: ${streamedResponse.statusCode} ${streamedResponse.body}',
        );
      }
    } catch (e) {
      _logger.warning('Error uploading full song', e);
    }
    return false;
  }

  Future<SongDto> getServerSong(String fileHash) async {
    try {
      final response = await get('/songs/$fileHash');

      if (response.statusCode == 200) {
        return SongDto.fromJson(jsonDecode(response.body));
      } else {
        _logger.warning(
          'Failed to fetch song: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _logger.warning('Error fetching song', e);
    }
    throw Exception('Failed to fetch song with file hash $fileHash');
  }

  Future<SongPageDto> getSongsPage({
    String? query,
    String? filterAlbumHash,
    String? filterArtistHash,
    int? filterPlaylistId,
    int page = 0,
    int size = 50,
    String sort = 'name,asc',
  }) async {
    _logger.fine('Fetching songs page from server...');

    final qp = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      'sort': sort,
    };
    if (query != null && query.trim().isNotEmpty) {
      qp['q'] = query.trim();
    }
    if (filterAlbumHash != null) {
      qp['filter[albumHash]'] = filterAlbumHash;
    }
    if (filterArtistHash != null) {
      qp['filter[artistHash]'] = filterArtistHash;
    }
    if (filterPlaylistId != null) {
      qp['filter[playlistId]'] = filterPlaylistId.toString();
    }

    final endpoint = '/songs?${Uri(queryParameters: qp).query}';

    try {
      final response = await get(endpoint);

      if (response.statusCode == 200) {
        return SongPageDto.fromJson(jsonDecode(response.body));
      } else {
        _logger.warning(
          'Failed to fetch songs: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _logger.warning('Error fetching songs', e);
    }

    return SongPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<SongPageDto> getRecommendations({int page = 0, int size = 10}) async {
    final qp = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    try {
      final response = await get(
        '/songs/recommendations?${Uri(queryParameters: qp).query}',
      );
      if (response.statusCode == 200) {
        return SongPageDto.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      _logger.warning('Error fetching recommendations', e);
    }
    return SongPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<SongPageDto> getForgottenFavourites({
    int page = 0,
    int size = 10,
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    try {
      final response = await get(
        '/songs/forgotten?${Uri(queryParameters: qp).query}',
      );
      if (response.statusCode == 200) {
        return SongPageDto.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      _logger.warning('Error fetching forgotten favourites', e);
    }
    return SongPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<SongPageDto> getQuickDial({int page = 0, int size = 10}) async {
    final qp = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    try {
      final response = await get(
        '/songs/quick-dial?${Uri(queryParameters: qp).query}',
      );
      if (response.statusCode == 200) {
        return SongPageDto.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      _logger.warning('Error fetching quick dial', e);
    }
    return SongPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<SongPageDto> getFavourites({int page = 0, int size = 250}) async {
    final qp = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    try {
      final response = await get(
        '/songs/favourites?${Uri(queryParameters: qp).query}',
      );
      if (response.statusCode == 200) {
        return SongPageDto.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      _logger.warning('Error fetching favourites', e);
    }
    return SongPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<SongPageDto> getMostPlayed({int page = 0, int size = 50}) async {
    final qp = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    try {
      final response = await get(
        '/songs/most-played?${Uri(queryParameters: qp).query}',
      );
      if (response.statusCode == 200) {
        return SongPageDto.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      _logger.warning('Error fetching most played songs', e);
    }
    return SongPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<SongPageDto> getRecentlyPlayed({int page = 0, int size = 50}) async {
    final qp = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    try {
      final response = await get(
        '/songs/recently-played?${Uri(queryParameters: qp).query}',
      );
      if (response.statusCode == 200) {
        return SongPageDto.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      _logger.warning('Error fetching recently played songs', e);
    }
    return SongPageDto(
      content: const [],
      page: page,
      size: size,
      totalPages: 0,
      totalElements: 0,
    );
  }

  Future<SongDto?> updateSongLibraryEntry(
    String songFileHash,
    bool likedByUser,
    DateTime? lastPlayed,
    int playCount,
  ) async {
    try {
      final response = await patch('/songs/$songFileHash', {
        'likedByUser': likedByUser,
        'lastPlayed': lastPlayed?.toUtc().toIso8601String(),
        'playCount': playCount,
      });
      if (response.statusCode == 200) {
        return SongDto.fromJson(jsonDecode(response.body));
      } else {
        _logger.warning(
          'Failed to update song: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _logger.warning('Error updating song', e);
    }
    return null;
  }
}
