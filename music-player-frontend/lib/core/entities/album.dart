import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_collection.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Album with AbstractCollection implements BaseEntity {
  @Id()
  int id = 0;

  @Index()
  int serverId = -1;
  bool requiresSync = false;

  String _name = "Unknown album";

  @Property(type: PropertyType.byteVector)
  Uint8List? imageBytes;

  @Transient()
  List<Color> colors = [];

  @Backlink('album')
  final _songs = ToMany<Song>();
  final artist = ToOne<Artist>();

  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  @override
  ToMany<Song> get songs => _songs;

  @override
  Uint8List get coverArt => imageBytes ?? Constants.logoBytes;

  int _duration = -1;

  int get durationInSeconds {
    if (_duration != -1) {
      return _duration;
    }
    int total = 0;
    for (var song in _songs) {
      total += song.durationInSeconds;
    }
    _duration = total;
    return total;
  }

  @override
  String toString() {
    return name;
  }

  Album();

  factory Album.fromJson(Map<String, dynamic> json) {
    Album album = Album();
    album.id = 0;
    album.name = json['name'] ?? "Unknown Album";
    album.serverId = json['id'] ?? -1;
    if (json['photo'] != null) {
      debugPrint("Decoded image for album ${album.name} (${album.serverId})");
      debugPrint("Image size: ${json['photo'].length} bytes");
      album.imageBytes = Uint8List.fromList(base64Decode(json['photo']));
    }
    return album;
  }
}
