import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';

class PlaylistSongDto {
  final SongDto song;
  final int position;

  PlaylistSongDto({required this.song, required this.position});

  factory PlaylistSongDto.fromJson(Map<String, dynamic> json) {
    return PlaylistSongDto(
      song: SongDto.fromJson(json['song'] as Map<String, dynamic>),
      position: (json['position'] as num).toInt(),
    );
  }
}
