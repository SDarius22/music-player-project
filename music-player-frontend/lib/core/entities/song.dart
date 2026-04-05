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
  @Unique()
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

  int pendingPlayCountDelta = 0;
  int pendingPlayDurationSeconds = 0;

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

  @override
  Uint8List? get coverArt => album.target?.coverArt;

  @override
  String? get imageUrl =>
      fileHash.isNotEmpty ? '/songs/$fileHash/cover' : album.target?.imageUrl;

  List<Color> get colors {
    if (album.target != null && album.target!.colors.isNotEmpty) {
      return album.target!.colors;
    }
    return [];
  }

  Song();

  factory Song.fromJson(Map<String, dynamic> json) {
    final song = Song();
    song.fileHash = json['fileHash'] as String? ?? '';
    song.name = json['name'] as String? ?? 'Unknown Song';
    song.durationInSeconds = (json['durationInSeconds'] as num? ?? 0).toInt();
    song.trackNumber = (json['trackNumber'] as num? ?? 0).toInt();
    song.discNumber = (json['discNumber'] as num? ?? 0).toInt();
    song.year = (json['year'] as num? ?? 0).toInt();
    song.fullyLoaded = true;
    final artistJson = json['artist'] as Map<String, dynamic>?;
    if (artistJson != null) {
      final artist = Artist();
      artist.id = (artistJson['id'] as num? ?? 0).toInt();
      artist.name = artistJson['name'] as String? ?? '';
      song.artist.target = artist;
    }
    final albumJson = json['album'] as Map<String, dynamic>?;
    if (albumJson != null) {
      final album = Album();
      album.id = (albumJson['id'] as num? ?? 0).toInt();
      album.name = albumJson['name'] as String? ?? '';
      song.album.target = album;
    }
    return song;
  }
}
