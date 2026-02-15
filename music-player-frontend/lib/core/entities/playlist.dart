import 'dart:typed_data';

import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_collection.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Playlist with AbstractCollection implements BaseEntity {
  @Id(assignable: true)
  int id = 0;

  @Unique()
  String _name = "Unknown playlist";

  bool indestructible = false;

  String nextAdded = "last";

  @Property(type: PropertyType.byteVector)
  Uint8List imageBytes = Constants.logoBytes;

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  final _songs = ToMany<Song>();

  @override
  ToMany<Song> get songs => _songs;

  @override
  Uint8List get coverArt => imageBytes;

  List<int> songsIds = [];

  List<Song> get songsList {
    return songsIds
        .map((id) => songs.firstWhere((song) => song.id == id))
        .toList();
  }

  int _duration = -1;

  int get duration {
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
}
