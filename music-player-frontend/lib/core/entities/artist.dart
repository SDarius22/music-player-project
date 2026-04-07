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
  final String hash;

  @Unique()
  final String name;

  @Property(type: PropertyType.byteVector)
  Uint8List? imageBytes;

  @Backlink('artist')
  final _songs = ToMany<Song>();

  Artist(this.hash, this.name, {List<Song> songs = const []}) {
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
    return name;
  }

  @override
  String getHash() {
    return hash;
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
    return '/artists/$hash/image';
  }

  @override
  String toString() {
    return "Artist{name: $name, hash: $hash, songs: ${_songs.length}}";
  }
}
