import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';

class AlbumExpandedDto {
  final int id;
  final String name;
  final List<String> songFileHashes;
  final ArtistDto artist;

  AlbumExpandedDto({
    required this.id,
    required this.name,
    required this.songFileHashes,
    required this.artist,
  });

  factory AlbumExpandedDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        (json['songFileHashes'] as List<dynamic>? ?? const []);
    return AlbumExpandedDto(
      id: (json['id'] as num? ?? 0).toInt(),
      name: json['name'] as String? ?? 'Unknown album',
      songFileHashes: raw.map((e) => e as String).toList(),
      artist: ArtistDto.fromJson(json['artist'] as Map<String, dynamic>? ?? {}),
    );
  }
}
