import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/album.dart';

class AlbumService {
  Box<Album> get _albumBox => ObjectBox.store.box<Album>();

  Stream watchAlbums() => _albumBox.query().watch(triggerImmediately: true);

  Album addAlbum(String name) {
    Album album = Album();
    album.name = name;
    album.id = _albumBox.put(album);
    return album;
  }

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

  void updateAlbum(Album album) {
    _albumBox.put(album);
  }
}