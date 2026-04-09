import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';

class PlaylistDetailDto {
  final int id;
  final String name;
  final List<SongDto> songs;

  PlaylistDetailDto({
    required this.id,
    required this.name,
    required this.songs,
  });

  factory PlaylistDetailDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['songs'] as List<dynamic>);
    return PlaylistDetailDto(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      songs:
          raw.map((e) => SongDto.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
