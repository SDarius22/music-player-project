import 'package:music_player_frontend/core/dtos/albums/album_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';

class SongDto {
  final String fileHash;
  final String name;
  final int durationInSeconds;
  final int trackNumber;
  final int discNumber;
  final int year;
  final ArtistDto artist;
  final AlbumDto album;
  final int playCount;
  final DateTime? lastPlayed;
  final bool likedByUser;

  SongDto({
    required this.fileHash,
    required this.name,
    required this.durationInSeconds,
    required this.trackNumber,
    required this.discNumber,
    required this.year,
    required this.artist,
    required this.album,
    required this.playCount,
    this.lastPlayed,
    required this.likedByUser,
  });

  int get releaseYear => year;

  factory SongDto.fromJson(Map<String, dynamic> json) {
    return SongDto(
      fileHash: json['fileHash'] as String,
      name: json['name'] as String,
      durationInSeconds: (json['durationInSeconds'] as num? ?? 0).toInt(),
      trackNumber: (json['trackNumber'] as num? ?? 0).toInt(),
      discNumber: (json['discNumber'] as num? ?? 0).toInt(),
      year: (json['year'] as num? ?? 0).toInt(),
      artist: ArtistDto.fromJson(json['artist'] as Map<String, dynamic>),
      album: AlbumDto.fromJson(json['album'] as Map<String, dynamic>),
      playCount: (json['playCount'] as num? ?? 0).toInt(),
      lastPlayed:
          json['lastPlayed'] != null
              ? DateTime.parse(json['lastPlayed'] as String)
              : null,
      likedByUser: json['likedByUser'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'fileHash': fileHash,
    'name': name,
    'durationInSeconds': durationInSeconds,
    'trackNumber': trackNumber,
    'discNumber': discNumber,
    'year': year,
    'artist': {'hash': artist.hash, 'name': artist.name},
    'album': {'hash': album.hash, 'name': album.name},
  };
}
