import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';

@Entity()
class Song implements BaseEntity {
  @Id(assignable: true)
  int id = 0;

  @Index()
  String fileHash = '';

  bool requiresSync = true;

  String path = "";
  String _name = "Unknown song";

  final artist = ToOne<Artist>();
  final album = ToOne<Album>();

  int durationInSeconds = 0;
  int trackNumber = 0;
  int discNumber = 0;
  int year = 0;

  bool fullyLoaded = false;
  bool likedByUser = false;

  @Property(type: PropertyType.dateNano)
  DateTime? lastPlayed;
  int playCount = 0;

  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  @override
  bool get isLocal => path.isNotEmpty;

  @override
  String get cloudId => fileHash;

  @override
  bool operator ==(Object other) {
    if (other is! Song) return false;

    if (fileHash.isNotEmpty && other.fileHash.isNotEmpty) {
      return fileHash == other.fileHash;
    }

    if (path.isNotEmpty && other.path.isNotEmpty) {
      return path == other.path;
    }

    return id != 0 && id == other.id;
  }

  @override
  int get hashCode {
    if (fileHash.isNotEmpty) return fileHash.hashCode;
    if (path.isNotEmpty) return path.hashCode;
    return id.hashCode;
  }

  Song();

  factory Song.fromJson(Map<String, dynamic> json) {
    Song song = Song();
    song.id = 0;
    song.fileHash = json['fileHash'] ?? '';
    song.name = json['name'] ?? "Unknown Song";
    song.path = "";
    song.durationInSeconds = json['durationInSeconds'] ?? 0;
    song.trackNumber = json['trackNumber'] ?? 0;
    song.discNumber = json['discNumber'] ?? 0;
    song.year = json['year'] ?? 0;
    song.fullyLoaded = true;

    if (json['artist'] != null) {
      song.artist.target = Artist.fromJson(
        json['artist'] as Map<String, dynamic>,
      );
    }
    if (json['album'] != null) {
      song.album.target = Album.fromJson(json['album'] as Map<String, dynamic>);
    }

    return song;
  }

  Map<String, dynamic> toJson() => {
    'fileHash': fileHash,
    'playCountDelta': playCount,
    'likedByUser': likedByUser,
    'lastPlayed': lastPlayed,
  };

  @override
  Uint8List? get coverArt => album.target?.coverArt;

  /// Song cover = its album's cover. Falls back to the album's imageUrl.
  @override
  String? get imageUrl =>
      fileHash.isNotEmpty ? '/songs/$fileHash/cover' : album.target?.imageUrl;

  List<Color> get colors {
    if (album.target != null && album.target!.colors.isNotEmpty) {
      return album.target!.colors;
    }
    return [];
  }
}
