import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/sync/song_sync_dto.dart';
import 'package:music_player_frontend/core/dtos/sync/sync_response_dto.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class DataSyncClient extends AbstractRestClient {
  static final _logger = Logger('DataSyncClient');

  DataSyncClient({required String baseUrl, required AuthService authService}) {
    super.baseUrl = baseUrl;
    super.authService = authService;
  }

  Future<SyncResponseDto?> syncUserLibrary({
    required DateTime? lastSyncTime,
    required List<SongSyncDto> localChanges,
  }) async {
    try {
      final requestPayload = {
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'localChanges': localChanges.map((e) => e.toJson()).toList(),
      };

      final response = await post('/sync', requestPayload);

      if (response.statusCode == 200) {
        return SyncResponseDto.fromJson(jsonDecode(response.body));
      } else {
        _logger.warning('DataSyncService: Sync failed ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.warning('DataSyncService Error', e);
      return null;
    }
  }
}
