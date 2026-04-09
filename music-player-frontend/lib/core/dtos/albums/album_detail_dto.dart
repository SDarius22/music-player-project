import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';

class AlbumDetailDto {
  final String hash;
  final String name;
  final List<SongDto> songs;
  final List<ArtistDto> artists;

  AlbumDetailDto({
    required this.hash,
    required this.name,
    required this.songs,
    required this.artists,
  });

  factory AlbumDetailDto.fromJson(Map<String, dynamic> json) {
    return AlbumDetailDto(
      hash: json['hash'] as String,
      name: json['name'] as String,
      songs:
          (json['songs'] as List<dynamic>)
              .map((e) => SongDto.fromJson(e as Map<String, dynamic>))
              .toList(),
      artists:
          (json['artists'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => ArtistDto.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}
