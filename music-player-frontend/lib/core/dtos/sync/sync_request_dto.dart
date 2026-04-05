import 'package:music_player_frontend/core/dtos/sync/song_sync_dto.dart';

class SyncRequestDto {
  final DateTime? lastSyncTime;
  final List<SongSyncDto> localChanges;

  SyncRequestDto({this.lastSyncTime, required this.localChanges});

  Map<String, dynamic> toJson() => {
    'lastSyncTime': lastSyncTime?.toIso8601String(),
    'localChanges': localChanges.map((e) => e.toJson()).toList(),
  };
}
