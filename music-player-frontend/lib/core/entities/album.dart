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
  int _duration = 0;

  @Property(type: PropertyType.byteVector)
  Uint8List? imageBytes;

  @Transient()
  List<Color> colors = [];

  @Backlink('album')
  final ToMany<Song> _songs = ToMany<Song>();
  final ToOne<Artist> _artist = ToOne<Artist>();

  Album(this.hash, this.name);

  void addSong(Song song) {
    int index = _songs.indexWhere((s) {
      if (s.discNumber != song.discNumber) {
        return s.discNumber > song.discNumber;
      }
      return s.trackNumber > song.trackNumber;
    });
    if (index == -1) {
      _songs.add(song);
    } else {
      _songs.insert(index, song);
    }
    _duration += song.durationInSeconds;
  }

  List<Song> getSongs() {
    return List.unmodifiable(_songs);
  }

  String getArtistName() {
    return _artist.target?.getName() ?? 'Unknown Artist';
  }

  void setArtist(Artist artist) {
    _artist.target = artist;
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
    return imageBytes;
  }

  @override
  String getImageUrl() {
    return '/albums/$hash/cover';
  }

  int getDurationInSeconds() {
    return _duration;
  }

  @override
  String toString() {
    return "Album{name: $name, hash: $hash, songs: ${_songs.length}, artist: ${_artist.target?.getName() ?? 'Unknown Artist'}}";
  }
}
