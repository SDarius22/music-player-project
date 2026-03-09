import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Song implements BaseEntity {
  @Id(assignable: true)
  int id = 0;

  @Index()
  int serverId = -1;
  bool requiresSync = false;

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
  bool operator ==(Object other) {
    if (path.isEmpty) {
      return other is Song && other.serverId == serverId && serverId != -1;
    }
    return other is Song && other.path == path;
  }

  @override
  int get hashCode => path.isEmpty ? serverId.hashCode : path.hashCode;

  Song();

  factory Song.fromJson(Map<String, dynamic> json) {
    Song song = Song();
    song.id = 0;
    song.serverId = json['id'] ?? -1;
    song.name = json['name'] ?? "Unknown Song";
    song.path = "";
    song.durationInSeconds = json['durationInSeconds'] ?? 0;
    song.trackNumber = json['trackNumber'] ?? 0;
    song.discNumber = json['discNumber'] ?? 0;
    song.year = json['year'] ?? 0;
    song.artist.target = Artist.fromJson(json['artist']);
    song.album.target = Album.fromJson(json['album']);

    return song;
  }

  void fromJson(Map<String, dynamic> json) {
    path = json['path'] ?? "";
    name = json['title'] ?? "Unknown Song";
    durationInSeconds = json['duration'] ?? 0;
    trackNumber = json['trackNumber'] ?? 0;
    discNumber = json['discNumber'] ?? 0;
    year = json['year'] ?? 0;
  }

  Map<String, dynamic> toJson() => {
    'songId': id,
    'playCountDelta': playCount,
    'likedByUser': likedByUser,
    'lastPlayed': lastPlayed,
  };

  @override
  Uint8List get coverArt => album.target?.coverArt ?? Constants.logoBytes;

  List<Color> get colors {
    if (album.target != null && album.target!.colors.isNotEmpty) {
      return album.target!.colors;
    }
    return [];
  }
}
