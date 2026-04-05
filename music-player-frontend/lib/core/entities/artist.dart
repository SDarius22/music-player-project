import 'dart:typed_data';

import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_collection.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';

@Entity()
class Artist with AbstractCollection implements BaseEntity {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  int serverId = -1;

  @override
  String get cloudId => serverId > 0 ? serverId.toString() : '';

  bool requiresSync = false;

  @override
  bool get isLocal {
    for (var song in _songs) {
      if (!song.isLocal) {
        return false;
      }
    }
    return true;
  }

  @Unique()
  String _name = "Unknown artist";

  @Backlink('artist')
  final _songs = ToMany<Song>();

  @Backlink('artist')
  final albums = ToMany<Album>();

  @Transient()
  List<String> serverSongFileHashes = [];

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
  Uint8List? get coverArt => albums.isNotEmpty ? albums.first.coverArt : null;

  @override
  String? get imageUrl => serverId > 0 ? '/artists/$serverId/cover' : null;
}
