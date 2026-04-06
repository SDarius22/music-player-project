import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';

class AlbumExpandedDto {
  final String hash;
  final String name;
  final List<String> songFileHashes;
  final ArtistDto artist;

  AlbumExpandedDto({
    required this.hash,
    required this.name,
    required this.songFileHashes,
    required this.artist,
  });

  factory AlbumExpandedDto.fromJson(Map<String, dynamic> json) {
    final List<String> raw = (json['songFileHashes'] as List<String>);
    return AlbumExpandedDto(
      hash: json['hash'] as String,
      name: json['name'] as String,
      songFileHashes: raw,
      artist: ArtistDto.fromJson(json['artist'] as Map<String, dynamic>),
    );
  }
}
