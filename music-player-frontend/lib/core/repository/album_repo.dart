import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/album.dart';

class AlbumRepository {
  get albumBox => ObjectBox.store.box<Album>();

  void addAlbum(Album album) {
    albumBox.put(album);
  }

  Stream watchAllAlbums() {
    final query = albumBox.query();
    return query.watch();
  }

  Album? getAlbum(String name) {
    return albumBox.query(Album_.name.equals(name)).build().findUnique();
  }

  List<Album> getAlbums(String query, String sortField, bool flag) {
    Query<Album> builderQuery;
    if (flag == false) {
      builderQuery =
          albumBox
              .query(Album_.name.contains(query, caseSensitive: false))
              .order(sortField == 'Name' ? Album_.name : Album_.duration)
              .build();
    } else {
      builderQuery =
          albumBox
              .query(Album_.name.contains(query, caseSensitive: false))
              .order(
                sortField == 'Name' ? Album_.name : Album_.duration,
                flags: Order.descending,
              )
              .build();
    }
    return builderQuery.find();
  }

  List<Album> getAllAlbums() {
    return albumBox.query().order(Album_.name).build().find();
  }

  void deleteAlbum(Album album) {
    albumBox.remove(album.id);
  }

  void updateAlbum(Album album) {
    albumBox.put(album);
  }
}
