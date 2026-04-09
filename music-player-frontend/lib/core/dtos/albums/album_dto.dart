import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';

class AlbumDto {
  final String hash;
  final String name;
  final List<ArtistDto> artists;

  AlbumDto({required this.hash, required this.name, required this.artists});

  factory AlbumDto.fromJson(Map<String, dynamic> json) {
    return AlbumDto(
      hash: json['hash'] as String,
      name: json['name'] as String,
      artists:
          (json['artists'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => ArtistDto.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}
