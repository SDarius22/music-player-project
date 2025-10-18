import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/playlist_song.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Playlist implements BaseEntity {
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

  @override
  Uint8List get coverArt => imageBytes;

  final playlistSongs = ToMany<PlaylistSong>();

  List<Song> get songsInOrder =>
      playlistSongs
          .sorted((a, b) => a.order.compareTo(b.order))
          .map((e) => e.song.target!)
          .toList();
}
