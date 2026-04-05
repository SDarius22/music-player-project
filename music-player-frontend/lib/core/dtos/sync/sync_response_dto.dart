import 'package:music_player_frontend/core/dtos/sync/song_sync_dto.dart';

class SyncResponseDto {
  final DateTime newSyncTime;
  final List<SongSyncDto> serverChanges;

  SyncResponseDto.fromJson(Map<String, dynamic> json)
    : newSyncTime = DateTime.parse(json['newSyncTime']),
      serverChanges =
          (json['serverChanges'] as List)
              .map((e) => SongSyncDto.fromJson(e))
              .toList();
}
