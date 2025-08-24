import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/song.dart';

class SongsRepository {
  get songBox => ObjectBox.store.box<Song>();

  void addSong(Song song) {
    songBox.put(song);
  }

  Stream watchAllSongs({bool triggerImmediately = true}) {
    final query = songBox.query();
    return query.watch();
  }

  Song? getSong(String path) {
    return songBox.query(Song_.path.equals(path)).build().findUnique();
  }

  Song? getSongContaining(String query) {
    if (query.isEmpty) {
      return null;
    }
    return songBox
        .query(Song_.path.contains(query, caseSensitive: false))
        .build()
        .findFirst();
  }

  List<Song> getSongs(String query, String sortField, bool flag) {
    Query<Song> builderQuery;
    if (flag == false) {
      builderQuery =
          songBox
              .query(
                Song_.name.contains(query, caseSensitive: false) |
                    Song_.trackArtist.contains(query, caseSensitive: false) |
                    Song_.album.contains(query, caseSensitive: false),
              )
              .order(sortField == 'Name' ? Song_.name : Song_.duration)
              .build();
    } else {
      builderQuery =
          songBox
              .query(Song_.name.contains(query, caseSensitive: false))
              .order(
                sortField == 'Name' ? Song_.name : Song_.duration,
                flags: Order.descending,
              )
              .build();
    }
    return builderQuery.find();
  }

  List<Song> getSongsFromPaths(List<String> paths) {
    if (paths.isEmpty) {
      return [];
    }
    List<Song> songs = [];
    for (String path in paths) {
      final song = getSong(path);
      if (song != null) {
        songs.add(song);
      }
    }
    return songs;
  }

  List<Song> getNonExistingSongs() {
    List<Song> allSongs = getAllSongs();
    List<Song> nonExistingSongs = [];
    for (Song song in allSongs) {
      if (song.existsExternally == false) {
        nonExistingSongs.add(song);
      }
    }
    return nonExistingSongs;
  }

  List<Song> getAllSongs() {
    return songBox.query().order(Song_.name).build().find();
  }

  void deleteSong(Song song) {
    songBox.remove(song.id);
  }

  void updateSong(Song song) {
    songBox.put(song);
  }

  List<Song> getFavoriteSongs() {
    return songBox
        .query(Song_.liked.equals(true))
        .order(Song_.name)
        .build()
        .find();
  }

  List<Song> getSongsWithLastPlayed() {
    Query<Song> query =
        songBox
            .query(Song_.lastPlayed.notNull())
            .order(Song_.lastPlayed, flags: Order.descending)
            .build();
    query.limit = 100;
    return query.find();
  }

  List<Song> getSongsWithPlayCount() {
    Query<Song> query =
        songBox
            .query(Song_.playCount.greaterThan(0))
            .order(Song_.playCount, flags: Order.descending)
            .build();
    query.limit = 100;
    return query.find();
  }
}
