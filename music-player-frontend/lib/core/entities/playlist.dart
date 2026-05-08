import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
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
  int duration = -1;

  @Property(type: PropertyType.byteVector)
  Uint8List? imageBytes;

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  final songs = ToMany<Song>();
  List<String> songFileHashes = [];

  Playlist(this.name, {List<Song> songs = const []}) {
    for (var song in songs) {
      addSong(song);
    }
  }

  void addSong(Song song) {
    if (songFileHashes.contains(song.getHash())) {
      return;
    }
    songs.add(song);
    songFileHashes.add(song.getHash());
    duration += song.durationInSeconds;
  }

  void removeSong(Song song) {
    songs.remove(song);
    songFileHashes.remove(song.getHash());
    duration -= song.durationInSeconds;
  }

  void clearSongs() {
    songs.clear();
    songFileHashes.clear();
    duration = 0;
  }

  List<Song> getSongs() {
    debugPrint(
      "Getting songs for playlist '$name' with ${songFileHashes.length} song hashes",
    );
    return List.unmodifiable(
      songFileHashes.map(
        (hash) => songs.firstWhere((song) => song.getHash() == hash),
      ),
    );
  }

  @override
  String getName() {
    return name;
  }

  @override
  String getSecondaryText() {
    return "${songs.length} Songs";
  }

  void setName(String value) {
    name = value;
  }

  @override
  String getHash() {
    return serverId.toString();
  }

  @override
  bool get isLocal {
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

  set isLocal(bool value) {
    // No-op: Playlist's locality is determined by its songs
  }

  @override
  String getImageUrl() {
    return "/playlists/$serverId/cover";
  }

  @override
  Uint8List? getCoverArt() {
    return imageBytes;
  }

  int getDurationInSeconds() {
    return duration;
  }

  @override
  String toString() {
    return 'Playlist{id: $id, serverId: $serverId, name: $name, duration: $duration seconds, songs: ${songs.length}, songFileHashes: ${songFileHashes.length}, indestructible: $indestructible}';
  }
}
