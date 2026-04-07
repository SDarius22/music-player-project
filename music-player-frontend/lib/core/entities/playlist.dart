import 'dart:typed_data';

import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';

@Entity()
class Playlist implements BaseEntity {
  @Id()
  int id = 0;

  bool requiresSync = false;
  bool indestructible = false;

  @Index()
  int serverId = -1;

  @Unique()
  String name;
  int _duration = -1;

  @Property(type: PropertyType.byteVector)
  Uint8List? imageBytes;

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  final _songs = ToMany<Song>();
  final List<String> _songFileHashes = [];

  Playlist(this.name, {List<Song> songs = const []}) {
    for (var song in songs) {
      addSong(song);
    }
  }

  void addSong(Song song) {
    _songs.add(song);
    _songFileHashes.add(song.getHash());
    _duration += song.durationInSeconds;
  }

  void removeSong(Song song) {
    _songs.remove(song);
    _songFileHashes.remove(song.getHash());
    _duration -= song.durationInSeconds;
  }

  void clearSongs() {
    _songs.clear();
    _songFileHashes.clear();
    _duration = 0;
  }

  List<Song> getSongs() {
    return List.unmodifiable(
      _songFileHashes.map(
        (hash) => _songs.firstWhere((song) => song.getHash() == hash),
      ),
    );
  }

  @override
  String getName() {
    return name;
  }

  void setName(String value) {
    name = value;
  }

  @override
  String getHash() {
    return serverId.toString();
  }

  @override
  bool isLocal() {
    if (_songs.isEmpty) {
      return false;
    }
    for (var song in _songs) {
      if (!song.isLocal()) {
        return false;
      }
    }
    return true;
  }

  @override
  String getImageUrl() {
    return "/playlist/$serverId/cover";
  }

  @override
  Uint8List? getCoverArt() {
    return imageBytes;
  }

  int getDurationInSeconds() {
    return _duration;
  }

  @override
  String toString() {
    return 'Playlist{id: $id, serverId: $serverId, name: $name, duration: $_duration seconds, songs: ${_songs.length}}';
  }
}
