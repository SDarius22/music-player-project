import 'dart:typed_data';
import 'dart:ui';

import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';

@Entity()
class Song implements BaseEntity {
  @Id()
  int id = 0;

  bool fullyLoaded = false;

  @Index()
  @Unique()
  final String fileHash;

  String? path;
  String name = 'Unknown Song';
  int durationInSeconds = 0;
  int trackNumber = 0;
  int discNumber = 0;
  int year = 0;

  final ToOne<Artist> artist = ToOne<Artist>();
  final ToOne<Album> album = ToOne<Album>();

  @Property(type: PropertyType.dateNano)
  DateTime? lastPlayed;
  int playCount = 0;
  bool likedByUser = false;

  Song(this.fileHash);

  @override
  String getName() {
    return name;
  }

  @override
  String getSecondaryText() {
    return artist.target?.name ?? 'Unknown Artist';
  }

  @override
  String getHash() {
    return fileHash;
  }

  @override
  bool get isLocal {
    return path != null && path!.isNotEmpty;
  }

  set isLocal(bool value) {
    // This setter is intentionally left blank. The isLocal property is derived from the presence of a valid path.
  }

  @override
  String getImageUrl() {
    return '/songs/$fileHash/cover';
  }

  @override
  Uint8List? getCoverArt() {
    if (album.target != null) {
      return album.target!.imageBytes;
    }
    if (artist.target != null) {
      return artist.target!.imageBytes;
    }
    return null;
  }

  List<Color> getColors() {
    if (album.target != null && album.target!.colors.isNotEmpty) {
      return album.target!.colors;
    }
    return [];
  }

  void updateFrom(Song other) {
    if (other.fileHash != fileHash) {
      throw ArgumentError(
        'Cannot update from a song with a different file hash',
      );
    }

    name = other.name;
    durationInSeconds = other.durationInSeconds;
    trackNumber = other.trackNumber;
    discNumber = other.discNumber;
    year = other.year;
    path = other.path;
    fullyLoaded = other.fullyLoaded;
    artist.target = other.artist.target;
    album.target = other.album.target;
  }

  @override
  bool operator ==(Object other) {
    if (other is! Song) return false;

    return fileHash == other.fileHash;
  }

  @override
  int get hashCode {
    return fileHash.hashCode;
  }

  @override
  String toString() {
    return 'Song{id: $id, fileHash: $fileHash, name: $name, artist: ${artist.target?.name}, album: ${album.target?.name}}';
  }
}
