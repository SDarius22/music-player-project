import 'package:music_player_frontend/core/dtos/albums/album_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';

class SongDto {
  final String fileHash;
  final String name;
  final int durationInSeconds;
  final int trackNumber;
  final int discNumber;
  final int releaseYear;
  final ArtistDto artist;
  final AlbumDto album;

  SongDto({
    required this.fileHash,
    required this.name,
    required this.durationInSeconds,
    required this.trackNumber,
    required this.discNumber,
    required this.releaseYear,
    required this.artist,
    required this.album,
  });

  factory SongDto.fromJson(Map<String, dynamic> json) {
    return SongDto(
      fileHash: json['fileHash'] as String,
      name: json['name'] as String,
      durationInSeconds: (json['durationInSeconds'] as num? ?? 0).toInt(),
      trackNumber: (json['trackNumber'] as num? ?? 0).toInt(),
      discNumber: (json['discNumber'] as num? ?? 0).toInt(),
      releaseYear: (json['year'] as num? ?? 0).toInt(),
      artist: ArtistDto.fromJson(json['artist'] as Map<String, dynamic>),
      album: AlbumDto.fromJson(json['album'] as Map<String, dynamic>),
    );
  }
}
