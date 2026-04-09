import 'package:music_player_frontend/core/dtos/playlists/playlist_song_position_dto.dart';

class UpdatePlaylistDto {
  final String name;
  final List<PlaylistSongPositionDto> songFileHashes;
  final String coverImageBase64;

  UpdatePlaylistDto({
    required this.name,
    required this.songFileHashes,
    required this.coverImageBase64,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'songFileHashes': songFileHashes.map((e) => e.toJson()).toList(),
      'coverImage': coverImageBase64,
    };
  }
}
