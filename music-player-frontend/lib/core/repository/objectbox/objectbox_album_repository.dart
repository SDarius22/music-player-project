import 'package:music_player_frontend/core/database/object_box_store.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';

class ObjectBoxAlbumRepository implements AlbumRepository {
  Box<Album> get _albumBox => ObjectBox.store.box<Album>();

  @override
  Stream watchAlbums() => _albumBox.query().watch(triggerImmediately: true);

  @override
  Map<String, dynamic> get sortFields => {'Name': Album_.name};

  @override
  Album saveAlbum(Album album) {
    album.id = _albumBox.put(album);
    return album;
  }

  @override
  Album? getAlbum(int albumId) {
    return _albumBox.get(albumId);
  }

  @override
  Album? getAlbumByName(String albumName) {
    return _albumBox.query(Album_.name.equals(albumName)).build().findFirst();
  }

  @override
  Album? getAlbumByNameAndArtistName(String albumName, String artistName) {
    final candidates =
        _albumBox.query(Album_.name.equals(albumName)).build().find();
    for (final album in candidates) {
      if (album.artist.target?.name == artistName) return album;
    }
    return null;
  }

  @override
  Album? getAlbumByServerId(int serverId) {
    return _albumBox
        .query(Album_.serverId.equals(serverId))
        .build()
        .findFirst();
  }

  @override
  Album getOrCreateAlbumByServerId(int serverId) {
    final existingAlbum = getAlbumByServerId(serverId);
    if (existingAlbum != null) {
      return existingAlbum;
    }
    Album newAlbum = Album();
    newAlbum.serverId = serverId;
    return saveAlbum(newAlbum);
  }

  @override
  List<Album> getAlbums(String query, String sortField, bool ascending) {
    Query<Album> builderQuery;
    if (ascending) {
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

  @override
  List<Album> getAlbumsPaged(
    String query,
    String sortField,
    bool ascending,
    int offset,
    int limit,
  ) {
    final q =
        _albumBox
            .query(Album_.name.contains(query, caseSensitive: false))
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
  List<Album> getAllAlbums() {
    return _albumBox.getAll();
  }

  @override
  void updateAlbum(Album album) {
    _albumBox.put(album);
  }
}
