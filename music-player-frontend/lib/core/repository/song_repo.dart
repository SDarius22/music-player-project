import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/song.dart';

class SongRepository {
  Box<Song> get _songBox => ObjectBox.store.box<Song>();

  Stream watchSongs() => _songBox
      .query()
      .watch(triggerImmediately: true)
      .map((query) => query.find());

  Map<String, dynamic> get sortFields => {
    'Title': Song_.name,
    'Duration': Song_.durationInSeconds,
    'Year': Song_.year,
  };

  Song saveSong(Song song) {
    song.id = _songBox.put(song);
    return song;
  }

  List<Song> saveSongs(List<Song> songs) {
    final ids = _songBox.putMany(songs);
    for (int i = 0; i < songs.length; i++) {
      songs[i].id = ids[i];
    }
    return songs;
  }

  int getSongCount() {
    return _songBox.count();
  }

  Song getSongByPath(String path) {
    try {
      return _songBox.query(Song_.path.equals(path)).build().findUnique()!;
    } catch (e) {
      throw Exception("Song with path $path not found");
    }
  }

  Song getSong(int id) {
    try {
      return _songBox.get(id)!;
    } catch (e) {
      throw Exception("Song with id $id not found");
    }
  }

  Song getSongContaining(String query) {
    try {
      return _songBox
          .query(Song_.path.contains(query, caseSensitive: false))
          .build()
          .findFirst()!;
    } catch (e) {
      throw Exception("Song containing $query not found");
    }
  }

  Song? getMostRecentPlayedSong() {
    return _songBox
        .query(Song_.lastPlayed.notNull())
        .order(Song_.lastPlayed, flags: Order.descending)
        .build()
        .findFirst();
  }

  List<Song> getRecentlyPlayedSongs(int limit) {
    var query =
        _songBox
            .query(Song_.lastPlayed.notNull())
            .order(Song_.lastPlayed, flags: Order.descending)
            .build();

    query.limit = limit;

    return query.find();
  }

  List<Song> getMostPlayedSongs(int limit) {
    var query =
        _songBox
            .query(Song_.playCount.greaterThan(0))
            .order(Song_.playCount, flags: Order.descending)
            .build();

    query.limit = limit;

    return query.find();
  }

  List<Song> getFavoriteSongs() {
    return _songBox.query(Song_.likedByUser.equals(true)).build().find();
  }

  List<Song> getSongs(String query, String sortField, bool flag) {
    Query<Song> builderQuery;
    if (flag == true) {
      builderQuery =
          _songBox
              .query(Song_.name.contains(query, caseSensitive: false))
              .order(
                sortFields.containsKey(sortField)
                    ? sortFields[sortField]
                    : Song_.name,
              )
              .build();
    } else {
      builderQuery =
          _songBox
              .query(Song_.name.contains(query, caseSensitive: false))
              .order(
                sortFields.containsKey(sortField)
                    ? sortFields[sortField]
                    : Song_.name,
                flags: Order.descending,
              )
              .build();
    }
    return builderQuery.find();
  }

  List<Song> getAllSongs() {
    return _songBox.query().order(Song_.name).build().find();
  }

  List<Song> getUnsyncedSongs() {
    return _songBox.query(Song_.requiresSync.equals(true)).build().find();
  }

  void markSongsAsSynced(List<int> serverIds) {
    for (int serverId in serverIds) {
      var song =
          _songBox.query(Song_.serverId.equals(serverId)).build().findFirst();
      if (song != null) {
        song.requiresSync = false;
        _songBox.put(song);
      }
    }
  }

  void deleteSong(Song song) {
    _songBox.remove(song.id);
  }

  void updateSong(Song song) {
    _songBox.put(song);
  }

  void updateSongs(List<Song> songs) {
    _songBox.putMany(songs);
  }
}
