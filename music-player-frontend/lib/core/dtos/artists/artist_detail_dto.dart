import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';

class ArtistDetailDto {
  final int id;
  final String name;
  final List<SongDto> songs;

  ArtistDetailDto({required this.id, required this.name, required this.songs});

  factory ArtistDetailDto.fromJson(Map<String, dynamic> json) {
    return ArtistDetailDto(
      id: (json['id'] as num? ?? 0).toInt(),
      name: json['name'] as String? ?? 'Unknown artist',
      songs:
          (json['songs'] as List<dynamic>? ?? const [])
              .map((e) => SongDto.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}
