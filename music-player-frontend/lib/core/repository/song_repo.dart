import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/song.dart';

class SongRepository {
  Box<Song> get _songBox => ObjectBox.store.box<Song>();

  Stream watchSongs() => _songBox.query().watch(triggerImmediately: true);

  Song saveSong(Song song) {
    song.id = _songBox.put(song);
    return song;
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

  List<Song> getSongs(String query, String sortField, bool flag) {
    Query<Song> builderQuery;
    if (flag == false) {
      builderQuery =
          _songBox
              .query(Song_.name.contains(query, caseSensitive: false))
              .order(sortField == 'Name' ? Song_.name : Song_.duration)
              .build();
    } else {
      builderQuery =
          _songBox
              .query(Song_.name.contains(query, caseSensitive: false))
              .order(
                sortField == 'Name' ? Song_.name : Song_.duration,
                flags: Order.descending,
              )
              .build();
    }
    return builderQuery.find();
  }

  List<Song> getAllSongs() {
    return _songBox.query().order(Song_.name).build().find();
  }

  void deleteSong(Song song) {
    _songBox.remove(song.id);
  }

  void updateSong(Song song) {
    _songBox.put(song);
  }

  List<Song> getFavoriteSongs() {
    return _songBox
        .query(Song_.liked.equals(true))
        .order(Song_.name)
        .build()
        .find();
  }
}
