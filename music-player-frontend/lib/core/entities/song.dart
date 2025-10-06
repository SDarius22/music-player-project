import 'dart:typed_data';

import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Song implements BaseEntity {
  @Id()
  int id = 0;

  @Unique()
  String path = "";

  String lyricsPath = "";

  String _name = "Unknown song";

  final artist = ToOne<Artist>();
  final album = ToOne<Album>();

  int duration = 0; // in seconds
  int trackNumber = 0;
  int discNumber = 0;
  int year = 0;

  bool liked = false;
  bool fullyLoaded = false;

  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  @override
  bool operator ==(Object other) =>
      other is Song && other.runtimeType == runtimeType && other.path == path;

  @override
  int get hashCode => path.hashCode;

  void fromJson(Map<String, dynamic> json) {
    path = json['path'] ?? "";
    lyricsPath = json['lyricsPath'] ?? "";
    name = json['title'] ?? "Unknown Song";
    duration = json['duration'] ?? 0;
    trackNumber = json['trackNumber'] ?? 0;
    discNumber = json['discNumber'] ?? 0;
    year = json['year'] ?? 0;
  }

  @override
  Uint8List get coverArt => album.target?.coverArt ?? Constants.logoBytes;
}
