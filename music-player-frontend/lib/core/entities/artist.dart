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
  final songs = ToMany<Song>();

  Artist(this.hash, this.name, {List<Song> songs = const []}) {
    for (var song in songs) {
      addSong(song);
    }
  }

  void addSong(Song song) {
    songs.add(song);
  }

  List<Song> getSongs() {
    return List.unmodifiable(songs);
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
    if (songs.isEmpty) {
      return false;
    }
    for (var song in songs) {
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
    for (var song in songs) {
      if (song.album.target != null && song.album.target!.imageBytes != null) {
        return song.album.target!.imageBytes;
      }
    }
    return null;
  }

  @override
  String getImageUrl() {
    return '/artists/$hash/cover';
  }

  @override
  String toString() {
    return "Artist{id: $id, hash: $hash, name: $name, songs: ${songs.length}}";
  }
}
