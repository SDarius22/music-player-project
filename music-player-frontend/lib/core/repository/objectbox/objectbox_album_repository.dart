import 'package:music_player_frontend/core/database/object_box_store.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';

class ObjectBoxAlbumRepository implements AlbumRepository {
  Box<Album> get _albumBox => ObjectBox.store.box<Album>();

  @override
  Map<String, dynamic> get sortFields => {'Name': Album_.name};

  @override
  Album saveAlbum(Album album) {
    album.id = _albumBox.put(album);
    return album;
  }

  @override
  Album? getAlbumByHash(String albumHash) {
    return _albumBox.query(Album_.hash.equals(albumHash)).build().findFirst();
  }

  @override
  Album getOrCreateAlbum(String albumHash, String albumName, Artist artist) {
    final existing = getAlbumByHash(albumHash);
    if (existing != null) return existing;
    var album = Album(albumHash, albumName);
    album.setArtist(artist);
    return saveAlbum(album);
  }

  @override
  int getAlbumCount(String query, bool containLocalOnly) {
    var conditions = Album_.name.contains(query, caseSensitive: false);
    if (containLocalOnly) {
      conditions = conditions.and(Album_.isLocal.equals(true));
    }
    return _albumBox.query(conditions).build().count();
  }

  @override
  List<Album> getAlbumsPaged(
    String query,
    String sortField,
    bool ascending,
    bool containLocalOnly,
    int offset,
    int limit,
  ) {
    var conditions = Album_.name.contains(query, caseSensitive: false);
    if (containLocalOnly) {
      conditions = conditions.and(Album_.isLocal.equals(true));
    }
    final q =
        _albumBox
            .query(conditions)
            .order(
              sortFields.containsKey(sortField)
                  ? sortFields[sortField]
                  : Album_.name,
              flags: ascending ? 0 : Order.descending,
            )
            .build();
    q.offset = offset;
    q.limit = limit;
    return q.find();
  }

  @override
  void updateAlbum(Album album) {
    _albumBox.put(album);
  }

  @override
  void clearAll() {
    _albumBox.removeAll();
  }
}
