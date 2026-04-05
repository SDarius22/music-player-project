import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';

class PlaylistDetailDto {
  final int id;
  final String name;
  final List<SongDto> songs;
  final bool hasCover;

  PlaylistDetailDto({
    required this.id,
    required this.name,
    required this.songs,
    required this.hasCover,
  });

  factory PlaylistDetailDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['songs'] as List<dynamic>? ?? const []);
    return PlaylistDetailDto(
      id: (json['id'] as num? ?? 0).toInt(),
      name: json['name'] as String? ?? 'Unknown playlist',
      songs:
          raw
              .map((e) => SongDto.fromJson(e as Map<String, dynamic>? ?? {}))
              .toList(),
      hasCover: json['hasCover'] as bool? ?? false,
    );
  }
}
