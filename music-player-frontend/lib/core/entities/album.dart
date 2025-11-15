import 'dart:typed_data';

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

  String _name = "Unknown album";

  @Property(type: PropertyType.byteVector)
  Uint8List? imageBytes;

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

  get duration {
    int total = 0;
    for (var song in _songs) {
      total += song.duration;
    }
    return total;
  }

  @override
  String toString() {
    return name;
  }
}
