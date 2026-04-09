import 'package:flutter/cupertino.dart';
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
    debugPrint('Creating new album: $album');
    return saveAlbum(album);
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
  void updateAlbum(Album album) {
    _albumBox.put(album);
  }
}
