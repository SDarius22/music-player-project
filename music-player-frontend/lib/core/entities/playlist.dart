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

  @Index()
  @Unique()
  int serverId = -1;

  @override
  String get cloudId => serverId > 0 ? serverId.toString() : '';

  @override
  bool get isLocal {
    for (var song in _songs) {
      if (!song.isLocal) {
        return false;
      }
    }
    return true;
  }

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

  @override
  String? get imageUrl => serverId > 0 ? '/playlists/$serverId/cover' : null;

  List<String> songFileHashes = [];

  @Transient()
  List<String> serverSongFileHashes = [];

  List<Song> get songsList {
    try {
      return songFileHashes
          .map((hash) => songs.firstWhere((song) => song.fileHash == hash))
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
