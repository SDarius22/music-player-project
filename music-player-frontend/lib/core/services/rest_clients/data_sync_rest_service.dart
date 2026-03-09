import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/dtos/song_sync_dto.dart';
import 'package:music_player_frontend/core/dtos/sync_response_dto.dart';
import 'package:music_player_frontend/core/services/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';

class DataSyncService extends AbstractRestService {
  DataSyncService({required String baseUrl, required AuthService authService}) {
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
        debugPrint("DataSyncService: Sync failed ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("DataSyncService Error: $e");
      return null;
    }
  }
}
