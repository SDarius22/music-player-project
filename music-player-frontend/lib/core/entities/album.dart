import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';

@Entity()
class Album implements BaseEntity {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  final String hash;

  final String name;
  int duration = 0;

  @Property(type: PropertyType.byteVector)
  Uint8List? imageBytes;

  @Transient()
  List<Color> colors = [];

  @Transient()
  bool hasOfflineSource = false;

  @Transient()
  bool hasRemoteSource = false;

  @Transient()
  List<String> remoteSourceHashes = [];

  @Backlink('album')
  final ToMany<Song> songs = ToMany<Song>();
  final ToOne<Artist> artist = ToOne<Artist>();

  Album(this.hash, this.name);

  void addSong(Song song) {
    var existingSong = songs.firstWhereOrNull((s) => s == song);

    if (existingSong != null) {
      songs.remove(existingSong);
      duration -= existingSong.durationInSeconds;
    }

    songs.add(song);
    duration += song.durationInSeconds;
  }

  List<Song> getSongs() {
    songs.sort((a, b) {
      final discCompare = a.discNumber.compareTo(b.discNumber);
      if (discCompare != 0) {
        return discCompare;
      }
      final trackCompare = a.trackNumber.compareTo(b.trackNumber);
      if (trackCompare != 0) {
        return trackCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List.unmodifiable(songs);
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
  bool get isLocal {
    if (hasOfflineSource) return true;
    if (songs.isEmpty) {
      return false;
    }

    for (var song in songs) {
      if (song.isLocal) {
        return true;
      }
    }
    return false;
  }

  @override
  bool get isAvailableOffline => isLocal;

  @override
  bool get isAvailableToStream =>
      hasRemoteSource || songs.any((song) => song.isAvailableToStream);

  set isLocal(bool value) {
    // No-op: isLocal is derived from the songs, so we don't set it directly.
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
