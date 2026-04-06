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

  bool requiresSync = true;
  bool fullyLoaded = false;
  int pendingPlayCountDelta = 0;
  int pendingPlayDurationSeconds = 0;

  @Index()
  @Unique()
  final String _fileHash;

  String? path;
  String _name = 'Unknown Song';
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

  Song(this._fileHash) {
    assert(_fileHash.isNotEmpty, 'File hash cannot be empty');
  }

  @override
  String getName() {
    return _name;
  }

  void setName(String value) {
    _name = value;
  }

  @override
  String getHash() {
    return _fileHash;
  }

  @override
  bool isLocal() {
    return path != null && path!.isNotEmpty;
  }

  @override
  String getImageUrl() {
    return '/songs/$_fileHash/cover';
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

  @override
  bool operator ==(Object other) {
    if (other is! Song) return false;

    return _fileHash == other._fileHash;
  }

  @override
  int get hashCode {
    return _fileHash.hashCode;
  }

  List<Color> getColors() {
    if (album.target != null && album.target!.colors.isNotEmpty) {
      return album.target!.colors;
    }
    return [];
  }
}
