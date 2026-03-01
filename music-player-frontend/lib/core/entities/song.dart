import 'dart:typed_data';
import 'dart:ui';

import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Song implements BaseEntity {
  @Id(assignable: true)
  int id = 0;

  @Unique()
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
  bool operator ==(Object other) =>
      other is Song && other.runtimeType == runtimeType && other.path == path;

  @override
  int get hashCode => path.hashCode;

  void fromJson(Map<String, dynamic> json) {
    path = json['path'] ?? "";
    name = json['title'] ?? "Unknown Song";
    durationInSeconds = json['duration'] ?? 0;
    trackNumber = json['trackNumber'] ?? 0;
    discNumber = json['discNumber'] ?? 0;
    year = json['year'] ?? 0;
  }

  @override
  Uint8List get coverArt => album.target?.coverArt ?? Constants.logoBytes;

  List<Color> get colors {
    if (album.target != null && album.target!.colors.isNotEmpty) {
      return album.target!.colors;
    }
    return [];
  }
}
