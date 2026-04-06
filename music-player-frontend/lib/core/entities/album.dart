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
  final String _hash;

  final String _name;
  int _duration = 0;

  @Property(type: PropertyType.byteVector)
  Uint8List? imageBytes;

  @Transient()
  List<Color> colors = [];

  @Backlink('album')
  final ToMany<Song> _songs = ToMany<Song>();
  final ToOne<Artist> _artist = ToOne<Artist>();

  Album(this._hash, this._name, Artist artist, {List<Song> songs = const []}) {
    assert(_hash.isNotEmpty, 'Album hash cannot be empty');
    assert(_name.isNotEmpty, 'Album name cannot be empty');
    assert(artist.getName().isNotEmpty, 'Artist name cannot be empty');
    _artist.target = artist;
    for (var song in songs) {
      addSong(song);
    }
  }

  void addSong(Song song) {
    _songs.add(song);
    _duration += song.durationInSeconds;
  }

  List<Song> getSongs() {
    return List.unmodifiable(_songs);
  }

  String getArtistName() {
    return _artist.target?.getName() ?? 'Unknown Artist';
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
    return imageBytes;
  }

  @override
  String getImageUrl() {
    return '/albums/$_hash/cover';
  }

  int getDurationInSeconds() {
    return _duration;
  }

  @override
  String toString() {
    return "Album{name: $_name, hash: $_hash, songs: ${_songs.length}, artist: ${_artist.target?.getName() ?? 'Unknown Artist'}}";
  }
}
