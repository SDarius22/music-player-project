import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/album.dart';

class AlbumRepository {
  Box<Album> get _albumBox => ObjectBox.store.box<Album>();

  Stream watchAlbums() => _albumBox.query().watch(triggerImmediately: true);

  Map<String, dynamic> get sortFields => {'Name': Album_.name};

  Album saveAlbum(Album album) {
    album.id = _albumBox.put(album);
    return album;
  }

  Album? getAlbum(int albumId) {
    return _albumBox.get(albumId);
  }

  Album? getAlbumByName(String albumName) {
    return _albumBox.query(Album_.name.equals(albumName)).build().findUnique();
  }

  List<Album> getAlbums(String query, String sortField, bool flag) {
    Query<Album> builderQuery;
    if (flag == true) {
      builderQuery =
          _albumBox
              .query(Album_.name.contains(query, caseSensitive: false))
              .order(
                sortFields.containsKey(sortField)
                    ? sortFields[sortField]
                    : Album_.name,
              )
              .build();
    } else {
      builderQuery =
          _albumBox
              .query(Album_.name.contains(query, caseSensitive: false))
              .order(
                sortFields.containsKey(sortField)
                    ? sortFields[sortField]
                    : Album_.name,
                flags: Order.descending,
              )
              .build();
    }
    return builderQuery.find();
  }

  List<Album> getAllAlbums() {
    return _albumBox.getAll();
  }

  void updateAlbum(Album album) {
    _albumBox.put(album);
  }
}
