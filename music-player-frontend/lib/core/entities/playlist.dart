import 'dart:typed_data';

import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_collection.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';

@Entity()
class Playlist with AbstractCollection implements BaseEntity {
  @Id(assignable: true)
  int id = 0;

  @Unique()
  String _name = "Unknown playlist";
  bool requiresSync = false;
  bool _isLocal = false;

  @Index()
  @Unique()
  int _serverId = -1;

  @override
  int get serverId => _serverId;

  @override
  set serverId(int value) => _serverId = value;

  @override
  bool get isLocal => _isLocal;

  @override
  set isLocal(bool value) => _isLocal = value;

  bool indestructible = false;

  String nextAdded = "last";

  @Property(type: PropertyType.byteVector)
  Uint8List? imageBytes;

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
  Uint8List? get coverArt => imageBytes;

  List<int> songsIds = [];

  List<Song> get songsList {
    try {
      return songsIds
          .map((id) => songs.firstWhere((song) => song.id == id))
          .toList();
    } catch (e) {
      return [];
    }
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
