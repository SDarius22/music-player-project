import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';

class ArtistDetailDto {
  final String hash;
  final String name;
  final List<SongDto> songs;

  ArtistDetailDto({
    required this.hash,
    required this.name,
    required this.songs,
  });

  factory ArtistDetailDto.fromJson(Map<String, dynamic> json) {
    return ArtistDetailDto(
      hash: json['hash'] as String,
      name: json['name'] as String,
      songs:
          (json['songs'] as List<dynamic>)
              .map((e) => SongDto.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}
