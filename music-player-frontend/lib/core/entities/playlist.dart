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
    if (_containsSongIdentity(song)) {
      return;
    }
    if (_isPersistable(song)) songs.add(song);
    songFileHashes.add(song.getHash());
    duration += song.durationInSeconds;
  }

  void insertSongAt(Song song, int index) {
    if (_containsSongIdentity(song)) {
      return;
    }
    if (_isPersistable(song)) songs.add(song);
    songFileHashes.insert(index, song.getHash());
    duration += song.durationInSeconds;
  }

  static bool _isPersistable(Song song) =>
      song.fileHash.isNotEmpty && song.localSourceKey == null;

  void removeSong(Song song) {
    songs.remove(song);
    final removed = songFileHashes.remove(song.getHash());
    final removedRemote = song.potentialRemoteHashes.any(
      songFileHashes.contains,
    );
    songFileHashes.removeWhere(song.potentialRemoteHashes.contains);
    if (removed || removedRemote) {
      duration -= song.durationInSeconds;
    }
  }

  bool _containsSongIdentity(Song song) =>
      songFileHashes.contains(song.getHash()) ||
      song.potentialRemoteHashes.any(songFileHashes.contains);

  void clearSongs() {
    songs.clear();
    songFileHashes.clear();
    duration = 0;
  }

  List<Song> getSongs() {
    final byHash = {for (final song in songs) song.getHash(): song};
    return List.unmodifiable([
      for (final hash in songFileHashes)
        if (byHash[hash] != null) byHash[hash]!,
    ]);
  }

  @override
  String getName() {
    return name;
  }

  @override
  String getSecondaryText() {
    return "${songFileHashes.length} Songs";
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

  @override
  bool get isAvailableOffline => isLocal;

  @override
  bool get isAvailableToStream => serverId >= 0;

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
