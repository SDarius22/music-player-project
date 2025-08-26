import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/song.dart';

class SongsRepository {
  Box<Song> get _songBox => ObjectBox.store.box<Song>();

  Song saveSong(Song song)  {
    song.id = _songBox.put(song);
    return song;
  }

  Stream watchSongs() => _songBox.query().watch(triggerImmediately: true);

  Song? getSongByPath(String path)  {
    return _songBox.query(Song_.path.equals(path)).build().findUnique();
  }

  Song? getSong(int id)  {
    return _songBox.get(id);
  }

  Song? getSongContaining(String query)  {
    return _songBox.query(Song_.path.contains(query, caseSensitive: false)).build().findFirst();
  }

  List<Song> getSongs(String query, String sortField, bool flag)  {
    Query<Song> builderQuery;
    if (flag == false) {
      builderQuery = _songBox
          .query(Song_.name.contains(query, caseSensitive: false))
          .order(
        sortField == 'Name' ? Song_.name : Song_.duration,
      ).build();
    }
    else {
      builderQuery = _songBox
          .query(Song_.name.contains(query, caseSensitive: false))
          .order(
        sortField == 'Name' ? Song_.name : Song_.duration,
        flags: Order.descending,
      ).build();
    }
    return builderQuery.find();
  }

  List<Song> getAllSongs()  {
    return _songBox.query().order(Song_.name).build().find();
  }

  void deleteSong(Song song)  {
    _songBox.remove(song.id);
  }

  List<Song> getFavoriteSongs()  {
    return _songBox.query(Song_.liked.equals(true)).order(Song_.name).build().find();
  }

  List<Song> getSongsWithLastPlayed()  {
    Query<Song> query = _songBox.query(Song_.lastPlayed.notNull()).order(Song_.lastPlayed, flags: Order.descending).build();
    query.limit = 50;
    return query.find();
  }

  List<Song> getSongsWithPlayCount()  {
    Query<Song> query = _songBox.query(Song_.playCount.greaterThan(0)).order(Song_.playCount, flags: Order.descending).build();
    query.limit = 50;
    return query.find();
  }
}