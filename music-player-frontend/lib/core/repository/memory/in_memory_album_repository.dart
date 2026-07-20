import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';

class InMemoryAlbumRepository implements AlbumRepository {
  final Map<int, Album> _byId = {};
  int _nextId = 1;

  @override
  Map<String, dynamic> get sortFields => const {'Name': null};

  @override
  Album saveAlbum(Album album) {
    if (album.id == 0) {
      album.id = _nextId++;
    } else if (album.id >= _nextId) {
      _nextId = album.id + 1;
    }
    _byId[album.id] = album;
    return album;
  }

  @override
  Album? getAlbumByHash(String hash) {
    for (final a in _byId.values) {
      if (a.getHash() == hash) return a;
    }
    return null;
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
    final q = query.toLowerCase();
    return _byId.values
        .where(
          (album) =>
              album.getName().toLowerCase().contains(q) &&
              (!containLocalOnly || album.isLocal),
        )
        .length;
  }

  List<Album> getAlbums(
    String query,
    String sortField,
    bool ascending, {
    bool localOnly = false,
  }) {
    final q = query.toLowerCase();
    final list =
        _byId.values
            .where(
              (album) =>
                  album.getName().toLowerCase().contains(q) &&
                  (!localOnly || album.isLocal),
            )
            .toList();
    list.sort((a, b) {
      final result = a.getName().compareTo(b.getName());
      return ascending ? result : -result;
    });
    return list;
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
    final all = getAlbums(
      query,
      sortField,
      ascending,
      localOnly: containLocalOnly,
    );
    if (offset >= all.length) return [];
    return all.sublist(offset, (offset + limit).clamp(0, all.length));
  }

  @override
  void updateAlbum(Album album) {
    saveAlbum(album);
  }

  @override
  void clearAll() {
    _byId.clear();
    _nextId = 1;
  }
}
