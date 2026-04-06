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
  @Unique()
  int serverId = -1;

  @Unique()
  String _name;
  int _duration = -1;

  @Property(type: PropertyType.byteVector)
  Uint8List? imageBytes;

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  final _songs = ToMany<Song>();
  final List<String> _songFileHashes = [];

  Playlist(this.serverId, this._name, {List<Song> songs = const []}) {
    assert(_name.isNotEmpty, 'Playlist name cannot be empty');
    for (var song in songs) {
      addSong(song);
    }
  }

  void addSong(Song song) {
    _songs.add(song);
    _songFileHashes.add(song.getHash());
    _duration += song.durationInSeconds;
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
    return _name;
  }

  void setName(String value) {
    _name = value;
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
    return 'Playlist{id: $id, serverId: $serverId, name: $_name, duration: $_duration seconds, songs: ${_songs.length}}';
  }
}
