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
  int _serverId = -1;

  @override
  int get serverId => _serverId;

  @override
  set serverId(int value) => _serverId = value;

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

  @Transient()
  int serverArtistId = 0;
  @Transient()
  int serverAlbumId = 0;

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
  bool operator ==(Object other) {
    if (isLocal) {
      return other is Song && other.path == path;
    }
    return other is Song && other.serverId == serverId && serverId != -1;
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
    song.serverArtistId = json['artistId'] ?? 0;
    song.serverAlbumId = json['albumId'] ?? 0;
    song.fullyLoaded = true;
    return song;
  }

  Map<String, dynamic> toJson() => {
    'songId': id,
    'playCountDelta': playCount,
    'likedByUser': likedByUser,
    'lastPlayed': lastPlayed,
  };

  @override
  Uint8List? get coverArt => album.target?.coverArt;

  List<Color> get colors {
    if (album.target != null && album.target!.colors.isNotEmpty) {
      return album.target!.colors;
    }
    return [];
  }
}
