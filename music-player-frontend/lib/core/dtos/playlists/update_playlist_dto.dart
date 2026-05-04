import 'package:music_player_frontend/core/dtos/playlists/playlist_song_position_dto.dart';

class UpdatePlaylistDto {
  final String? name;
  final List<PlaylistSongPositionDto>? playlistSongs;
  final String? coverImageBase64;

  UpdatePlaylistDto({this.name, this.playlistSongs, this.coverImageBase64});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'playlistSongs': playlistSongs?.map((e) => e.toJson()).toList(),
      'coverImage': coverImageBase64,
    };
  }
}
