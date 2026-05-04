import 'package:music_player_frontend/core/dtos/playlists/playlist_song_dto.dart';

class PlaylistDetailDto {
  final int id;
  final String name;
  final List<PlaylistSongDto> playlistSongs;

  PlaylistDetailDto({
    required this.id,
    required this.name,
    required this.playlistSongs,
  });

  factory PlaylistDetailDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['playlistSongs'] as List<dynamic>? ?? []);
    return PlaylistDetailDto(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      playlistSongs: raw
          .map((e) => PlaylistSongDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
