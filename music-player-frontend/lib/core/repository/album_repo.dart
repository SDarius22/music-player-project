import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/album.dart';

class AlbumRepository {
  Box<Album> get _albumBox => ObjectBox.store.box<Album>();

  Album saveAlbum(Album album) {
    album.id = _albumBox.put(album);
    return album;
  }

  Stream watchAlbums() => _albumBox.query().watch(triggerImmediately: true);

  Album? getAlbum(int albumId) {
    return _albumBox.get(albumId);
  }

  List<Album> getAlbums(String query, String sortField, bool flag) {
    Query<Album> builderQuery;
    if (flag == false) {
      builderQuery = _albumBox
          .query(Album_.name.contains(query, caseSensitive: false))
          .order(Album_.name).build();
    } else {
      builderQuery = _albumBox
          .query(Album_.name.contains(query, caseSensitive: false))
          .order(Album_.name, flags: Order.descending)
          .build();
    }
    return builderQuery.find();
  }

  List<Album> getAllAlbums() {
    return _albumBox.getAll();
  }

  void deleteAlbum(Album album) {
    _albumBox.remove(album.id);
  }
}