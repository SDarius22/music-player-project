import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';

@Entity()
class Album implements BaseEntity {
  @Id()
  int id = 0;

  bool requiresSync = false;

  @Index()
  @Unique()
  final String hash;

  final String name;
  int duration = 0;

  @Property(type: PropertyType.byteVector)
  Uint8List? imageBytes;

  @Transient()
  List<Color> colors = [];

  @Backlink('album')
  final ToMany<Song> songs = ToMany<Song>();
  final ToOne<Artist> artist = ToOne<Artist>();

  Album(this.hash, this.name);

  void addSong(Song song) {
    if (!songs.contains(song)) {
      songs.add(song);
      duration += song.durationInSeconds;
    }
  }

  List<Song> getSongs() {
    return List.unmodifiable(songs);
  }

  String getArtistName() {
    return artist.target?.getName() ?? 'Unknown Artist';
  }

  void setArtist(Artist artist) {
    this.artist.target = artist;
  }

  @override
  String getName() {
    return name;
  }

  @override
  String getSecondaryText() {
    return artist.target?.name ?? 'Unknown Artist';
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
    return imageBytes;
  }

  @override
  String getImageUrl() {
    return '/albums/$hash/cover';
  }

  int getDurationInSeconds() {
    return duration;
  }

  @override
  String toString() {
    return "Album{id: $id, hash: $hash, name: $name, artist: ${artist.target?.name}, songs: ${songs.length}}";
  }
}
