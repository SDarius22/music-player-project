import 'dart:typed_data';

import 'package:music_player_frontend/core/entities/abstract/abstract_collection.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Playlist extends AbstractEntity with AbstractCollection {
  @Id()
  int id = 0;

  @Unique()
  String _name = "Unknown playlist";

  // Override the abstract getter
  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  bool indestructible = false;

  int duration = 0; // in seconds

  String nextAdded = "last";
  List<String> pathsInOrder = [];
  List<String> artistCount = []; // Strings of form "Artist - Count"

  @Property(type: PropertyType.byteVector)
  Uint8List? coverArt;

  @Property(type: PropertyType.date) // milliseconds since epoch
  DateTime createdAt = DateTime.now();

  final _songs = ToMany<Song>();

  @override
  ToMany<Song> get songs => _songs;
}
