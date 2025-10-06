import 'dart:typed_data';

import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/abstract/mixin_collection.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Artist with AbstractCollection implements BaseEntity {
  @Id()
  int id = 0;

  @Unique()
  String _name = "Unknown artist";

  @Backlink('artist')
  final _songs = ToMany<Song>();

  @Backlink('artist')
  final albums = ToMany<Album>();

  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  @override
  ToMany<Song> get songs => _songs;

  @override
  String toString() {
    return name;
  }

  @override
  Uint8List get coverArt =>
      albums.isNotEmpty ? albums.first.coverArt : Constants.logoBytes;
}
