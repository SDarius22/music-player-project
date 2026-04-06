import 'dart:typed_data';

import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';

@Entity()
class Artist implements BaseEntity {
  @Id()
  int id = 0;

  bool requiresSync = false;

  @Index()
  @Unique()
  final String _hash;

  @Unique()
  final String _name;

  @Property(type: PropertyType.byteVector)
  Uint8List? imageBytes;

  @Backlink('artist')
  final _songs = ToMany<Song>();

  Artist(this._hash, this._name, {List<Song> songs = const []}) {
    assert(_hash.isNotEmpty, 'Artist hash cannot be empty');
    assert(_name.isNotEmpty, 'Artist name cannot be empty');
    for (var song in songs) {
      addSong(song);
    }
  }

  void addSong(Song song) {
    _songs.add(song);
  }

  List<Song> getSongs() {
    return List.unmodifiable(_songs);
  }

  @override
  String getName() {
    return _name;
  }

  @override
  String getHash() {
    return _hash;
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
  Uint8List? getCoverArt() {
    if (imageBytes != null) {
      return imageBytes;
    }
    for (var song in _songs) {
      if (song.album.target != null && song.album.target!.imageBytes != null) {
        return song.album.target!.imageBytes;
      }
    }
    return null;
  }

  @override
  String getImageUrl() {
    return '/artists/$_hash/image';
  }

  @override
  String toString() {
    return "Artist{name: $_name, hash: $_hash, songs: ${_songs.length}}";
  }
}
