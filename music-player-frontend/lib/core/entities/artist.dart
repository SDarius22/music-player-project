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
  int _serverId = -1;

  @override
  int get serverId => _serverId;

  @override
  set serverId(int value) => _serverId = value;

  bool requiresSync = false;
  bool _isLocal = false;

  @override
  bool get isLocal => _isLocal;

  @override
  set isLocal(bool value) => _isLocal = value;

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

  Artist();

  factory Artist.fromJson(Map<String, dynamic> json) {
    Artist artist = Artist();
    artist.id = 0;
    artist.name = json['name'] ?? "Unknown Artist";
    artist.serverId = json['id'] ?? -1;
    return artist;
  }

  @override
  ToMany<Song> get songs => _songs;

  @override
  String toString() {
    return name;
  }

  @override
  Uint8List? get coverArt => albums.isNotEmpty ? albums.first.coverArt : null;
}
